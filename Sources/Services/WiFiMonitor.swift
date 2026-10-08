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
    public let locationHelper = LocationPermissionHelper.shared
    
    // Published State
    @Published public var currentMetrics: WiFiMetrics = WiFiMetrics()
    @Published public var history: [SignalHistoryEntry] = []
    @Published public var optimizationAdvice: [OptimizationAdvice] = []
    @Published public var isMonitoring: Bool = false
    @Published public var lastUpdateTimestamp: Date = Date()
    
    // Configuration
    private var monitorTimer: Timer?
    private let maxHistoryEntries = 120 // ~60 seconds at 500ms interval
    
    public init() {
        // Request location authorization to unlock SSID and scan access
        locationHelper.requestPermission()
        startMonitoring()
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
            currentChannel: currentMetrics.channelNumber
        )
    }
    
    public func pollWiFiMetrics() {
        guard let iface = wifiClient.interface() else {
            self.currentMetrics = WiFiMetrics(isConnected: false)
            return
        }
        
        let rssiVal = iface.rssiValue()
        let noiseVal = iface.noiseMeasurement()
        let ch = iface.wlanChannel()
        let chNum = ch?.channelNumber ?? 0
        let chBand = ch != nil ? ChannelBand.from(cwBand: ch!.channelBand) : .unknown
        let chWidth = ch != nil ? ChannelWidth.from(cwWidth: ch!.channelWidth) : .unknown
        let txRate = iface.transmitRate()
        let ssidName = iface.ssid()
        let bssidAddr = iface.bssid()
        
        let isAssociated = (rssiVal != 0 && chNum != 0)
        
        let updated = WiFiMetrics(
            isConnected: isAssociated,
            interfaceName: iface.interfaceName ?? "en0",
            ssid: ssidName,
            bssid: bssidAddr,
            rssi: rssiVal,
            noise: noiseVal,
            channelNumber: chNum,
            channelBand: chBand,
            channelWidth: chWidth,
            transmitRate: txRate,
            gatewayIP: prober.currentGatewayIP,
            gatewayLatencyMs: prober.latestLatencyMs,
            gatewayJitterMs: prober.latestJitterMs,
            packetLossPercent: prober.packetLossPercent
        )
        
        self.currentMetrics = updated
        self.lastUpdateTimestamp = Date()
        
        // Record history entry for real-time live chart
        let entry = SignalHistoryEntry(
            timestamp: Date(),
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
            scannedNetworks: scanner.scannedNetworks
        )
    }
}
