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

public struct SignalRadarCanvas: View {
    public let qualityScore: Int
    public let rating: SignalRating
    public let isConnected: Bool
    
    public init(qualityScore: Int, rating: SignalRating, isConnected: Bool) {
        self.qualityScore = qualityScore
        self.rating = rating
        self.isConnected = isConnected
    }
    
    public var body: some View {
        TimelineView(.animation) { (timeline: TimelineViewDefaultContext) in
            Canvas { (context: inout GraphicsContext, size: CGSize) in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawRadar(context: &context, size: size, time: time)
            }
        }
    }
    
    private func drawRadar(context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2 - 10
        
        guard isConnected else {
            // Dim static rings when disconnected
            for i in 1...4 {
                let r = maxRadius * (Double(i) / 4.0)
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color.gray.opacity(0.15)),
                    lineWidth: 1
                )
            }
            return
        }
        
        let baseColor = rating.color
        let speedMultiplier = max(0.5, Double(qualityScore) / 40.0)
        
        // Draw 4 concentric background guide rings
        for i in 1...4 {
            let r = maxRadius * (Double(i) / 4.0)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(baseColor.opacity(0.12)),
                lineWidth: 1
            )
        }
        
        // Draw expanding pulse waves
        let waveCount = 3
        for i in 0..<waveCount {
            let phase = (time * speedMultiplier * 0.4 + Double(i) / Double(waveCount)).truncatingRemainder(dividingBy: 1.0)
            let currentRadius = maxRadius * phase
            let opacity = max(0.0, (1.0 - phase) * 0.6)
            
            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - currentRadius,
                y: center.y - currentRadius,
                width: currentRadius * 2,
                height: currentRadius * 2
            ))
            
            context.stroke(
                path,
                with: .color(baseColor.opacity(opacity)),
                lineWidth: CGFloat(2.5 * (1.0 - phase) + 0.5)
            )
        }
        
        // Radial sweep beam (Radar scanner)
        let angle = (time * speedMultiplier * 0.8).truncatingRemainder(dividingBy: .pi * 2)
        var sweepPath = Path()
        sweepPath.move(to: center)
        sweepPath.addArc(
            center: center,
            radius: maxRadius,
            startAngle: Angle(radians: angle - 0.4),
            endAngle: Angle(radians: angle),
            clockwise: false
        )
        sweepPath.closeSubpath()
        
        let gradient = Gradient(colors: [
            baseColor.opacity(0.0),
            baseColor.opacity(0.25)
        ])
        context.fill(
            sweepPath,
            with: .conicGradient(
                gradient,
                center: center,
                angle: Angle(radians: angle - 0.4)
            )
        )
        
        // Center glowing core
        let coreRadius: CGFloat = 16.0
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
        context.fill(Path(ellipseIn: coreRect), with: .color(baseColor.opacity(0.9)))
        
        // Outer core halo
        let haloRect = CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)
        context.stroke(Path(ellipseIn: haloRect), with: .color(baseColor.opacity(0.5)), lineWidth: 1.5)
    }
}
