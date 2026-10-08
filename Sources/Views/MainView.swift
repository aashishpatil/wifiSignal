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

public enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Live Dashboard"
    case spectrum = "RF Spectrum & Channels"
    case survey = "Room Survey Walk"
    case advisor = "Placement Advisor"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .dashboard: return "waveform.path.ecg"
        case .spectrum: return "chart.bar.xaxis"
        case .survey: return "figure.walk.motion"
        case .advisor: return "lightbulb.max.fill"
        }
    }
}

public struct MainView: View {
    @StateObject private var monitor = WiFiMonitor.shared
    @State private var selectedTab: NavigationTab = .dashboard
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(NavigationTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("WiFi Signal")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .safeAreaInset(edge: .bottom) {
                sidebarStatusPill
            }
        } detail: {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(monitor: monitor)
                case .spectrum:
                    ChannelSpectrumView(monitor: monitor)
                case .survey:
                    RoomSurveyView(monitor: monitor)
                case .advisor:
                    OptimizationAdvisorView(monitor: monitor)
                }
            }
            .frame(minWidth: 700, minHeight: 600)
            .background(Color(red: 0.08, green: 0.09, blue: 0.11))
        }
    }
    
    private var sidebarStatusPill: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.currentMetrics.rating.color)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.currentMetrics.ssid ?? "Disconnected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(monitor.currentMetrics.rssi) dBm • Ch \(monitor.currentMetrics.channelNumber)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(monitor.currentMetrics.qualityScore)%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(monitor.currentMetrics.rating.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
