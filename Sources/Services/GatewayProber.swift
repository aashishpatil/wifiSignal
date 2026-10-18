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
import Network
import SystemConfiguration

public struct ProbeResult: Equatable {
    public let latencyMs: Double
    public let isSuccess: Bool
    public let timestamp: Date
}

public final class GatewayProber: ObservableObject {
    @Published public var currentGatewayIP: String? = nil
    @Published public var latestLatencyMs: Double? = nil
    @Published public var latestJitterMs: Double? = nil
    @Published public var packetLossPercent: Double? = nil
    @Published public var isProbing: Bool = false
    
    private var probeTimer: Timer?
    private var historyWindow: [ProbeResult] = []
    private var consecutiveFailures: Int = 0
    private let maxHistoryWindow = 15
    private let probeQueue = DispatchQueue(label: "com.wifisignal.prober", qos: .utility)
    
    public init() {
        refreshGatewayIP()
    }
    
    public func startProbing(interval: TimeInterval = 1.0) {
        stopProbing()
        isProbing = true
        refreshGatewayIP()
        
        probeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performSingleProbe()
        }
    }
    
    public func stopProbing() {
        probeTimer?.invalidate()
        probeTimer = nil
        isProbing = false
    }
    
    public func refreshGatewayIP(resetHistory: Bool = false) {
        if resetHistory {
            DispatchQueue.main.async {
                self.historyWindow.removeAll()
                self.consecutiveFailures = 0
                self.latestLatencyMs = nil
                self.latestJitterMs = nil
                self.packetLossPercent = nil
            }
        }
        probeQueue.async { [weak self] in
            guard let self = self else { return }
            let ip = self.resolveDefaultGatewayIP()
            DispatchQueue.main.async {
                self.currentGatewayIP = ip
            }
        }
    }
    
    private func isValidIPv4(_ candidate: String) -> String? {
        let stripped = String(candidate.split(separator: "%").first ?? "")
        guard !stripped.isEmpty, IPv4Address(stripped) != nil else {
            return nil
        }
        return stripped
    }
    
    private func resolveDefaultGatewayIP() -> String? {
        // 1. Primary: Fast in-process lookup via SystemConfiguration dynamic store
        if let store = SCDynamicStoreCreate(nil, "com.wifisignal.prober" as CFString, nil, nil),
           let globalIPv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let router = globalIPv4[kSCPropNetIPv4Router as String] as? String,
           let validIP = isValidIPv4(router) {
            return validIP
        }
        
        // 2. Fallback: Parse routing table via netstat
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-nr", "-f", "inet"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 2 && parts[0] == "default" {
                        if let validIP = isValidIPv4(String(parts[1])) {
                            return validIP
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func performSingleProbe() {
        guard let gateway = currentGatewayIP, let validGateway = isValidIPv4(gateway) else {
            refreshGatewayIP()
            return
        }
        
        probeQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/sbin/ping")
            task.arguments = ["-c", "1", "-t", "1", "--", validGateway]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            var rtt: Double? = nil
            var success = false
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                if task.terminationStatus == 0, let output = String(data: data, encoding: .utf8) {
                    // Look for 'time=4.123 ms'
                    if let range = output.range(of: "time=") {
                        let sub = output[range.upperBound...]
                        if let msRange = sub.range(of: " ms") {
                            let timeStr = sub[..<msRange.lowerBound]
                            if let parsed = Double(timeStr) {
                                rtt = parsed
                                success = true
                            }
                        }
                    }
                }
            } catch {
                success = false
            }
            
            let measuredLatency = rtt ?? 0.0
            let result = ProbeResult(latencyMs: measuredLatency, isSuccess: success, timestamp: Date())
            
            DispatchQueue.main.async {
                self.recordProbeResult(result)
            }
        }
    }
    
    private func recordProbeResult(_ result: ProbeResult) {
        if result.isSuccess {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            if consecutiveFailures >= 3 {
                consecutiveFailures = 0
                refreshGatewayIP()
            }
        }
        
        historyWindow.append(result)
        if historyWindow.count > maxHistoryWindow {
            historyWindow.removeFirst()
        }
        
        let successful = historyWindow.filter { $0.isSuccess }
        let lossRate = Double(historyWindow.count - successful.count) / Double(max(1, historyWindow.count)) * 100.0
        self.packetLossPercent = lossRate
        
        if let latest = successful.last {
            self.latestLatencyMs = latest.latencyMs
        } else {
            self.latestLatencyMs = nil
        }
        
        // Calculate jitter = RFC 3550 interarrival jitter / mean deviation
        if successful.count >= 2 {
            var diffSum = 0.0
            for i in 1..<successful.count {
                diffSum += abs(successful[i].latencyMs - successful[i - 1].latencyMs)
            }
            self.latestJitterMs = diffSum / Double(successful.count - 1)
        } else {
            self.latestJitterMs = 0.0
        }
    }
}
