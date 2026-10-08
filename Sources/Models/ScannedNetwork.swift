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
import CoreWLAN
import SwiftUI

public struct ScannedNetwork: Identifiable, Equatable {
    public let id: String // BSSID or composite key
    public let ssid: String
    public let bssid: String
    public let rssi: Int
    public let channelNumber: Int
    public let channelBand: ChannelBand
    public let channelWidth: ChannelWidth
    public let beaconInterval: Int
    public let isCurrentNetwork: Bool
    
    public init(
        ssid: String,
        bssid: String,
        rssi: Int,
        channelNumber: Int,
        channelBand: ChannelBand,
        channelWidth: ChannelWidth,
        beaconInterval: Int = 100,
        isCurrentNetwork: Bool = false
    ) {
        self.id = bssid.isEmpty ? "\(ssid)_\(channelNumber)" : bssid
        self.ssid = ssid.isEmpty ? "<Hidden Network>" : ssid
        self.bssid = bssid
        self.rssi = rssi
        self.channelNumber = channelNumber
        self.channelBand = channelBand
        self.channelWidth = channelWidth
        self.beaconInterval = beaconInterval
        self.isCurrentNetwork = isCurrentNetwork
    }
    
    public var signalStrengthRatio: Double {
        // -95 dBm -> 0.0, -30 dBm -> 1.0
        return max(0.0, min(1.0, Double(rssi + 95) / 65.0))
    }
    
    public var signalColor: Color {
        if isCurrentNetwork {
            return Color(red: 0.0, green: 0.9, blue: 1.0)
        }
        if rssi > -60 {
            return Color(red: 0.9, green: 0.4, blue: 0.4) // Strong neighbor = high interference
        } else if rssi > -75 {
            return Color(red: 0.9, green: 0.7, blue: 0.3)
        } else {
            return Color(red: 0.4, green: 0.7, blue: 0.9)
        }
    }
}

public struct ChannelUtilization: Identifiable {
    public var id: Int { channelNumber }
    public let channelNumber: Int
    public let band: ChannelBand
    public var networks: [ScannedNetwork]
    public var isCurrentChannel: Bool
    
    public var totalInterferenceScore: Double {
        // Sum of neighbor signal power
        return networks
            .filter { !$0.isCurrentNetwork }
            .reduce(0.0) { sum, net in
                sum + net.signalStrengthRatio
            }
    }
    
    public var congestionRating: String {
        let count = networks.count
        if count == 0 { return "Clear" }
        if count == 1 && isCurrentChannel { return "Optimal (Exclusive)" }
        if count <= 2 { return "Low" }
        if count <= 4 { return "Moderate" }
        return "Crowded"
    }
    
    public var congestionColor: Color {
        let count = networks.count
        if count == 0 || (count == 1 && isCurrentChannel) {
            return Color.green
        } else if count <= 2 {
            return Color.blue
        } else if count <= 4 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}
