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

import SwiftUI
import AppKit

public struct NetworkDiagnosticView: View {
    @ObservedObject var monitor: WiFiMonitor
    let runner: DiagnosticRunner
    @State private var copiedFeedback: Bool = false
    
    public init(monitor: WiFiMonitor, runner: DiagnosticRunner) {
        self.monitor = monitor
        self.runner = runner
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                DiagnosticHeaderCard(
                    isConnected: monitor.currentMetrics.isConnected,
                    isRunning: runner.isRunning,
                    hasReport: runner.latestReport != nil,
                    isPinnedAsBaseline: isLatestPinnedAsBaseline,
                    copiedFeedback: copiedFeedback,
                    onRunOrStop: {
                        if runner.isRunning {
                            runner.cancel()
                        } else {
                            runner.runFullDiagnostic(monitor: monitor)
                        }
                    },
                    onPinBaseline: {
                        runner.pinLatestAsBaseline()
                    },
                    onCopyAIReport: copyReportToClipboard
                )
                
                if let error = runner.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                StagePipelineView(
                    stageStates: runner.stageStates,
                    isRunning: runner.isRunning,
                    progress: runner.progress,
                    statusMessage: runner.statusMessage
                )
                
                if let report = runner.latestReport {
                    if let baseline = runner.baselineReport, baseline.id != report.id {
                        BaselineComparisonCard(
                            baseline: baseline,
                            latest: report,
                            onClearBaseline: { runner.clearBaseline() }
                        )
                    }
                    
                    RankedBottlenecksSection(bottlenecks: report.bottlenecks)
                    
                    HStack(alignment: .top, spacing: 14) {
                        ThroughputBufferbloatCard(networkQuality: report.networkQuality, phyRateMbps: report.transmitRateMbps)
                        HopIsolationCard(
                            gatewayPing: report.gatewayPing,
                            internetIPv4: report.internetPingIPv4,
                            internetIPv6: report.internetPingIPv6,
                            hops: report.tracerouteHops
                        )
                    }
                    
                    HStack(alignment: .top, spacing: 14) {
                        DNSRaceCard(systemDNS: report.systemDNSServers, results: report.dnsResults)
                        EnvironmentAndRoamsCard(report: report, roamEvents: monitor.roamEvents)
                    }
                } else {
                    emptyStateCard
                }
            }
            .padding(18)
        }
    }
    
    private var isLatestPinnedAsBaseline: Bool {
        guard let latest = runner.latestReport, let baseline = runner.baselineReport else { return false }
        return latest.id == baseline.id
    }
    
    private func copyReportToClipboard() {
        guard let report = runner.latestReport else { return }
        let markdown = report.markdownExport(baseline: runner.baselineReport)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        copiedFeedback = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedFeedback = false
        }
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 32))
                .foregroundColor(.cyan.opacity(0.8))
            Text("Sequential 4-Stage Network Audit")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text("Pauses continuous background pings during tests so idle latency isn't polluted by load. Measures PHY/SNR, Hop-by-Hop Ping + Traceroute, Uncached DNS, and Apple networkQuality Speed + Bufferbloat.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12).opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Header Card
private struct DiagnosticHeaderCard: View {
    let isConnected: Bool
    let isRunning: Bool
    let hasReport: Bool
    let isPinnedAsBaseline: Bool
    let copiedFeedback: Bool
    let onRunOrStop: () -> Void
    let onPinBaseline: () -> Void
    let onCopyAIReport: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "stethoscope")
                .font(.system(size: 24))
                .foregroundColor(.cyan)
                .padding(10)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Sequential Wi-Fi & Network Deep Diagnostic")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Separates RF congestion, local hogs/DNS, router bufferbloat, and ISP latency without parallel test pollution.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if hasReport && !isRunning {
                    Button(action: onPinBaseline) {
                        Label(isPinnedAsBaseline ? "Baseline Pinned" : "Pin as Baseline", systemImage: isPinnedAsBaseline ? "pin.fill" : "pin")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(isPinnedAsBaseline ? .green : .white)
                    .disabled(isPinnedAsBaseline)
                    
                    Button(action: onCopyAIReport) {
                        Label(copiedFeedback ? "Copied!" : "Copy AI Report", systemImage: copiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedFeedback ? .green : .cyan)
                }
                
                Button(action: onRunOrStop) {
                    Label(isRunning ? "Stop Audit" : "Run Full Diagnostic (~25s)", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .cyan)
                .disabled(!isConnected && !isRunning)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - 4-Stage Pipeline Stepper
private struct StagePipelineView: View {
    let stageStates: [DiagnosticStage: DiagnosticStageState]
    let isRunning: Bool
    let progress: Double
    let statusMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(DiagnosticStage.allCases) { stage in
                    StagePillCard(stage: stage, state: stageStates[stage] ?? .pending)
                }
            }
            
            if isRunning || progress > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress, total: 1.0)
                        .tint(.cyan)
                    Text(statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.11).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct StagePillCard: View {
    let stage: DiagnosticStage
    let state: DiagnosticStageState
    
    private var accentColor: Color {
        switch state {
        case .pending: return .white.opacity(0.35)
        case .running: return .cyan
        case .completed: return .green
        case .failed: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                switch state {
                case .running:
                    ProgressView()
                        .controlSize(.small)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                case .pending:
                    Image(systemName: stage.icon)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stage.rawValue + 1). \(stage.title)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(state == .pending ? .white.opacity(0.6) : .white)
                    .lineLimit(1)
                Text(stage.subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state == .running ? accentColor.opacity(0.7) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Before vs. After Comparison
private struct ComparisonMetricRow: Identifiable {
    let id: String
    let label: String
    let before: String
    let after: String
    let deltaText: String
    let deltaColor: Color
}

private struct BaselineComparisonCard: View {
    let baseline: DiagnosticReport
    let latest: DiagnosticReport
    let onClearBaseline: () -> Void
    
    private var rows: [ComparisonMetricRow] {
        var list: [ComparisonMetricRow] = []
        
        list.append(ComparisonMetricRow(
            id: "link",
            label: "Wi-Fi PHY / Width",
            before: "\(baseline.band) \(baseline.channelWidth) • \(Int(baseline.transmitRateMbps)) Mbps",
            after: "\(latest.band) \(latest.channelWidth) • \(Int(latest.transmitRateMbps)) Mbps",
            deltaText: formatSignedDelta(latest.transmitRateMbps - baseline.transmitRateMbps, unit: " Mbps", higherIsBetter: true).text,
            deltaColor: formatSignedDelta(latest.transmitRateMbps - baseline.transmitRateMbps, unit: " Mbps", higherIsBetter: true).color
        ))
        
        list.append(ComparisonMetricRow(
            id: "snr",
            label: "Signal / SNR",
            before: "\(baseline.rssi) dBm / \(baseline.snr) dB",
            after: "\(latest.rssi) dBm / \(latest.snr) dB",
            deltaText: formatSignedDelta(Double(latest.snr - baseline.snr), unit: " dB", higherIsBetter: true).text,
            deltaColor: formatSignedDelta(Double(latest.snr - baseline.snr), unit: " dB", higherIsBetter: true).color
        ))
        
        if let bGw = baseline.gatewayPing, let lGw = latest.gatewayPing {
            let d = formatSignedDelta(lGw.avgMs - bGw.avgMs, unit: " ms", higherIsBetter: false)
            list.append(ComparisonMetricRow(
                id: "gw_ping",
                label: "Gateway Ping (Idle)",
                before: String(format: "%.1f ms (%.1f%% loss)", bGw.avgMs, bGw.packetLossPercent),
                after: String(format: "%.1f ms (%.1f%% loss)", lGw.avgMs, lGw.packetLossPercent),
                deltaText: d.text,
                deltaColor: d.color
            ))
        }
        
        if let bInet = baseline.internetPingIPv4, let lInet = latest.internetPingIPv4 {
            let d = formatSignedDelta(lInet.avgMs - bInet.avgMs, unit: " ms", higherIsBetter: false)
            list.append(ComparisonMetricRow(
                id: "inet_ping",
                label: "Internet Ping (1.1.1.1)",
                before: String(format: "%.1f ms (%.1f%% loss)", bInet.avgMs, bInet.packetLossPercent),
                after: String(format: "%.1f ms (%.1f%% loss)", lInet.avgMs, lInet.packetLossPercent),
                deltaText: d.text,
                deltaColor: d.color
            ))
        }
        
        if let bNq = baseline.networkQuality, let lNq = latest.networkQuality {
            let dlDelta = formatSignedDelta(lNq.downlinkMbps - bNq.downlinkMbps, unit: " Mbps", higherIsBetter: true)
            list.append(ComparisonMetricRow(
                id: "dl",
                label: "Downlink Speed",
                before: String(format: "%.1f Mbps", bNq.downlinkMbps),
                after: String(format: "%.1f Mbps", lNq.downlinkMbps),
                deltaText: dlDelta.text,
                deltaColor: dlDelta.color
            ))
            
            let ulDelta = formatSignedDelta(lNq.uplinkMbps - bNq.uplinkMbps, unit: " Mbps", higherIsBetter: true)
            list.append(ComparisonMetricRow(
                id: "ul",
                label: "Uplink Speed",
                before: String(format: "%.1f Mbps", bNq.uplinkMbps),
                after: String(format: "%.1f Mbps", lNq.uplinkMbps),
                deltaText: ulDelta.text,
                deltaColor: ulDelta.color
            ))
            
            let bloatDelta = formatSignedDelta(lNq.bufferbloatDeltaMs - bNq.bufferbloatDeltaMs, unit: " ms", higherIsBetter: false)
            list.append(ComparisonMetricRow(
                id: "bloat",
                label: "Bufferbloat (Loaded Δ)",
                before: String(format: "+%.0f ms (%@)", bNq.bufferbloatDeltaMs, bNq.bufferbloatGrade),
                after: String(format: "+%.0f ms (%@)", lNq.bufferbloatDeltaMs, lNq.bufferbloatGrade),
                deltaText: bloatDelta.text,
                deltaColor: bloatDelta.color
            ))
            
            let rpmDelta = formatSignedDelta(lNq.responsivenessRPM - bNq.responsivenessRPM, unit: " RPM", higherIsBetter: true)
            list.append(ComparisonMetricRow(
                id: "rpm",
                label: "Responsiveness",
                before: "\(Int(bNq.responsivenessRPM.rounded())) RPM",
                after: "\(Int(lNq.responsivenessRPM.rounded())) RPM",
                deltaText: rpmDelta.text,
                deltaColor: rpmDelta.color
            ))
        }
        
        return list
    }
    
    private func formatSignedDelta(_ diff: Double, unit: String, higherIsBetter: Bool) -> (text: String, color: Color) {
        if abs(diff) < 0.5 {
            return ("No change", .white.opacity(0.5))
        }
        let sign = diff > 0 ? "+" : ""
        let text = String(format: "%@%.0f%@", sign, diff, unit)
        let improved = higherIsBetter ? (diff > 0) : (diff < 0)
        return (text, improved ? .green : .red)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Before vs. After Comparison", systemImage: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                Spacer()
                Text("Baseline: \(baseline.timestamp.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                Button("Reset Baseline", action: onClearBaseline)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text("Metric").frame(width: 155, alignment: .leading)
                    Text("Before (Baseline)").frame(maxWidth: .infinity, alignment: .leading)
                    Text("After (Latest)").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Change").frame(width: 95, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 4)
                
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 155, alignment: .leading)
                        Text(row.before)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.after)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.deltaText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(row.deltaColor)
                            .frame(width: 95, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ranked Bottlenecks
private struct RankedBottlenecksSection: View {
    let bottlenecks: [RankedBottleneck]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ranked Bottlenecks & Action Plan", systemImage: "list.number")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            ForEach(bottlenecks) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text("#\(item.rank)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(item.severityColor)
                        .frame(width: 30, height: 30)
                        .background(item.severityColor.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.scope.rawValue.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundColor(item.scope.badgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.scope.badgeColor.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        Text(item.evidence)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Fix: " + item.recommendation)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.12).opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(item.severityColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Throughput & Bufferbloat Card
private struct ThroughputBufferbloatCard: View {
    let networkQuality: NetworkQualityResult?
    let phyRateMbps: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Throughput & Bufferbloat", systemImage: "speedometer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let nq = networkQuality {
                    Text("GRADE \(nq.bufferbloatGrade)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(nq.gradeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(nq.gradeColor.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            
            if let nq = networkQuality {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Downlink")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                        Text(String(format: "%.1f Mbps", nq.downlinkMbps))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uplink")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                        Text(String(format: "%.1f Mbps", nq.uplinkMbps))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Responsiveness")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                        Text("\(Int(nq.responsivenessRPM.rounded())) RPM")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(nq.gradeColor)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "Idle → Loaded RTT: %.1f ms → %.1f ms (+%.0f ms bloat)", nq.idleLatencyMs, nq.loadedLatencyMs, nq.bufferbloatDeltaMs))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                    Text("PHY Link Ceiling: \(Int(phyRateMbps)) Mbps • ECN: \(nq.ecnStatus) • L4S: \(nq.l4sStatus)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
            } else {
                Text("networkQuality measurements did not complete.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Hop-by-Hop Isolation Card
private struct HopIsolationCard: View {
    let gatewayPing: PingBurstStats?
    let internetIPv4: PingBurstStats?
    let internetIPv6: PingBurstStats?
    let hops: [TracerouteHop]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hop-by-Hop Latency & Trace", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 6) {
                if let gw = gatewayPing {
                    pingRow(stats: gw)
                }
                if let inet = internetIPv4 {
                    pingRow(stats: inet)
                }
                if let v6 = internetIPv6 {
                    pingRow(stats: v6)
                }
            }
            
            if !hops.isEmpty {
                Divider()
                Text("First 5 Hops to 1.1.1.1")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                
                ForEach(hops) { hop in
                    HStack {
                        Text("Hop \(hop.hopNumber)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .frame(width: 44, alignment: .leading)
                        Text(hop.address)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text(hop.latencyMs != nil ? String(format: "%.1f ms", hop.latencyMs!) : "*")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor((hop.latencyMs ?? 0) > 35 ? .orange : .green)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func pingRow(stats: PingBurstStats) -> some View {
        HStack {
            Text(stats.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 90, alignment: .leading)
            Text(stats.target)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
            Spacer()
            if stats.isReachable {
                Text(String(format: "%.1f ms (±%.1f) • %.0f%% loss", stats.avgMs, stats.stddevMs, stats.packetLossPercent))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(stats.packetLossPercent > 1 ? .red : .green)
            } else {
                Text("Unreachable")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - DNS Race Card
private struct DNSRaceCard: View {
    let systemDNS: [String]
    let results: [DNSBenchmarkResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Uncached DNS Race", systemImage: "globe.americas.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(systemDNS.isEmpty ? "No DNS" : systemDNS.joined(separator: ", "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            let maxMs = max(30.0, results.compactMap(\.avgLatencyMs).max() ?? 50.0)
            ForEach(results) { res in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(res.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            if res.isSystemDefault {
                                Text("CURRENT")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.cyan)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(res.serverIP)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 145, alignment: .leading)
                    
                    GeometryReader { geo in
                        let fraction = res.avgLatencyMs.map { min(1.0, max(0.08, $0 / maxMs)) } ?? 0.0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)
                            if res.succeeded {
                                Capsule()
                                    .fill((res.avgLatencyMs ?? 0) < 25 ? Color.green : Color.orange)
                                    .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 16)
                    
                    Text(res.avgLatencyMs != nil ? String(format: "%.1f ms", res.avgLatencyMs!) : "Timeout")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(res.succeeded ? .white : .red)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Environment & Session Roam Log Card
private struct EnvironmentAndRoamsCard: View {
    let report: DiagnosticReport
    let roamEvents: [RoamEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Link, Environment & Roam Log", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 5) {
                envLine("PHY & Width", "\(report.phyMode) • \(report.band) Ch \(report.channel) @ \(report.channelWidth)")
                envLine("Cleanest 5 GHz", "Non-DFS Ch \(report.cleanest5GHzNonDFSChannel) (\(report.cleanest5GHzNonDFSNeighbors) APs) • DFS Ch \(report.cleanest5GHzDFSChannel) (\(report.cleanest5GHzDFSNeighbors) APs)")
                envLine("Cleanest 2.4 GHz", "Ch \(report.cleanest24GHzChannel) (\(report.cleanest24GHzNeighbors) APs)")
                envLine("Local BG Traffic", String(format: "%.2f Mbps • Extra Same-Radio SSIDs: %d", report.backgroundTrafficMbps, report.sameRouterExtraSSIDs))
                envLine("Interface Errors", "In: \(report.interfaceInputErrors), Out: \(report.interfaceOutputErrors) (Δ \(report.interfaceErrorDelta) in audit)")
                envLine("VPN / Proxy", "\(report.isVPNActive ? "Active (\(report.vpnInterfaceName ?? "utun"))" : "None") / \(report.isProxyActive ? "Active" : "None")")
            }
            
            Divider()
            
            Text("Session Roam & Link Events (\(roamEvents.count))")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            
            if roamEvents.isEmpty {
                Text("No roaming or disconnect events recorded in this session.")
                    .font(.system(size: 10))
                    .foregroundColor(.green.opacity(0.8))
            } else {
                ForEach(roamEvents.prefix(5)) { event in
                    HStack {
                        Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                        Text(event.summary)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func envLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 115, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
    }
}
