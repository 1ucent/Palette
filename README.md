# Nautilus

A minimal, premium "Liquid Glass" iOS app for controlling **ELK-BLEDOM** Bluetooth Low Energy LED strip controllers.

Built with SwiftUI + CoreBluetooth, no external dependencies.

## Features

- **Power on / off** with a glowing touch disk
- **Live color control** with coalesced, throttled writes (write-without-response) for smooth streaming
- **Brightness, pattern speed, and preset pattern** selection (29 built-in patterns)
- **Automatic clock sync** (on connect) and **weekly scheduling** (per-day on/off times)
- Beautiful dark "liquid glass" UI with connection status indicator

## Requirements

- iOS 17.0+
- Xcode 15+
- A physical device with Bluetooth LE (the ELK-BLEDOM strip)

## Getting started

1. Open `Nautilus.xcodeproj` in Xcode.
2. Select your Team under **Signing & Capabilities** (or leave unsigned for simulator/sideload).
3. Build & run on a physical iPhone (BLE works best on-device).

The app scans for a peripheral advertising **`ELK-BLEDOM`** (or service **`FFF0`**), connects, and writes to characteristic **`FFF3`**.

> **Why no camera/location strings?** The app only needs Bluetooth — it doesn't request Camera, Photo Library, or Location, so no extra Info.plist permission keys are required.

## BLE Protocol

The ELK-BLEDOM protocol is a simple `7E … EF` framed command set. Frames are implemented in `Nautilus/BluetoothManager.swift`:

| Command | Frame |
|---------|-------|
| Power on | `7E 04 04 01 00 01 FF 00 EF` |
| Power off | `7E 04 04 00 00 00 FF 00 EF` |
| Set color | `7E 07 05 03 RR GG BB 10 EF` |
| Brightness | `7E 04 01 v FF FF FF 00 EF` |
| Speed | `7E 04 02 v FF FF FF 00 EF` |
| Pattern | `7E 05 03 (p+128) 03 FF FF 00 EF` |
| Sync time | `7E 07 83 HH MM SS (weekday-1) FF EF` |

## Building an IPA

The repo includes a GitHub Actions workflow (`.github/workflows/build-ipa.yml`) that:

1. Builds the app on a `macos-15` runner
2. Packages it as an **unsigned** `.ipa` (for AltStore / Sideloadly / TrollStore)
3. Publishes it to [GitHub Releases](https://github.com/1ucent/Palette/releases) under the rolling `latest` tag

To build locally on macOS:

```bash
./build_ipa.sh                 # unsigned build
TEAM_ID=XXXXXXXXXX ./build_ipa.sh   # signed with your team
```

## Project structure

```
Nautilus/
  NautilusApp.swift        # App entry point + TabView
  ContentView.swift        # Dashboard (power disk + color)
  SettingsView.swift       # Brightness / speed / pattern / schedule
  BluetoothManager.swift   # CoreBluetooth + protocol implementation
  Assets.xcassets/         # App icon, accent color, launch background
  Info.plist               # Bluetooth usage descriptions, orientations
  Nautilus.entitlements    # com.apple.developer.bluetooth-central
```

## License

This project is provided as-is for personal use.
