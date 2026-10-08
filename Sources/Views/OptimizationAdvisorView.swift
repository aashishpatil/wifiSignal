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

public struct OptimizationAdvisorView: View {
    @ObservedObject var monitor: WiFiMonitor
    
    public init(monitor: WiFiMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 18) {
                // Header Banner
                HStack(spacing: 14) {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.yellow)
                        .padding(10)
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Router Placement & Wi-Fi Tuning Advisor")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Physical placement rules and frequency tuning to eliminate dead zones and radio interference.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
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
                
                // Active Diagnostic Recommendations from live metrics
                activeDiagnosticsSection
                
                // Core Router Placement Best Practices
                goldenPlacementRulesSection
            }
            .padding(18)
        }
    }
    
    private var activeDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Active Diagnostics for Current Position", systemImage: "stethoscope")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            if monitor.optimizationAdvice.isEmpty {
                Text("Analyzing connection...")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 12))
            } else {
                ForEach(monitor.optimizationAdvice) { advice in
                    adviceCard(advice: advice)
                }
            }
        }
    }
    
    @ViewBuilder
    private func adviceCard(advice: OptimizationAdvice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(advice.title, systemImage: advice.category.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(advice.severity.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(advice.severity.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(advice.severity.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Text(advice.diagnosis)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
            
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 11))
                    .padding(.top, 2)
                Text(advice.actionPlan)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(advice.severity.color.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    private var goldenPlacementRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Golden Rules of Router Placement", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                ruleRow(
                    num: "1",
                    title: "Central & Elevated",
                    desc: "Wi-Fi signals radiate outwards and downwards like an umbrella. Mount or place the router 4 to 6 feet off the floor on an open table or shelf, not on the carpet or tucked behind a desk.",
                    icon: "arrow.up.circle"
                )
                
                ruleRow(
                    num: "2",
                    title: "Beware of RF Absorbers & Reflectors",
                    desc: "Dense concrete, brick walls, plumbing pipes, large mirrors, and metal appliances (refrigerators, microwaves) severely absorb and bounce 5GHz and 6GHz signals.",
                    icon: "shield.slash"
                )
                
                ruleRow(
                    num: "3",
                    title: "Avoid Electronic Interference",
                    desc: "Keep the router at least 3 feet away from microwave ovens, baby monitors, cordless phone stations, and unshielded USB 3.0 hubs, which leak radiation directly into the 2.4 GHz spectrum.",
                    icon: "antenna.radiowaves.left.and.right.slash"
                )
                
                ruleRow(
                    num: "4",
                    title: "Antenna Orientation Matters",
                    desc: "If your router has external antennas: for a single-story home, orient antennas vertically. For a multi-story home, tilt one antenna at a 45° angle to project signal through the ceiling and floors.",
                    icon: "tuningfork"
                )
            }
        }
    }
    
    @ViewBuilder
    private func ruleRow(num: String, title: String, desc: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.cyan)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.12).opacity(0.55))
        )
    }
}
