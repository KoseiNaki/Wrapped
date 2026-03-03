// File: ViewModels/HistoryViewModel.swift
import Foundation
import Combine
import SwiftUI

enum GroupingMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

struct GroupedEvents: Identifiable {
    let id: String
    let title: String
    let events: [ListeningEvent]
}

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var events: [ListeningEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var hasMore = true
    @Published var groupingMode: GroupingMode = .day

    // Date search
    @Published var selectedDate: Date = Date()
    @Published var showNoDataMessage = false
    @Published var noDataDateString: String = ""
    @Published var targetScrollDate: String? = nil
    @Published var shouldScrollToTop = false

    private let api = APIClient.shared
    private let appState = AppState.shared

    private var total = 0
    private var currentOffset = 0
    private let pageSize = 50

    private let calendar = Calendar.current

    // MARK: - Date Search

    /// Returns true if data exists for the date, false otherwise
    @discardableResult
    func searchForDate(_ date: Date) -> Bool {
        let searchKey = dayKey(for: date)

        // Format the date for display
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let displayDate = formatter.string(from: date)

        // Check if we have any events for this date
        let hasDataForDate = events.contains { event in
            dayKey(for: event.playedAt) == searchKey
        }

        if hasDataForDate {
            // Set the target to scroll to
            targetScrollDate = searchKey
            showNoDataMessage = false
            return true
        } else {
            // Show no data message
            noDataDateString = displayDate
            showNoDataMessage = true
            targetScrollDate = nil

            // Reset selected date back to today
            selectedDate = Date()

            // Auto-hide message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showNoDataMessage = false
                }
            }
            return false
        }
    }

    func clearScrollTarget() {
        targetScrollDate = nil
    }

    func stopLoading() {
        isLoading = false
    }

    func scrollToTop() {
        shouldScrollToTop = true
    }

    func clearScrollToTop() {
        shouldScrollToTop = false
    }

    // MARK: - Grouped Events

    var groupedEvents: [GroupedEvents] {
        let grouped: [String: [ListeningEvent]]

        switch groupingMode {
        case .day:
            grouped = Dictionary(grouping: events) { event in
                dayKey(for: event.playedAt)
            }
        case .week:
            grouped = Dictionary(grouping: events) { event in
                weekKey(for: event.playedAt)
            }
        case .month:
            grouped = Dictionary(grouping: events) { event in
                monthKey(for: event.playedAt)
            }
        }

        // Sort by date (most recent first)
        return grouped.map { key, events in
            GroupedEvents(
                id: key,
                title: formatGroupTitle(key: key, mode: groupingMode),
                events: events.sorted { $0.playedAt > $1.playedAt }
            )
        }
        .sorted { group1, group2 in
            // Sort groups by the first event's date (most recent first)
            guard let date1 = group1.events.first?.playedAt,
                  let date2 = group2.events.first?.playedAt else {
                return false
            }
            return date1 > date2
        }
    }

    // MARK: - Date Grouping Keys

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func weekKey(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
    }

    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: - Format Group Titles

    private func formatGroupTitle(key: String, mode: GroupingMode) -> String {
        let formatter = DateFormatter()

        switch mode {
        case .day:
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: key) else { return key }

            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                formatter.dateFormat = "EEEE, MMM d"
                return formatter.string(from: date)
            }

        case .week:
            // Parse "2026-W8" format
            let parts = key.components(separatedBy: "-W")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let week = Int(parts[1]) else { return key }

            var components = DateComponents()
            components.yearForWeekOfYear = year
            components.weekOfYear = week
            components.weekday = 1 // Sunday

            guard let startOfWeek = calendar.date(from: components) else { return key }

            let now = Date()
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))

            if let currentStart = currentWeekStart,
               calendar.isDate(startOfWeek, equalTo: currentStart, toGranularity: .weekOfYear) {
                return "This Week"
            }

            if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart ?? now),
               calendar.isDate(startOfWeek, equalTo: lastWeekStart, toGranularity: .weekOfYear) {
                return "Last Week"
            }

            formatter.dateFormat = "MMM d"
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"

        case .month:
            formatter.dateFormat = "yyyy-MM"
            guard let date = formatter.date(from: key) else { return key }

            let now = Date()
            if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                return "This Month"
            }

            if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
               calendar.isDate(date, equalTo: lastMonth, toGranularity: .month) {
                return "Last Month"
            }

            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Load History

    func loadHistory(reset: Bool = false) async {
        guard !isLoading else { return }

        // For reset, we'll clear AFTER successful fetch to avoid losing data on error
        let isResetting = reset
        if isResetting {
            currentOffset = 0
            hasMore = true
        }

        guard hasMore else { return }

        isLoading = true
        errorMessage = nil
        showError = false

        do {
            let history = try await appState.performAuthenticatedRequest { jwt in
                try await self.api.getHistory(jwt: jwt, limit: self.pageSize, offset: self.currentOffset)
            }

            let newEvents = history.items.map { ListeningEvent(from: $0) }

            // Only clear old events after successful fetch
            if isResetting {
                events = newEvents
            } else {
                events.append(contentsOf: newEvents)
            }

            total = history.total
            currentOffset += newEvents.count
            hasMore = currentOffset < total

            print("Loaded \(newEvents.count) events, total: \(events.count)/\(total)")

        } catch {
            print("Failed to load history: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            // Don't clear events on error - keep showing old data
        }

        isLoading = false
    }

    func loadNextPageIfNeeded(currentItem: ListeningEvent) async {
        // Start loading next page when user reaches 10 items from the end
        let thresholdIndex = events.index(events.endIndex, offsetBy: -10)
        if let currentIndex = events.firstIndex(where: { $0.id == currentItem.id }),
           currentIndex >= thresholdIndex {
            await loadHistory()
        }
    }
}
