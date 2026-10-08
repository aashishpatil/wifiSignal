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

public struct ChannelSpectrumView: View {
    @ObservedObject var monitor: WiFiMonitor
    
    public init(monitor: WiFiMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 18) {
                // Header Banner
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wi-Fi Spectrum & Interference Analyzer")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Detect co-channel interference and busy neighboring access points.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        monitor.triggerScan()
                    }) {
                        Label(monitor.scanner.isScanning ? "Scanning..." : "Rescan Spectrum", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(monitor.scanner.isScanning)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                
                // Visual Spectrum Bar Chart
                SpectrumBarChart(
                    utilizations: monitor.scanner.channelUtilizations,
                    currentChannel: monitor.currentMetrics.channelNumber,
                    currentSSID: monitor.currentMetrics.ssid
                )
                
                // Channel Recommendation Cards (Best 2.4 GHz & 5 GHz channel)
                channelRecommendationSection
                
                // Detailed Neighbor Access Point Table
                scannedNetworksTable
            }
            .padding(18)
        }
    }
    
    private var channelRecommendationSection: some View {
        HStack(spacing: 14) {
            // 2.4 GHz Recommendation
            let best24 = bestChannelFor(band: .band2GHz, candidates: [1, 6, 11])
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Best 2.4 GHz Channel", systemImage: "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Channels 1, 6, 11")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Channel \(best24.ch)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("(\(best24.count) APs)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                Text(best24.count == 0 ? "Zero interference detected on this channel." : "Lowest congestion among non-overlapping 2.4GHz channels.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // 5 GHz Recommendation
            let best5 = bestChannelFor(band: .band5GHz, candidates: [36, 44, 48, 149, 157, 161])
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Best 5 GHz Channel", systemImage: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("Wider Bandwidth")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Channel \(best5.ch)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("(\(best5.count) APs)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                Text(best5.count == 0 ? "Clean frequency slot. Maximum throughput for 80/160MHz width." : "Least occupied 5GHz channel in your area.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private func bestChannelFor(band: ChannelBand, candidates: [Int]) -> (ch: Int, count: Int) {
        let bandUtils = monitor.scanner.channelUtilizations.filter { $0.band == band }
        var bestCh = candidates.first ?? 1
        var lowestCount = 999
        
        for ch in candidates {
            let util = bandUtils.first(where: { $0.channelNumber == ch })
            let count = util?.networks.count ?? 0
            if count < lowestCount {
                lowestCount = count
                bestCh = ch
            }
        }
        return (bestCh, lowestCount == 999 ? 0 : lowestCount)
    }
    
    // MARK: - Scanned Networks Table
    private var scannedNetworksTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Detected Access Points (\(monitor.scanner.scannedNetworks.count))", systemImage: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let lastDate = monitor.scanner.lastScanDate {
                    Text("Last scan: \(lastDate.formatted(date: .omitted, time: .standard))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            if monitor.scanner.scannedNetworks.isEmpty {
                VStack(spacing: 8) {
                    Text("No scan data available.")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 6) {
                    ForEach(monitor.scanner.scannedNetworks) { net in
                        networkRow(net: net)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func networkRow(net: ScannedNetwork) -> some View {
        HStack(spacing: 12) {
            // Signal Dot
            Circle()
                .fill(net.signalColor)
                .frame(width: 8, height: 8)
            
            // Network Name & BSSID
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(net.ssid)
                        .font(.system(size: 13, weight: net.isCurrentNetwork ? .bold : .medium))
                        .foregroundColor(net.isCurrentNetwork ? .cyan : .white)
                    
                    if net.isCurrentNetwork {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan)
                            .clipShape(Capsule())
                    }
                }
                
                Text(net.bssid)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            Spacer()
            
            // Channel & Band
            VStack(alignment: .trailing, spacing: 2) {
                Text("Ch \(net.channelNumber) (\(net.channelBand.rawValue))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                Text(net.channelWidth.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 140, alignment: .trailing)
            
            // RSSI
            Text("\(net.rssi) dBm")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(net.signalColor)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(net.isCurrentNetwork ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(net.isCurrentNetwork ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }
}
