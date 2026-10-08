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

import Foundation
import SwiftUI

public enum AdviceCategory: String, CaseIterable {
    case placement = "Router Placement"
    case channel = "Channel Optimization"
    case interference = "Interference & Noise"
    case bandwidth = "Link Speed & Hardware"
    
    public var icon: String {
        switch self {
        case .placement: return "point.3.filled.connected.trianglepath.dotted"
        case .channel: return "waveform.badge.magnifyingglass"
        case .interference: return "antenna.radiowaves.left.and.right.slash"
        case .bandwidth: return "bolt.horizontal.fill"
        }
    }
}

public enum AdviceSeverity: String {
    case optimal = "Optimal"
    case tip = "Tip"
    case warning = "Action Required"
    case critical = "Critical Issue"
    
    public var color: Color {
        switch self {
        case .optimal: return Color(red: 0.0, green: 0.9, blue: 0.5)
        case .tip: return Color(red: 0.2, green: 0.8, blue: 1.0)
        case .warning: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .critical: return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }
}

public struct OptimizationAdvice: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let category: AdviceCategory
    public let severity: AdviceSeverity
    public let diagnosis: String
    public let actionPlan: String
    
    public init(
        title: String,
        category: AdviceCategory,
        severity: AdviceSeverity,
        diagnosis: String,
        actionPlan: String
    ) {
        self.title = title
        self.category = category
        self.severity = severity
        self.diagnosis = diagnosis
        self.actionPlan = actionPlan
    }
}
