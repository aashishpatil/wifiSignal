<p align="center">
  <img src="docs/app_icon.png" width="128" height="128" alt="WiFi Signal App Icon" />
</p>

<h1 align="center">WiFi Signal</h1>

<p align="center">
  <b>A native macOS SwiftUI application designed to analyze Wi-Fi signal strength in real time, inspect the active channel, detect radio interference and channel congestion, and guide optimal router placement.</b>
</p>

<p align="center">
  <a href="https://github.com/aashishpatil/wifiSignal/releases/latest/download/WiFiSignal.dmg">
    <img src="https://img.shields.io/badge/Download-WiFiSignal.dmg-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download WiFiSignal for macOS" />
  </a>
  <a href="https://github.com/aashishpatil/wifiSignal/releases/latest">
    <img src="https://img.shields.io/github/v/release/aashishpatil/wifiSignal?style=for-the-badge&label=Latest%20Release&color=007AFF" alt="Latest Release" />
  </a>
  <a href="https://github.com/aashishpatil/wifiSignal/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-Apache%202.0-34C759?style=for-the-badge" alt="Apache 2.0 License" />
  </a>
</p>

---

## 📥 Download & Installation

1. **[Download the Latest Release (`WiFiSignal.dmg`)](https://github.com/aashishpatil/wifiSignal/releases/latest/download/WiFiSignal.dmg)**
2. Double-click the downloaded `.dmg` file.
3. Drag **WiFiSignal** into your **Applications** folder.
4. Launch **WiFiSignal** from your Applications folder, Spotlight, or Launchpad.

> **Apple Notarized**: WiFiSignal is signed with Apple Developer ID and notarized by Apple. It runs natively on Apple Silicon (M1/M2/M3/M4) and Intel Macs running macOS 14.0 (Sonoma) or newer.

---

![WiFi Signal Dashboard](docs/screenshot.png)

---

## ✨ Features

### 1. 2D Real-Time Dashboard
* **Dynamic Waveform & Radar Visualizer**: 30fps pulsating concentric radar canvas with a rotating sweep beam, color-shifting from Emerald Green (pristine) to Crimson (dead zone).
* **Radial Signal Gauge**: High-precision 0–100% Signal Quality Index (SQI) fusing physical RF metrics with link-layer telemetry.
* **Live Oscilloscope History**: Scrolling timeline plotting live RSSI (dBm), Noise Floor (dBm), and Gateway Latency (ms) over a sliding 60-second window as you walk around with your MacBook.
* **6-Metric Telemetry HUD**:
  * **Signal Strength**: Intuitive 0–100% scale, 4-bar stepped indicator, and plain-English proximity rating alongside technical `RSSI` dBm (e.g. `95% • -42 dBm • Maximum (Near Router)`)
  * **Connected Channel**: Active channel (e.g. `Ch 36`), band (`5 GHz / 6 GHz`), and channel width (`80 MHz / 160 MHz`)
  * **Noise Floor & SNR**: Measures background RF noise with Apple Silicon zero-floor normalization and computes true `SNR` (e.g. `45 dB`)
  * **Transmit Link Speed**: Negotiated PHY speed in Mbps (e.g. `2400 Mbps`)
  * **Router Ping Latency & Jitter**: In-process gateway resolution and low-overhead ICMP probing to your default router
  * **Packet Loss Rate**: Sliding window loss rate with retransmission alerts

### 2. RF Spectrum & Channel Interference Analyzer
* **Visual Spectrum Bar Chart**: Compares your connected channel against neighboring networks.
* **Co-Channel Interference (CCI) Detection**: Identifies how many neighboring routers share your frequency.
* **Channel Recommendation Engine**: Automatically calculates the cleanest, least congested channels for 2.4 GHz (1, 6, 11) and 5 GHz bands.
* **Access Point Inventory**: Displays SSID, BSSID, RSSI, and channel details for all detected access points.

### 3. Room-by-Room Walkthrough & Survey
* **Walk & Map Mode**: Walk to different rooms (Living Room, Office, Bedroom, Kitchen, Basement) and log signal checkpoints with one click.
* **Signal Grading**: Assigns letter grades (`A+` to `F`) and coverage verdicts.
* **Placement Audit Summary**: Compares strongest vs. weakest areas to pinpoint coverage drop-off and recommend router repositioning.

### 4. Router Placement & Optimization Advisor
* **Active Diagnostics**: Real-time evaluation of wall attenuation, RF noise, and airtime saturation.
* **Golden Rules of Router Placement**: Actionable rules on router elevation, antenna orientation, avoiding concrete/appliances, and mitigating Bluetooth/USB 3.0 interference.

---

## 🛠 Project Structure

```
WiFiSignal/
├── project.yml                     # XcodeGen project specification
├── WiFiSignal.xcodeproj            # Generated Xcode project
├── LICENSE                         # Apache 2.0 License
├── docs/
│   └── screenshot.png              # Application screenshot
├── Resources/
│   ├── Info.plist                  # Location & network permissions
│   └── WiFiSignal.entitlements      # CoreWLAN & networking entitlements
└── Sources/
    ├── App/
    │   └── WiFiSignalApp.swift      # Main SwiftUI entry point
    ├── Models/
    │   ├── WiFiMetrics.swift        # CoreWLAN telemetry & SQI calculation
    │   ├── ScannedNetwork.swift     # Neighbor network & channel utilization
    │   ├── RoomSurvey.swift         # Walkthrough survey points & grades
    │   └── OptimizationAdvice.swift # Diagnostic recommendations
    ├── Services/
    │   ├── WiFiMonitor.swift        # Master telemetry coordinator
    │   ├── GatewayProber.swift      # Ping latency, jitter & packet loss
    │   ├── NetworkScanner.swift     # Background RF access point scanner
    │   ├── OptimizationEngine.swift # Rule-based diagnostic engine
    │   └── LocationPermissionHelper.swift # CoreLocation manager
    ├── Components/
    │   ├── SignalRadarCanvas.swift  # 60fps Canvas radar animation
    │   ├── RadialGaugeView.swift    # Circular gauge dial
    │   ├── LiveHistoryGraph.swift   # Oscilloscope timeline graph
    │   ├── MetricCard.swift         # Glassmorphic telemetry tiles
    │   └── SpectrumBarChart.swift   # 2.4/5GHz spectrum visualizer
    └── Views/
        ├── MainView.swift           # Sidebar navigation
        ├── DashboardView.swift      # Live telemetry dashboard
        ├── ChannelSpectrumView.swift# Spectrum analyzer & recommendations
        ├── RoomSurveyView.swift     # Room walk & placement audit
        └── OptimizationAdvisorView.swift # Router placement guide
```

---

## 🚀 Building & Running

### Option 1: Open in Xcode
1. Open the project in Xcode:
   ```bash
   open WiFiSignal.xcodeproj
   ```
2. Select the `WiFiSignal` scheme and press **Cmd + R** to run.

### Option 2: Regenerate with XcodeGen
If you modify `project.yml`, regenerate the project anytime:
```bash
xcodegen generate
```

### Option 3: Command Line Build
```bash
xcodebuild -project WiFiSignal.xcodeproj -scheme WiFiSignal -derivedDataPath ./DerivedData build
```
Launch the compiled app:
```bash
open DerivedData/Build/Products/Debug/WiFiSignal.app
```

---

## 📄 License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
