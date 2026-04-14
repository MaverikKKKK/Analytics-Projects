import Foundation

extension Date {

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var timeAgoDisplay: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 172800 { return "Yesterday" }
        return formatted(date: .abbreviated, time: .omitted)
    }

    var shortTimeString: String {
        formatted(date: .omitted, time: .shortened)
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    var dateHeaderString: String {
        if isToday { return "Today" }
        if isTomorrow { return "Tomorrow" }
        if isYesterday { return "Yesterday" }
        return formatted(date: .abbreviated, time: .omitted)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self)!
    }

    static func timeSlot(hour: Int) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        let date = calendar.date(from: components)!
        return date.formatted(date: .omitted, time: .shortened)
    }
}

extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let slackTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
