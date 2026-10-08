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

public struct RoomSurveyView: View {
    @ObservedObject var monitor: WiFiMonitor
    @State private var surveyPoints: [RoomSurveyPoint] = []
    @State private var newRoomName: String = ""
    @State private var selectedPreset: String = "Living Room"
    
    private let roomPresets = ["Living Room", "Home Office", "Master Bedroom", "Kitchen", "Guest Room", "Basement", "Patio / Deck", "Hallway"]
    
    public init(monitor: WiFiMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 18) {
                // Intro Guide Banner
                walkthroughBanner
                
                // Active Room Logger Controls
                loggingControlCard
                
                // Router Placement Recommendation Summary (if at least 2 rooms logged)
                if surveyPoints.count >= 2 {
                    placementAuditSummaryCard
                }
                
                // Logged Rooms Ranked List
                loggedRoomsList
            }
            .padding(18)
        }
    }
    
    private var walkthroughBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 28))
                .foregroundColor(.cyan)
                .padding(10)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Room-by-Room Wi-Fi Survey")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Walk through your home to map signal health and pinpoint the best router location.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if !surveyPoints.isEmpty {
                Button("Clear Survey", role: .destructive) {
                    surveyPoints.removeAll()
                }
                .buttonStyle(.bordered)
            }
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
    }
    
    private var loggingControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Log Current Location", systemImage: "mappin.and.ellipse")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                // Preset Dropdown
                Picker("Room", selection: $selectedPreset) {
                    ForEach(roomPresets, id: \.self) { preset in
                        Text(preset).tag(preset)
                    }
                }
                .frame(width: 160)
                
                // Custom Name Field
                TextField("Or type custom room name", text: $newRoomName)
                    .textFieldStyle(.roundedBorder)
                
                // Record Button
                Button(action: recordCurrentSpot) {
                    Label("Log Measurement", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.green)
                .disabled(!monitor.currentMetrics.isConnected)
            }
            
            // Live Preview of Current Readings
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Current Live Signal:")
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(monitor.currentMetrics.rssi) dBm")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(monitor.currentMetrics.rating.color)
                }
                
                HStack(spacing: 4) {
                    Text("SNR:")
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(monitor.currentMetrics.snr) dB")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 4) {
                    Text("Gateway Ping:")
                        .foregroundColor(.white.opacity(0.6))
                    let lat = monitor.currentMetrics.gatewayLatencyMs != nil ? String(format: "%.1f ms", monitor.currentMetrics.gatewayLatencyMs!) : "--"
                    Text(lat)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Text("Quality Score: \(monitor.currentMetrics.qualityScore)%")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(monitor.currentMetrics.rating.color)
            }
            .font(.system(size: 11))
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func recordCurrentSpot() {
        let name = newRoomName.trimmingCharacters(in: .whitespaces).isEmpty ? selectedPreset : newRoomName
        let m = monitor.currentMetrics
        
        let point = RoomSurveyPoint(
            roomName: name,
            rssi: m.rssi,
            noise: m.noise,
            snr: m.snr,
            channelNumber: m.channelNumber,
            transmitRate: m.transmitRate,
            latencyMs: m.gatewayLatencyMs ?? 0.0,
            jitterMs: m.gatewayJitterMs ?? 0.0,
            packetLossPercent: m.packetLossPercent ?? 0.0,
            qualityScore: m.qualityScore
        )
        
        withAnimation {
            surveyPoints.append(point)
            newRoomName = ""
        }
    }
    
    private var placementAuditSummaryCard: some View {
        let sorted = surveyPoints.sorted { $0.qualityScore > $1.qualityScore }
        let best = sorted.first!
        let worst = sorted.last!
        let scoreDiff = best.qualityScore - worst.qualityScore
        
        return VStack(alignment: .leading, spacing: 10) {
            Label("Router Placement Audit Results", systemImage: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.cyan)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strongest Location")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Text(best.roomName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.green)
                    Text("\(best.rssi) dBm • Grade \(best.grade)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weakest Zone")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Text(worst.roomName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(worst.qualityScore < 60 ? .red : .yellow)
                    Text("\(worst.rssi) dBm • Grade \(worst.grade)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Signal Drop-off")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Text("-\(scoreDiff)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(scoreDiff > 35 ? .orange : .green)
                    Text("\(abs(best.rssi - worst.rssi)) dB attenuation")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
            
            Text(placementAdviceText(best: best, worst: worst, diff: scoreDiff))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .padding(8)
                .background(Color.cyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func placementAdviceText(best: RoomSurveyPoint, worst: RoomSurveyPoint, diff: Int) -> String {
        if diff > 40 {
            return "Placement Advice: Severe coverage gradient detected. Your router is currently heavily biased towards \(best.roomName). To balance coverage for \(worst.roomName), move the router closer to the physical center of your home, or install a wireless mesh satellite midway."
        } else if worst.qualityScore < 50 {
            return "Placement Advice: \(worst.roomName) is in a near-dead zone. Radio waves are likely being absorbed by thick walls, metal appliances, or plumbing between your router and this room. Raising the router by 3–4 feet often bypasses heavy ground clutter."
        } else {
            return "Placement Advice: Healthy signal distribution across surveyed rooms. Coverage is consistent with minimal attenuation."
        }
    }
    
    private var loggedRoomsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Surveyed Locations (\(surveyPoints.count))", systemImage: "list.number")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            if surveyPoints.isEmpty {
                VStack(spacing: 8) {
                    Text("No rooms surveyed yet.")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 12))
                    Text("Select a room above and tap 'Log Measurement' to start.")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ForEach(surveyPoints.sorted(by: { $0.qualityScore > $1.qualityScore })) { pt in
                    roomRow(pt: pt)
                }
            }
        }
    }
    
    @ViewBuilder
    private func roomRow(pt: RoomSurveyPoint) -> some View {
        HStack(spacing: 14) {
            // Grade badge
            Text(pt.grade)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 38, height: 38)
                .background(pt.gradeColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(pt.roomName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(pt.verdict)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(pt.rssi) dBm")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(pt.gradeColor)
                
                Text("\(pt.snr) dB SNR • \(String(format: "%.1f ms", pt.latencyMs))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.12).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
