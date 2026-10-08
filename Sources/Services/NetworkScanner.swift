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

public final class NetworkScanner: ObservableObject {
    @Published public var scannedNetworks: [ScannedNetwork] = []
    @Published public var channelUtilizations: [ChannelUtilization] = []
    @Published public var isScanning: Bool = false
    @Published public var lastScanDate: Date? = nil
    @Published public var scanErrorMessage: String? = nil
    
    private let scanQueue = DispatchQueue(label: "com.wifisignal.scanner", qos: .userInitiated)
    
    public init() {}
    
    public func performScan(interface: CWInterface?, currentSSID: String?, currentChannel: Int) {
        guard let iface = interface else {
            self.scanErrorMessage = "No active Wi-Fi interface found."
            return
        }
        
        guard !isScanning else { return }
        
        isScanning = true
        scanErrorMessage = nil
        
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let networks = try iface.scanForNetworks(withSSID: nil)
                
                var results: [ScannedNetwork] = []
                for net in networks {
                    let ssid = net.ssid ?? ""
                    let bssid = net.bssid ?? ""
                    let rssi = net.rssiValue
                    let chNum = net.wlanChannel?.channelNumber ?? 0
                    let band = net.wlanChannel != nil ? ChannelBand.from(cwBand: net.wlanChannel!.channelBand) : .unknown
                    let width = net.wlanChannel != nil ? ChannelWidth.from(cwWidth: net.wlanChannel!.channelWidth) : .unknown
                    let isCurrent = (ssid == currentSSID && chNum == currentChannel)
                    
                    let scanned = ScannedNetwork(
                        ssid: ssid,
                        bssid: bssid,
                        rssi: rssi,
                        channelNumber: chNum,
                        channelBand: band,
                        channelWidth: width,
                        beaconInterval: net.beaconInterval,
                        isCurrentNetwork: isCurrent
                    )
                    results.append(scanned)
                }
                
                // Sort by RSSI descending (strongest networks first)
                results.sort { $0.rssi > $1.rssi }
                
                // Group by channel
                var channelMap: [Int: [ScannedNetwork]] = [:]
                for net in results {
                    channelMap[net.channelNumber, default: []].append(net)
                }
                
                var utilizations: [ChannelUtilization] = []
                for (ch, nets) in channelMap {
                    let band = nets.first?.channelBand ?? .unknown
                    let util = ChannelUtilization(
                        channelNumber: ch,
                        band: band,
                        networks: nets,
                        isCurrentChannel: (ch == currentChannel)
                    )
                    utilizations.append(util)
                }
                
                // Sort channels numerically
                utilizations.sort { $0.channelNumber < $1.channelNumber }
                
                DispatchQueue.main.async {
                    self.scannedNetworks = results
                    self.channelUtilizations = utilizations
                    self.isScanning = false
                    self.lastScanDate = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    self.scanErrorMessage = "Scan notice: \(error.localizedDescription)"
                    self.isScanning = false
                }
            }
        }
    }
}
