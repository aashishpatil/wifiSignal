//
// Copyright 2026 Aashish Patil
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import CoreWLAN
import CoreLocation
import Combine
import SwiftUI

public struct SignalHistoryEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let rssi: Double
    public let noise: Double
    public let snr: Double
    public let latencyMs: Double?
    public let qualityScore: Double
}

@MainActor
public final class WiFiMonitor: ObservableObject {
    public static let shared = WiFiMonitor()
    
    // Core Services
    private let wifiClient = CWWiFiClient.shared()
    public let prober = GatewayProber()
    public let scanner = NetworkScanner()
    public let diagnosticRunner = DiagnosticRunner()
    public let locationHelper = LocationPermissionHelper.shared
    
    // Published State
    @Published public var currentMetrics: WiFiMetrics = WiFiMetrics()
    @Published public var history: [SignalHistoryEntry] = []
    @Published public var optimizationAdvice: [OptimizationAdvice] = []
    @Published public var roamEvents: [RoamEvent] = []
    @Published public var surveyPoints: [RoomSurveyPoint] = [] {
        didSet {
            saveSurveyPoints()
        }
    }
    @Published public var isMonitoring: Bool = false
    @Published public var lastUpdateTimestamp: Date = Date()
    
    // Configuration & Telemetry Delta Tracking
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryEntries = 120 // ~60 seconds at 500ms interval
    private let maxRoamEvents = 50
    private let surveyStorageKey = "com.wifisignal.surveyPoints"
    private var lastCounters: InterfaceCounters?
    private var lastCounterTimestamp: Date?
    private var pollTickCount: Int = 0
    private var cachedVPNState: (isVPNActive: Bool, vpnInterface: String?, isProxyActive: Bool) = (false, nil, false)
    
    public init() {
        loadSurveyPoints()
        setupSubscriptions()
        // Request location authorization to unlock SSID and scan access
        locationHelper.requestPermission()
        startMonitoring()
    }
    
    private func setupSubscriptions() {
        // Forward child ObservableObject changes so SwiftUI views observing WiFiMonitor stay in sync
        prober.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        scanner.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.optimizationAdvice = OptimizationEngine.analyze(
                    metrics: self.currentMetrics,
                    channelUtilizations: self.scanner.channelUtilizations,
                    scannedNetworks: self.scanner.scannedNetworks,
                    roamEvents: self.roamEvents
                )
            }
            .store(in: &cancellables)
        
        locationHelper.$authorizationStatus
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.pollWiFiMetrics()
                self.triggerScan()
            }
            .store(in: &cancellables)
    }
    
    private func loadSurveyPoints() {
        guard let data = UserDefaults.standard.data(forKey: surveyStorageKey),
              let decoded = try? JSONDecoder().decode([RoomSurveyPoint].self, from: data) else {
            return
        }
        self.surveyPoints = decoded
    }
    
    private func saveSurveyPoints() {
        if let encoded = try? JSONEncoder().encode(surveyPoints) {
            UserDefaults.standard.set(encoded, forKey: surveyStorageKey)
        }
    }
    
    public func startMonitoring(interval: TimeInterval = 0.5) {
        stopMonitoring()
        isMonitoring = true
        
        // Start gateway prober
        prober.startProbing(interval: 1.0)
        
        // Immediate first poll
        pollWiFiMetrics()
        
        // Periodic telemetry timer
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollWiFiMetrics()
            }
        }
        
        // Trigger initial network scan
        triggerScan()
    }
    
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        prober.stopProbing()
        isMonitoring = false
    }
    
    public func triggerScan() {
        let iface = wifiClient.interface()
        scanner.performScan(
            interface: iface,
            currentSSID: currentMetrics.ssid,
            currentBSSID: currentMetrics.bssid,
            currentChannel: currentMetrics.channelNumber
        )
    }
    
    public func pollWiFiMetrics() {
        pollTickCount &+= 1
        let now = Date()
        
        guard let iface = wifiClient.interface() else {
            if currentMetrics.isConnected {
                prober.refreshGatewayIP(resetHistory: true)
                recordRoamEvent(RoamEvent(
                    kind: .disconnected,
                    fromBSSID: currentMetrics.bssid,
                    toBSSID: nil,
                    channel: currentMetrics.channelNumber,
                    band: currentMetrics.channelBand.rawValue,
                    summary: "Disconnected from \(currentMetrics.ssid ?? "Wi-Fi")"
                ))
            }
            lastCounters = nil
            lastCounterTimestamp = nil
            self.currentMetrics = WiFiMetrics(isConnected: false)
            return
        }
        
        let ifaceName = iface.interfaceName ?? "en0"
        let rssiVal = iface.rssiValue()
        let rawNoise = iface.noiseMeasurement()
        let noiseVal = (rawNoise < 0) ? rawNoise : -95
        let ch = iface.wlanChannel()
        let chNum = ch?.channelNumber ?? 0
        let chBand = ch != nil ? ChannelBand.from(cwBand: ch!.channelBand) : .unknown
        let chWidth = ch != nil ? ChannelWidth.from(cwWidth: ch!.channelWidth) : .unknown
        let phyMode = WiFiPHYMode.from(cwMode: iface.activePHYMode())
        let txRate = iface.transmitRate()
        let ssidName = iface.ssid()
        let bssidAddr = iface.bssid()
        
        let isAssociated = (rssiVal != 0 && chNum != 0)
        let isDFSChannel = ch?.description.contains("DFS") ?? false
        
        // Interface traffic & error delta
        var trafficMbps = 0.0
        var inErrors: UInt32 = 0
        var outErrors: UInt32 = 0
        if let counters = InterfaceInspector.readCounters(for: ifaceName) {
            inErrors = counters.inputErrors
            outErrors = counters.outputErrors
            if let prev = lastCounters, let prevTime = lastCounterTimestamp {
                let dt = now.timeIntervalSince(prevTime)
                if dt > 0.1 && counters.totalBytes >= prev.totalBytes {
                    let deltaBytes = counters.totalBytes - prev.totalBytes
                    trafficMbps = (Double(deltaBytes) * 8.0) / dt / 1_000_000.0
                }
            }
            lastCounters = counters
            lastCounterTimestamp = now
        }
        
        // Detect network / AP changes
        let networkChanged = (isAssociated != currentMetrics.isConnected)
            || (ssidName != nil && ssidName != currentMetrics.ssid)
            || (bssidAddr != nil && bssidAddr != currentMetrics.bssid)
        if networkChanged {
            prober.refreshGatewayIP(resetHistory: true)
        }
        
        // Refresh VPN/Proxy detection periodically or on network transition
        if pollTickCount == 1 || pollTickCount % 4 == 0 || networkChanged {
            cachedVPNState = InterfaceInspector.detectVPNAndProxy()
        }
        
        // Record Roam / Channel-Hop / Disconnect events (skip initial startup sample)
        if !history.isEmpty {
            if currentMetrics.isConnected && !isAssociated {
                recordRoamEvent(RoamEvent(
                    kind: .disconnected,
                    fromBSSID: currentMetrics.bssid,
                    toBSSID: nil,
                    channel: currentMetrics.channelNumber,
                    band: currentMetrics.channelBand.rawValue,
                    summary: "Link dropped from Ch \(currentMetrics.channelNumber)"
                ))
            } else if !currentMetrics.isConnected && isAssociated {
                recordRoamEvent(RoamEvent(
                    kind: .reconnected,
                    fromBSSID: nil,
                    toBSSID: bssidAddr,
                    channel: chNum,
                    band: chBand.rawValue,
                    summary: "Reconnected on Ch \(chNum) (\(chBand.rawValue))"
                ))
            } else if currentMetrics.isConnected && isAssociated {
                if let oldBSSID = currentMetrics.bssid, let newBSSID = bssidAddr,
                   oldBSSID.caseInsensitiveCompare(newBSSID) != .orderedSame {
                    recordRoamEvent(RoamEvent(
                        kind: .roamed,
                        fromBSSID: oldBSSID,
                        toBSSID: newBSSID,
                        channel: chNum,
                        band: chBand.rawValue,
                        summary: "Roamed AP \(oldBSSID) → \(newBSSID) (Ch \(chNum) \(chBand.rawValue))"
                    ))
                } else if currentMetrics.channelNumber > 0 && chNum != currentMetrics.channelNumber {
                    recordRoamEvent(RoamEvent(
                        kind: .channelChanged,
                        fromBSSID: bssidAddr,
                        toBSSID: bssidAddr,
                        channel: chNum,
                        band: chBand.rawValue,
                        summary: "Channel hopped Ch \(currentMetrics.channelNumber) → Ch \(chNum) (\(chBand.rawValue))"
                    ))
                }
            }
        }
        
        let updated = WiFiMetrics(
            isConnected: isAssociated,
            interfaceName: ifaceName,
            ssid: ssidName,
            bssid: bssidAddr,
            rssi: rssiVal,
            noise: noiseVal,
            channelNumber: chNum,
            channelBand: chBand,
            channelWidth: chWidth,
            isDFS: isDFSChannel,
            phyMode: phyMode,
            transmitRate: txRate,
            interfaceInputErrors: inErrors,
            interfaceOutputErrors: outErrors,
            isVPNActive: cachedVPNState.isVPNActive,
            vpnInterfaceName: cachedVPNState.vpnInterface,
            isProxyActive: cachedVPNState.isProxyActive,
            localTrafficMbps: trafficMbps,
            gatewayIP: prober.currentGatewayIP,
            gatewayLatencyMs: prober.latestLatencyMs,
            gatewayJitterMs: prober.latestJitterMs,
            packetLossPercent: prober.packetLossPercent
        )
        
        self.currentMetrics = updated
        self.lastUpdateTimestamp = now
        
        // Record history entry for real-time live chart
        let entry = SignalHistoryEntry(
            timestamp: now,
            rssi: Double(rssiVal),
            noise: Double(noiseVal),
            snr: Double(updated.snr),
            latencyMs: prober.latestLatencyMs,
            qualityScore: Double(updated.qualityScore)
        )
        history.append(entry)
        if history.count > maxHistoryEntries {
            history.removeFirst()
        }
        
        // Re-evaluate optimization advice
        self.optimizationAdvice = OptimizationEngine.analyze(
            metrics: updated,
            channelUtilizations: scanner.channelUtilizations,
            scannedNetworks: scanner.scannedNetworks,
            roamEvents: roamEvents
        )
    }
    
    private func recordRoamEvent(_ event: RoamEvent) {
        roamEvents.insert(event, at: 0)
        if roamEvents.count > maxRoamEvents {
            roamEvents.removeLast(roamEvents.count - maxRoamEvents)
        }
    }
}
