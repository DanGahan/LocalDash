import Cocoa
import SwiftUI
import MapKit

@main
struct MenuBarInfo {
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
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Info")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 675, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())

        // Close popover when clicking outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    @MainActor @objc func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    @MainActor func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }

    @MainActor func showMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @MainActor @objc func openSettings() {
        print("openSettings called")
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "LocalDash Settings"
            settingsWindow?.contentViewController = NSHostingController(rootView: SettingsView())
            settingsWindow?.level = .floating
            settingsWindow?.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    @MainActor @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                WeatherQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)

                TideQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)

                SunQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 0) {
                TrainQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)

                SchoolRunQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)

                CardiffCityQuadrant()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.3), width: 0.5)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Weather Quadrant
struct WeatherQuadrant: View {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let condition = viewModel.condition {
                    Image(systemName: condition.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                Text("Weather")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let temp = viewModel.temperature {
                        Text("\(String(format: "%.1f", temp))°C")
                            .font(.title)
                    }

                    if let condition = viewModel.condition {
                        Text(condition.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let nextRain = viewModel.nextRain {
                        Text("Next rain: \(nextRain)")
                            .font(.caption)
                            .padding(.top, 4)
                    }

                    if let rainChance = viewModel.rainChance {
                        Text("Chance: \(rainChance)%")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchWeather()
        }
    }
}

@MainActor
class WeatherViewModel: ObservableObject {
    enum WeatherCondition {
        case clearSky
        case partlyCloudy
        case cloudy
        case rain
        case heavyRain
        case thunderstorm
        case snow
        case fog

        var iconName: String {
            switch self {
            case .clearSky: return "sun.max.fill"
            case .partlyCloudy: return "cloud.sun.fill"
            case .cloudy: return "cloud.fill"
            case .rain: return "cloud.rain.fill"
            case .heavyRain: return "cloud.heavyrain.fill"
            case .thunderstorm: return "cloud.bolt.rain.fill"
            case .snow: return "cloud.snow.fill"
            case .fog: return "cloud.fog.fill"
            }
        }

        var description: String {
            switch self {
            case .clearSky: return "Clear sky"
            case .partlyCloudy: return "Partly cloudy"
            case .cloudy: return "Cloudy"
            case .rain: return "Rain"
            case .heavyRain: return "Heavy rain"
            case .thunderstorm: return "Thunderstorm"
            case .snow: return "Snow"
            case .fog: return "Foggy"
            }
        }

        static func from(weatherCode: Int) -> WeatherCondition {
            switch weatherCode {
            case 0: return .clearSky
            case 1, 2: return .partlyCloudy
            case 3: return .cloudy
            case 45, 48: return .fog
            case 51, 53, 55, 56, 57, 61, 63, 80, 81: return .rain
            case 65, 82: return .heavyRain
            case 71, 73, 75, 77, 85, 86: return .snow
            case 95, 96, 99: return .thunderstorm
            default: return .cloudy
            }
        }
    }

    @Published var temperature: Double?
    @Published var condition: WeatherCondition?
    @Published var nextRain: String?
    @Published var rainChance: Int?
    @Published var isLoading = false
    @Published var error: String?

    func fetchWeather() {
        isLoading = true
        error = nil

        let settings = Settings.shared
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(settings.latitude)&longitude=\(settings.longitude)&current=temperature_2m,weather_code&hourly=precipitation_probability,precipitation&timezone=auto&forecast_days=1"

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

                self.temperature = response.current.temperature_2m
                self.condition = WeatherCondition.from(weatherCode: response.current.weather_code)

                // Find next rain
                if let nextRainInfo = findNextRain(hourly: response.hourly) {
                    self.nextRain = nextRainInfo.time
                    self.rainChance = nextRainInfo.probability
                } else {
                    self.nextRain = "No rain expected"
                    self.rainChance = 0
                }

                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func findNextRain(hourly: OpenMeteoResponse.Hourly) -> (time: String, probability: Int)? {
        let dateFormatter = ISO8601DateFormatter()
        let now = Date()

        for (index, timeString) in hourly.time.enumerated() {
            guard let time = dateFormatter.date(from: timeString),
                  time > now,
                  let probability = hourly.precipitation_probability[index],
                  probability > 30 else {
                continue
            }

            let timeUntil = time.timeIntervalSince(now)
            let hours = Int(timeUntil / 3600)
            let minutes = Int((timeUntil.truncatingRemainder(dividingBy: 3600)) / 60)

            let timeString: String
            if hours == 0 {
                timeString = "In \(minutes)min"
            } else if hours < 6 {
                timeString = "In \(hours)h \(minutes)min"
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                timeString = "At \(formatter.string(from: time))"
            }

            return (timeString, probability)
        }

        return nil
    }
}

// MARK: - Open-Meteo API Models
struct OpenMeteoResponse: Codable {
    let current: Current
    let hourly: Hourly

    struct Current: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }

    struct Hourly: Codable {
        let time: [String]
        let precipitation_probability: [Int?]
        let precipitation: [Double?]
    }
}

// MARK: - Tide Quadrant
struct TideQuadrant: View {
    @StateObject private var viewModel = TideViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "water.waves")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                Text("Tide")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let level = viewModel.currentLevel {
                        Text("\(String(format: "%.1f", level))m")
                            .font(.title)
                    }

                    if let trend = viewModel.trend {
                        HStack(spacing: 4) {
                            Image(systemName: trend == "rising" ? "arrow.up" : "arrow.down")
                            Text(trend.capitalized)
                        }
                        .font(.caption)
                    }

                    if let station = viewModel.stationName {
                        Text(station)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchTide()
        }
    }
}

@MainActor
class TideViewModel: ObservableObject {
    @Published var currentLevel: Double?
    @Published var trend: String?
    @Published var stationName: String?
    @Published var isLoading = false
    @Published var error: String?

    func fetchTide() {
        isLoading = true
        error = nil

        Task {
            do {
                let tideData = try await fetchBarryTideData()

                self.stationName = "Barry"
                self.currentLevel = tideData.currentHeight
                self.trend = tideData.trend

                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchBarryTideData() async throws -> (currentHeight: Double, trend: String) {
        let urlString = "https://www.tidetimes.org.uk/barry-tide-times"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TideAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TideAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode HTML"])
        }

        // Extract current water height directly from the page
        let currentHeight = try parseCurrentHeight(from: html)

        // Parse today's high and low tides to determine trend
        let tides = try parseTideTimes(from: html)
        let trend = calculateTrend(tides: tides, now: Date())

        return (currentHeight, trend)
    }

    private func parseCurrentHeight(from html: String) throws -> Double {
        // Pattern: "Right now, the water height at Barry is approximately X.XXm"
        let pattern = #"water height at Barry is approximately ([\d.]+)m"#

        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let nsString = html as NSString

        if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
           match.numberOfRanges == 2 {
            let heightRange = match.range(at: 1)
            let heightString = nsString.substring(with: heightRange)

            if let height = Double(heightString) {
                return height
            }
        }

        throw NSError(domain: "TideAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not parse current height"])
    }

    private func parseTideTimes(from html: String) throws -> [TideEvent] {
        var tides: [TideEvent] = []

        // Look for tide data in table format
        // Pattern: <td>High/Low</td><td><span>HH:MM</span></td><td>X.XXm</td>
        let pattern = #"<td[^>]*>(High|Low)</td>\s*<td[^>]*><span>(\d{2}:\d{2})</span></td>\s*<td[^>]*>([\d.]+)m</td>"#

        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone.current

        for match in matches {
            if match.numberOfRanges == 4 {
                let typeRange = match.range(at: 1)
                let timeRange = match.range(at: 2)
                let heightRange = match.range(at: 3)

                let type = nsString.substring(with: typeRange)
                let timeString = nsString.substring(with: timeRange)
                let heightString = nsString.substring(with: heightRange)

                if let time = dateFormatter.date(from: timeString),
                   let height = Double(heightString) {

                    // Combine today's date with the time
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let tideDate = calendar.date(bySettingHour: calendar.component(.hour, from: time),
                                                   minute: calendar.component(.minute, from: time),
                                                   second: 0,
                                                   of: today)!

                    tides.append(TideEvent(type: type, time: tideDate, height: height))
                }
            }
        }

        return tides
    }

    private func calculateTrend(tides: [TideEvent], now: Date) -> String {
        // Find the tides before and after now
        let sortedTides = tides.sorted { $0.time < $1.time }

        var nextTide: TideEvent?

        for tide in sortedTides {
            if tide.time > now {
                nextTide = tide
                break
            }
        }

        guard let next = nextTide else {
            return "unknown"
        }

        // If next tide is high, we're rising; if next is low, we're falling
        return next.type == "High" ? "rising" : "falling"
    }
}

// MARK: - Tide Models
struct TideEvent {
    let type: String
    let time: Date
    let height: Double
}

// MARK: - Train Quadrant
struct TrainQuadrant: View {
    @StateObject private var viewModel = TrainViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                Text("Trains")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                ForEach(viewModel.departures, id: \.self) { departure in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(departure.destination)
                                .font(.caption)
                            Spacer()
                            Text(departure.scheduledTime)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Text(departure.status)
                            .font(.system(size: 9))
                            .foregroundColor(departure.status == "Cancelled" ? .red : .secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchDepartures()
        }
    }
}

@MainActor
class TrainViewModel: ObservableObject {
    struct Departure: Hashable {
        let destination: String
        let scheduledTime: String
        let status: String
    }

    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var error: String?

    func fetchDepartures() {
        isLoading = true
        error = nil

        Task {
            do {
                let trains = try await fetchRhooseTrains()
                self.departures = trains
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchRhooseTrains() async throws -> [Departure] {
        let station = Settings.shared.trainStation
        let urlString = "https://huxley2.azurewebsites.net/departures/\(station)/10"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TrainAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HuxleyResponse.self, from: data)

        var cardiffTrain: Departure?
        var bridgendTrain: Departure?

        for service in response.trainServices ?? [] {
            guard let destination = service.destination?.first?.locationName,
                  let std = service.std,
                  let etd = service.etd else {
                continue
            }

            // Determine status
            let status: String
            if service.isCancelled {
                status = "Cancelled"
            } else if etd == "On time" {
                status = "On time"
            } else if etd == "Delayed" {
                status = "Delayed"
            } else if etd != std {
                // etd contains the expected time
                status = "Delayed (\(etd))"
            } else {
                status = "On time"
            }

            // Determine direction based on destination
            // Eastbound: Cardiff, Caerphilly, Pontypridd, Treherbert, etc.
            // Westbound: Bridgend, Swansea
            if (destination.contains("Cardiff") || destination.contains("Caerphilly") ||
                destination.contains("Pontypridd") || destination.contains("Treherbert")) && cardiffTrain == nil {
                cardiffTrain = Departure(
                    destination: "Cardiff",
                    scheduledTime: std,
                    status: status
                )
            } else if (destination.contains("Bridgend") || destination.contains("Swansea")) && bridgendTrain == nil {
                bridgendTrain = Departure(
                    destination: "Bridgend",
                    scheduledTime: std,
                    status: status
                )
            }

            // Stop once we have both directions
            if cardiffTrain != nil && bridgendTrain != nil {
                break
            }
        }

        var trains: [Departure] = []
        if let cardiff = cardiffTrain {
            trains.append(cardiff)
        }
        if let bridgend = bridgendTrain {
            trains.append(bridgend)
        }

        return trains
    }
}

// MARK: - Huxley API Models
struct HuxleyResponse: Codable {
    let trainServices: [TrainService]?
}

struct TrainService: Codable {
    let destination: [Location]?
    let std: String?
    let etd: String?
    let platform: String?
    let isCancelled: Bool

    struct Location: Codable {
        let locationName: String
        let crs: String?
    }
}

// MARK: - Sun Quadrant
struct SunQuadrant: View {
    @StateObject private var viewModel = SunViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sunset.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                Text("Sunset")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let sunset = viewModel.sunsetTime {
                        HStack {
                            Text("Sunset:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(sunset)
                                .font(.title3)
                        }
                    }

                    if let sunrise = viewModel.sunriseTime {
                        HStack {
                            Text("Sunrise:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(sunrise)
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchSunTimes()
        }
    }
}

@MainActor
class SunViewModel: ObservableObject {
    struct SunEvent {
        let type: String
        let time: String
    }

    @Published var sunriseTime: String?
    @Published var sunsetTime: String?
    @Published var nextEvent: SunEvent?
    @Published var isLoading = false
    @Published var error: String?

    func fetchSunTimes() {
        isLoading = true
        error = nil

        Task {
            do {
                let times = try await fetchBarrySunTimes()
                self.sunriseTime = times.sunrise
                self.sunsetTime = times.sunset

                // Determine which is next
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: Date())

                if hour < 18 {
                    self.nextEvent = SunEvent(type: "Sunset", time: times.sunset)
                } else {
                    self.nextEvent = SunEvent(type: "Sunrise", time: times.sunrise)
                }

                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchBarrySunTimes() async throws -> (sunrise: String, sunset: String) {
        let urlString = "https://www.tidetimes.org.uk/barry-tide-times"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "SunAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SunAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode HTML"])
        }

        // Parse sunrise and sunset times
        // Pattern: <div>Sunrise :<span>HH:MM</span></div> and <div>Sunset  :<span>HH:MM</span></div>
        let sunrisePattern = #"Sunrise\s*:<span>(\d{2}:\d{2})</span>"#
        let sunsetPattern = #"Sunset\s*:<span>(\d{2}:\d{2})</span>"#

        let sunriseRegex = try NSRegularExpression(pattern: sunrisePattern, options: [])
        let sunsetRegex = try NSRegularExpression(pattern: sunsetPattern, options: [])

        let nsString = html as NSString

        var sunrise: String?
        var sunset: String?

        if let sunriseMatch = sunriseRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
           sunriseMatch.numberOfRanges == 2 {
            let timeRange = sunriseMatch.range(at: 1)
            sunrise = nsString.substring(with: timeRange)
        }

        if let sunsetMatch = sunsetRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
           sunsetMatch.numberOfRanges == 2 {
            let timeRange = sunsetMatch.range(at: 1)
            sunset = nsString.substring(with: timeRange)
        }

        guard let sunriseTime = sunrise, let sunsetTime = sunset else {
            throw NSError(domain: "SunAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not parse sun times"])
        }

        return (sunriseTime, sunsetTime)
    }
}

// MARK: - School Run Quadrant
struct SchoolRunQuadrant: View {
    @StateObject private var viewModel = SchoolRunViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                Text("School Run")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let travelTime = viewModel.travelTime {
                        Text(travelTime)
                            .font(.title)
                    }

                    Text("Journey time to Gaer Primary")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchTravelTime()
        }
    }
}

@MainActor
class SchoolRunViewModel: ObservableObject {
    @Published var travelTime: String?
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 300 // 5 minutes

    func fetchTravelTime() {
        // Check if we have cached data that's still fresh
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInterval,
           travelTime != nil {
            return
        }

        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                let time = try await calculateDriveTime(from: "CF62 3ND", to: "Gaer Primary School")
                self.travelTime = time
                self.lastFetchTime = Date()
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func calculateDriveTime(from origin: String, to destination: String) async throws -> String {
        // Geocode origin
        let originCoordinate = try await geocode(address: origin)

        // Geocode destination
        let destinationCoordinate = try await geocode(address: destination)

        // Create placemarks
        let originPlacemark = MKPlacemark(coordinate: originCoordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)

        // Create directions request
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: originPlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        // Get directions
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw NSError(domain: "SchoolRunAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "No route found"])
        }

        // Format travel time
        let travelTimeSeconds = route.expectedTravelTime
        return formatTravelTime(seconds: travelTimeSeconds)
    }

    private func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)

        guard let location = placemarks.first?.location else {
            throw NSError(domain: "SchoolRunAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not geocode address: \(address)"])
        }

        return location.coordinate
    }

    private func formatTravelTime(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours) hr \(remainingMinutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Cardiff City Quadrant
struct CardiffCityQuadrant: View {
    @StateObject private var viewModel = CardiffCityViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let bluebirdImage = loadBlackBluebirdImage() {
                    Image(nsImage: bluebirdImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                Text("Cardiff City")
                    .font(.headline)
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let position = viewModel.leaguePosition {
                        Text(position)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if let lastResult = viewModel.lastResult {
                        Text(lastResult)
                            .font(.caption)
                    }

                    if let nextFixture = viewModel.nextFixture {
                        Text(nextFixture)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.fetchCardiffCityData()
        }
    }

    private func loadBlackBluebirdImage() -> NSImage? {
        // Try different resource loading methods
        if let resourceURL = Bundle.module.url(forResource: "bluebird", withExtension: "png") {
            return NSImage(contentsOf: resourceURL)
        }

        if let resourceURL = Bundle.module.url(forResource: "bluebird", withExtension: "png", subdirectory: "Resources") {
            return NSImage(contentsOf: resourceURL)
        }

        // If bundle loading fails, try direct path as fallback
        let directPath = "/Users/dan/Documents/Code/MenuBarInfo/Sources/MenuBarInfo/Resources/bluebird.png"
        if FileManager.default.fileExists(atPath: directPath) {
            return NSImage(contentsOfFile: directPath)
        }

        return nil
    }
}

@MainActor
class CardiffCityViewModel: ObservableObject {
    @Published var leaguePosition: String?
    @Published var lastResult: String?
    @Published var nextFixture: String?
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 3600 // 1 hour

    func fetchCardiffCityData() {
        // Check if we have cached data that's still fresh
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInterval,
           leaguePosition != nil {
            return
        }

        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                // Fetch Cardiff City data from TheSportsDB API
                async let lastEventTask = fetchLastEvent()
                async let nextEventTask = fetchNextEvent()
                async let tableTask = fetchLeagueTable()

                let (lastEvent, nextEvent, table) = try await (lastEventTask, nextEventTask, tableTask)

                self.lastResult = lastEvent
                self.nextFixture = nextEvent
                self.leaguePosition = table
                self.lastFetchTime = Date()
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchLastEvent() async throws -> String {
        let url = URL(string: "https://www.thesportsdb.com/api/v1/json/3/eventslast.php?id=133637")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let results = json?["results"] as? [[String: Any]] else {
            return "No recent result"
        }

        // Find most recent league match
        guard let event = results.first(where: { event in
            let league = event["strLeague"] as? String ?? ""
            return league == "English League 1"
        }) else {
            return "No recent result"
        }

        let homeTeam = event["strHomeTeam"] as? String ?? ""
        let awayTeam = event["strAwayTeam"] as? String ?? ""
        let homeScore = event["intHomeScore"] as? String ?? "0"
        let awayScore = event["intAwayScore"] as? String ?? "0"
        let dateStr = event["dateEvent"] as? String ?? ""
        let date = formatDate(dateStr)

        let isHome = homeTeam.contains("Cardiff")
        let opponent = isHome ? awayTeam : homeTeam
        let result = isHome ? "\(homeScore)-\(awayScore)" : "\(awayScore)-\(homeScore)"

        return "Previous Fixture (\(date)):\nCardiff City \(result) \(opponent)"
    }

    private func fetchNextEvent() async throws -> String {
        // Search through multiple rounds to find next non-postponed Cardiff fixture
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        for round in 12...20 {
            let url = URL(string: "https://www.thesportsdb.com/api/v1/json/3/eventsround.php?id=4396&r=\(round)&s=2025-2026")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let events = json?["events"] as? [[String: Any]] else {
                continue
            }

            // Find Cardiff match that is not postponed and is in the future
            if let event = events.first(where: { event in
                let homeTeam = event["strHomeTeam"] as? String ?? ""
                let awayTeam = event["strAwayTeam"] as? String ?? ""
                let postponed = event["strPostponed"] as? String ?? "no"
                let dateStr = event["dateEvent"] as? String ?? ""

                // Check if the match is Cardiff, not postponed, and in the future
                let isCardiffMatch = homeTeam.contains("Cardiff") || awayTeam.contains("Cardiff")
                let isNotPostponed = postponed != "yes"

                // Parse date and check if it's in the future
                let isFuture: Bool
                if let matchDate = dateFormatter.date(from: dateStr) {
                    // Add one day to account for matches that happen later on the same date
                    isFuture = matchDate.addingTimeInterval(86400) > now
                } else {
                    isFuture = false
                }

                return isCardiffMatch && isNotPostponed && isFuture
            }) {
                let homeTeam = event["strHomeTeam"] as? String ?? ""
                let awayTeam = event["strAwayTeam"] as? String ?? ""
                let dateStr = event["dateEvent"] as? String ?? ""
                let date = formatDate(dateStr)

                let isHome = homeTeam.contains("Cardiff")
                let opponent = isHome ? awayTeam : homeTeam

                return "Next Fixture (\(date)):\nCardiff City v \(opponent)"
            }
        }

        return "No upcoming fixture"
    }

    private func fetchLeagueTable() async throws -> String {
        let url = URL(string: "https://www.thesportsdb.com/api/v1/json/3/lookuptable.php?l=4396&s=2025-2026")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let table = json?["table"] as? [[String: Any]] else {
            return "Position unknown"
        }

        // Find Cardiff City in the table
        for entry in table {
            if let teamName = entry["strTeam"] as? String,
               teamName.contains("Cardiff"),
               let rank = entry["intRank"] as? String {
                let position = formatPosition(Int(rank) ?? 0)
                return "\(position) in League 1"
            }
        }

        return "Position unknown"
    }

    private func formatDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else { return dateStr }
        return "\(parts[2])/\(parts[1])/\(parts[0])"
    }

    private func formatPosition(_ position: Int) -> String {
        switch position {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(position)th"
        }
    }
}

// MARK: - Settings
@MainActor
class Settings: ObservableObject {
    static let shared = Settings()
    
    @Published var latitude: Double {
        didSet { UserDefaults.standard.set(latitude, forKey: "latitude") }
    }
    
    @Published var longitude: Double {
        didSet { UserDefaults.standard.set(longitude, forKey: "longitude") }
    }
    
    @Published var trainStation: String {
        didSet { UserDefaults.standard.set(trainStation, forKey: "trainStation") }
    }
    
    private init() {
        self.latitude = UserDefaults.standard.double(forKey: "latitude")
        self.longitude = UserDefaults.standard.double(forKey: "longitude")
        self.trainStation = UserDefaults.standard.string(forKey: "trainStation") ?? "RIA"
        
        // Set defaults if not configured
        if latitude == 0 && longitude == 0 {
            latitude = 51.38635735792241
            longitude = -3.3383067307875467
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var trainStationText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("LocalDash Settings")
                .font(.title2)

            Text("Changes are saved automatically when you close this window")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            Group {
                Text("Location")
                    .font(.headline)
                
                HStack {
                    Text("Latitude:")
                        .frame(width: 80, alignment: .leading)
                    TextField("51.38636", text: $latitudeText)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Longitude:")
                        .frame(width: 80, alignment: .leading)
                    TextField("-3.33831", text: $longitudeText)
                        .textFieldStyle(.roundedBorder)
                }

                // Map preview
                if let lat = Double(latitudeText), let lon = Double(longitudeText) {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )))) {
                        Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                    .frame(height: 120)
                    .cornerRadius(8)
                }
            }

            Divider()
            
            Group {
                Text("Train Station")
                    .font(.headline)
                
                HStack {
                    Text("CRS Code:")
                        .frame(width: 80, alignment: .leading)
                    TextField("RIA", text: $trainStationText)
                        .textFieldStyle(.roundedBorder)
                }
                
                Text("Enter the 3-letter station code (e.g., RIA for Rhoose)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    saveSettings()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            latitudeText = String(settings.latitude)
            longitudeText = String(settings.longitude)
            trainStationText = settings.trainStation
        }
    }
    
    private func saveSettings() {
        if let lat = Double(latitudeText), let lon = Double(longitudeText) {
            settings.latitude = lat
            settings.longitude = lon
        }

        if !trainStationText.isEmpty {
            settings.trainStation = trainStationText.uppercased()
        }
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}
