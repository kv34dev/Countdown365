import SwiftUI
import Combine

// MARK: - Theme
enum AppTheme: String, CaseIterable, Codable {
    case night, light, nostalgia

    var displayName: String {
        switch self {
        case .night:     return "Night"
        case .light:     return "Warm Light"
        case .nostalgia: return "Nostalgia"
        }
    }
    var icon: String {
        switch self {
        case .night:     return "moon.stars.fill"
        case .light:     return "sun.max.fill"
        case .nostalgia: return "sparkles"
        }
    }
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
    var cardBg: Color {
        switch self {
        case .light: return Color(hex: "D4A97A").opacity(0.25)
        default:     return Color.white.opacity(0.07)
        }
    }
    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        default:     return .dark
        }
    }
}

// MARK: - Model
struct CountdownTimer: Identifiable, Codable {
    var id = UUID()
    var name: String
    var targetDate: Date

    func timeRemaining(from now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = max(0, targetDate.timeIntervalSince(now))
        let total = Int(diff)
        return (total / 86400, (total % 86400) / 3600, (total % 3600) / 60, total % 60)
    }

    func isExpired(from now: Date) -> Bool { targetDate <= now }
}

// MARK: - Store
class CountdownStore: ObservableObject {
    @Published var timers: [CountdownTimer] = [] {
        didSet { saveTimers() }
    }
    @Published var selectedTimerID: UUID? {
        didSet { saveSelectedID() }
    }
    @Published var theme: AppTheme = .night {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }

    var selectedTimer: CountdownTimer? {
        if let id = selectedTimerID, let found = timers.first(where: { $0.id == id }) {
            return found
        }
        return timers.first
    }

    init() {
        load()
        if timers.isEmpty {
            timers = [
                CountdownTimer(name: "New Year 2027", targetDate: Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1))!),
                CountdownTimer(name: "Summer 2026",  targetDate: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
            ]
        }
    }

    func saveTimers() {
        if let data = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(data, forKey: "timers")
        }
    }
    func saveSelectedID() {
        if let id = selectedTimerID {
            UserDefaults.standard.set(id.uuidString, forKey: "selectedID")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedID")
        }
    }
    func load() {
        if let data = UserDefaults.standard.data(forKey: "timers"),
           let decoded = try? JSONDecoder().decode([CountdownTimer].self, from: data) {
            timers = decoded
        }
        if let idStr = UserDefaults.standard.string(forKey: "selectedID"),
           let id = UUID(uuidString: idStr) {
            selectedTimerID = id
        }
        if let raw = UserDefaults.standard.string(forKey: "appTheme"),
           let t = AppTheme(rawValue: raw) {
            theme = t
        }
    }

    func addTimer(_ timer: CountdownTimer) { timers.append(timer) }
    func deleteTimer(at offsets: IndexSet) { timers.remove(atOffsets: offsets) }
    func updateTimer(_ timer: CountdownTimer) {
        if let idx = timers.firstIndex(where: { $0.id == timer.id }) {
            timers[idx] = timer
        }
    }
}

// MARK: - Root
struct ContentView: View {
    @StateObject var store = CountdownStore()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Timer", systemImage: "timer") }
            TimersListView()
                .tabItem { Label("List", systemImage: "list.bullet") }
            ThemeView()
                .tabItem { Label("Theme", systemImage: "paintpalette.fill") }
        }
        .environmentObject(store)
        .preferredColorScheme(store.theme.colorScheme)
        .accentColor(store.theme.accent)
    }
}

// MARK: - Starfield
// Seeded RNG so star positions are always identical — never re-randomised on re-render.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let t = Double(nextUInt64()) / Double(UInt64.max)
        return range.lowerBound + t * (range.upperBound - range.lowerBound)
    }
}

struct StarData: Identifiable {
    let id: Int
    let x, y, size: CGFloat
    let opacity, speed, delay: Double
}

// Generated once at app launch — positions are fixed forever.
private let fixedStars: [StarData] = {
    var rng = SeededRandom(seed: 42)
    return (0..<200).map { i in
        StarData(
            id: i,
            x: CGFloat(rng.next(in: 0...1)),
            y: CGFloat(rng.next(in: 0...1)),
            size: CGFloat(rng.next(in: 0.8...3.2)),
            opacity: rng.next(in: 0.3...1.0),
            speed: rng.next(in: 1.8...4.5),
            delay: rng.next(in: 0...3)
        )
    }
}()

struct StarfieldView: View {
    @State private var blink = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "020818"), Color(hex: "050D2E"), Color(hex: "071025")],
                    startPoint: .top, endPoint: .bottom
                )
                ForEach(fixedStars) { s in
                    Circle()
                        .fill(Color.white)
                        .frame(width: s.size, height: s.size)
                        .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                        .opacity(blink ? s.opacity : s.opacity * 0.28)
                        .animation(
                            .easeInOut(duration: s.speed)
                                .repeatForever(autoreverses: true)
                                .delay(s.delay),
                            value: blink
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Fire once — the repeatForever keeps them blinking without any external trigger.
            withAnimation { blink = true }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var store: CountdownStore
    // Real-time clock — updates every second and triggers view refresh
    @State private var now = Date()
    @State private var showPicker = false

    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var t: AppTheme { store.theme }

    var body: some View {
        ZStack {
            background
            if let sel = store.selectedTimer {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    // Event title
                    Text(sel.name)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(t.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .shadow(color: t.accent.opacity(0.6), radius: 16)

                    Text(sel.targetDate.formatted(date: .long, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundColor(t.secondaryText)
                        .padding(.top, 8)

                    Spacer()

                    // Countdown
                    if sel.isExpired(from: now) {
                        Text("Already here!")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(t.accent)
                    } else {
                        let r = sel.timeRemaining(from: now)
                        // 2×2 grid — equal-width columns, centred, no wrapping on 3-digit days
                        VStack(spacing: 12) {
                            HStack(spacing: 0) {
                                CountUnit(value: r.days,  label: "days",    theme: t)
                                CountUnit(value: r.hours, label: "hours",   theme: t)
                            }
                            HStack(spacing: 0) {
                                CountUnit(value: r.minutes, label: "minutes", theme: t)
                                CountUnit(value: r.seconds, label: "seconds", theme: t)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    Button(action: { showPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Switch Timer")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(LinearGradient(colors: t.accentGradient, startPoint: .leading, endPoint: .trailing)))
                        .shadow(color: t.accent.opacity(0.4), radius: 14)
                    }
                    .padding(.bottom, 48)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "timer").font(.system(size: 60)).foregroundColor(t.primaryText.opacity(0.2))
                    Text("No Timers").font(.title2).foregroundColor(t.primaryText.opacity(0.5))
                    Text("Add a timer in the List tab").foregroundColor(t.secondaryText)
                }
            }
        }
        // Every second update `now` — this rebuilds the view with fresh values
        .onReceive(ticker) { _ in now = Date() }
        .sheet(isPresented: $showPicker) { TimerPickerSheet().environmentObject(store) }
    }

    @ViewBuilder var background: some View {
        if t == .nostalgia { StarfieldView() }
        else {
            LinearGradient(colors: t.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Count Unit (clean, no box)
// The number text never wraps — font size steps down for 3-digit values.
// Each cell takes equal width inside the row so everything stays centred.
struct CountUnit: View {
    let value: Int
    let label: String
    let theme: AppTheme

    private var digitsText: String {
        // Always at least 2 digits; show raw number for 3+ digits
        value >= 100 ? "\(value)" : String(format: "%02d", value)
    }

    // Shrink font a little when we have 3 digits so it fits on one line
    private var fontSize: CGFloat { value >= 100 ? 60 : 72 }

    var body: some View {
        VStack(spacing: 4) {
            Text(digitsText)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)   // safety net — won't normally fire
                .fixedSize(horizontal: true, vertical: false)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .kerning(0.5)
        }
        // Equal width for every cell so both columns are perfectly aligned
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Timer Picker Sheet
struct TimerPickerSheet: View {
    @EnvironmentObject var store: CountdownStore
    @Environment(\.dismiss) var dismiss
    var t: AppTheme { store.theme }

    var body: some View {
        NavigationView {
            ZStack {
                if t == .nostalgia { StarfieldView() }
                else { LinearGradient(colors: t.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }

                List {
                    ForEach(store.timers) { timer in
                        Button(action: { store.selectedTimerID = timer.id; dismiss() }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(timer.name).font(.system(size: 17, weight: .semibold)).foregroundColor(t.primaryText)
                                    Text(timer.targetDate.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13)).foregroundColor(t.secondaryText)
                                }
                                Spacer()
                                if store.selectedTimer?.id == timer.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(t.accent).font(.system(size: 22))
                                }
                            }.padding(.vertical, 4)
                        }
                        .listRowBackground(t.cardBg)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(t.accent)
                }
            }
        }
        .colorScheme(t.colorScheme)
    }
}

// MARK: - Timers List View
struct TimersListView: View {
    @EnvironmentObject var store: CountdownStore
    @State private var showAdd = false
    @State private var timerToEdit: CountdownTimer? = nil
    var t: AppTheme { store.theme }

    var body: some View {
        NavigationView {
            ZStack {
                if t == .nostalgia { StarfieldView() }
                else { LinearGradient(colors: t.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }

                if store.timers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 60)).foregroundColor(t.accent.opacity(0.5))
                        Text("No Timers").font(.title3).foregroundColor(t.primaryText.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(store.timers) { timer in
                            TimerRow(timer: timer, theme: t, onEdit: { timerToEdit = timer })
                                .listRowBackground(t.cardBg)
                                .listRowSeparatorTint(t.primaryText.opacity(0.1))
                        }
                        .onDelete(perform: store.deleteTimer)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Timers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(t.accent)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTimerView(existingTimer: nil).environmentObject(store)
            }
            .sheet(item: $timerToEdit) { timer in
                AddTimerView(existingTimer: timer).environmentObject(store)
            }
        }
    }
}

// MARK: - Timer Row
struct TimerRow: View {
    let timer: CountdownTimer
    let theme: AppTheme
    // Callback so the row itself can trigger the edit sheet
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: timer.isExpired(from: Date()) ? "checkmark" : "timer")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name).font(.system(size: 17, weight: .semibold)).foregroundColor(theme.primaryText)
                if timer.isExpired(from: Date()) {
                    Text("Already here!").font(.system(size: 13)).foregroundColor(theme.accent)
                } else {
                    let r = timer.timeRemaining(from: Date())
                    Text("\(r.days)d \(r.hours)h \(r.minutes)m \(r.seconds)s")
                        .font(.system(size: 13)).foregroundColor(theme.secondaryText)
                }
                Text(timer.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11)).foregroundColor(theme.secondaryText.opacity(0.6))
            }
            Spacer()
            // Edit button always visible on the right
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(theme.accent.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add / Edit Timer View
struct AddTimerView: View {
    @EnvironmentObject var store: CountdownStore
    @Environment(\.dismiss) var dismiss

    // Pass nil to create, pass a timer to edit
    let existingTimer: CountdownTimer?

    @State private var name: String
    @State private var targetDate: Date

    init(existingTimer: CountdownTimer?) {
        self.existingTimer = existingTimer
        _name = State(initialValue: existingTimer?.name ?? "")
        _targetDate = State(initialValue: existingTimer?.targetDate ?? Date().addingTimeInterval(86400 * 30))
    }

    var isEditing: Bool { existingTimer != nil }
    var t: AppTheme { store.theme }

    var body: some View {
        NavigationView {
            ZStack {
                if t == .nostalgia { StarfieldView() }
                else { LinearGradient(colors: t.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVENT NAME")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(t.secondaryText).kerning(1)
                        TextField("e.g. Birthday, Vacation...", text: $name)
                            .font(.system(size: 17)).foregroundColor(t.primaryText)
                            .padding(16).background(t.cardBg).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.accent.opacity(0.2)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVENT DATE")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(t.secondaryText).kerning(1)
                        DatePicker("", selection: $targetDate, displayedComponents: .date)
                            .datePickerStyle(.graphical).accentColor(t.accent)
                            .padding(12).background(t.cardBg).cornerRadius(16)
                    }

                    Spacer()

                    Button(action: save) {
                        Text(isEditing ? "Save Changes" : "Add Timer")
                            .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: t.accentGradient, startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(16)
                            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }
            .navigationTitle(isEditing ? "Edit Timer" : "New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(t.secondaryText)
                }
            }
        }
        .colorScheme(t.colorScheme)
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if isEditing, var updated = existingTimer {
            updated.name = trimmed
            updated.targetDate = targetDate
            store.updateTimer(updated)
        } else {
            store.addTimer(CountdownTimer(name: trimmed, targetDate: targetDate))
        }
        dismiss()
    }
}

// MARK: - Theme View
struct ThemeView: View {
    @EnvironmentObject var store: CountdownStore
    var t: AppTheme { store.theme }

    var body: some View {
        NavigationView {
            ZStack {
                if t == .nostalgia { StarfieldView() }
                else { LinearGradient(colors: t.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }

                ScrollView {
                    VStack(spacing: 16) {
                        Text("Choose your vibe")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(t.secondaryText)
                            .padding(.top, 8)

                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeCard(theme: theme, isSelected: store.theme == theme) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    store.theme = theme
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
            .navigationTitle("Theme").navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // BG preview
                ZStack {
                    if theme == .nostalgia {
                        LinearGradient(colors: [Color(hex: "020818"), Color(hex: "050D2E")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        ForEach(0..<50, id: \.self) { i in
                            let px = CGFloat((i * 41 + 11) % 100) / 100.0
                            let py = CGFloat((i * 67 + 19) % 100) / 100.0
                            Circle().fill(Color.white.opacity(0.7))
                                .frame(width: i % 4 == 0 ? 2 : 1, height: i % 4 == 0 ? 2 : 1)
                                .position(x: px * 360, y: py * 140)
                        }
                    } else {
                        LinearGradient(colors: theme.bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Mini 2x2 digit preview
                VStack(spacing: 2) {
                    HStack(spacing: 16) {
                        MiniDigit(num: "24", lbl: "days", theme: theme)
                        MiniDigit(num: "07", lbl: "hours", theme: theme)
                    }
                    HStack(spacing: 16) {
                        MiniDigit(num: "30", lbl: "min", theme: theme)
                        MiniDigit(num: "12", lbl: "sec", theme: theme)
                    }
                }
                .padding(.leading, 18).padding(.bottom, 10)

                // Badge
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: theme.icon)
                            Text(theme.displayName).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(theme.primaryText.opacity(0.9))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(theme.accent.opacity(0.3))
                        .clipShape(Capsule())
                        .padding(12)
                    }
                    Spacer()
                }
            }
            .frame(height: 140)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? theme.accent : Color.clear, lineWidth: 3))
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26)).foregroundColor(theme.accent).padding(14)
                }
            }
            .shadow(color: isSelected ? theme.accent.opacity(0.4) : Color.black.opacity(0.25), radius: isSelected ? 16 : 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MiniDigit: View {
    let num: String
    let lbl: String
    let theme: AppTheme
    var body: some View {
        VStack(spacing: 0) {
            Text(num).font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(theme.primaryText)
            Text(lbl).font(.system(size: 8, weight: .semibold)).foregroundColor(theme.secondaryText)
        }
        .frame(width: 60)
    }
}

// MARK: - Color Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
