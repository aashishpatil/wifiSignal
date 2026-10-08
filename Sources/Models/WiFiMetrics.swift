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
import CoreWLAN

public enum ChannelBand: String, CaseIterable, Identifiable {
    case band2GHz = "2.4 GHz"
    case band5GHz = "5 GHz"
    case band6GHz = "6 GHz"
    case unknown = "Unknown"
    
    public var id: String { rawValue }
    
    public static func from(cwBand: CWChannelBand) -> ChannelBand {
        switch cwBand {
        case .band2GHz: return .band2GHz
        case .band5GHz: return .band5GHz
        case .band6GHz: return .band6GHz
        case .bandUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

public enum ChannelWidth: String, CaseIterable, Identifiable {
    case width20MHz = "20 MHz"
    case width40MHz = "40 MHz"
    case width80MHz = "80 MHz"
    case width160MHz = "160 MHz"
    case unknown = "Unknown"
    
    public var id: String { rawValue }
    
    public static func from(cwWidth: CWChannelWidth) -> ChannelWidth {
        switch cwWidth {
        case .width20MHz: return .width20MHz
        case .width40MHz: return .width40MHz
        case .width80MHz: return .width80MHz
        case .width160MHz: return .width160MHz
        case .widthUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

public enum SignalRating: String, CaseIterable {
    case pristine = "Pristine"
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    case unusable = "Unusable"
    
    public var color: Color {
        switch self {
        case .pristine: return Color(red: 0.0, green: 0.95, blue: 0.55)
        case .excellent: return Color(red: 0.0, green: 0.85, blue: 0.95)
        case .good: return Color(red: 0.2, green: 0.7, blue: 1.0)
        case .fair: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .weak: return Color(red: 1.0, green: 0.45, blue: 0.0)
        case .unusable: return Color(red: 1.0, green: 0.2, blue: 0.25)
        }
    }
}

public struct WiFiMetrics: Identifiable, Equatable {
    public let id = UUID()
    public var timestamp: Date = Date()
    
    public var isConnected: Bool = false
    public var interfaceName: String = "en0"
    public var ssid: String? = nil
    public var bssid: String? = nil
    
    public var rssi: Int = 0               // dBm (e.g. -50)
    public var noise: Int = -95            // dBm (e.g. -95)
    public var snr: Int { rssi - noise }   // dB (e.g. 45 dB)
    
    public var channelNumber: Int = 0
    public var channelBand: ChannelBand = .unknown
    public var channelWidth: ChannelWidth = .unknown
    public var transmitRate: Double = 0.0  // Mbps
    
    // Gateway telemetry
    public var gatewayIP: String? = nil
    public var gatewayLatencyMs: Double? = nil
    public var gatewayJitterMs: Double? = nil
    public var packetLossPercent: Double? = nil
    
    public init(
        isConnected: Bool = false,
        interfaceName: String = "en0",
        ssid: String? = nil,
        bssid: String? = nil,
        rssi: Int = 0,
        noise: Int = -95,
        channelNumber: Int = 0,
        channelBand: ChannelBand = .unknown,
        channelWidth: ChannelWidth = .unknown,
        transmitRate: Double = 0.0,
        gatewayIP: String? = nil,
        gatewayLatencyMs: Double? = nil,
        gatewayJitterMs: Double? = nil,
        packetLossPercent: Double? = nil
    ) {
        self.isConnected = isConnected
        self.interfaceName = interfaceName
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.noise = noise
        self.channelNumber = channelNumber
        self.channelBand = channelBand
        self.channelWidth = channelWidth
        self.transmitRate = transmitRate
        self.gatewayIP = gatewayIP
        self.gatewayLatencyMs = gatewayLatencyMs
        self.gatewayJitterMs = gatewayJitterMs
        self.packetLossPercent = packetLossPercent
        self.timestamp = Date()
    }
    
    /// Calculated 0 - 100 composite Signal Quality Index (SQI)
    public var qualityScore: Int {
        guard isConnected else { return 0 }
        
        // Base score from RSSI (-90 dBm to -30 dBm maps to 0..100)
        let normalizedRSSI = max(0.0, min(100.0, Double(rssi + 95) / 65.0 * 100.0))
        
        // SNR factor (SNR > 35 is 100%, SNR < 10 is 0%)
        let normalizedSNR = max(0.0, min(100.0, Double(snr - 10) / 25.0 * 100.0))
        
        // Latency penalty if available
        var latencyFactor = 100.0
        if let latency = gatewayLatencyMs {
            if latency < 5.0 {
                latencyFactor = 100.0
            } else if latency < 20.0 {
                latencyFactor = 85.0
            } else if latency < 60.0 {
                latencyFactor = 60.0
            } else {
                latencyFactor = max(20.0, 100.0 - (latency * 0.8))
            }
        }
        
        // Jitter penalty
        var jitterFactor = 100.0
        if let jitter = gatewayJitterMs {
            if jitter < 2.0 {
                jitterFactor = 100.0
            } else if jitter < 10.0 {
                jitterFactor = 80.0
            } else {
                jitterFactor = max(30.0, 100.0 - (jitter * 3.0))
            }
        }
        
        // Packet loss penalty
        var lossPenalty = 0.0
        if let loss = packetLossPercent {
            lossPenalty = loss * 1.5
        }
        
        // Weighted composite
        let weighted = (normalizedRSSI * 0.45) + (normalizedSNR * 0.25) + (latencyFactor * 0.15) + (jitterFactor * 0.15) - lossPenalty
        return max(0, min(100, Int(weighted.rounded())))
    }
    
    public var rating: SignalRating {
        switch qualityScore {
        case 90...100: return .pristine
        case 75..<90: return .excellent
        case 55..<75: return .good
        case 35..<55: return .fair
        case 15..<35: return .weak
        default: return .unusable
        }
    }
    
    public var bars: Int {
        switch qualityScore {
        case 80...100: return 4
        case 55..<80: return 3
        case 30..<55: return 2
        case 1..<30: return 1
        default: return 0
        }
    }
    
    public var humanDescription: String {
        guard isConnected else { return "Disconnected from Wi-Fi" }
        switch rating {
        case .pristine:
            return "Pristine connection: zero loss, high SNR. Ideal placement."
        case .excellent:
            return "Great signal strength. Smooth 4K streaming and low-latency gaming."
        case .good:
            return "Solid everyday Wi-Fi. Minor attenuation from distance or walls."
        case .fair:
            return "Moderate attenuation or interference. Noticeable speed drops may occur."
        case .weak:
            return "Weak signal zone: packet retransmissions likely. Move closer to router."
        case .unusable:
            return "Dead zone. Severe packet loss or out of effective range."
        }
    }
}
