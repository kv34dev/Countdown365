import WidgetKit
import SwiftUI

// MARK: - Shared Data (App Group)
private let appGroupID = "group.com.kv.countdown365"

// MARK: - Shared Theme (mirrors AppTheme in main app)
enum WidgetTheme: String, Codable {
    case night, light, nostalgia

    var bgColors: [Color] {
        switch self {
        case .night:     return [Color(hex: "0D0D1A"), Color(hex: "1A0D2E"), Color(hex: "0D1A2E")]
        case .light:     return [Color(hex: "FFF8EC"), Color(hex: "F5E6C8"), Color(hex: "EDD9A3")]
        case .nostalgia: return [Color(hex: "020818"), Color(hex: "050D2E"), Color(hex: "071025")]
        }
    }
    var accent: Color {
        switch self {
        case .night:     return Color(hex: "A855F7")
        case .light:     return Color(hex: "A0714F")
        case .nostalgia: return Color(hex: "4A8FE7")
        }
    }
    var accentGradient: [Color] {
        switch self {
        case .night:     return [Color(hex: "A855F7"), Color(hex: "6366F1")]
        case .light:     return [Color(hex: "C9955A"), Color(hex: "A0714F")]
        case .nostalgia: return [Color(hex: "4A8FE7"), Color(hex: "2255C4")]
        }
    }
    var primaryText: Color {
        switch self {
        case .light: return Color(hex: "4A3728")
        default:     return .white
        }
    }
    var secondaryText: Color {
        switch self {
        case .light: return Color(hex: "8B6650").opacity(0.8)
        default:     return Color.white.opacity(0.45)
        }
    }
    // Static starfield colors (no animation in widgets)
    var starfieldBg: [Color] {
        return [Color(hex: "020818"), Color(hex: "050D2E"), Color(hex: "071025")]
    }
}

// MARK: - Shared Models
struct WidgetTimerData: Codable, Identifiable {
    var id: String
    var name: String
    var targetDate: Date
}

struct WidgetSharedData: Codable {
    var timers: [WidgetTimerData]
    var selectedTimerID: String?
    var theme: String // WidgetTheme rawValue
}

// MARK: - Shared Data Reader
struct SharedDataReader {
    static func read() -> WidgetSharedData? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        guard let data = defaults.data(forKey: "widgetData") else { return nil }
        return try? JSONDecoder().decode(WidgetSharedData.self, from: data)
    }
}

// MARK: - Timeline Entry
struct CountdownEntry: TimelineEntry {
    let date: Date
    let timerName: String
    let targetDate: Date
    let theme: WidgetTheme
    let allTimers: [WidgetTimerData]
    let isExpired: Bool
    var days: Int
    var hours: Int
    var minutes: Int
    var seconds: Int
}

// MARK: - Provider
struct CountdownProvider: AppIntentTimelineProvider {
    typealias Intent = CountdownConfigIntent

    func placeholder(in context: Context) -> CountdownEntry {
        makeEntry(date: Date(), timerName: "New Year 2027", targetDate: futureDate(days: 300), theme: .night, allTimers: [])
    }

    func snapshot(for configuration: CountdownConfigIntent, in context: Context) async -> CountdownEntry {
        let shared = SharedDataReader.read()
        let theme = WidgetTheme(rawValue: shared?.theme ?? "night") ?? .night
        let timers = shared?.timers ?? []

        if let chosen = resolveTimer(configuration: configuration, shared: shared) {
            return makeEntry(date: Date(), timerName: chosen.name, targetDate: chosen.targetDate, theme: theme, allTimers: timers)
        }
        return makeEntry(date: Date(), timerName: "New Year 2027", targetDate: futureDate(days: 300), theme: theme, allTimers: timers)
    }

    func timeline(for configuration: CountdownConfigIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let shared = SharedDataReader.read()
        let theme = WidgetTheme(rawValue: shared?.theme ?? "night") ?? .night
        let timers = shared?.timers ?? []
        let now = Date()

        var entries: [CountdownEntry] = []

        if let chosen = resolveTimer(configuration: configuration, shared: shared) {
            // Generate entries every minute for the next hour, then every hour
            for i in 0..<60 {
                let entryDate = now.addingTimeInterval(Double(i) * 60)
                entries.append(makeEntry(date: entryDate, timerName: chosen.name, targetDate: chosen.targetDate, theme: theme, allTimers: timers))
            }
        } else {
            entries.append(makeEntry(date: now, timerName: "No Timers", targetDate: now, theme: theme, allTimers: timers))
        }

        // Refresh every hour
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    // MARK: Helpers
    private func resolveTimer(configuration: CountdownConfigIntent, shared: WidgetSharedData?) -> WidgetTimerData? {
        let timers = shared?.timers ?? []
        // If user picked a specific timer in widget config — use it
        if let pickedID = configuration.timerID, !pickedID.isEmpty {
            return timers.first(where: { $0.id == pickedID })
        }
        // Otherwise fall back to the app's selected timer
        if let selID = shared?.selectedTimerID {
            return timers.first(where: { $0.id == selID })
        }
        return timers.first
    }

    private func makeEntry(date: Date, timerName: String, targetDate: Date, theme: WidgetTheme, allTimers: [WidgetTimerData]) -> CountdownEntry {
        let expired = targetDate <= date
        let diff = max(0, targetDate.timeIntervalSince(date))
        let total = Int(diff)
        return CountdownEntry(
            date: date,
            timerName: timerName,
            targetDate: targetDate,
            theme: theme,
            allTimers: allTimers,
            isExpired: expired,
            days: total / 86400,
            hours: (total % 86400) / 3600,
            minutes: (total % 3600) / 60,
            seconds: total % 60
        )
    }

    private func futureDate(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}

// MARK: - App Intent (Widget Configuration)
import AppIntents

struct CountdownConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Countdown Timer"
    static var description = IntentDescription("Choose which timer to display.")

    // The user picks a timer from a list; nil = follow app selection
    @Parameter(title: "Timer", optionsProvider: TimerOptionsProvider())
    var timerID: String?
}

struct TimerOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        guard let shared = SharedDataReader.read() else { return [] }
        return shared.timers.map { $0.id }
    }

    func defaultResult() async -> String? { nil }
}

// MARK: - Small Widget View  (systemSmall)
struct SmallCountdownWidgetView: View {
    let entry: CountdownEntry

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 4) {
                // Gradient accent line
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: entry.theme.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: 36, height: 3)

                Spacer()

                if entry.isExpired {
                    Text("🎉")
                        .font(.system(size: 34))
                    Text("Already here!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(entry.theme.accent)
                } else {
                    // Big days number
                    Text("\(entry.days)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(entry.theme.primaryText)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("days")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(entry.theme.secondaryText)

                    HStack(spacing: 8) {
                        SmallUnit(value: entry.hours,   label: "h", theme: entry.theme)
                        SmallUnit(value: entry.minutes, label: "m", theme: entry.theme)
                        SmallUnit(value: entry.seconds, label: "s", theme: entry.theme)
                    }
                }

                Spacer()

                Text(entry.timerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(entry.theme.secondaryText)
                    .lineLimit(1)
            }
            .padding(14)
        }
    }

    @ViewBuilder var background: some View {
        if entry.theme == .nostalgia {
            ZStack {
                LinearGradient(colors: entry.theme.starfieldBg, startPoint: .topLeading, endPoint: .bottomTrailing)
                StaticStarfield()
            }
        } else {
            LinearGradient(colors: entry.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Large Widget View  (systemLarge / systemMedium used as "big square")
struct LargeCountdownWidgetView: View {
    let entry: CountdownEntry

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer()

                // Event name
                Text(entry.timerName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(entry.theme.primaryText)
                    .multilineTextAlignment(.center)
                    .shadow(color: entry.theme.accent.opacity(0.5), radius: 8)
                    .padding(.horizontal, 16)

                Text(entry.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(entry.theme.secondaryText)
                    .padding(.top, 4)

                Spacer()

                if entry.isExpired {
                    Text("🎉 Already here!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(entry.theme.accent)
                } else {
                    // 2×2 grid matching the app
                    VStack(spacing: 10) {
                        HStack(spacing: 0) {
                            WidgetCountUnit(value: entry.days,  label: "days",    theme: entry.theme)
                            WidgetCountUnit(value: entry.hours, label: "hours",   theme: entry.theme)
                        }
                        HStack(spacing: 0) {
                            WidgetCountUnit(value: entry.minutes, label: "minutes", theme: entry.theme)
                            WidgetCountUnit(value: entry.seconds, label: "seconds", theme: entry.theme)
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Spacer()

                // Accent gradient bar at bottom
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: entry.theme.accentGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder var background: some View {
        if entry.theme == .nostalgia {
            ZStack {
                LinearGradient(colors: entry.theme.starfieldBg, startPoint: .topLeading, endPoint: .bottomTrailing)
                StaticStarfield()
            }
        } else {
            LinearGradient(colors: entry.theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Reusable sub-views

struct WidgetCountUnit: View {
    let value: Int
    let label: String
    let theme: WidgetTheme

    private var text: String { value >= 100 ? "\(value)" : String(format: "%02d", value) }
    private var fontSize: CGFloat { value >= 100 ? 44 : 52 }

    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(theme.primaryText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SmallUnit: View {
    let value: Int
    let label: String
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 1) {
            Text(String(format: "%02d", value))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(theme.primaryText)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.secondaryText)
        }
    }
}

// MARK: - Static Starfield (no animation — widgets don't support it)
struct StaticStarfield: View {
    // Same seeded positions as the app, just rendered without blinking
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = {
        var state: UInt64 = 42
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        func rand(_ lo: Double, _ hi: Double) -> Double {
            let t = Double(next()) / Double(UInt64.max)
            return lo + t * (hi - lo)
        }
        return (0..<160).map { _ in
            (CGFloat(rand(0,1)), CGFloat(rand(0,1)), CGFloat(rand(0.8,2.5)), rand(0.15, 0.7))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                    Circle()
                        .fill(Color.white.opacity(s.opacity))
                        .frame(width: s.size, height: s.size)
                        .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                }
            }
        }
    }
}

// MARK: - Widget Definition
@main
struct CountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownSmallWidget()
        CountdownLargeWidget()
    }
}

struct CountdownSmallWidget: Widget {
    let kind = "CountdownSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CountdownConfigIntent.self, provider: CountdownProvider()) { entry in
            SmallCountdownWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Countdown")
        .description("Shows your countdown timer.")
        .supportedFamilies([.systemSmall])
    }
}

struct CountdownLargeWidget: Widget {
    let kind = "CountdownLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CountdownConfigIntent.self, provider: CountdownProvider()) { entry in
            LargeCountdownWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Countdown (Large)")
        .description("Shows your countdown timer in full detail.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Color Hex (copied from main app)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Previews
#Preview("Small – Night", as: .systemSmall) {
    CountdownSmallWidget()
} timeline: {
    CountdownEntry(date: .now, timerName: "New Year 2027", targetDate: Calendar.current.date(from: DateComponents(year:2027,month:1,day:1))!, theme: .night, allTimers: [], isExpired: false, days: 307, hours: 14, minutes: 22, seconds: 8)
}

#Preview("Small – Light", as: .systemSmall) {
    CountdownSmallWidget()
} timeline: {
    CountdownEntry(date: .now, timerName: "Summer 2026", targetDate: Calendar.current.date(from: DateComponents(year:2026,month:6,day:1))!, theme: .light, allTimers: [], isExpired: false, days: 93, hours: 7, minutes: 44, seconds: 55)
}

#Preview("Small – Nostalgia", as: .systemSmall) {
    CountdownSmallWidget()
} timeline: {
    CountdownEntry(date: .now, timerName: "Summer 2026", targetDate: Calendar.current.date(from: DateComponents(year:2026,month:6,day:1))!, theme: .nostalgia, allTimers: [], isExpired: false, days: 93, hours: 7, minutes: 44, seconds: 55)
}

#Preview("Large – Night", as: .systemLarge) {
    CountdownLargeWidget()
} timeline: {
    CountdownEntry(date: .now, timerName: "New Year 2027", targetDate: Calendar.current.date(from: DateComponents(year:2027,month:1,day:1))!, theme: .night, allTimers: [], isExpired: false, days: 307, hours: 14, minutes: 22, seconds: 8)
}

#Preview("Large – Nostalgia", as: .systemLarge) {
    CountdownLargeWidget()
} timeline: {
    CountdownEntry(date: .now, timerName: "New Year 2027", targetDate: Calendar.current.date(from: DateComponents(year:2027,month:1,day:1))!, theme: .nostalgia, allTimers: [], isExpired: false, days: 307, hours: 14, minutes: 22, seconds: 8)
}
