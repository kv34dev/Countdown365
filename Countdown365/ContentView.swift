import SwiftUI
import Combine

// MARK: - Model
struct CountdownTimer: Identifiable, Codable {
    var id = UUID()
    var name: String
    var targetDate: Date
    
    var timeRemaining: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = max(0, targetDate.timeIntervalSinceNow)
        let totalSeconds = Int(diff)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return (days, hours, minutes, seconds)
    }
    
    var isExpired: Bool {
        targetDate <= Date()
    }
}

// MARK: - ViewModel
class CountdownStore: ObservableObject {
    @Published var timers: [CountdownTimer] = [] {
        didSet { save() }
    }
    @Published var selectedTimerID: UUID?
    
    var selectedTimer: CountdownTimer? {
        timers.first { $0.id == selectedTimerID }
    }
    
    init() {
        load()
        if timers.isEmpty {
            // Demo timers
            timers = [
                CountdownTimer(name: "New Year 2027", targetDate: Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1))!),
                CountdownTimer(name: "Summer", targetDate: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1))!)
            ]
            selectedTimerID = timers.first?.id
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(data, forKey: "timers")
        }
        if let id = selectedTimerID {
            UserDefaults.standard.set(id.uuidString, forKey: "selectedID")
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "timers"),
           let decoded = try? JSONDecoder().decode([CountdownTimer].self, from: data) {
            timers = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: "selectedID"),
           let id = UUID(uuidString: idString) {
            selectedTimerID = id
        }
    }
    
    func addTimer(_ timer: CountdownTimer) {
        timers.append(timer)
    }
    
    func deleteTimer(at offsets: IndexSet) {
        timers.remove(atOffsets: offsets)
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject var store = CountdownStore()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
            
            TimersListView()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
        }
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var store: CountdownStore
    @State private var tick = false
    @State private var showPicker = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0D0D1A"), Color(hex: "1A0D2E"), Color(hex: "0D1A2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if let selected = store.selectedTimer {
                VStack(spacing: 0) {
                    // Title
                    Text(selected.name)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .shadow(color: Color(hex: "A855F7").opacity(0.8), radius: 20)
                    
                    Text("days until event")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.top, 6)
                    
                    Spacer()
                    
                    // Countdown digits
                    if selected.isExpired {
                        Text("🎉 Already here!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "A855F7"))
                    } else {
                        let t = selected.timeRemaining
                        HStack(spacing: 12) {
                            TimeUnit(value: t.days, label: "DAYS")
                            Separator()
                            TimeUnit(value: t.hours, label: "HRS")
                            Separator()
                            TimeUnit(value: t.minutes, label: "MIN")
                            Separator()
                            TimeUnit(value: t.seconds, label: "SEC")
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Target date
                    Text(selected.targetDate.formatted(date: .long, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.top, 28)
                    
                    Spacer()
                    
                    // Change timer button
                    Button(action: { showPicker = true }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Switch Timer")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "A855F7"), Color(hex: "6366F1")], startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: Color(hex: "A855F7").opacity(0.5), radius: 15)
                    }
                    .padding(.bottom, 50)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No Timers")
                        .font(.title2)
                        .foregroundColor(Color.white.opacity(0.5))
                    Text("Add a timer in the List tab")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onReceive(timer) { _ in tick.toggle() }
        .sheet(isPresented: $showPicker) {
            TimerPickerSheet()
                .environmentObject(store)
        }
    }
}

// MARK: - Time Unit
struct TimeUnit: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Text(String(format: "%02d", value))
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(width: 78, height: 90)
            
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.4))
                .kerning(2)
        }
    }
}

struct Separator: View {
    var body: some View {
        Text(":")
            .font(.system(size: 48, weight: .black))
            .foregroundColor(Color(hex: "A855F7").opacity(0.7))
            .padding(.bottom, 20)
    }
}

// MARK: - Timer Picker Sheet
struct TimerPickerSheet: View {
    @EnvironmentObject var store: CountdownStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D0D1A").ignoresSafeArea()
                
                List {
                    ForEach(store.timers) { t in
                        Button(action: {
                            store.selectedTimerID = t.id
                            store.save()
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.name)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(t.targetDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                                Spacer()
                                if store.selectedTimerID == t.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "A855F7"))
                                        .font(.system(size: 22))
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "A855F7"))
                }
            }
        }
    }
}

// MARK: - Timers List View
struct TimersListView: View {
    @EnvironmentObject var store: CountdownStore
    @State private var showAdd = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D0D1A").ignoresSafeArea()
                
                if store.timers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "A855F7").opacity(0.5))
                        Text("No Timers")
                            .font(.title3)
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(store.timers) { t in
                            TimerRow(timer: t)
                                .listRowBackground(Color.white.opacity(0.06))
                                .listRowSeparatorTint(Color.white.opacity(0.1))
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
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "A855F7"))
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTimerView()
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Timer Row
struct TimerRow: View {
    let timer: CountdownTimer
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "A855F7"), Color(hex: "6366F1")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: timer.isExpired ? "checkmark" : "timer")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                if timer.isExpired {
                    Text("Already here!")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "A855F7"))
                } else {
                    let t = timer.timeRemaining
                    Text("\(t.days)d \(t.hours)h \(t.minutes)m")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                
                Text(timer.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.25))
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Add Timer View
struct AddTimerView: View {
    @EnvironmentObject var store: CountdownStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var targetDate = Date().addingTimeInterval(86400 * 30)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D0D1A").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVENT NAME")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .kerning(1)
                        
                        TextField("e.g. Birthday, Vacation...", text: $name)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1)))
                    }
                    
                    // Date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVENT DATE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .kerning(1)
                        
                        DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .accentColor(Color(hex: "A855F7"))
                            .colorScheme(.dark)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                    }
                    
                    Spacer()
                    
                    // Add button
                    Button(action: addTimer) {
                        Text("Add Timer")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(hex: "A855F7"), Color(hex: "6366F1")], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .opacity(name.isEmpty ? 0.4 : 1)
                    }
                    .disabled(name.isEmpty)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
        }
    }
    
    func addTimer() {
        let t = CountdownTimer(name: name.trimmingCharacters(in: .whitespaces), targetDate: targetDate)
        store.addTimer(t)
        if store.selectedTimerID == nil {
            store.selectedTimerID = t.id
        }
        dismiss()
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
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
