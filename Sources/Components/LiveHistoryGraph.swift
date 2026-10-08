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

public enum GraphDisplayMode: String, CaseIterable, Identifiable {
    case rssi = "Signal (dBm)"
    case quality = "Quality Index (%)"
    case latency = "Gateway Latency (ms)"
    
    public var id: String { rawValue }
}

public struct LiveHistoryGraph: View {
    public let history: [SignalHistoryEntry]
    public let isConnected: Bool
    
    @State private var displayMode: GraphDisplayMode = .rssi
    
    public init(history: [SignalHistoryEntry], isConnected: Bool) {
        self.history = history
        self.isConnected = isConnected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with mode selector
            HStack {
                Label("Live Signal Oscilloscope", systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("", selection: $displayMode) {
                    ForEach(GraphDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            
            // Graph Viewport
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                if !isConnected || history.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("Awaiting live signal telemetry...")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                } else {
                    GeometryReader { geo in
                        drawGraph(in: geo.size)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .frame(height: 180)
            
            // Statistics Footer
            if isConnected && !history.isEmpty {
                statsFooter
            }
        }
    }
    
    @ViewBuilder
    private func drawGraph(in size: CGSize) -> some View {
        let values: [Double] = history.map { entry in
            switch displayMode {
            case .rssi: return entry.rssi
            case .quality: return entry.qualityScore
            case .latency: return entry.latencyMs ?? 0.0
            }
        }
        
        let (minY, maxY) = valueBounds()
        let rangeY = max(1.0, maxY - minY)
        
        // Helper to convert index and value to CGPoint
        func point(for index: Int, value: Double) -> CGPoint {
            let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * size.width
            let normalizedY = (value - minY) / rangeY
            let y = size.height - (CGFloat(normalizedY) * size.height)
            return CGPoint(x: x, y: max(4, min(size.height - 4, y)))
        }
        
        return ZStack {
            // Horizontal reference guide lines
            referenceGuides(in: size, minY: minY, maxY: maxY)
            
            // Area gradient path
            Path { path in
                guard values.count > 1 else { return }
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: point(for: 0, value: values[0]))
                for i in 1..<values.count {
                    path.addLine(to: point(for: i, value: values[i]))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        curveColor.opacity(0.35),
                        curveColor.opacity(0.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Line stroke path
            Path { path in
                guard values.count > 1 else { return }
                path.move(to: point(for: 0, value: values[0]))
                for i in 1..<values.count {
                    path.addLine(to: point(for: i, value: values[i]))
                }
            }
            .stroke(
                curveColor,
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            
            // Leading live pulse dot
            if let lastValue = values.last {
                let leadPt = point(for: values.count - 1, value: lastValue)
                Circle()
                    .fill(curveColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: curveColor, radius: 4)
                    .position(leadPt)
            }
        }
    }
    
    @ViewBuilder
    private func referenceGuides(in size: CGSize, minY: Double, maxY: Double) -> some View {
        let guides: [(val: Double, label: String)] = {
            switch displayMode {
            case .rssi:
                return [(-40.0, "Great -40"), (-67.0, "Good -67"), (-80.0, "Weak -80")]
            case .quality:
                return [(80.0, "80%"), (50.0, "50%"), (20.0, "20%")]
            case .latency:
                return [(5.0, "5ms"), (25.0, "25ms"), (50.0, "50ms")]
            }
        }()
        
        let rangeY = max(1.0, maxY - minY)
        
        ForEach(guides, id: \.label) { guide in
            if guide.val >= minY && guide.val <= maxY {
                let norm = (guide.val - minY) / rangeY
                let y = size.height - (CGFloat(norm) * size.height)
                
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                
                Text(guide.label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .position(x: 35, y: y - 8)
            }
        }
    }
    
    private var statsFooter: some View {
        let values: [Double] = history.map { entry in
            switch displayMode {
            case .rssi: return entry.rssi
            case .quality: return entry.qualityScore
            case .latency: return entry.latencyMs ?? 0.0
            }
        }
        
        let minVal = values.min() ?? 0.0
        let maxVal = values.max() ?? 0.0
        let avgVal = values.reduce(0.0, +) / Double(max(1, values.count))
        let unit = displayMode == .rssi ? " dBm" : (displayMode == .quality ? "%" : " ms")
        
        return HStack(spacing: 20) {
            statBadge(label: "Current", val: String(format: "%.1f%@", values.last ?? 0.0, unit), color: curveColor)
            statBadge(label: "Avg", val: String(format: "%.1f%@", avgVal, unit), color: .white.opacity(0.8))
            statBadge(label: "Peak", val: String(format: "%.1f%@", maxVal, unit), color: .green)
            statBadge(label: "Low", val: String(format: "%.1f%@", minVal, unit), color: .orange)
            
            Spacer()
            
            Text("Real-time (60s sliding window)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 4)
    }
    
    private func statBadge(label: String, val: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(val)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
    
    private var curveColor: Color {
        switch displayMode {
        case .rssi:
            let lastRSSI = history.last?.rssi ?? -80.0
            if lastRSSI > -60 { return Color(red: 0.0, green: 0.9, blue: 0.6) }
            else if lastRSSI > -75 { return Color(red: 0.2, green: 0.8, blue: 1.0) }
            else { return Color(red: 1.0, green: 0.45, blue: 0.0) }
        case .quality:
            return Color(red: 0.0, green: 0.9, blue: 0.8)
        case .latency:
            return Color(red: 1.0, green: 0.7, blue: 0.2)
        }
    }
    
    private func valueBounds() -> (Double, Double) {
        switch displayMode {
        case .rssi:
            return (-95.0, -30.0)
        case .quality:
            return (0.0, 100.0)
        case .latency:
            let maxL = history.compactMap { $0.latencyMs }.max() ?? 20.0
            return (0.0, max(25.0, maxL * 1.2))
        }
    }
}
