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
import Observation

@MainActor
@Observable
public final class DiagnosticRunner {
    public private(set) var isRunning: Bool = false
    public private(set) var currentStage: DiagnosticStage? = nil
    public private(set) var stageStates: [DiagnosticStage: DiagnosticStageState] = Dictionary(
        uniqueKeysWithValues: DiagnosticStage.allCases.map { ($0, DiagnosticStageState.pending) }
    )
    public private(set) var statusMessage: String = "Ready to run sequential network audit."
    public private(set) var progress: Double = 0.0
    public private(set) var latestReport: DiagnosticReport? = nil
    public private(set) var baselineReport: DiagnosticReport? = nil
    public private(set) var errorMessage: String? = nil
    
    @ObservationIgnored private let latestKey = "com.wifisignal.diagnostic.latest"
    @ObservationIgnored private let baselineKey = "com.wifisignal.diagnostic.baseline"
    @ObservationIgnored private var diagnosticTask: Task<Void, Never>?
    @ObservationIgnored private let processController = ActiveProcessController()
    
    public init() {
        loadSavedReports()
    }
    
    private func loadSavedReports() {
        if let data = UserDefaults.standard.data(forKey: latestKey),
           let decoded = try? JSONDecoder().decode(DiagnosticReport.self, from: data) {
            self.latestReport = decoded
        }
        if let data = UserDefaults.standard.data(forKey: baselineKey),
           let decoded = try? JSONDecoder().decode(DiagnosticReport.self, from: data) {
            self.baselineReport = decoded
        }
    }
    
    private func saveReport(_ report: DiagnosticReport, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(report) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    public func pinLatestAsBaseline() {
        guard let latest = latestReport else { return }
        baselineReport = latest
        saveReport(latest, forKey: baselineKey)
    }
    
    public func clearBaseline() {
        baselineReport = nil
        UserDefaults.standard.removeObject(forKey: baselineKey)
    }
    
    public func cancel() {
        processController.terminateActive()
        diagnosticTask?.cancel()
        diagnosticTask = nil
        isRunning = false
        currentStage = nil
        statusMessage = "Diagnostic cancelled."
        progress = 0.0
    }
    
    public func runFullDiagnostic(monitor: WiFiMonitor) {
        guard !isRunning else { return }
        guard monitor.currentMetrics.isConnected else {
            errorMessage = "Connect to a Wi-Fi network before running the diagnostic."
            return
        }
        
        isRunning = true
        errorMessage = nil
        progress = 0.02
        currentStage = .preflightAndRF
        for stage in DiagnosticStage.allCases {
            stageStates[stage] = .pending
        }
        
        diagnosticTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let wasProbing = monitor.prober.isProbing
            monitor.prober.stopProbing()
            defer {
                if wasProbing && monitor.isMonitoring {
                    monitor.prober.startProbing(interval: 1.0)
                }
                self.isRunning = false
                self.currentStage = nil
                self.diagnosticTask = nil
            }
            
            // MARK: Stage 1 — Pre-flight, Interface Counters & RF Audit
            self.currentStage = .preflightAndRF
            self.stageStates[.preflightAndRF] = .running
            self.statusMessage = "Scanning RF environment & measuring background traffic..."
            
            monitor.triggerScan()
            let ifaceName = monitor.currentMetrics.interfaceName
            let startCounters = InterfaceInspector.readCounters(for: ifaceName)
            
            // Wait up to 4.0s for scan completion, minimum 1.5s for clean traffic rate measurement
            let stage1Start = Date()
            while Date().timeIntervalSince(stage1Start) < 4.0 {
                if Task.isCancelled { return }
                let elapsed = Date().timeIntervalSince(stage1Start)
                if elapsed >= 1.5 && !monitor.scanner.isScanning {
                    break
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            if Task.isCancelled { return }
            
            let stage1Elapsed = max(0.5, Date().timeIntervalSince(stage1Start))
            let endCounters = InterfaceInspector.readCounters(for: ifaceName)
            let metrics = monitor.currentMetrics
            let scannedNetworks = monitor.scanner.scannedNetworks
            let roamCount = monitor.roamEvents.count
            
            var bgTrafficMbps = 0.0
            var errorDelta: UInt32 = 0
            if let s = startCounters, let e = endCounters {
                let deltaBytes = e.totalBytes >= s.totalBytes ? (e.totalBytes - s.totalBytes) : 0
                bgTrafficMbps = (Double(deltaBytes) * 8.0) / stage1Elapsed / 1_000_000.0
                errorDelta = e.totalErrors >= s.totalErrors ? (e.totalErrors - s.totalErrors) : 0
            }
            
            let vpnProxy = InterfaceInspector.detectVPNAndProxy()
            let extraSSIDs = InterfaceInspector.countSameRouterExtraSSIDs(
                currentBSSID: metrics.bssid,
                currentChannel: metrics.channelNumber,
                currentRSSI: metrics.rssi,
                scannedNetworks: scannedNetworks
            )
            
            let best24 = InterfaceInspector.bestChannelFor(band: .band2GHz, candidates: [1, 6, 11], scannedNetworks: scannedNetworks)
            let best5NonDFS = InterfaceInspector.bestChannelFor(band: .band5GHz, candidates: [36, 40, 44, 48, 149, 153, 157, 161], scannedNetworks: scannedNetworks)
            let best5DFS = InterfaceInspector.bestChannelFor(band: .band5GHz, candidates: [52, 56, 60, 64, 100, 104, 108, 112, 116, 132, 136, 140], scannedNetworks: scannedNetworks)
            
            self.stageStates[.preflightAndRF] = .completed
            self.progress = 0.25
            
            // MARK: Stage 2 — Hop-by-Hop Idle Stability
            self.currentStage = .hopStability
            self.stageStates[.hopStability] = .running
            
            var gatewayPing: PingBurstStats? = nil
            if let gw = metrics.gatewayIP, let validGW = InterfaceInspector.isValidIPv4(gw) {
                self.statusMessage = "Pinging default gateway (\(validGW), 30 packets while idle)..."
                let gwOut = await self.processController.run(
                    executablePath: "/sbin/ping",
                    arguments: ["-c", "30", "-i", "0.1", "-t", "8", "--", validGW],
                    timeoutSeconds: 10.0
                )
                if Task.isCancelled { return }
                gatewayPing = Self.parsePingOutput(gwOut.output, target: validGW, label: "Gateway")
            }
            self.progress = 0.36
            
            self.statusMessage = "Pinging Cloudflare 1.1.1.1 (30 packets while idle)..."
            let inetOut = await self.processController.run(
                executablePath: "/sbin/ping",
                arguments: ["-c", "30", "-i", "0.1", "-t", "8", "--", "1.1.1.1"],
                timeoutSeconds: 10.0
            )
            if Task.isCancelled { return }
            let internetPingIPv4 = Self.parsePingOutput(inetOut.output, target: "1.1.1.1", label: "Internet IPv4")
            self.progress = 0.45
            
            var internetPingIPv6: PingBurstStats? = nil
            if InterfaceInspector.isIPv6Active() {
                self.statusMessage = "Checking IPv6 path latency (2606:4700:4700::1111)..."
                let v6Out = await self.processController.run(
                    executablePath: "/sbin/ping6",
                    arguments: ["-c", "15", "-i", "0.2", "2606:4700:4700::1111"],
                    timeoutSeconds: 6.0
                )
                if Task.isCancelled { return }
                internetPingIPv6 = Self.parsePingOutput(v6Out.output, target: "2606:4700:4700::1111", label: "Internet IPv6")
            }
            self.progress = 0.50
            
            self.statusMessage = "Tracing first 5 hops to 1.1.1.1..."
            let traceOut = await self.processController.run(
                executablePath: "/usr/sbin/traceroute",
                arguments: ["-n", "-m", "5", "-q", "1", "-w", "1", "1.1.1.1"],
                timeoutSeconds: 8.0
            )
            if Task.isCancelled { return }
            let hops = Self.parseTracerouteOutput(traceOut.output)
            
            self.stageStates[.hopStability] = .completed
            self.progress = 0.58
            
            // MARK: Stage 3 — Uncached DNS Race
            self.currentStage = .dnsBenchmark
            self.stageStates[.dnsBenchmark] = .running
            self.statusMessage = "Benchmarking uncached DNS lookup latency..."
            
            let systemDNS = InterfaceInspector.readSystemDNSServers()
            let dnsResults = await DNSBenchmarker.benchmark(systemDNS: systemDNS, gatewayIP: metrics.gatewayIP)
            if Task.isCancelled { return }
            
            self.stageStates[.dnsBenchmark] = .completed
            self.progress = 0.72
            
            // MARK: Stage 4 — Throughput & Bufferbloat Under Load
            self.currentStage = .throughputAndBufferbloat
            self.stageStates[.throughputAndBufferbloat] = .running
            self.statusMessage = "Measuring downlink, uplink, responsiveness & bufferbloat..."
            
            var nqArgs = ["-c", "-M", "12"]
            if InterfaceInspector.isValidInterfaceName(ifaceName) {
                nqArgs = ["-c", "-I", ifaceName, "-M", "12"]
            }
            let nqOut = await self.processController.run(
                executablePath: "/usr/bin/networkQuality",
                arguments: nqArgs,
                timeoutSeconds: 20.0
            )
            if Task.isCancelled { return }
            
            let nqResult = Self.parseNetworkQualityOutput(nqOut.output, fallbackInterface: ifaceName)
            if nqResult == nil {
                self.stageStates[.throughputAndBufferbloat] = .failed("networkQuality could not reach test server")
            } else {
                self.stageStates[.throughputAndBufferbloat] = .completed
            }
            self.progress = 0.95
            
            // MARK: Finalize & Rank Bottlenecks
            let bottlenecks = Self.rankBottlenecks(
                metrics: metrics,
                backgroundTrafficMbps: bgTrafficMbps,
                interfaceErrorDelta: errorDelta,
                isVPNActive: vpnProxy.isVPNActive,
                vpnInterface: vpnProxy.vpnInterface,
                isProxyActive: vpnProxy.isProxyActive,
                roamCount: roamCount,
                extraSSIDs: extraSSIDs,
                best24: best24,
                best5NonDFS: best5NonDFS,
                best5DFS: best5DFS,
                gatewayPing: gatewayPing,
                internetPingIPv4: internetPingIPv4,
                tracerouteHops: hops,
                dnsResults: dnsResults,
                networkQuality: nqResult
            )
            
            let report = DiagnosticReport(
                ssid: metrics.ssid ?? "Wi-Fi Connected",
                bssid: metrics.bssid ?? "--",
                interfaceName: ifaceName,
                phyMode: metrics.phyMode.generationLabel,
                band: metrics.channelBand.rawValue,
                channel: metrics.channelNumber,
                channelWidth: metrics.channelWidth.rawValue,
                isDFS: metrics.isDFS,
                rssi: metrics.rssi,
                noise: metrics.noise,
                snr: metrics.snr,
                transmitRateMbps: metrics.transmitRate,
                interfaceInputErrors: endCounters?.inputErrors ?? metrics.interfaceInputErrors,
                interfaceOutputErrors: endCounters?.outputErrors ?? metrics.interfaceOutputErrors,
                interfaceErrorDelta: errorDelta,
                backgroundTrafficMbps: bgTrafficMbps,
                isVPNActive: vpnProxy.isVPNActive,
                vpnInterfaceName: vpnProxy.vpnInterface,
                isProxyActive: vpnProxy.isProxyActive,
                roamEventCount: roamCount,
                sameRouterExtraSSIDs: extraSSIDs,
                cleanest24GHzChannel: best24.ch,
                cleanest24GHzNeighbors: best24.count,
                cleanest5GHzNonDFSChannel: best5NonDFS.ch,
                cleanest5GHzNonDFSNeighbors: best5NonDFS.count,
                cleanest5GHzDFSChannel: best5DFS.ch,
                cleanest5GHzDFSNeighbors: best5DFS.count,
                gatewayPing: gatewayPing,
                internetPingIPv4: internetPingIPv4,
                internetPingIPv6: internetPingIPv6,
                tracerouteHops: hops,
                systemDNSServers: systemDNS,
                dnsResults: dnsResults,
                networkQuality: nqResult,
                bottlenecks: bottlenecks
            )
            
            self.latestReport = report
            self.saveReport(report, forKey: self.latestKey)
            if self.baselineReport == nil {
                self.baselineReport = report
                self.saveReport(report, forKey: self.baselineKey)
            }
            
            self.progress = 1.0
            self.statusMessage = "Diagnostic complete."
        }
    }
    
    // MARK: - Output Parsers
    
    private static func parsePingOutput(_ output: String, target: String, label: String) -> PingBurstStats {
        var sent = 0
        var received = 0
        var loss = 100.0
        var minMs = 0.0
        var avgMs = 0.0
        var maxMs = 0.0
        var stddevMs = 0.0
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("packets transmitted") {
                let ns = line as NSString
                if let regex = try? NSRegularExpression(pattern: #"(\d+) packets transmitted,\s+(\d+) (?:packets )?received,\s+([0-9.]+)% packet loss"#),
                   let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                    sent = Int(ns.substring(with: match.range(at: 1))) ?? 0
                    received = Int(ns.substring(with: match.range(at: 2))) ?? 0
                    loss = Double(ns.substring(with: match.range(at: 3))) ?? 100.0
                }
            } else if line.contains("min/avg/max") {
                let ns = line as NSString
                if let regex = try? NSRegularExpression(pattern: #"=\s*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+)\s*ms"#),
                   let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                    minMs = Double(ns.substring(with: match.range(at: 1))) ?? 0.0
                    avgMs = Double(ns.substring(with: match.range(at: 2))) ?? 0.0
                    maxMs = Double(ns.substring(with: match.range(at: 3))) ?? 0.0
                    stddevMs = Double(ns.substring(with: match.range(at: 4))) ?? 0.0
                }
            }
        }
        
        return PingBurstStats(
            target: target,
            label: label,
            packetsSent: sent,
            packetsReceived: received,
            packetLossPercent: loss,
            minMs: minMs,
            avgMs: avgMs,
            maxMs: maxMs,
            stddevMs: stddevMs,
            isReachable: received > 0
        )
    }
    
    private static func parseTracerouteOutput(_ output: String) -> [TracerouteHop] {
        var hops: [TracerouteHop] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, let hopNum = Int(parts[0]), (1...10).contains(hopNum) else {
                continue
            }
            let second = String(parts[1])
            if second == "*" {
                hops.append(TracerouteHop(hopNumber: hopNum, address: "*", latencyMs: nil))
                continue
            }
            var parsedMs: Double? = nil
            for i in 2..<parts.count {
                if parts[i] == "ms", let val = Double(parts[i - 1]) {
                    parsedMs = val
                    break
                }
            }
            hops.append(TracerouteHop(hopNumber: hopNum, address: second, latencyMs: parsedMs))
        }
        return hops
    }
    
    private struct NetworkQualityJSON: Decodable {
        struct OtherInfo: Decodable {
            let ecn_values: [String: Int]?
            let l4s_enablement: [String: Int]?
            let proxy_state: [String: Int]?
        }
        let base_rtt: Double?
        let dl_throughput: Double?
        let ul_throughput: Double?
        let responsiveness: Double?
        let dl_responsiveness: Double?
        let ul_responsiveness: Double?
        let il_h2_req_resp: [Double]?
        let lud_foreign_h2_req_resp: [Double]?
        let lud_foreign_dl_h2_req_resp: [Double]?
        let lud_foreign_ul_h2_req_resp: [Double]?
        let interface_name: String?
        let test_endpoint: String?
        let other: OtherInfo?
    }
    
    private static func parseNetworkQualityOutput(_ output: String, fallbackInterface: String) -> NetworkQualityResult? {
        guard let firstBrace = output.firstIndex(of: "{"),
              let lastBrace = output.lastIndex(of: "}"),
              firstBrace < lastBrace else {
            return nil
        }
        let jsonSlice = String(output[firstBrace...lastBrace])
        guard let data = jsonSlice.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NetworkQualityJSON.self, from: data) else {
            return nil
        }
        
        let dlMbps = (payload.dl_throughput ?? 0.0) / 1_000_000.0
        let ulMbps = (payload.ul_throughput ?? 0.0) / 1_000_000.0
        let idleMs = payload.base_rtt ?? median(of: payload.il_h2_req_resp) ?? 0.0
        
        let rpm: Double = {
            if let r = payload.responsiveness, r > 0 { return r }
            let pair = [payload.dl_responsiveness, payload.ul_responsiveness].compactMap { $0 }
            if !pair.isEmpty { return pair.reduce(0.0, +) / Double(pair.count) }
            return 0.0
        }()
        
        let loadedSamples: [Double]? = {
            if let combined = payload.lud_foreign_h2_req_resp, !combined.isEmpty { return combined }
            let split = (payload.lud_foreign_dl_h2_req_resp ?? []) + (payload.lud_foreign_ul_h2_req_resp ?? [])
            return split.isEmpty ? nil : split
        }()
        
        let loadedMs = median(of: loadedSamples) ?? (rpm > 0 ? (60_000.0 / rpm) : idleMs)
        let deltaMs = max(0.0, loadedMs - idleMs)
        let grade = NetworkQualityResult.gradeForBufferbloat(deltaMs: deltaMs)
        
        let ecnStr = summarizeFlagMap(payload.other?.ecn_values, positivePrefix: "ecn_enabled", positiveLabel: "Enabled", negativeLabel: "Disabled")
        let l4sStr = summarizeFlagMap(payload.other?.l4s_enablement, positivePrefix: "enabled", positiveLabel: "Enabled", negativeLabel: "Disabled")
        let proxyStr = summarizeFlagMap(payload.other?.proxy_state, positivePrefix: "proxied", positiveLabel: "Proxied", negativeLabel: "Direct")
        
        return NetworkQualityResult(
            downlinkMbps: dlMbps,
            uplinkMbps: ulMbps,
            idleLatencyMs: idleMs,
            loadedLatencyMs: loadedMs,
            responsivenessRPM: rpm,
            bufferbloatDeltaMs: deltaMs,
            bufferbloatGrade: grade,
            ecnStatus: ecnStr,
            l4sStatus: l4sStr,
            proxyState: proxyStr,
            interfaceName: payload.interface_name ?? fallbackInterface,
            testEndpoint: payload.test_endpoint
        )
    }
    
    private static func median(of values: [Double]?) -> Double? {
        guard let values, !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }
    
    private static func summarizeFlagMap(_ map: [String: Int]?, positivePrefix: String, positiveLabel: String, negativeLabel: String) -> String {
        guard let map, !map.isEmpty else { return "Unknown" }
        let hasPositive = map.keys.contains { $0.lowercased().contains(positivePrefix) && (map[$0] ?? 0) > 0 }
        return hasPositive ? positiveLabel : negativeLabel
    }
    
    // MARK: - Impact-Ranked Bottleneck Analyzer
    
    private static func rankBottlenecks(
        metrics: WiFiMetrics,
        backgroundTrafficMbps: Double,
        interfaceErrorDelta: UInt32,
        isVPNActive: Bool,
        vpnInterface: String?,
        isProxyActive: Bool,
        roamCount: Int,
        extraSSIDs: Int,
        best24: (ch: Int, count: Int),
        best5NonDFS: (ch: Int, count: Int),
        best5DFS: (ch: Int, count: Int),
        gatewayPing: PingBurstStats?,
        internetPingIPv4: PingBurstStats?,
        tracerouteHops: [TracerouteHop],
        dnsResults: [DNSBenchmarkResult],
        networkQuality: NetworkQualityResult?
    ) -> [RankedBottleneck] {
        var findings: [RankedBottleneck] = []
        
        // 1. Active local background traffic hog
        if backgroundTrafficMbps > 10.0 {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 95,
                severity: "warning",
                scope: .localQuickWin,
                title: "Active Local Background Download/Upload",
                evidence: String(format: "%.1f Mbps was transferring on %@ during pre-flight.", backgroundTrafficMbps, metrics.interfaceName),
                recommendation: "Pause cloud backups (iCloud, Dropbox), macOS updates, or background downloads on this Mac before trusting speed measurements."
            ))
        }
        
        // 2. Active VPN or Proxy
        if isVPNActive || isProxyActive {
            let tunnelDesc = isVPNActive ? "VPN (\(vpnInterface ?? "tunnel"))" : "HTTP/SOCKS Proxy"
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 88,
                severity: "warning",
                scope: .localQuickWin,
                title: "Active \(tunnelDesc) Adding Encryption & Routing Overhead",
                evidence: "\(tunnelDesc) is routing all traffic through an external tunnel.",
                recommendation: "Disconnect the VPN or disable the proxy temporarily to separate true Wi-Fi/ISP throughput from VPN server throttling."
            ))
        }
        
        // 3. Wi-Fi Hop-1 instability (RF / airtime)
        if let gw = gatewayPing, (!gw.isReachable || gw.packetLossPercent > 1.0 || gw.stddevMs > 10.0 || gw.avgMs > 15.0) {
            let score = (!gw.isReachable || gw.packetLossPercent > 2.0) ? 98 : 85
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: score,
                severity: (gw.packetLossPercent > 2.0 || !gw.isReachable) ? "critical" : "warning",
                scope: .routerOrModem,
                title: "Wi-Fi / LAN Hop-1 Instability",
                evidence: String(format: "Gateway ping: %.1f ms avg, %.1f ms jitter, %.1f%% loss (RSSI %d dBm, SNR %d dB).", gw.avgMs, gw.stddevMs, gw.packetLossPercent, metrics.rssi, metrics.snr),
                recommendation: metrics.rssi < -68
                    ? "Signal is attenuated (\(metrics.rssi) dBm). Elevate/reposition the router or add a wired Ethernet/mesh node."
                    : "High Hop-1 jitter despite decent signal indicates co-channel airtime congestion or wireless retransmissions."
            ))
        }
        
        // 4. Modem / ISP upstream issue (Gateway healthy, Internet/Hop-2 degraded)
        let gwHealthy = gatewayPing.map { $0.isReachable && $0.packetLossPercent < 0.5 && $0.avgMs < 8.0 } ?? false
        let hop2Ms = tracerouteHops.first(where: { $0.hopNumber == 2 })?.latencyMs
        let hop2Jump = (hop2Ms ?? 0.0) > 30.0
        if gwHealthy, let inet = internetPingIPv4, (!inet.isReachable || inet.packetLossPercent > 1.0 || inet.avgMs > 45.0 || hop2Jump) {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 84,
                severity: inet.packetLossPercent > 1.0 ? "critical" : "warning",
                scope: .ispUpstream,
                title: "Modem / ISP Upstream Bottleneck (Not Your Wi-Fi)",
                evidence: String(format: "Wi-Fi Hop 1 is clean (%.1f ms, 0%% loss), but 1.1.1.1 is %.1f ms (%.1f%% loss)%@.", gatewayPing?.avgMs ?? 0, inet.avgMs, inet.packetLossPercent, hop2Ms != nil ? String(format: ", Hop 2 = %.1f ms", hop2Ms!) : ""),
                recommendation: "Check your cable/fiber modem admin page for out-of-spec downstream/upstream power levels, low SNR, or uncorrectable codeword errors, and inspect coax/fiber splitters."
            ))
        }
        
        // 5. Bufferbloat under load
        if let nq = networkQuality, (nq.bufferbloatDeltaMs >= 60.0 || (nq.responsivenessRPM > 0 && nq.responsivenessRPM < 400.0)) {
            let sev = nq.bufferbloatDeltaMs >= 150.0 ? "critical" : "warning"
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: nq.bufferbloatDeltaMs >= 150.0 ? 86 : 74,
                severity: sev,
                scope: .routerOrModem,
                title: "Router Bufferbloat Under Load (Grade \(nq.bufferbloatGrade))",
                evidence: String(format: "Latency spiked +%.0f ms under load (%.1f ms idle → %.1f ms loaded, %d RPM).", nq.bufferbloatDeltaMs, nq.idleLatencyMs, nq.loadedLatencyMs, Int(nq.responsivenessRPM.rounded())),
                recommendation: "Enable Smart Queue Management (SQM / CAKE / fq_codel) or Adaptive QoS on your router capped at ~90–95% of your ISP upload/download speed."
            ))
        }
        
        // 6. Slow DNS
        let sysDNS = dnsResults.first(where: { $0.isSystemDefault })
        let fastestPublic = dnsResults.filter { !$0.isRouter && $0.succeeded && $0.avgLatencyMs != nil }
            .min(by: { ($0.avgLatencyMs ?? .greatestFiniteMagnitude) < ($1.avgLatencyMs ?? .greatestFiniteMagnitude) })
        if let sys = sysDNS {
            if !sys.succeeded, let fast = fastestPublic, let fastMs = fast.avgLatencyMs {
                findings.append(RankedBottleneck(
                    rank: 0,
                    impactScore: 76,
                    severity: "warning",
                    scope: .localQuickWin,
                    title: "Current DNS Server Unresponsive",
                    evidence: "\(sys.name) (\(sys.serverIP)) timed out while \(fast.name) (\(fast.serverIP)) resolved in \(String(format: "%.1f ms", fastMs)).",
                    recommendation: "Switch macOS Wi-Fi DNS (or router DHCP DNS) to \(fast.serverIP) (\(fast.name))."
                ))
            } else if let sysMs = sys.avgLatencyMs, let fast = fastestPublic, let fastMs = fast.avgLatencyMs,
                      sys.serverIP != fast.serverIP, (sysMs - fastMs) > 20.0 {
                findings.append(RankedBottleneck(
                    rank: 0,
                    impactScore: 60,
                    severity: "tip",
                    scope: .localQuickWin,
                    title: "Slow System DNS Resolution",
                    evidence: String(format: "System DNS %@ averages %.1f ms vs. %.1f ms on %@ (%@).", sys.serverIP, sysMs, fastMs, fast.name, fast.serverIP),
                    recommendation: "Set DNS order in macOS System Settings → Wi-Fi → Details → DNS to \(fast.serverIP) first for snappier page loads."
                ))
            }
        }
        
        // 7. Narrow Channel Width / Legacy PHY / 2.4 GHz
        if metrics.channelBand == .band2GHz {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 80,
                severity: "warning",
                scope: .routerOrModem,
                title: "Connected on Slow 2.4 GHz Band",
                evidence: "Channel \(metrics.channelNumber) (\(metrics.channelWidth.rawValue), \(Int(metrics.transmitRate)) Mbps PHY).",
                recommendation: "Move to 5 GHz or 6 GHz. If using Smart Connect / Band Steering, split the SSIDs or raise the 5 GHz steering threshold."
            ))
        } else if (metrics.channelWidth == .width20MHz || metrics.channelWidth == .width40MHz) && metrics.channelBand != .unknown {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 78,
                severity: "warning",
                scope: .routerOrModem,
                title: "Narrow \(metrics.channelWidth.rawValue) Width Capping \(metrics.channelBand.rawValue) Speeds",
                evidence: "5/6 GHz link is capped at \(metrics.channelWidth.rawValue) (\(Int(metrics.transmitRate)) Mbps PHY).",
                recommendation: "Unlock 80 MHz (or 160 MHz) channel width in router Wireless Settings, enable Wi-Fi 6 (802.11ax) / OFDMA / WMM, and avoid Channel 165 (20 MHz only)."
            ))
        }
        
        // 8. Frequent AP roaming / Smart Connect flapping
        if roamCount >= 3 {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 70,
                severity: "warning",
                scope: .routerOrModem,
                title: "Frequent Roaming / Band-Steering Drops (\(roamCount) events)",
                evidence: "Detected \(roamCount) BSSID changes or disconnects during this session.",
                recommendation: "Disable Smart Connect / Band Steering if your Mac keeps bouncing between 2.4 GHz and 5 GHz or mesh nodes."
            ))
        }
        
        // 9. Excess guest/IoT SSID overhead
        if extraSSIDs >= 2 {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 45,
                severity: "tip",
                scope: .routerOrModem,
                title: "Beacon Overhead From Multiple SSIDs on Same Radio",
                evidence: "Detected \(extraSSIDs) additional SSIDs sharing your router's radio OUI on Ch \(metrics.channelNumber).",
                recommendation: "Disable unused guest or legacy IoT SSIDs on 5 GHz to reclaim management beacon airtime."
            ))
        }
        
        // 10. Interface packet errors
        if interfaceErrorDelta > 0 {
            findings.append(RankedBottleneck(
                rank: 0,
                impactScore: 68,
                severity: "warning",
                scope: .routerOrModem,
                title: "Interface Packet Errors Detected (Δ \(interfaceErrorDelta))",
                evidence: "\(metrics.interfaceName) logged \(interfaceErrorDelta) new input/output errors during this audit.",
                recommendation: "Check for nearby 5 GHz/USB-3 RF interference or switch to a cleaner non-overlapping channel."
            ))
        }
        
        // 11. Channel congestion (skip warning if already on 160 MHz Auto)
        if metrics.channelWidth != .width160MHz {
            let recommendedText: String
            switch metrics.channelBand {
            case .band2GHz:
                recommendedText = "Switch 2.4 GHz to Ch \(best24.ch) (\(best24.count) competing APs, non-overlapping 1/6/11)."
            case .band5GHz:
                recommendedText = "Cleanest 5 GHz targets: Non-DFS Ch \(best5NonDFS.ch) (\(best5NonDFS.count) APs) or DFS Ch \(best5DFS.ch) (\(best5DFS.count) APs) with 80 MHz enabled."
            default:
                recommendedText = ""
            }
            if !recommendedText.isEmpty && metrics.snr < 25 {
                findings.append(RankedBottleneck(
                    rank: 0,
                    impactScore: 55,
                    severity: "tip",
                    scope: .routerOrModem,
                    title: "RF Signal-to-Noise Headroom Can Improve",
                    evidence: "Current SNR is \(metrics.snr) dB on Ch \(metrics.channelNumber).",
                    recommendation: recommendedText
                ))
            }
        }
        
        if findings.isEmpty {
            findings.append(RankedBottleneck(
                rank: 1,
                impactScore: 100,
                severity: "optimal",
                scope: .healthy,
                title: "Healthy Wi-Fi & Upstream Path",
                evidence: String(format: "%@ %@ @ %@ (%d Mbps PHY), %d dB SNR, %.1f ms gateway ping, %.1f Mbps ↓.", metrics.phyMode.generationLabel, metrics.channelBand.rawValue, metrics.channelWidth.rawValue, Int(metrics.transmitRate), metrics.snr, gatewayPing?.avgMs ?? 0.0, networkQuality?.downlinkMbps ?? 0.0),
                recommendation: "No major Wi-Fi or ISP bottlenecks detected. Pin this run as your baseline."
            ))
            return findings
        }
        
        let sorted = findings.sorted { $0.impactScore > $1.impactScore }
        return sorted.enumerated().map { idx, item in
            RankedBottleneck(
                id: item.id,
                rank: idx + 1,
                impactScore: item.impactScore,
                severity: item.severity,
                scope: item.scope,
                title: item.title,
                evidence: item.evidence,
                recommendation: item.recommendation
            )
        }
    }
}

private final class ActiveProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var activeProcess: Process?
    
    func terminateActive() {
        lock.lock()
        let proc = activeProcess
        lock.unlock()
        if let proc, proc.isRunning {
            proc.terminate()
        }
    }
    
    private func setActiveProcess(_ process: Process?) {
        lock.withLock {
            activeProcess = process
        }
    }
    
    private func clearActiveProcess(_ process: Process) {
        lock.withLock {
            if activeProcess === process {
                activeProcess = nil
            }
        }
    }
    
    func run(executablePath: String, arguments: [String], timeoutSeconds: TimeInterval) async -> (exitCode: Int32, output: String) {
        await Task.detached(priority: .utility) { [self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = FileHandle.nullDevice
            
            self.setActiveProcess(process)
            defer {
                self.clearActiveProcess(process)
            }
            
            do {
                try process.run()
            } catch {
                return (-1, "")
            }
            
            let watchdog = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds, execute: watchdog)
            
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            watchdog.cancel()
            
            let text = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, text)
        }.value
    }
}
