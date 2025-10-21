# Code Refactor Example: Platform-Neutral Architecture

This document shows how to refactor the current monolithic `MenuBarInfo.swift` into a modular, cross-platform structure.

## Before: Monolithic Structure (Current)

```
LocalDash/
└── Sources/
    └── MenuBarInfo/
        └── MenuBarInfo.swift (1,351 lines - everything!)
```

## After: Modular Structure (Proposed)

```
LocalDash/
└── Sources/
    ├── LocalDashCore/              # ✅ iOS + macOS + future platforms
    │   ├── Models/
    │   ├── ViewModels/
    │   ├── Views/
    │   └── Settings/
    ├── LocalDashMac/               # 🖥️ macOS only
    └── LocalDashiOS/               # 📱 iOS only
```

## Example: Weather Component Separation

### Current (Mixed Platform Code)

Everything in one file with macOS assumptions:

```swift
// MenuBarInfo.swift - Line 150
struct WeatherQuadrant: View {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ... SwiftUI code (works on both platforms) ...
        }
        .onAppear {
            viewModel.fetchWeather()
        }
    }
}

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var temperature: Double?
    // ... platform-neutral logic ...

    func fetchWeather() {
        // URLSession code - works on both platforms
    }
}
```

### After (Separated)

**File: `Sources/LocalDashCore/Views/WeatherQuadrant.swift`**
```swift
import SwiftUI

/// Shared view - works on iOS and macOS
public struct WeatherQuadrant: View {
    @StateObject private var viewModel = WeatherViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let condition = viewModel.condition {
                    Image(systemName: condition.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.primary) // .primary works on both
                }
                Text("Weather")
                    .font(.headline)
            }

            // ... rest of view code ...
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchWeather()
        }
    }
}
```

**File: `Sources/LocalDashCore/ViewModels/WeatherViewModel.swift`**
```swift
import Foundation
import SwiftUI

/// Shared view model - works on iOS and macOS
@MainActor
public class WeatherViewModel: ObservableObject {
    @Published public var temperature: Double?
    @Published public var condition: WeatherCondition?
    @Published public var nextRain: String?
    @Published public var rainChance: Int?
    @Published public var isLoading = false
    @Published public var error: String?

    public init() {}

    public func fetchWeather() {
        isLoading = true
        error = nil

        let settings = Settings.shared
        let urlString = "https://api.open-meteo.com/v1/forecast?..."

        // ... URLSession code - works on both platforms ...
    }
}
```

## Example: Platform-Specific App Structure

### macOS App Entry Point

**File: `Sources/LocalDashMac/MacApp.swift`**
```swift
import Cocoa
import SwiftUI
import LocalDashCore

@main
struct LocalDashMac {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar setup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "info.circle",
                                  accessibilityDescription: "Info")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Use shared DashboardGrid from LocalDashCore
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(
            rootView: DashboardGrid() // From LocalDashCore!
        )
    }

    @objc func togglePopover() {
        // macOS-specific popover logic
    }
}
```

### iOS App Entry Point

**File: `Sources/LocalDashiOS/iOSApp.swift`**
```swift
import SwiftUI
import LocalDashCore

@main
struct LocalDashiOS: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            // All these views come from LocalDashCore!

            DashboardGrid()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            WeatherQuadrant()
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun")
                }

            TideQuadrant()
                .tabItem {
                    Label("Tide", systemImage: "water.waves")
                }

            CardiffCityQuadrant()
                .tabItem {
                    Label("Cardiff", systemImage: "sportscourt")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
```

## Example: Conditional Image Loading

### Problem: NSImage vs UIImage

**File: `Sources/LocalDashCore/Utilities/PlatformImage.swift`**
```swift
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

public extension PlatformImage {
    static func loadFromBundle(named name: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(named: name)
        #elseif canImport(AppKit)
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
        #endif
    }
}
```

**Usage in CardiffCityQuadrant:**
```swift
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct CardiffCityQuadrant: View {
    public var body: some View {
        HStack(spacing: 8) {
            if let bluebirdImage = loadBluebirdImage() {
                #if canImport(UIKit)
                Image(uiImage: bluebirdImage)
                #elseif canImport(AppKit)
                Image(nsImage: bluebirdImage)
                #endif
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            }
            Text("Cardiff City")
        }
    }

    private func loadBluebirdImage() -> PlatformImage? {
        return PlatformImage.loadFromBundle(named: "bluebird")
    }
}
```

## Updated Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalDash",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)  // Add iOS support!
    ],
    products: [
        .library(
            name: "LocalDashCore",
            targets: ["LocalDashCore"]
        ),
        .executable(
            name: "LocalDashMac",
            targets: ["LocalDashMac"]
        ),
        // iOS executable would be added via Xcode project
    ],
    targets: [
        // Shared core - works on ALL platforms
        .target(
            name: "LocalDashCore",
            resources: [
                .process("Resources")
            ]
        ),

        // macOS-specific executable
        .executableTarget(
            name: "LocalDashMac",
            dependencies: ["LocalDashCore"]
        ),

        // iOS would typically be added via Xcode
        // but could also be here:
        .executableTarget(
            name: "LocalDashiOS",
            dependencies: ["LocalDashCore"],
            resources: [.process("Resources")]
        ),
    ]
)
```

## Migration Path

### Step 1: Create Core Module
```bash
mkdir -p Sources/LocalDashCore/{Models,ViewModels,Views,Settings,Resources}
```

### Step 2: Move Shared Code
Move these to LocalDashCore:
- All ViewModels (Weather, Tide, Train, Sun, SchoolRun, CardiffCity)
- All Quadrant Views
- All Data Models (OpenMeteoResponse, etc.)
- Settings class
- Resources (bluebird.png)

### Step 3: Create macOS Module
```bash
mkdir -p Sources/LocalDashMac
```

Move macOS-specific:
- AppDelegate
- Menu bar handling
- Popover management

### Step 4: Create iOS Module (New)
```bash
mkdir -p Sources/LocalDashiOS
```

Create iOS-specific:
- App structure
- Tab view
- Navigation

### Step 5: Update Imports
All platform-specific code imports `LocalDashCore`:
```swift
import LocalDashCore
```

### Step 6: Test Both Platforms
```bash
# Test macOS
swift build -c release

# Test iOS (requires Xcode)
xcodebuild -scheme LocalDashiOS -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Benefits of This Structure

### ✅ Code Reuse
- Weather logic written once, works on iPhone, iPad, Mac
- Cardiff City updates visible everywhere
- Settings sync automatically

### ✅ Maintainability
- Fix a bug once, fixed everywhere
- Add a feature once, available everywhere
- Clear separation of concerns

### ✅ Testing
- Test core logic independently
- Platform-specific code is minimal
- Easier to mock and test

### ✅ Future-Proof
- Add watchOS: just create `LocalDashWatch` target
- Add visionOS: just create `LocalDashVision` target
- Add widgets: already have shared views!

## Conclusion

The refactor is straightforward:
1. **85% of code** moves to `LocalDashCore` unchanged
2. **10% of code** stays in `LocalDashMac` with minor updates
3. **5% of code** is new iOS-specific UI

Total refactor time: **2-3 hours**
iOS app creation time: **4-6 hours**
Total time to universal app: **6-9 hours**

This is a **very achievable** goal with huge benefits!
