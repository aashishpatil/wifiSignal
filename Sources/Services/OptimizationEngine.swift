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

public final class OptimizationEngine {
    public static func analyze(
        metrics: WiFiMetrics,
        channelUtilizations: [ChannelUtilization],
        scannedNetworks: [ScannedNetwork]
    ) -> [OptimizationAdvice] {
        var adviceList: [OptimizationAdvice] = []
        
        guard metrics.isConnected else {
            adviceList.append(
                OptimizationAdvice(
                    title: "Wi-Fi Disconnected",
                    category: .placement,
                    severity: .critical,
                    diagnosis: "The Mac is not associated with any active Wi-Fi access point.",
                    actionPlan: "Connect to your home Wi-Fi network in macOS Settings to begin real-time analysis."
                )
            )
            return adviceList
        }
        
        // 1. Placement & Physical Obstruction Analysis
        if metrics.rssi < -75 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Severe Distance / Wall Attenuation",
                    category: .placement,
                    severity: .critical,
                    diagnosis: "Signal strength is at \(metrics.rssi) dBm, which is near the disconnect threshold. Radio waves are heavily attenuated by concrete walls, metal fixtures, or distance.",
                    actionPlan: "Move your router to a central, elevated position (e.g. on top of a bookshelf, not in a cabinet or on the floor). If your home has multiple stories, consider a dedicated Wi-Fi 6 mesh node."
                )
            )
        } else if metrics.rssi < -65 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Moderate Range Degradation",
                    category: .placement,
                    severity: .warning,
                    diagnosis: "Current signal is \(metrics.rssi) dBm. While adequate for basic web browsing, link modulation drops and speeds fluctuate.",
                    actionPlan: "Ensure line-of-sight between rooms is unobstructed. Elevate the router above furniture to prevent ground-level signal bounce."
                )
            )
        } else {
            adviceList.append(
                OptimizationAdvice(
                    title: "Strong Physical Proximity",
                    category: .placement,
                    severity: .optimal,
                    diagnosis: "Current signal strength is strong (\(metrics.rssi) dBm). The distance and line-of-sight to the router at this location are excellent.",
                    actionPlan: "This position provides ideal RF reception. Use this spot as a benchmark when testing other rooms."
                )
            )
        }
        
        // 2. Channel Congestion & Co-Channel Interference (CCI)
        let currentCh = metrics.channelNumber
        let overlapping = channelUtilizations.first(where: { $0.channelNumber == currentCh })
        let neighborCount = (overlapping?.networks.filter { !$0.isCurrentNetwork }.count) ?? 0
        
        if neighborCount >= 3 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Crowded Channel Collision",
                    category: .channel,
                    severity: .critical,
                    diagnosis: "Detected \(neighborCount) neighboring Wi-Fi access points broadcasting on Channel \(currentCh). Your devices must take turns waiting for airtime.",
                    actionPlan: "Access your router admin dashboard and switch your 5GHz channel to an open DFS channel (e.g. 52-140) or upper UNII-3 channel (149-161), or let the router auto-select the cleanest frequency."
                )
            )
        } else if neighborCount >= 1 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Mild Co-Channel Interference",
                    category: .channel,
                    severity: .warning,
                    diagnosis: "Detected \(neighborCount) neighboring network on Channel \(currentCh).",
                    actionPlan: "Check the Channel Spectrum tab to see if alternative channels in your band have zero competing access points."
                )
            )
        } else if currentCh > 0 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Clear Wireless Channel",
                    category: .channel,
                    severity: .optimal,
                    diagnosis: "Channel \(currentCh) is clean with zero detected co-channel interference.",
                    actionPlan: "Keep this channel frequency locked in your router settings to prevent random auto-hopping."
                )
            )
        }
        
        // DFS Channel Assessment
        if metrics.isDFS {
            adviceList.append(
                OptimizationAdvice(
                    title: "DFS Channel Active (\(metrics.regulatorySubband.shortName))",
                    category: .channel,
                    severity: .optimal,
                    diagnosis: "Operating on DFS Channel \(metrics.channelNumber). DFS frequencies enjoy substantially cleaner spectrum with minimal neighbor clutter.",
                    actionPlan: "Note: In the event of nearby airport/weather radar detection, your router may temporarily channel-hop. Ensure legacy IoT devices support DFS."
                )
            )
        } else if metrics.channelBand == .band5GHz && neighborCount >= 2 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Consider Migrating to a DFS Channel",
                    category: .channel,
                    severity: .tip,
                    diagnosis: "Your Non-DFS 5GHz Channel (\(metrics.channelNumber)) is sharing airtime with \(neighborCount) neighboring routers.",
                    actionPlan: "Switch your router's 5GHz band to an open DFS channel (e.g. 52-64 or 100-144) to escape consumer congestion."
                )
            )
        }
        
        // 3. Band Selection (2.4 GHz vs 5 GHz / 6 GHz)
        if metrics.channelBand == .band2GHz {
            adviceList.append(
                OptimizationAdvice(
                    title: "Operating on Congested 2.4 GHz Band",
                    category: .bandwidth,
                    severity: .warning,
                    diagnosis: "Your Mac is connected on the 2.4 GHz band. This band has narrow 20MHz channels and suffers heavy interference from Bluetooth, microwaves, and neighbors.",
                    actionPlan: "Switch to your router's 5 GHz or 6 GHz network. If your router uses a single combined SSID (Band Steering), consider creating a dedicated 5GHz network name."
                )
            )
        }
        
        // 4. High Bandwidth (160MHz / 80MHz) Channel Switching Protection
        if metrics.channelWidth == .width160MHz {
            adviceList.insert(
                OptimizationAdvice(
                    title: "160 MHz Ultrawide Active — Keep Auto",
                    category: .bandwidth,
                    severity: .optimal,
                    diagnosis: "Your connection is bonding 8 channels for 160 MHz bandwidth with a high link rate of \(Int(metrics.transmitRate)) Mbps.",
                    actionPlan: "Do NOT manually change to an isolated channel. Manually overriding Auto often forces routers down to 20/40 MHz, dropping throughput from 500+ Mbps to <100 Mbps. Stick to Auto to preserve 160 MHz speeds."
                ),
                at: 0
            )
        } else if metrics.channelWidth == .width80MHz && metrics.transmitRate >= 600 {
            adviceList.append(
                OptimizationAdvice(
                    title: "80 MHz Wideband Active",
                    category: .bandwidth,
                    severity: .optimal,
                    diagnosis: "Your connection is utilizing 80 MHz channel bonding with a link rate of \(Int(metrics.transmitRate)) Mbps.",
                    actionPlan: "If switching to an uncongested channel, ensure your router's Channel Width is explicitly locked to 80 MHz rather than dropping to 20 MHz."
                )
            )
        }
        
        // 4. RF Noise Floor & Jitter Diagnostics
        if metrics.noise > -85 {
            adviceList.append(
                OptimizationAdvice(
                    title: "High Environmental RF Noise",
                    category: .interference,
                    severity: .warning,
                    diagnosis: "The background noise floor is elevated at \(metrics.noise) dBm (normal is below -92 dBm), cutting your Signal-to-Noise Ratio to \(metrics.snr) dB.",
                    actionPlan: "Look for nearby electronic devices causing electromagnetic interference: unshielded USB 3.0 cables/docks, cordless phone bases, smart home bridges, or power adapters."
                )
            )
        }
        
        // 5. Gateway Latency & Jitter
        if let jitter = metrics.gatewayJitterMs, jitter > 12.0 {
            adviceList.append(
                OptimizationAdvice(
                    title: "Packet Jitter / Retransmissions",
                    category: .interference,
                    severity: .warning,
                    diagnosis: "Latency jitter to the router is fluctuating by \(String(format: "%.1f", jitter)) ms, indicating packet retransmissions over the wireless link.",
                    actionPlan: "Try moving 3-5 feet away from metal appliances or mirrors. If jitter persists, the channel airtime may be saturated."
                )
            )
        }
        
        return adviceList
    }
}
