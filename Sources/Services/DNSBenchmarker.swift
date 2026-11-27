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

public enum DNSBenchmarker {
    /// Sequentially measures uncached UDP port-53 A-record lookup latency across system, router, and public resolvers.
    public static func benchmark(systemDNS: [String], gatewayIP: String?) async -> [DNSBenchmarkResult] {
        let candidates = buildCandidates(systemDNS: systemDNS, gatewayIP: gatewayIP)
        return await Task.detached(priority: .utility) {
            var results: [DNSBenchmarkResult] = []
            for candidate in candidates {
                if Task.isCancelled { break }
                var latencies: [Double] = []
                for _ in 0..<3 {
                    if Task.isCancelled { break }
                    let randomLabel = "wfs-\(UUID().uuidString.prefix(8).lowercased())"
                    let domain = "\(randomLabel).cloudflare.com"
                    if let ms = querySingleUDP(domain: domain, serverIP: candidate.ip, timeoutSec: 2) {
                        latencies.append(ms)
                    }
                }
                let avg = latencies.isEmpty ? nil : (latencies.reduce(0.0, +) / Double(latencies.count))
                let minVal = latencies.min()
                results.append(
                    DNSBenchmarkResult(
                        name: candidate.name,
                        serverIP: candidate.ip,
                        isSystemDefault: candidate.isSystemDefault,
                        isRouter: candidate.isRouter,
                        avgLatencyMs: avg,
                        minLatencyMs: minVal,
                        succeeded: !latencies.isEmpty
                    )
                )
            }
            return results
        }.value
    }
    
    private struct Candidate {
        let name: String
        let ip: String
        let isSystemDefault: Bool
        let isRouter: Bool
    }
    
    private static func buildCandidates(systemDNS: [String], gatewayIP: String?) -> [Candidate] {
        var seenIPs = Set<String>()
        var list: [Candidate] = []
        
        let validGateway = gatewayIP.flatMap { InterfaceInspector.isValidIPv4($0) }
        let validSystemIPs = systemDNS.compactMap { InterfaceInspector.isValidIPv4($0) }
        let primarySystem = validSystemIPs.first
        
        let publicServers: [(ip: String, name: String)] = [
            ("1.1.1.1", "Cloudflare"),
            ("8.8.8.8", "Google"),
            ("9.9.9.9", "Quad9")
        ]
        
        if let sysIP = primarySystem {
            let isRouter = (sysIP == validGateway)
            let publicName = publicServers.first(where: { $0.ip == sysIP })?.name
            let label = isRouter ? "System DNS (Router)" : (publicName != nil ? "System DNS (\(publicName!))" : "System DNS")
            list.append(Candidate(name: label, ip: sysIP, isSystemDefault: true, isRouter: isRouter))
            seenIPs.insert(sysIP)
        }
        
        if let gw = validGateway, !seenIPs.contains(gw) {
            list.append(Candidate(name: "Router DNS", ip: gw, isSystemDefault: false, isRouter: true))
            seenIPs.insert(gw)
        }
        
        for pub in publicServers where !seenIPs.contains(pub.ip) {
            let isAlsoSystem = validSystemIPs.contains(pub.ip)
            list.append(Candidate(name: pub.name, ip: pub.ip, isSystemDefault: isAlsoSystem, isRouter: false))
            seenIPs.insert(pub.ip)
        }
        
        return list
    }
    
    /// Sends one RFC 1035 UDP DNS A-record query and returns round-trip time in milliseconds, or nil on error/timeout.
    private static func querySingleUDP(domain: String, serverIP: String, timeoutSec: Int) -> Double? {
        let txID = UInt16.random(in: 1...UInt16.max)
        let packet = buildDNSQueryPacket(transactionID: txID, domain: domain)
        
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        
        var tv = timeval(tv_sec: timeoutSec, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(53).bigEndian
        guard inet_pton(AF_INET, serverIP, &addr.sin_addr) == 1 else {
            return nil
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        let sentCount: ssize_t = packet.withUnsafeBytes { rawBuf in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    sendto(fd, rawBuf.baseAddress, packet.count, 0, sockAddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sentCount == packet.count else { return nil }
        
        var recvBuf = [UInt8](repeating: 0, count: 512)
        let receivedCount = recv(fd, &recvBuf, recvBuf.count, 0)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        
        guard receivedCount >= 12 else { return nil }
        let respID = (UInt16(recvBuf[0]) << 8) | UInt16(recvBuf[1])
        guard respID == txID else { return nil }
        
        return elapsedMs
    }
    
    private static func buildDNSQueryPacket(transactionID: UInt16, domain: String) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(64)
        // Header: ID, Flags (0x0100 = standard query, RD=1), QDCOUNT=1, AN/NS/AR=0
        bytes.append(UInt8(transactionID >> 8))
        bytes.append(UInt8(transactionID & 0xFF))
        bytes.append(0x01)
        bytes.append(0x00)
        bytes.append(0x00)
        bytes.append(0x01)
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // QNAME labels
        for label in domain.split(separator: ".") {
            let utf8 = Array(label.utf8)
            bytes.append(UInt8(min(63, utf8.count)))
            bytes.append(contentsOf: utf8.prefix(63))
        }
        bytes.append(0x00) // root terminator
        
        // QTYPE = A (1), QCLASS = IN (1)
        bytes.append(contentsOf: [0x00, 0x01, 0x00, 0x01])
        return bytes
    }
}
