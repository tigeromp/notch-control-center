import AppKit
import EventKit
import Foundation

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let joinURL: URL?

    var timeLabel: String {
        if isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var isHappeningNow: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    func minutesUntilStart(from date: Date = Date()) -> Int {
        max(0, Int(startDate.timeIntervalSince(date) / 60))
    }

    func countdownLabel(from date: Date = Date()) -> String {
        if isHappeningNow { return "Happening now" }
        let minutes = minutesUntilStart(from: date)
        if minutes == 0 { return "Starting soon" }
        if minutes < 60 { return "In \(minutes)m" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "In \(hours)h" : "In \(hours)h \(rem)m"
    }
}

final class CalendarController: ObservableObject {
    @Published var events: [CalendarEventItem] = []
    @Published var nextMeeting: CalendarEventItem?
    @Published var statusMessage = "Loading calendar…"

    private let store = EKEventStore()
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?

    func startMonitoring() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
        if let countdownTimer {
            RunLoop.main.add(countdownTimer, forMode: .common)
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        countdownTimer?.invalidate()
        refreshTimer = nil
        countdownTimer = nil
    }

    func refresh() {
        requestAccess { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.events = []
                    self.nextMeeting = nil
                    self.statusMessage = "Allow Calendar access in System Settings"
                }
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let fetched = self.fetchUpcomingEvents()
                DispatchQueue.main.async {
                    self.events = fetched
                    self.nextMeeting = fetched.first
                    self.statusMessage = fetched.isEmpty ? "No upcoming events today" : ""
                }
            }
        }
    }

    func joinNextMeeting() {
        guard let url = nextMeeting?.joinURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                completion(granted)
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                completion(granted)
            }
        }
    }

    private func fetchUpcomingEvents() -> [CalendarEventItem] {
        let calendar = Calendar.current
        let start = Date()
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = store.events(matching: predicate)
            .filter { !$0.isAllDay || calendar.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }

        return ekEvents.prefix(4).map { event in
            CalendarEventItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title.isEmpty ? "Untitled Event" : event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                joinURL: Self.resolveJoinURL(event: event)
            )
        }
    }

    private static func resolveJoinURL(event: EKEvent) -> URL? {
        if let url = event.url { return url }

        let candidates = [event.location, event.notes].compactMap { $0 }
        for text in candidates {
            if let url = firstURL(in: text) { return url }
        }
        return nil
    }

    private static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let match = detector?.firstMatch(in: text, options: [], range: range)
        return match?.url
    }
}
