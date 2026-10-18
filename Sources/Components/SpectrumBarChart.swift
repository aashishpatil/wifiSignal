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

public struct SpectrumBarChart: View {
    public let utilizations: [ChannelUtilization]
    public let currentChannel: Int
    public let currentSSID: String?
    
    @State private var selectedBand: ChannelBand = .band5GHz
    
    public init(utilizations: [ChannelUtilization], currentChannel: Int, currentSSID: String?) {
        self.utilizations = utilizations
        self.currentChannel = currentChannel
        self.currentSSID = currentSSID
    }
    
    private var filteredUtilizations: [ChannelUtilization] {
        return utilizations.filter { $0.band == selectedBand }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header & Band Selector
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("RF Channel Spectrum & Interference", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Shows your network (cyan) vs neighboring access points (amber/red)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Picker("Band", selection: $selectedBand) {
                    Text("2.4 GHz").tag(ChannelBand.band2GHz)
                    Text("5 GHz").tag(ChannelBand.band5GHz)
                    Text("6 GHz").tag(ChannelBand.band6GHz)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            
            // Legend
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Circle().fill(Color.cyan).frame(width: 6, height: 6)
                    Text("Your Network").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("Neighbor APs").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                }
                if selectedBand == .band5GHz {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.75, green: 0.55, blue: 1.0)).frame(width: 8, height: 8)
                        Text("DFS Channels (52–144)").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Spectrum Canvas / Bar View
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                if filteredUtilizations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No networks detected on \(selectedBand.rawValue) yet.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Click 'Scan Surroundings' in the toolbar to detect neighboring APs.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 16) {
                            ForEach(filteredUtilizations) { util in
                                channelColumn(util: util)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .frame(height: 235)
        }
    }
    
    @ViewBuilder
    private func channelColumn(util: ChannelUtilization) -> some View {
        let isConnectedCh = (util.channelNumber == currentChannel)
        
        VStack(spacing: 6) {
            // Signal power stack
            ZStack(alignment: .bottom) {
                // Background channel lane
                RoundedRectangle(cornerRadius: 6)
                    .fill(util.isDFS ? Color.purple.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(util.isDFS ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    .frame(width: 48, height: 140)
                
                // Stack of networks broadcasting on this channel
                VStack(spacing: 2) {
                    ForEach(util.networks.prefix(4)) { net in
                        let height = max(18.0, CGFloat(net.signalStrengthRatio * 110.0))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                net.isCurrentNetwork ?
                                LinearGradient(colors: [Color.cyan, Color.green], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .overlay(
                                VStack {
                                    Text("\(net.rssi)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            )
                            .frame(width: 42, height: height)
                    }
                }
            }
            
            // Channel Number Pill + DFS badge
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    Text("Ch \(util.channelNumber)")
                        .font(.system(size: 11, weight: isConnectedCh ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isConnectedCh ? .cyan : .white.opacity(0.8))
                }
                
                if util.isDFS {
                    Text("DFS")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(red: 0.8, green: 0.55, blue: 1.0))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(red: 0.8, green: 0.55, blue: 1.0).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                
                if isConnectedCh {
                    Text("ACTIVE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                } else {
                    Text("\(util.networks.count) APs")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(util.congestionColor)
                }
            }
        }
    }
}
