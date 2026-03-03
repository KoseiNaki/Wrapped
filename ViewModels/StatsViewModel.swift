// File: ViewModels/StatsViewModel.swift
import Foundation
import Combine
import SwiftUI

enum ChartViewMode: String, CaseIterable {
    case days = "Day"
    case weeks = "Week"
    case months = "Month"
    case years = "Year"
}

enum StatsPeriod: String, CaseIterable {
    case day = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All Time"

    var apiValue: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        case .all: return "all"
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let dayOfWeek: String
    let dateLabel: String
    let minutes: Double
    let trackCount: Int
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var recentTracks: [HistoryItemResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: StatsPeriod = .all
    @Published var selectedPeriodOffset: Int = 0
    @Published var chartViewMode: ChartViewMode = .weeks
    @Published var periodOffset: Int = 0

    private var currentJWT: String?

    @AppStorage("weekStartsOnSunday") var weekStartsOnSunday: Bool = true

    // Daily goal in minutes (2 hours default)
    let dailyGoalMinutes: Double = 120

    private let apiClient = APIClient.shared

    // Chart bar color
    static let barColor = Color(red: 0.0, green: 0.48, blue: 1.0) // Blue

    var currentPeriodLabel: String {
        let calendar = Calendar.current
        let today = Date()

        switch chartViewMode {
        case .days:
            let date = calendar.date(byAdding: .day, value: periodOffset, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)

        case .weeks:
            let weekStart = getWeekStart(for: today, weeksAgo: -periodOffset)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"

        case .months:
            let date = calendar.date(byAdding: .month, value: periodOffset, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)

        case .years:
            let date = calendar.date(byAdding: .year, value: periodOffset, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        }
    }

    var selectedPeriodLabel: String {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day:
            let date = calendar.date(byAdding: .day, value: selectedPeriodOffset, to: today) ?? today
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)

        case .week:
            var cal = calendar
            cal.firstWeekday = weekStartsOnSunday ? 1 : 2
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
            let targetWeekStart = cal.date(byAdding: .weekOfYear, value: selectedPeriodOffset, to: weekStart) ?? weekStart
            let weekEnd = cal.date(byAdding: .day, value: 6, to: targetWeekStart) ?? targetWeekStart
            formatter.dateFormat = "MMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: targetWeekStart)) - \(endFormatter.string(from: weekEnd))"

        case .month:
            let date = calendar.date(byAdding: .month, value: selectedPeriodOffset, to: today) ?? today
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)

        case .year:
            let date = calendar.date(byAdding: .year, value: selectedPeriodOffset, to: today) ?? today
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)

        case .all:
            return "All Time"
        }
    }

    var canGoToPreviousSelectedPeriod: Bool {
        // Allow going back for non-all periods
        selectedPeriod != .all
    }

    var canGoToNextSelectedPeriod: Bool {
        // Only allow going forward if we're in the past
        selectedPeriod != .all && selectedPeriodOffset < 0
    }

    func goToPreviousSelectedPeriod() {
        guard selectedPeriod != .all else { return }
        selectedPeriodOffset -= 1
        Task {
            guard let jwt = currentJWT else { return }
            await loadStats(jwt: jwt)
        }
    }

    func goToNextSelectedPeriod() {
        guard selectedPeriod != .all, selectedPeriodOffset < 0 else { return }
        selectedPeriodOffset += 1
        Task {
            guard let jwt = currentJWT else { return }
            await loadStats(jwt: jwt)
        }
    }

    func loadStats(jwt: String) async {
        currentJWT = jwt
        isLoading = true
        errorMessage = nil

        do {
            // Load stats and recent history in parallel
            async let fetchedStats = apiClient.getStats(jwt: jwt, period: selectedPeriod.apiValue, offset: selectedPeriodOffset)
            async let fetchedHistory = apiClient.getHistory(jwt: jwt, limit: 4, offset: 0)

            stats = try await fetchedStats
            recentTracks = try await fetchedHistory.items
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to load stats: \(error)")
        }

        isLoading = false
    }

    func refreshStats(jwt: String) async {
        await loadStats(jwt: jwt)
    }

    func changePeriod(to period: StatsPeriod) async {
        guard let jwt = currentJWT else { return }
        selectedPeriod = period
        selectedPeriodOffset = 0  // Reset offset when changing period type
        await loadStats(jwt: jwt)
    }

    func goToPreviousPeriod() {
        periodOffset -= 1
    }

    func goToNextPeriod() {
        if periodOffset < 0 {
            periodOffset += 1
        }
    }

    var canGoNext: Bool {
        periodOffset < 0
    }

    func navigateToWeek(containing date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)

        // Get start of current week
        let currentWeekStart = getWeekStart(for: today, weeksAgo: 0)
        let targetWeekStart = getWeekStart(for: targetDay, weeksAgo: 0)

        // Calculate the number of days between week starts
        let components = calendar.dateComponents([.day], from: currentWeekStart, to: targetWeekStart)
        let daysDiff = components.day ?? 0
        let weeksDiff = daysDiff / 7

        // Set the offset (negative means past)
        chartViewMode = .weeks
        periodOffset = weeksDiff
    }

    private func getWeekStart(for date: Date, weeksAgo: Int) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnSunday ? 1 : 2

        // Get the weekday of the given date (1 = Sunday, 2 = Monday, etc.)
        let weekday = calendar.component(.weekday, from: date)

        // Calculate days to subtract to get to start of week
        let daysToSubtract: Int
        if weekStartsOnSunday {
            daysToSubtract = weekday - 1
        } else {
            daysToSubtract = (weekday + 5) % 7
        }

        var weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date

        if weeksAgo != 0 {
            weekStart = calendar.date(byAdding: .day, value: -weeksAgo * 7, to: weekStart) ?? weekStart
        }

        return calendar.startOfDay(for: weekStart)
    }

    func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    func formatMinutesCompact(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString)
    }

    private func startOfMonth(for date: Date, offset: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: date)

        if offset != 0 {
            if let newDate = calendar.date(from: components),
               let offsetDate = calendar.date(byAdding: .month, value: offset, to: newDate) {
                components = calendar.dateComponents([.year, .month], from: offsetDate)
            }
        }

        return calendar.date(from: components) ?? date
    }

    func getChartData() -> [ChartDataPoint] {
        return getChartData(mode: chartViewMode, offset: periodOffset)
    }

    func getChartData(mode: ChartViewMode, offset: Int) -> [ChartDataPoint] {
        guard let stats = stats else { return [] }

        let calendar = Calendar.current
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        var statsLookup: [String: DailyStatResponse] = [:]
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        for stat in stats.dailyStats {
            statsLookup[stat.date] = stat
        }

        switch mode {
        case .days:
            let targetDate = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let dateKey = isoFormatter.string(from: targetDate)
            let stat = statsLookup[dateKey]

            return [ChartDataPoint(
                date: targetDate,
                dayOfWeek: dayFormatter.string(from: targetDate),
                dateLabel: dateFormatter.string(from: targetDate),
                minutes: stat?.minutes ?? 0,
                trackCount: stat?.trackCount ?? 0
            )]

        case .weeks:
            let weekStart = getWeekStart(for: today, weeksAgo: -offset)
            var data: [ChartDataPoint] = []

            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let dateKey = isoFormatter.string(from: date)
                let stat = statsLookup[dateKey]

                data.append(ChartDataPoint(
                    date: date,
                    dayOfWeek: dayFormatter.string(from: date),
                    dateLabel: dateFormatter.string(from: date),
                    minutes: stat?.minutes ?? 0,
                    trackCount: stat?.trackCount ?? 0
                ))
            }

            return data

        case .months:
            let monthStart = startOfMonth(for: today, offset: offset)
            guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

            var data: [ChartDataPoint] = []

            for day in range {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
                let dateKey = isoFormatter.string(from: date)
                let stat = statsLookup[dateKey]

                data.append(ChartDataPoint(
                    date: date,
                    dayOfWeek: dayFormatter.string(from: date),
                    dateLabel: dateFormatter.string(from: date),
                    minutes: stat?.minutes ?? 0,
                    trackCount: stat?.trackCount ?? 0
                ))
            }

            return data

        case .years:
            let yearStart: Date
            var components = calendar.dateComponents([.year], from: today)
            if offset != 0 {
                components.year = (components.year ?? 2025) + offset
            }
            components.month = 1
            components.day = 1
            yearStart = calendar.date(from: components) ?? today

            // Aggregate by month for year view
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            var data: [ChartDataPoint] = []

            for month in 0..<12 {
                guard let monthDate = calendar.date(byAdding: .month, value: month, to: yearStart) else { continue }
                guard let monthRange = calendar.range(of: .day, in: .month, for: monthDate) else { continue }

                var monthMinutes: Double = 0
                var monthTracks: Int = 0

                for day in monthRange {
                    guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthDate) else { continue }
                    let dateKey = isoFormatter.string(from: date)
                    if let stat = statsLookup[dateKey] {
                        monthMinutes += stat.minutes
                        monthTracks += stat.trackCount
                    }
                }

                data.append(ChartDataPoint(
                    date: monthDate,
                    dayOfWeek: monthFormatter.string(from: monthDate),
                    dateLabel: monthFormatter.string(from: monthDate),
                    minutes: monthMinutes,
                    trackCount: monthTracks
                ))
            }

            return data
        }
    }

    // Histogram data driven by selectedPeriod + selectedPeriodOffset
    func getHistogramData() -> [ChartDataPoint] {
        guard let stats = stats else { return [] }

        let calendar = Calendar.current
        let today = Date()
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"

        var statsLookup: [String: DailyStatResponse] = [:]
        for stat in stats.dailyStats {
            statsLookup[stat.date] = stat
        }

        switch selectedPeriod {
        case .day:
            return []

        case .week:
            var cal = calendar
            cal.firstWeekday = weekStartsOnSunday ? 1 : 2
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
            let targetWeekStart = cal.date(byAdding: .weekOfYear, value: selectedPeriodOffset, to: weekStart) ?? weekStart

            var data: [ChartDataPoint] = []
            for dayOffset in 0..<7 {
                guard let date = cal.date(byAdding: .day, value: dayOffset, to: targetWeekStart) else { continue }
                let dateKey = isoFormatter.string(from: date)
                let stat = statsLookup[dateKey]
                data.append(ChartDataPoint(
                    date: date,
                    dayOfWeek: dayFormatter.string(from: date),
                    dateLabel: dateFormatter.string(from: date),
                    minutes: stat?.minutes ?? 0,
                    trackCount: stat?.trackCount ?? 0
                ))
            }
            return data

        case .month:
            let targetMonth = calendar.date(byAdding: .month, value: selectedPeriodOffset, to: today) ?? today
            let components = calendar.dateComponents([.year, .month], from: targetMonth)
            let monthStart = calendar.date(from: components)!
            guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

            let rangeFmt = DateFormatter()
            rangeFmt.dateFormat = "M/d"

            var weekData: [ChartDataPoint] = []
            var weekMinutes: Double = 0
            var weekTracks: Int = 0
            var weekStartDate = monthStart

            for day in range {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
                let dateKey = isoFormatter.string(from: date)
                if let stat = statsLookup[dateKey] {
                    weekMinutes += stat.minutes
                    weekTracks += stat.trackCount
                }

                if day % 7 == 0 || day == range.upperBound - 1 {
                    let label = "\(rangeFmt.string(from: weekStartDate))-\(rangeFmt.string(from: date))"
                    weekData.append(ChartDataPoint(
                        date: weekStartDate,
                        dayOfWeek: label,
                        dateLabel: label,
                        minutes: weekMinutes,
                        trackCount: weekTracks
                    ))
                    weekMinutes = 0
                    weekTracks = 0
                    if let nextDate = calendar.date(byAdding: .day, value: 1, to: date) {
                        weekStartDate = nextDate
                    }
                }
            }
            return weekData

        case .year:
            var yearComponents = calendar.dateComponents([.year], from: today)
            yearComponents.year = (yearComponents.year ?? 2025) + selectedPeriodOffset
            yearComponents.month = 1
            yearComponents.day = 1
            let yearStart = calendar.date(from: yearComponents) ?? today

            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            var data: [ChartDataPoint] = []

            for month in 0..<12 {
                guard let monthDate = calendar.date(byAdding: .month, value: month, to: yearStart) else { continue }
                guard let monthRange = calendar.range(of: .day, in: .month, for: monthDate) else { continue }

                var monthMinutes: Double = 0
                var monthTracks: Int = 0

                for day in monthRange {
                    guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthDate) else { continue }
                    let dateKey = isoFormatter.string(from: date)
                    if let stat = statsLookup[dateKey] {
                        monthMinutes += stat.minutes
                        monthTracks += stat.trackCount
                    }
                }

                data.append(ChartDataPoint(
                    date: monthDate,
                    dayOfWeek: monthFormatter.string(from: monthDate),
                    dateLabel: monthFormatter.string(from: monthDate),
                    minutes: monthMinutes,
                    trackCount: monthTracks
                ))
            }
            return data

        case .all:
            let years = Set(stats.dailyStats.compactMap { stat -> Int? in
                guard let date = parseDate(stat.date) else { return nil }
                return calendar.component(.year, from: date)
            }).sorted()

            guard !years.isEmpty else { return [] }

            var data: [ChartDataPoint] = []
            for year in years {
                var yearMinutes: Double = 0
                var yearTracks: Int = 0

                for stat in stats.dailyStats {
                    guard let date = parseDate(stat.date) else { continue }
                    if calendar.component(.year, from: date) == year {
                        yearMinutes += stat.minutes
                        yearTracks += stat.trackCount
                    }
                }

                var comps = DateComponents()
                comps.year = year
                comps.month = 1
                comps.day = 1
                let yearDate = calendar.date(from: comps) ?? Date()

                data.append(ChartDataPoint(
                    date: yearDate,
                    dayOfWeek: "\(year)",
                    dateLabel: "\(year)",
                    minutes: yearMinutes,
                    trackCount: yearTracks
                ))
            }
            return data
        }
    }

    var daysInPeriod: Int {
        let calendar = Calendar.current
        let today = Date()

        switch selectedPeriod {
        case .day: return 1
        case .week: return 7
        case .month:
            let date = calendar.date(byAdding: .month, value: selectedPeriodOffset, to: today) ?? today
            return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        case .year:
            let date = calendar.date(byAdding: .year, value: selectedPeriodOffset, to: today) ?? today
            return calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        case .all:
            guard let stats = stats, !stats.dailyStats.isEmpty else { return 1 }
            let dates = stats.dailyStats.compactMap { parseDate($0.date) }
            guard let earliest = dates.min(), let latest = dates.max() else { return 1 }
            return max((calendar.dateComponents([.day], from: earliest, to: latest).day ?? 0) + 1, 1)
        }
    }

    func colorForValue(_ value: Double, max: Double) -> Color {
        guard max > 0 && value > 0 else {
            return Color(red: 0.9, green: 0.96, blue: 0.9)
        }

        let ratio = min(value / max, 1.0)
        let r = 0.78 - (ratio * 0.66)
        let g = 0.94 - (ratio * 0.43)
        let b = 0.78 - (ratio * 0.58)

        return Color(red: r, green: g, blue: b)
    }
}
