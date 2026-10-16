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

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let systemImage: String
    public let accentColor: Color
    public var isHighlighted: Bool = false
    public var badge: String? = nil
    public var badgeColor: Color? = nil
    public var signalBars: Int? = nil
    public var progressBarValue: Double? = nil
    
    public init(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        accentColor: Color,
        isHighlighted: Bool = false,
        badge: String? = nil,
        badgeColor: Color? = nil,
        signalBars: Int? = nil,
        progressBarValue: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.isHighlighted = isHighlighted
        self.badge = badge
        self.badgeColor = badgeColor
        self.signalBars = signalBars
        self.progressBarValue = progressBarValue
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: accentColor.opacity(0.8), radius: 3)
            }
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let bars = signalBars {
                    SignalBarsIndicator(bars: bars, color: accentColor)
                }
                
                if let badge = badge {
                    let bColor = badgeColor ?? accentColor
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(bColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(bColor.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            
            if let progress = progressBarValue {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 3)
                        Capsule()
                            .fill(accentColor)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 3)
                    }
                }
                .frame(height: 3)
            }
            
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.65))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted ? accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: isHighlighted ? 1.5 : 1)
                )
        )
    }
}
