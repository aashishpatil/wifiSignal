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

public struct RadialGaugeView: View {
    public let score: Int
    public let rating: SignalRating
    public let rssi: Int
    public let isConnected: Bool
    
    public init(score: Int, rating: SignalRating, rssi: Int, isConnected: Bool) {
        self.score = score
        self.rating = rating
        self.rssi = rssi
        self.isConnected = isConnected
    }
    
    private var progress: Double {
        isConnected ? Double(score) / 100.0 : 0.0
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
            
            // Active progress track
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.red,
                            Color.orange,
                            Color.yellow,
                            Color.cyan,
                            rating.color
                        ]),
                        center: .center,
                        startAngle: .degrees(140),
                        endAngle: .degrees(400)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .shadow(color: rating.color.opacity(0.5), radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.4), value: progress)
            
            // Center Metrics Text
            VStack(spacing: 4) {
                if isConnected {
                    Text("\(score)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(rating.rawValue.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(rating.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(rating.color.opacity(0.18))
                        .clipShape(Capsule())
                    
                    Text("\(rssi) dBm")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.top, 2)
                } else {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 38))
                        .foregroundColor(.gray)
                    
                    Text("OFFLINE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 170, height: 170)
    }
}
