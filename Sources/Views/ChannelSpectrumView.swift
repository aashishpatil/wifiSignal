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
        VStack(spacing: 12) {
            // Bandwidth & Speed Protection Notice (Prevents accidental speed drops)
            if monitor.currentMetrics.channelWidth == .width160MHz {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("160 MHz Ultrawide Active — High Speed Protected")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("RECOMMENDED: KEEP AUTO")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        
                        Text("Your connection is currently bonding 8 channels together (160 MHz) delivering a negotiated PHY link rate of \(Int(monitor.currentMetrics.transmitRate)) Mbps.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Text("⚠️ Do NOT switch to an individual uncongested channel unless your router supports 160 MHz bonding on it! Switching channels away from Auto often forces routers to shrink bandwidth to 20/40 MHz, causing throughput to collapse from 500+ Mbps down to <100 Mbps.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                            .padding(.top, 2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                )
            } else if monitor.currentMetrics.channelWidth == .width80MHz {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 20))
                        .padding(6)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("80 MHz Wideband Active (\(Int(monitor.currentMetrics.transmitRate)) Mbps)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("If you manually select an uncongested channel, ensure your router settings keep 80 MHz channel width enabled so speed does not drop to 20 MHz.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(10)
                .background(Color.cyan.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            HStack(spacing: 14) {
                // 2.4 GHz Recommendation
                let best24 = bestChannelFor(band: .band2GHz, candidates: [1, 6, 11])
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Best 2.4 GHz", systemImage: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Spacer()
                        Text("1, 6, 11")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ch \(best24.ch)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("(\(best24.count) APs)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    Text(best24.count == 0 ? "Zero interference detected." : "Lowest congestion non-overlapping channel.")
                        .font(.system(size: 10))
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
                
                // 5 GHz Non-DFS Recommendation
                let best5NonDFS = bestChannelFor(band: .band5GHz, candidates: [36, 40, 44, 48, 149, 153, 157, 161])
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Best 5 GHz Standard", systemImage: "shield.slash")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("Non-DFS")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ch \(best5NonDFS.ch)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("(\(best5NonDFS.count) APs)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    Text("Guaranteed IoT compatibility with zero radar CAC disconnects.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("⚠️ Avoid Ch 165 (capped at 20MHz).")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
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
                
                // 5 GHz DFS Recommendation
                let best5DFS = bestChannelFor(band: .band5GHz, candidates: [52, 56, 60, 64, 100, 104, 108, 112, 116, 132, 136, 140])
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Best 5 GHz DFS", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.8, green: 0.55, blue: 1.0))
                        Spacer()
                        Text("DFS Clean")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.55, blue: 1.0))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ch \(best5DFS.ch)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("(\(best5DFS.count) APs)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    Text("Uncrowded spectrum for maximum 80/160MHz bandwidth.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Anchors 160MHz Block 2 (Ch 100–128).")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12).opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // DFS Informational Guide
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(red: 0.8, green: 0.55, blue: 1.0))
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Understanding DFS (Dynamic Frequency Selection)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Channels 52–144 share frequencies with weather and military radar. If radar is detected, routers must temporarily vacate the channel. DFS provides pristine, uncrowded airtime, but verify that legacy smart home devices support it.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func bestChannelFor(band: ChannelBand, candidates: [Int]) -> (ch: Int, count: Int) {
        let bandNets = monitor.scanner.scannedNetworks.filter { $0.channelBand == band && !$0.isCurrentNetwork }
        var bestCh = candidates.first ?? 1
        var lowestScore = Double.greatestFiniteMagnitude
        var bestCount = 0
        
        for ch in candidates {
            let overlappingNets = bandNets.filter { net in
                if band == .band2GHz {
                    return abs(net.channelNumber - ch) <= 4
                } else {
                    return net.channelNumber == ch
                }
            }
            let count = overlappingNets.count
            let interferenceScore = overlappingNets.reduce(0.0) { sum, net in
                let distanceWeight: Double = (band == .band2GHz)
                    ? max(0.2, 1.0 - (Double(abs(net.channelNumber - ch)) * 0.2))
                    : 1.0
                return sum + (net.signalStrengthRatio * distanceWeight)
            }
            if interferenceScore < lowestScore {
                lowestScore = interferenceScore
                bestCh = ch
                bestCount = count
            }
        }
        return (bestCh, bestCount)
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
                HStack(spacing: 4) {
                    if net.isDFS {
                        Text("DFS")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.55, blue: 1.0))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    Text("Ch \(net.channelNumber) (\(net.channelBand.rawValue))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text("\(net.channelWidth.rawValue) • \(net.regulatorySubband.shortName)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 170, alignment: .trailing)
            
            // RSSI & Signal Bars
            HStack(spacing: 6) {
                SignalBarsIndicator(
                    bars: net.rssiBars,
                    color: net.signalColor,
                    barWidth: 2.5,
                    maxHeight: 12,
                    spacing: 1.5
                )
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(net.signalPercentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(net.signalColor)
                    Text("\(net.rssi) dBm")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 85, alignment: .trailing)
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
