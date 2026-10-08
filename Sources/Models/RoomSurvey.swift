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

public struct RoomSurveyPoint: Identifiable, Codable, Equatable {
    public let id: UUID
    public var roomName: String
    public var timestamp: Date
    public var rssi: Int
    public var noise: Int
    public var snr: Int
    public var channelNumber: Int
    public var transmitRate: Double
    public var latencyMs: Double
    public var jitterMs: Double
    public var packetLossPercent: Double
    public var qualityScore: Int
    
    public init(
        id: UUID = UUID(),
        roomName: String,
        timestamp: Date = Date(),
        rssi: Int,
        noise: Int,
        snr: Int,
        channelNumber: Int,
        transmitRate: Double,
        latencyMs: Double,
        jitterMs: Double,
        packetLossPercent: Double,
        qualityScore: Int
    ) {
        self.id = id
        self.roomName = roomName
        self.timestamp = timestamp
        self.rssi = rssi
        self.noise = noise
        self.snr = snr
        self.channelNumber = channelNumber
        self.transmitRate = transmitRate
        self.latencyMs = latencyMs
        self.jitterMs = jitterMs
        self.packetLossPercent = packetLossPercent
        self.qualityScore = qualityScore
    }
    
    public var grade: String {
        switch qualityScore {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 55..<70: return "C"
        case 40..<55: return "D"
        default: return "F"
        }
    }
    
    public var gradeColor: Color {
        switch grade {
        case "A+", "A": return Color(red: 0.0, green: 0.9, blue: 0.5)
        case "B": return Color(red: 0.2, green: 0.8, blue: 1.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.0)
        case "D": return Color(red: 1.0, green: 0.5, blue: 0.0)
        default: return Color(red: 1.0, green: 0.25, blue: 0.25)
        }
    }
    
    public var verdict: String {
        if qualityScore >= 80 {
            return "Optimal coverage area"
        } else if qualityScore >= 60 {
            return "Good coverage; mild wall attenuation"
        } else if qualityScore >= 40 {
            return "Marginal zone; potential bufferbloat"
        } else {
            return "Dead zone; needs router repositioning or mesh node"
        }
    }
}
