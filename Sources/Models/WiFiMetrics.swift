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

public enum RegulatorySubband: String, CaseIterable, Identifiable {
    case unii1 = "UNII-1 (Non-DFS)"
    case unii2A = "UNII-2A (DFS)"
    case unii2C = "UNII-2C (DFS)"
    case unii3 = "UNII-3 (Non-DFS)"
    case unii4 = "UNII-4 (Non-DFS)"
    case ghz24 = "2.4 GHz ISM"
    case ghz6 = "6 GHz UNII-5..8"
    case unknown = "Unknown"
    
    public var id: String { rawValue }
    
    public var isDFS: Bool {
        return self == .unii2A || self == .unii2C
    }
    
    public var shortName: String {
        switch self {
        case .unii1: return "UNII-1"
        case .unii2A: return "UNII-2A (DFS)"
        case .unii2C: return "UNII-2C (DFS)"
        case .unii3: return "UNII-3"
        case .unii4: return "UNII-4"
        case .ghz24: return "2.4G"
        case .ghz6: return "6G"
        case .unknown: return "Unknown"
        }
    }
    
    public static func from(channelNumber: Int, band: ChannelBand) -> RegulatorySubband {
        switch band {
        case .band2GHz:
            return .ghz24
        case .band5GHz:
            switch channelNumber {
            case 36...48:
                return .unii1
            case 52...64:
                return .unii2A
            case 100...144:
                return .unii2C
            case 149...165:
                return .unii3
            case 168...177:
                return .unii4
            default:
                return .unknown
            }
        case .band6GHz:
            return .ghz6
        case .unknown:
            return .unknown
        }
    }
}

public enum WiFiPHYMode: String, Codable, Equatable, CaseIterable {
    case none = "None"
    case mode11a = "802.11a"
    case mode11b = "802.11b"
    case mode11g = "802.11g"
    case mode11n = "802.11n"
    case mode11ac = "802.11ac"
    case mode11ax = "802.11ax"
    case mode11be = "802.11be"
    case unknown = "Unknown"
    
    public var generationLabel: String {
        switch self {
        case .mode11be: return "Wi-Fi 7 (802.11be)"
        case .mode11ax: return "Wi-Fi 6 (802.11ax)"
        case .mode11ac: return "Wi-Fi 5 (802.11ac)"
        case .mode11n: return "Wi-Fi 4 (802.11n)"
        case .mode11g: return "802.11g"
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .none, .unknown: return "Unknown"
        }
    }
    
    public func displayBadge(for band: ChannelBand) -> String {
        switch self {
        case .mode11be: return "WI-FI 7"
        case .mode11ax: return band == .band6GHz ? "WI-FI 6E" : "WI-FI 6"
        case .mode11ac: return "WI-FI 5"
        case .mode11n: return "WI-FI 4"
        default: return ""
        }
    }
    
    public static func from(cwMode: CWPHYMode) -> WiFiPHYMode {
        switch cwMode.rawValue {
        case 0: return .none
        case 1: return .mode11a
        case 2: return .mode11b
        case 3: return .mode11g
        case 4: return .mode11n
        case 5: return .mode11ac
        case 6: return .mode11ax
        case 7: return .mode11be
        default: return .unknown
        }
    }
}

public struct RoamEvent: Identifiable, Codable, Equatable {
    public enum Kind: String, Codable, Equatable {
        case roamed = "Roamed AP"
        case disconnected = "Disconnected"
        case reconnected = "Reconnected"
        case channelChanged = "Channel Hop"
    }
    
    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public let fromBSSID: String?
    public let toBSSID: String?
    public let channel: Int
    public let band: String
    public let summary: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: Kind,
        fromBSSID: String? = nil,
        toBSSID: String? = nil,
        channel: Int,
        band: String,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.fromBSSID = fromBSSID
        self.toBSSID = toBSSID
        self.channel = channel
        self.band = band
        self.summary = summary
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
    public var snr: Int { rssi - (noise < 0 ? noise : -95) } // dB (e.g. 45 dB)
    
    public var channelNumber: Int = 0
    public var channelBand: ChannelBand = .unknown
    public var channelWidth: ChannelWidth = .unknown
    public var isDFS: Bool = false
    public var regulatorySubband: RegulatorySubband = .unknown
    public var phyMode: WiFiPHYMode = .unknown
    public var transmitRate: Double = 0.0  // Mbps
    
    // Interface & Environment telemetry
    public var interfaceInputErrors: UInt32 = 0
    public var interfaceOutputErrors: UInt32 = 0
    public var isVPNActive: Bool = false
    public var vpnInterfaceName: String? = nil
    public var isProxyActive: Bool = false
    public var localTrafficMbps: Double = 0.0
    
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
        isDFS: Bool? = nil,
        regulatorySubband: RegulatorySubband? = nil,
        phyMode: WiFiPHYMode = .unknown,
        transmitRate: Double = 0.0,
        interfaceInputErrors: UInt32 = 0,
        interfaceOutputErrors: UInt32 = 0,
        isVPNActive: Bool = false,
        vpnInterfaceName: String? = nil,
        isProxyActive: Bool = false,
        localTrafficMbps: Double = 0.0,
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
        let computedSubband = regulatorySubband ?? RegulatorySubband.from(channelNumber: channelNumber, band: channelBand)
        self.regulatorySubband = computedSubband
        self.isDFS = isDFS ?? computedSubband.isDFS
        self.phyMode = phyMode
        self.transmitRate = transmitRate
        self.interfaceInputErrors = interfaceInputErrors
        self.interfaceOutputErrors = interfaceOutputErrors
        self.isVPNActive = isVPNActive
        self.vpnInterfaceName = vpnInterfaceName
        self.isProxyActive = isProxyActive
        self.localTrafficMbps = localTrafficMbps
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
    
    /// User-friendly 0-100% signal strength derived directly from RSSI (-90 dBm to -50 dBm)
    public var signalPercentage: Int {
        guard isConnected, rssi != 0 else { return 0 }
        let norm = (Double(rssi) - (-90.0)) / ((-50.0) - (-90.0)) * 100.0
        return max(0, min(100, Int(norm.rounded())))
    }
    
    /// Signal strength bars (0 to 4) mapped directly to RSSI thresholds
    public var rssiBars: Int {
        guard isConnected, rssi != 0 else { return 0 }
        switch rssi {
        case -55...0: return 4
        case -67 ..< -55: return 3
        case -77 ..< -67: return 2
        case -88 ..< -77: return 1
        default: return 0
        }
    }
    
    /// Human-understandable qualitative description of the RSSI number
    public var rssiHumanRating: String {
        guard isConnected, rssi != 0 else { return "Disconnected" }
        switch rssi {
        case -50...0: return "Maximum (Near Router)"
        case -59 ..< -50: return "Very Strong (Same Room)"
        case -69 ..< -59: return "Good (1-2 Walls)"
        case -79 ..< -69: return "Fair (Distance / Obstacles)"
        case -89 ..< -79: return "Weak (Fringe Coverage)"
        default: return "Dead Zone (Fringe)"
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
