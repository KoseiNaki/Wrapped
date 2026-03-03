// File: Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showBackToTop = false
    @State private var showDatePicker = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with calendar button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.spacing4) {
                        Text("RECENTLY PLAYED")
                            .font(.labelSmall)
                            .foregroundColor(.goldPrimary)

                        Text("History")
                            .font(.displayLarge)
                            .foregroundColor(.emerald900)
                    }

                    Spacer()

                    // Jump to date button
                    Button(action: {
                        Haptic.light()
                        showDatePicker = true
                    }) {
                        HStack(spacing: Spacing.spacing6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .medium))
                            Text("Jump to Date")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.emerald800)
                        .padding(.horizontal, Spacing.spacing12)
                        .padding(.vertical, Spacing.spacing8)
                        .background(Color.emerald50)
                        .cornerRadius(Radius.full)
                    }
                }
                .padding(.horizontal, Spacing.spacing20)
                .padding(.top, Spacing.spacing8)
                .padding(.bottom, Spacing.spacing16)

                // Animated grouping picker
                groupingPicker
                    .padding(.horizontal, Spacing.spacing20)
                    .padding(.bottom, Spacing.spacing16)

                // Grouped List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Color.clear.frame(height: 1).id("top")

                            ForEach(viewModel.groupedEvents) { group in
                                Section {
                                    ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                                        HistoryItemRow(event: event)
                                            .padding(.horizontal, Spacing.spacing20)
                                            .onAppear {
                                                Task {
                                                    await viewModel.loadNextPageIfNeeded(currentItem: event)
                                                }
                                            }

                                        if index < group.events.count - 1 {
                                            Divider()
                                                .padding(.leading, 80)
                                                .padding(.trailing, Spacing.spacing20)
                                        }
                                    }
                                } header: {
                                    HistorySectionHeader(title: group.title, count: group.events.count)
                                        .id(group.id) // Add ID for scrolling
                                        .padding(.horizontal, Spacing.spacing20)
                                        .padding(.vertical, Spacing.spacing8)
                                        .background(.ultraThinMaterial)
                                }
                            }

                            if viewModel.isLoading {
                                VStack(spacing: Spacing.spacing12) {
                                    ForEach(0..<3, id: \.self) { _ in ShimmerRow() }
                                }
                                .padding(.horizontal, Spacing.spacing20)
                                .padding(.vertical, Spacing.spacing8)
                            }

                            if !viewModel.hasMore && !viewModel.events.isEmpty {
                                VStack(spacing: Spacing.spacing8) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.emerald400)
                                    Text("You've reached the end")
                                        .font(.caption)
                                        .foregroundColor(.textTertiary)
                                }
                                .padding(Spacing.spacing24)
                            }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showBackToTop {
                            Button {
                                Haptic.light()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("top", anchor: .top)
                                }
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.goldPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.emerald800)
                                    .clipShape(Circle())
                                    .shadow(color: Color.emerald900.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.trailing, Spacing.spacing20)
                            .padding(.bottom, Spacing.spacing20)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .onReceive(viewModel.$events) { events in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBackToTop = events.count > 20
                        }
                    }
                    .onReceive(viewModel.$targetScrollDate) { targetDate in
                        if let targetDate = targetDate {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(targetDate, anchor: .top)
                            }
                            // Clear the target after scrolling
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                viewModel.clearScrollTarget()
                            }
                        }
                    }
                    .onReceive(viewModel.$shouldScrollToTop) { shouldScroll in
                        if shouldScroll {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("top", anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                viewModel.clearScrollToTop()
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.emerald700)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $showDatePicker, onDismiss: {
            // Reset date when sheet closes
            viewModel.selectedDate = Date()
        }) {
            DatePickerSheet(
                selectedDate: $viewModel.selectedDate,
                onSearch: { date in
                    let hasData = viewModel.searchForDate(date)
                    if hasData {
                        showDatePicker = false
                    }
                    // If no data, sheet stays open and date resets to today
                }
            )
            .onAppear {
                // Reset to today when opening
                viewModel.selectedDate = Date()
            }
        }
        .preferredColorScheme(.light)
        .refreshable {
            await viewModel.loadHistory(reset: true)
        }
        .task {
            if viewModel.events.isEmpty {
                await viewModel.loadHistory()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                // Force stop loading state and scroll to top when dismissing error
                viewModel.stopLoading()
                viewModel.scrollToTop()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .overlay {
            if viewModel.events.isEmpty && !viewModel.isLoading {
                emptyState
            }
        }
        .overlay(alignment: .top) {
            // No data for date message
            if viewModel.showNoDataMessage {
                noDataBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showNoDataMessage)
    }

    // MARK: - No Data Banner
    private var noDataBanner: some View {
        HStack(spacing: Spacing.spacing12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundColor(.goldMuted)

            Text("No listening data for \(viewModel.noDataDateString)")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.spacing16)
        .padding(.vertical, Spacing.spacing12)
        .background(
            RoundedRectangle(cornerRadius: Radius.large)
                .fill(Color.surfaceCard)
                .shadow(color: Color.emerald900.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large)
                .stroke(Color.goldPrimary.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Grouping Picker
    private var groupingPicker: some View {
        HStack(spacing: 0) {
            ForEach(GroupingMode.allCases, id: \.self) { mode in
                Button(action: {
                    Haptic.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.groupingMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.groupingMode == mode ? .emerald900 : .textTertiary)
                        .padding(.horizontal, Spacing.spacing16)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.groupingMode == mode
                                ? Color.goldPrimary
                                : Color.clear
                        )
                        .cornerRadius(Radius.full)
                }
            }
        }
        .padding(4)
        .background(Color.bgSecondary)
        .cornerRadius(Radius.full)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.spacing20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.emerald50, Color.emerald100],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.emerald600, Color.emerald700],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: Spacing.spacing8) {
                Text("No History Yet")
                    .font(.h2)
                    .foregroundColor(.emerald900)
                
                Text("Start listening on Spotify and sync\nyour data to see your history here")
                    .font(.bodySmall)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - History Section Header
struct HistorySectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(.emerald800)

            Spacer()

            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.emerald900)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.goldPrimary.opacity(0.8))
                .cornerRadius(Radius.full)
        }
    }
}

// MARK: - History Item Row
struct HistoryItemRow: View {
    let event: ListeningEvent

    var body: some View {
        HStack(spacing: Spacing.spacing12) {
            // Album art
            ZStack {
                if let imageURL = event.albumImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.emerald50)
                    }
                } else {
                    Rectangle()
                        .fill(Color.emerald50)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 14))
                                .foregroundColor(.emerald400)
                        )
                }
            }
            .frame(width: 52, height: 52)
            .cornerRadius(Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .stroke(Color.borderDefault.opacity(0.3), lineWidth: 0.5)
            )

            // Track info
            VStack(alignment: .leading, spacing: 3) {
                Text(event.trackName)
                    .font(.bodyDefault)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(event.artistsString)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.spacing8)

            // Time ago
            Text(formatTimeAgo(event.playedAt))
                .font(.caption)
                .foregroundColor(.goldMuted)
                .lineLimit(1)
        }
        .padding(.vertical, Spacing.spacing8)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if minutes < 1440 { return "\(minutes / 60)h ago" }
        let days = minutes / 1440
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    var onSearch: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.spacing24) {
                // Header
                VStack(spacing: Spacing.spacing8) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Jump to Date")
                        .font(.h2)
                        .foregroundColor(.emerald900)

                    Text("Select a date to view your listening history")
                        .font(.bodySmall)
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.spacing16)

                // Date picker
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.goldPrimary)
                .padding(.horizontal, Spacing.spacing16)

                Spacer()

                // Search button
                Button(action: {
                    Haptic.medium()
                    onSearch(selectedDate)
                }) {
                    HStack(spacing: Spacing.spacing8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Go to Date")
                            .font(.h3)
                    }
                    .foregroundColor(.emerald900)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.spacing16)
                    .background(Color.goldPrimary)
                    .cornerRadius(Radius.large)
                }
                .padding(.horizontal, Spacing.spacing24)
                .padding(.bottom, Spacing.spacing24)
            }
            .background(Color.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.emerald700)
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { HistoryView() }
    }
}
