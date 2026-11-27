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
import Darwin
import Network
import SystemConfiguration

public struct InterfaceCounters: Equatable {
    public let inputBytes: UInt64
    public let outputBytes: UInt64
    public let inputErrors: UInt32
    public let outputErrors: UInt32
    public let collisions: UInt32
    
    public var totalBytes: UInt64 { inputBytes &+ outputBytes }
    public var totalErrors: UInt32 { inputErrors &+ outputErrors }
}

public enum InterfaceInspector {
    /// Reads link-layer byte and error counters for the named BSD interface via `getifaddrs()`.
    public static func readCounters(for interfaceName: String) -> InterfaceCounters? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            guard let namePtr = ptr.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)
            guard name == interfaceName,
                  let addr = ptr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let rawData = ptr.pointee.ifa_data else {
                continue
            }
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return InterfaceCounters(
                inputBytes: UInt64(data.ifi_ibytes),
                outputBytes: UInt64(data.ifi_obytes),
                inputErrors: data.ifi_ierrors,
                outputErrors: data.ifi_oerrors,
                collisions: data.ifi_collisions
            )
        }
        return nil
    }
    
    /// Detects active VPN tunnels and HTTP/HTTPS/SOCKS/PAC system proxies using SystemConfiguration and BSD interfaces.
    public static func detectVPNAndProxy() -> (isVPNActive: Bool, vpnInterface: String?, isProxyActive: Bool) {
        var isVPNActive = false
        var vpnInterface: String? = nil
        var isProxyActive = false
        
        if let store = SCDynamicStoreCreate(nil, "com.wifisignal.inspector" as CFString, nil, nil) {
            if let globalIPv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
               let primary = globalIPv4["PrimaryInterface"] as? String {
                if isTunnelInterfaceName(primary) {
                    isVPNActive = true
                    vpnInterface = primary
                }
            }
            
            if let proxies = SCDynamicStoreCopyValue(store, "State:/Network/Global/Proxies" as CFString) as? [String: Any] {
                let httpEnabled = (proxies["HTTPEnable"] as? Int) == 1
                let httpsEnabled = (proxies["HTTPSEnable"] as? Int) == 1
                let socksEnabled = (proxies["SOCKSEnable"] as? Int) == 1
                let pacEnabled = (proxies["ProxyAutoConfigEnable"] as? Int) == 1
                isProxyActive = httpEnabled || httpsEnabled || socksEnabled || pacEnabled
            }
        }
        
        // Secondary VPN check for split-tunnel VPNs with an active non-link-local IPv4 address
        if !isVPNActive, let tunnel = findActiveIPv4TunnelInterface() {
            isVPNActive = true
            vpnInterface = tunnel
        }
        
        return (isVPNActive, vpnInterface, isProxyActive)
    }
    
    private static func isTunnelInterfaceName(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
    }
    
    private static func findActiveIPv4TunnelInterface() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        let requiredFlags = UInt32(IFF_UP | IFF_RUNNING)
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            guard let namePtr = ptr.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)
            guard isTunnelInterfaceName(name),
                  (ptr.pointee.ifa_flags & requiredFlags) == requiredFlags,
                  let addr = ptr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                let ip = String(cString: hostBuffer)
                if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") {
                    return name
                }
            }
        }
        return nil
    }
    
    /// Reads current system DNS server IP addresses from SCDynamicStore.
    public static func readSystemDNSServers() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "com.wifisignal.inspector" as CFString, nil, nil),
              let dnsDict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dnsDict["ServerAddresses"] as? [String] else {
            return []
        }
        return servers
    }
    
    /// Checks whether a global IPv6 route/interface is currently active.
    public static func isIPv6Active() -> Bool {
        guard let store = SCDynamicStoreCreate(nil, "com.wifisignal.inspector" as CFString, nil, nil),
              let globalIPv6 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv6" as CFString) as? [String: Any] else {
            return false
        }
        if let primary = globalIPv6["PrimaryInterface"] as? String, !primary.isEmpty {
            return true
        }
        if let router = globalIPv6["Router"] as? String, !router.isEmpty {
            return true
        }
        return false
    }
    
    /// Validates a BSD interface name (1..16 ASCII alphanumeric characters).
    public static func isValidInterfaceName(_ name: String) -> Bool {
        guard (1...16).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57) || // 0-9
            (scalar.value >= 65 && scalar.value <= 90) || // A-Z
            (scalar.value >= 97 && scalar.value <= 122)   // a-z
        }
    }
    
    /// Validates an IPv4 address string, stripping any interface scope identifier.
    public static func isValidIPv4(_ candidate: String) -> String? {
        let stripped = String(candidate.split(separator: "%").first ?? "")
        guard !stripped.isEmpty, IPv4Address(stripped) != nil else {
            return nil
        }
        return stripped
    }
    
    /// Counts non-current SSIDs likely broadcast from the same physical radio (matching OUI, same channel, similar RSSI).
    public static func countSameRouterExtraSSIDs(
        currentBSSID: String?,
        currentChannel: Int,
        currentRSSI: Int,
        scannedNetworks: [ScannedNetwork]
    ) -> Int {
        guard let curOUI = ouiPrefix(from: currentBSSID), currentChannel > 0 else {
            return 0
        }
        return scannedNetworks.filter { net in
            guard !net.isCurrentNetwork,
                  net.channelNumber == currentChannel,
                  let netOUI = ouiPrefix(from: net.bssid) else {
                return false
            }
            return netOUI == curOUI && abs(net.rssi - currentRSSI) <= 8
        }.count
    }
    
    private static func ouiPrefix(from bssid: String?) -> String? {
        guard let bssid, !bssid.isEmpty else { return nil }
        let parts = bssid.lowercased().split(separator: ":")
        guard parts.count >= 3 else { return nil }
        return parts.prefix(3).joined(separator: ":")
    }
    
    /// Selects the cleanest candidate channel in a band accounting for 2.4 GHz ±4 adjacent channel overlap.
    public static func bestChannelFor(
        band: ChannelBand,
        candidates: [Int],
        scannedNetworks: [ScannedNetwork]
    ) -> (ch: Int, count: Int) {
        let bandNets = scannedNetworks.filter { $0.channelBand == band && !$0.isCurrentNetwork }
        var bestCh = candidates.first ?? 1
        var lowestScore = Double.greatestFiniteMagnitude
        var bestCount = 0
        
        for ch in candidates {
            let overlappingNets = bandNets.filter { net in
                if band == .band2GHz {
                    return abs(net.channelNumber - ch) <= 4
                } else {
                    return net.channelNumber == ch
                }
            }
            let count = overlappingNets.count
            let interferenceScore = overlappingNets.reduce(0.0) { sum, net in
                let distanceWeight: Double = (band == .band2GHz)
                    ? max(0.2, 1.0 - (Double(abs(net.channelNumber - ch)) * 0.2))
                    : 1.0
                return sum + (net.signalStrengthRatio * distanceWeight)
            }
            if interferenceScore < lowestScore {
                lowestScore = interferenceScore
                bestCh = ch
                bestCount = count
            }
        }
        return (bestCh, bestCount)
    }
}
