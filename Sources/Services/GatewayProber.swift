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
    
    public func refreshGatewayIP() {
        probeQueue.async {
            let ip = self.resolveDefaultGatewayIP()
            DispatchQueue.main.async {
                self.currentGatewayIP = ip
            }
        }
    }
    
    private func resolveDefaultGatewayIP() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-nr", "-f", "inet"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 2 && parts[0] == "default" {
                        let ip = String(parts[1])
                        // Verify not a link-local or empty
                        if ip.contains(".") {
                            return ip
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
        guard let gateway = currentGatewayIP, !gateway.isEmpty else {
            refreshGatewayIP()
            return
        }
        
        probeQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/sbin/ping")
            task.arguments = ["-c", "1", "-t", "1", gateway]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            let start = Date()
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
            
            // If ping exited with non-zero or failed to parse, fall back to delta or record failure
            let measuredLatency = rtt ?? (success ? Date().timeIntervalSince(start) * 1000.0 : 0.0)
            let result = ProbeResult(latencyMs: measuredLatency, isSuccess: success, timestamp: Date())
            
            DispatchQueue.main.async {
                self.recordProbeResult(result)
            }
        }
    }
    
    private func recordProbeResult(_ result: ProbeResult) {
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
