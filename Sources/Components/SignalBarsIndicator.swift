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

public struct SignalBarsIndicator: View {
    public let bars: Int
    public let maxBars: Int
    public let color: Color
    public var barWidth: CGFloat
    public var maxHeight: CGFloat
    public var spacing: CGFloat
    
    public init(
        bars: Int,
        maxBars: Int = 4,
        color: Color,
        barWidth: CGFloat = 4.0,
        maxHeight: CGFloat = 18.0,
        spacing: CGFloat = 2.5
    ) {
        self.bars = max(0, min(maxBars, bars))
        self.maxBars = maxBars
        self.color = color
        self.barWidth = barWidth
        self.maxHeight = maxHeight
        self.spacing = spacing
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(1...maxBars, id: \.self) { index in
                let isActive = index <= bars
                let stepHeight = maxHeight * (CGFloat(index) / CGFloat(maxBars))
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? color : Color.white.opacity(0.18))
                    .frame(width: barWidth, height: max(4, stepHeight))
                    .shadow(color: isActive ? color.opacity(0.6) : .clear, radius: 2)
                    .animation(.easeInOut(duration: 0.25), value: bars)
            }
        }
    }
}
