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

public struct DashboardView: View {
    @ObservedObject var monitor: WiFiMonitor
    
    public init(monitor: WiFiMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Top Header Card
                headerCard
                
                // Hero Visualizer: Radar + Radial Gauge + Status Summary
                heroVisualizerSection
                
                // 6-Metric HUD Grid
                metricsGrid
                
                // Live Real-Time Oscilloscope Graph (tracks as user moves)
                LiveHistoryGraph(
                    history: monitor.history,
                    isConnected: monitor.currentMetrics.isConnected
                )
                
                // Dynamic Router Placement & Interference Banner
                if let topAdvice = monitor.optimizationAdvice.first {
                    adviceBanner(topAdvice)
                }
            }
            .padding(18)
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(monitor.currentMetrics.rating.color.opacity(0.18))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: monitor.currentMetrics.isConnected ? "wifi" : "wifi.slash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(monitor.currentMetrics.rating.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(monitor.currentMetrics.ssid ?? "Wi-Fi Disconnected")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        if monitor.currentMetrics.isConnected {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 12) {
                        if let bssid = monitor.currentMetrics.bssid {
                            Text("BSSID: \(bssid)")
                        }
                        if let gw = monitor.currentMetrics.gatewayIP {
                            Text("Gateway: \(gw)")
                        }
                        Text("Interface: \(monitor.currentMetrics.interfaceName)")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: {
                    monitor.triggerScan()
                }) {
                    Label(monitor.scanner.isScanning ? "Scanning..." : "Scan RF Spectrum", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cyan.opacity(0.8))
                .disabled(monitor.scanner.isScanning)
                
                Button(action: {
                    if monitor.isMonitoring {
                        monitor.stopMonitoring()
                    } else {
                        monitor.startMonitoring()
                    }
                }) {
                    Image(systemName: monitor.isMonitoring ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help(monitor.isMonitoring ? "Pause live telemetry" : "Resume live telemetry")
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
    
    // MARK: - Hero Visualizer Section
    private var heroVisualizerSection: some View {
        HStack(spacing: 16) {
            // Animated Waveform Radar
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                SignalRadarCanvas(
                    qualityScore: monitor.currentMetrics.qualityScore,
                    rating: monitor.currentMetrics.rating,
                    isConnected: monitor.currentMetrics.isConnected
                )
                
                // Center Icon Overlay
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: monitor.currentMetrics.rating.color, radius: 8)
            }
            .frame(height: 180)
            
            // Radial Gauge Dial
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                RadialGaugeView(
                    score: monitor.currentMetrics.qualityScore,
                    rating: monitor.currentMetrics.rating,
                    rssi: monitor.currentMetrics.rssi,
                    isConnected: monitor.currentMetrics.isConnected
                )
            }
            .frame(width: 200, height: 180)
            
            // Quick Assessment & Advice Preview
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Signal Health", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("Auto-Updating")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Text(monitor.currentMetrics.humanDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(3)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down.and.sparkles")
                        .foregroundColor(.yellow)
                    Text("Move around with your Mac to watch the radar & graph react instantly.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .frame(height: 180)
        }
    }
    
    // MARK: - 6-Metric HUD Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // 1. Signal RSSI
            MetricCard(
                title: "Signal Strength (RSSI)",
                value: "\(monitor.currentMetrics.rssi) dBm",
                subtitle: monitor.currentMetrics.rating.rawValue + " range",
                systemImage: "antenna.radiowaves.left.and.right",
                accentColor: monitor.currentMetrics.rating.color,
                isHighlighted: true
            )
            
            // 2. Connected Channel & Band
            let bandStr = monitor.currentMetrics.channelBand.rawValue
            let widthStr = monitor.currentMetrics.channelWidth.rawValue
            MetricCard(
                title: "Connected Channel",
                value: "Ch \(monitor.currentMetrics.channelNumber)",
                subtitle: "\(bandStr) • \(widthStr)",
                systemImage: "point.3.connected.trianglepath.dotted",
                accentColor: .cyan,
                isHighlighted: true
            )
            
            // 3. Noise Floor & SNR
            MetricCard(
                title: "Noise Floor & SNR",
                value: "\(monitor.currentMetrics.snr) dB SNR",
                subtitle: "Noise: \(monitor.currentMetrics.noise) dBm",
                systemImage: "waveform.badge.magnifyingglass",
                accentColor: monitor.currentMetrics.snr > 30 ? .green : .orange
            )
            
            // 4. Transmit PHY Rate
            MetricCard(
                title: "Transmit Link Rate",
                value: String(format: "%.0f Mbps", monitor.currentMetrics.transmitRate),
                subtitle: "Negotiated PHY speed",
                systemImage: "bolt.horizontal.fill",
                accentColor: Color(red: 0.2, green: 0.8, blue: 1.0)
            )
            
            // 5. Gateway Latency & Jitter
            let latStr = monitor.currentMetrics.gatewayLatencyMs != nil ? String(format: "%.1f ms", monitor.currentMetrics.gatewayLatencyMs!) : "Measuring..."
            let jitStr = monitor.currentMetrics.gatewayJitterMs != nil ? String(format: "Jitter: %.1f ms", monitor.currentMetrics.gatewayJitterMs!) : "Jitter: --"
            MetricCard(
                title: "Router Ping Latency",
                value: latStr,
                subtitle: jitStr,
                systemImage: "timer",
                accentColor: .yellow
            )
            
            // 6. Packet Loss Rate
            let lossStr = monitor.currentMetrics.packetLossPercent != nil ? String(format: "%.1f%%", monitor.currentMetrics.packetLossPercent!) : "0.0%"
            MetricCard(
                title: "Packet Loss Rate",
                value: lossStr,
                subtitle: (monitor.currentMetrics.packetLossPercent ?? 0) > 0 ? "Retransmissions detected" : "Zero packet loss",
                systemImage: "chart.line.uptrend.xyaxis",
                accentColor: (monitor.currentMetrics.packetLossPercent ?? 0) > 2 ? .red : .green
            )
        }
    }
    
    // MARK: - Optimization Banner
    private func adviceBanner(_ advice: OptimizationAdvice) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: advice.category.icon)
                .font(.system(size: 24))
                .foregroundColor(advice.severity.color)
                .padding(8)
                .background(advice.severity.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(advice.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(advice.severity.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(advice.severity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(advice.severity.color.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                Text(advice.diagnosis)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                
                Text("Recommendation: " + advice.actionPlan)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(advice.severity.color.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
