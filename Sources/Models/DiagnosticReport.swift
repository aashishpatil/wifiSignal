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
import SwiftUI

public enum DiagnosticStage: Int, CaseIterable, Identifiable, Equatable {
    case preflightAndRF = 0
    case hopStability = 1
    case dnsBenchmark = 2
    case throughputAndBufferbloat = 3
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .preflightAndRF: return "Link, RF & Local Audit"
        case .hopStability: return "Hop-by-Hop Stability"
        case .dnsBenchmark: return "Uncached DNS Race"
        case .throughputAndBufferbloat: return "Throughput & Bufferbloat"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .preflightAndRF: return "PHY mode, SNR, errors, VPN & local traffic"
        case .hopStability: return "30-packet idle burst + 5-hop traceroute"
        case .dnsBenchmark: return "Uncached UDP lookup latency race"
        case .throughputAndBufferbloat: return "networkQuality speed, RPM & L4S"
        }
    }
    
    public var icon: String {
        switch self {
        case .preflightAndRF: return "antenna.radiowaves.left.and.right"
        case .hopStability: return "point.3.connected.trianglepath.dotted"
        case .dnsBenchmark: return "globe.americas.fill"
        case .throughputAndBufferbloat: return "speedometer"
        }
    }
}

public enum DiagnosticStageState: Equatable {
    case pending
    case running
    case completed
    case failed(String)
}

public struct PingBurstStats: Codable, Equatable {
    public let target: String
    public let label: String
    public let packetsSent: Int
    public let packetsReceived: Int
    public let packetLossPercent: Double
    public let minMs: Double
    public let avgMs: Double
    public let maxMs: Double
    public let stddevMs: Double
    public let isReachable: Bool
    
    public init(
        target: String,
        label: String,
        packetsSent: Int,
        packetsReceived: Int,
        packetLossPercent: Double,
        minMs: Double,
        avgMs: Double,
        maxMs: Double,
        stddevMs: Double,
        isReachable: Bool
    ) {
        self.target = target
        self.label = label
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.packetLossPercent = packetLossPercent
        self.minMs = minMs
        self.avgMs = avgMs
        self.maxMs = maxMs
        self.stddevMs = stddevMs
        self.isReachable = isReachable
    }
}

public struct TracerouteHop: Codable, Equatable, Identifiable {
    public var id: Int { hopNumber }
    public let hopNumber: Int
    public let address: String
    public let latencyMs: Double?
    
    public init(hopNumber: Int, address: String, latencyMs: Double?) {
        self.hopNumber = hopNumber
        self.address = address
        self.latencyMs = latencyMs
    }
}

public struct DNSBenchmarkResult: Codable, Equatable, Identifiable {
    public var id: String { "\(serverIP)_\(name)" }
    public let name: String
    public let serverIP: String
    public let isSystemDefault: Bool
    public let isRouter: Bool
    public let avgLatencyMs: Double?
    public let minLatencyMs: Double?
    public let succeeded: Bool
    
    public init(
        name: String,
        serverIP: String,
        isSystemDefault: Bool,
        isRouter: Bool,
        avgLatencyMs: Double?,
        minLatencyMs: Double?,
        succeeded: Bool
    ) {
        self.name = name
        self.serverIP = serverIP
        self.isSystemDefault = isSystemDefault
        self.isRouter = isRouter
        self.avgLatencyMs = avgLatencyMs
        self.minLatencyMs = minLatencyMs
        self.succeeded = succeeded
    }
}

public struct NetworkQualityResult: Codable, Equatable {
    public let downlinkMbps: Double
    public let uplinkMbps: Double
    public let idleLatencyMs: Double
    public let loadedLatencyMs: Double
    public let responsivenessRPM: Double
    public let bufferbloatDeltaMs: Double
    public let bufferbloatGrade: String
    public let ecnStatus: String
    public let l4sStatus: String
    public let proxyState: String
    public let interfaceName: String
    public let testEndpoint: String?
    
    public init(
        downlinkMbps: Double,
        uplinkMbps: Double,
        idleLatencyMs: Double,
        loadedLatencyMs: Double,
        responsivenessRPM: Double,
        bufferbloatDeltaMs: Double,
        bufferbloatGrade: String,
        ecnStatus: String,
        l4sStatus: String,
        proxyState: String,
        interfaceName: String,
        testEndpoint: String? = nil
    ) {
        self.downlinkMbps = downlinkMbps
        self.uplinkMbps = uplinkMbps
        self.idleLatencyMs = idleLatencyMs
        self.loadedLatencyMs = loadedLatencyMs
        self.responsivenessRPM = responsivenessRPM
        self.bufferbloatDeltaMs = bufferbloatDeltaMs
        self.bufferbloatGrade = bufferbloatGrade
        self.ecnStatus = ecnStatus
        self.l4sStatus = l4sStatus
        self.proxyState = proxyState
        self.interfaceName = interfaceName
        self.testEndpoint = testEndpoint
    }
    
    public static func gradeForBufferbloat(deltaMs: Double) -> String {
        if deltaMs < 5.0 { return "A+" }
        if deltaMs < 30.0 { return "A" }
        if deltaMs < 60.0 { return "B" }
        if deltaMs < 150.0 { return "C" }
        if deltaMs < 300.0 { return "D" }
        return "F"
    }
    
    public var gradeColor: Color {
        switch bufferbloatGrade {
        case "A+", "A": return Color(red: 0.0, green: 0.9, blue: 0.55)
        case "B": return Color(red: 0.2, green: 0.8, blue: 1.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.0)
        case "D": return Color(red: 1.0, green: 0.45, blue: 0.0)
        default: return Color(red: 1.0, green: 0.25, blue: 0.25)
        }
    }
}

public enum BottleneckScope: String, Codable, Equatable {
    case localQuickWin = "Local Quick Win"
    case routerOrModem = "Router / Modem"
    case ispUpstream = "ISP / Upstream"
    case healthy = "Healthy"
    
    public var badgeColor: Color {
        switch self {
        case .localQuickWin: return Color.cyan
        case .routerOrModem: return Color.orange
        case .ispUpstream: return Color.purple
        case .healthy: return Color.green
        }
    }
}

public struct RankedBottleneck: Codable, Equatable, Identifiable {
    public let id: UUID
    public let rank: Int
    public let impactScore: Int
    public let severity: String // "critical", "warning", "tip", "optimal"
    public let scope: BottleneckScope
    public let title: String
    public let evidence: String
    public let recommendation: String
    
    public init(
        id: UUID = UUID(),
        rank: Int,
        impactScore: Int,
        severity: String,
        scope: BottleneckScope,
        title: String,
        evidence: String,
        recommendation: String
    ) {
        self.id = id
        self.rank = rank
        self.impactScore = impactScore
        self.severity = severity
        self.scope = scope
        self.title = title
        self.evidence = evidence
        self.recommendation = recommendation
    }
    
    public var severityColor: Color {
        switch severity {
        case "critical": return Color(red: 1.0, green: 0.3, blue: 0.3)
        case "warning": return Color(red: 1.0, green: 0.75, blue: 0.0)
        case "tip": return Color(red: 0.2, green: 0.8, blue: 1.0)
        default: return Color(red: 0.0, green: 0.9, blue: 0.5)
        }
    }
}

public struct DiagnosticReport: Codable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    
    // Link & RF snapshot
    public let ssid: String
    public let bssid: String
    public let interfaceName: String
    public let phyMode: String
    public let band: String
    public let channel: Int
    public let channelWidth: String
    public let isDFS: Bool
    public let rssi: Int
    public let noise: Int
    public let snr: Int
    public let transmitRateMbps: Double
    
    // Interface & Environment
    public let interfaceInputErrors: UInt32
    public let interfaceOutputErrors: UInt32
    public let interfaceErrorDelta: UInt32
    public let backgroundTrafficMbps: Double
    public let isVPNActive: Bool
    public let vpnInterfaceName: String?
    public let isProxyActive: Bool
    public let roamEventCount: Int
    public let sameRouterExtraSSIDs: Int
    
    // RF Cleanest Channels
    public let cleanest24GHzChannel: Int
    public let cleanest24GHzNeighbors: Int
    public let cleanest5GHzNonDFSChannel: Int
    public let cleanest5GHzNonDFSNeighbors: Int
    public let cleanest5GHzDFSChannel: Int
    public let cleanest5GHzDFSNeighbors: Int
    
    // Hop-by-hop stability
    public let gatewayPing: PingBurstStats?
    public let internetPingIPv4: PingBurstStats?
    public let internetPingIPv6: PingBurstStats?
    public let tracerouteHops: [TracerouteHop]
    
    // DNS benchmark
    public let systemDNSServers: [String]
    public let dnsResults: [DNSBenchmarkResult]
    
    // Throughput & Bufferbloat
    public let networkQuality: NetworkQualityResult?
    
    // Ranked Bottlenecks
    public let bottlenecks: [RankedBottleneck]
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        ssid: String,
        bssid: String,
        interfaceName: String,
        phyMode: String,
        band: String,
        channel: Int,
        channelWidth: String,
        isDFS: Bool,
        rssi: Int,
        noise: Int,
        snr: Int,
        transmitRateMbps: Double,
        interfaceInputErrors: UInt32,
        interfaceOutputErrors: UInt32,
        interfaceErrorDelta: UInt32,
        backgroundTrafficMbps: Double,
        isVPNActive: Bool,
        vpnInterfaceName: String?,
        isProxyActive: Bool,
        roamEventCount: Int,
        sameRouterExtraSSIDs: Int,
        cleanest24GHzChannel: Int,
        cleanest24GHzNeighbors: Int,
        cleanest5GHzNonDFSChannel: Int,
        cleanest5GHzNonDFSNeighbors: Int,
        cleanest5GHzDFSChannel: Int,
        cleanest5GHzDFSNeighbors: Int,
        gatewayPing: PingBurstStats?,
        internetPingIPv4: PingBurstStats?,
        internetPingIPv6: PingBurstStats?,
        tracerouteHops: [TracerouteHop],
        systemDNSServers: [String],
        dnsResults: [DNSBenchmarkResult],
        networkQuality: NetworkQualityResult?,
        bottlenecks: [RankedBottleneck]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ssid = ssid
        self.bssid = bssid
        self.interfaceName = interfaceName
        self.phyMode = phyMode
        self.band = band
        self.channel = channel
        self.channelWidth = channelWidth
        self.isDFS = isDFS
        self.rssi = rssi
        self.noise = noise
        self.snr = snr
        self.transmitRateMbps = transmitRateMbps
        self.interfaceInputErrors = interfaceInputErrors
        self.interfaceOutputErrors = interfaceOutputErrors
        self.interfaceErrorDelta = interfaceErrorDelta
        self.backgroundTrafficMbps = backgroundTrafficMbps
        self.isVPNActive = isVPNActive
        self.vpnInterfaceName = vpnInterfaceName
        self.isProxyActive = isProxyActive
        self.roamEventCount = roamEventCount
        self.sameRouterExtraSSIDs = sameRouterExtraSSIDs
        self.cleanest24GHzChannel = cleanest24GHzChannel
        self.cleanest24GHzNeighbors = cleanest24GHzNeighbors
        self.cleanest5GHzNonDFSChannel = cleanest5GHzNonDFSChannel
        self.cleanest5GHzNonDFSNeighbors = cleanest5GHzNonDFSNeighbors
        self.cleanest5GHzDFSChannel = cleanest5GHzDFSChannel
        self.cleanest5GHzDFSNeighbors = cleanest5GHzDFSNeighbors
        self.gatewayPing = gatewayPing
        self.internetPingIPv4 = internetPingIPv4
        self.internetPingIPv6 = internetPingIPv6
        self.tracerouteHops = tracerouteHops
        self.systemDNSServers = systemDNSServers
        self.dnsResults = dnsResults
        self.networkQuality = networkQuality
        self.bottlenecks = bottlenecks
    }
    
    /// Generates a structured Markdown diagnostic summary and AI router-tuning prompt.
    public func markdownExport(baseline: DiagnosticReport? = nil) -> String {
        let fmtDate = timestamp.formatted(date: .abbreviated, time: .shortened)
        var lines: [String] = []
        lines.append("# WiFiSignal Deep Diagnostic Report (\(fmtDate))")
        lines.append("")
        lines.append("## 1. Baseline Link & Environment")
        lines.append("- **Network**: `\(ssid)` (BSSID `\(bssid)`, Interface `\(interfaceName)`)")
        lines.append("- **Wi-Fi PHY / Band**: \(phyMode) • \(band) • Ch \(channel)\(isDFS ? " (DFS)" : "") @ \(channelWidth)")
        lines.append("- **Signal / Noise / SNR**: \(rssi) dBm / \(noise) dBm / **\(snr) dB SNR**")
        lines.append("- **Transmit PHY Rate**: \(Int(transmitRateMbps)) Mbps")
        lines.append("- **Interface Errors**: In \(interfaceInputErrors), Out \(interfaceOutputErrors) (Δ \(interfaceErrorDelta) during test)")
        lines.append("- **Background Local Traffic**: \(String(format: "%.2f Mbps", backgroundTrafficMbps))")
        lines.append("- **VPN / Proxy**: \(isVPNActive ? "Active (\(vpnInterfaceName ?? "tunnel"))" : "None") / \(isProxyActive ? "Active" : "None")")
        lines.append("- **Session Roam Events**: \(roamEventCount) • **Same-Router Extra SSIDs**: \(sameRouterExtraSSIDs)")
        lines.append("- **Cleanest Channels**: 2.4 GHz Ch \(cleanest24GHzChannel) (\(cleanest24GHzNeighbors) APs) | 5 GHz Non-DFS Ch \(cleanest5GHzNonDFSChannel) (\(cleanest5GHzNonDFSNeighbors) APs) | 5 GHz DFS Ch \(cleanest5GHzDFSChannel) (\(cleanest5GHzDFSNeighbors) APs)")
        lines.append("")
        lines.append("## 2. Hop-by-Hop Idle Latency & Traceroute")
        if let gw = gatewayPing {
            lines.append("- **Gateway (`\(gw.target)`)**: \(String(format: "%.1f / %.1f / %.1f ms", gw.minMs, gw.avgMs, gw.maxMs)) (min/avg/max), Jitter \(String(format: "%.1f ms", gw.stddevMs)), Loss \(String(format: "%.1f%%", gw.packetLossPercent))")
        }
        if let inet = internetPingIPv4 {
            lines.append("- **Internet (`\(inet.target)`)**: \(String(format: "%.1f / %.1f / %.1f ms", inet.minMs, inet.avgMs, inet.maxMs)), Jitter \(String(format: "%.1f ms", inet.stddevMs)), Loss \(String(format: "%.1f%%", inet.packetLossPercent))")
        }
        if let v6 = internetPingIPv6 {
            lines.append("- **IPv6 (`\(v6.target)`)**: \(v6.isReachable ? String(format: "%.1f ms avg, %.1f%% loss", v6.avgMs, v6.packetLossPercent) : "Unreachable")")
        }
        if !tracerouteHops.isEmpty {
            let hopSummary = tracerouteHops.map { hop in
                let ms = hop.latencyMs != nil ? String(format: "%.1f ms", hop.latencyMs!) : "*"
                return "Hop \(hop.hopNumber): \(hop.address) (\(ms))"
            }.joined(separator: " → ")
            lines.append("- **5-Hop Trace**: \(hopSummary)")
        }
        lines.append("")
        lines.append("## 3. Uncached DNS Latency")
        lines.append("- **System DNS**: \(systemDNSServers.isEmpty ? "None" : systemDNSServers.joined(separator: ", "))")
        for dns in dnsResults {
            let lat = dns.avgLatencyMs != nil ? String(format: "%.1f ms", dns.avgLatencyMs!) : "Timeout"
            lines.append("  - \(dns.name) (`\(dns.serverIP)`)\(dns.isSystemDefault ? " [Current]" : ""): **\(lat)**")
        }
        lines.append("")
        lines.append("## 4. Throughput & Bufferbloat (`networkQuality`)")
        if let nq = networkQuality {
            lines.append("- **Downlink / Uplink**: **\(String(format: "%.1f", nq.downlinkMbps)) Mbps** ↓ / **\(String(format: "%.1f", nq.uplinkMbps)) Mbps** ↑")
            lines.append("- **Idle → Loaded Latency**: \(String(format: "%.1f", nq.idleLatencyMs)) ms → \(String(format: "%.1f", nq.loadedLatencyMs)) ms (**+\(String(format: "%.1f", nq.bufferbloatDeltaMs)) ms**, Grade **\(nq.bufferbloatGrade)**)")
            lines.append("- **Responsiveness**: \(Int(nq.responsivenessRPM.rounded())) RPM • **ECN**: \(nq.ecnStatus) • **L4S**: \(nq.l4sStatus)")
        } else {
            lines.append("- Not available")
        }
        lines.append("")
        lines.append("## 5. Top Ranked Bottlenecks")
        for item in bottlenecks {
            lines.append("\(item.rank). **[\(item.scope.rawValue)] \(item.title)** — \(item.evidence) → *\(item.recommendation)*")
        }
        if let base = baseline, base.id != self.id {
            lines.append("")
            lines.append("## 6. Before vs. After Comparison")
            lines.append("| Metric | Before | After |")
            lines.append("| :--- | :--- | :--- |")
            lines.append("| PHY / Width / Rate | \(base.band) \(base.channelWidth) (\(Int(base.transmitRateMbps)) Mbps) | \(band) \(channelWidth) (\(Int(transmitRateMbps)) Mbps) |")
            lines.append("| Signal / SNR | \(base.rssi) dBm / \(base.snr) dB | \(rssi) dBm / \(snr) dB |")
            if let bGw = base.gatewayPing, let aGw = gatewayPing {
                lines.append("| Gateway Ping | \(String(format: "%.1f ms", bGw.avgMs)) (\(String(format: "%.1f%%", bGw.packetLossPercent)) loss) | \(String(format: "%.1f ms", aGw.avgMs)) (\(String(format: "%.1f%%", aGw.packetLossPercent)) loss) |")
            }
            if let bNq = base.networkQuality, let aNq = networkQuality {
                lines.append("| Downlink / Uplink | \(String(format: "%.1f / %.1f Mbps", bNq.downlinkMbps, bNq.uplinkMbps)) | \(String(format: "%.1f / %.1f Mbps", aNq.downlinkMbps, aNq.uplinkMbps)) |")
                lines.append("| Bufferbloat / RPM | +\(String(format: "%.0f ms", bNq.bufferbloatDeltaMs)) (\(bNq.bufferbloatGrade)) / \(Int(bNq.responsivenessRPM)) RPM | +\(String(format: "%.0f ms", aNq.bufferbloatDeltaMs)) (\(aNq.bufferbloatGrade)) / \(Int(aNq.responsivenessRPM)) RPM |")
            }
        }
        lines.append("")
        lines.append("---")
        lines.append("Here is my router model (or Wireless Settings screenshot): **[insert router model]**. Please give me exact click-by-click settings based on these measurements.")
        return lines.joined(separator: "\n")
    }
}
