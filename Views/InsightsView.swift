// File: Views/InsightsView.swift
import SwiftUI

// MARK: - Insight Tab Enum

enum InsightTab: Int, CaseIterable {
    case listening = 0
    case streams = 1
    case tracks = 2
    case artists = 3
    case genres = 4

    var title: String {
        switch self {
        case .listening: return "Listening"
        case .streams: return "Streams"
        case .tracks: return "Tracks"
        case .artists: return "Artists"
        case .genres: return "Genres"
        }
    }

    var icon: String {
        switch self {
        case .listening: return "clock"
        case .streams: return "headphones"
        case .tracks: return "opticaldisc"
        case .artists: return "person.2"
        case .genres: return "guitars"
        }
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State var selectedTab: InsightTab
    @Environment(\.dismiss) private var dismiss

    init(initialTab: InsightTab = .listening) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            // Period picker
            periodPicker
                .padding(.horizontal, Spacing.spacing20)
                .padding(.bottom, Spacing.spacing12)

            // Swipeable pages
            TabView(selection: $selectedTab) {
                ListeningInsightTab(viewModel: viewModel)
                    .tag(InsightTab.listening)
                StreamsInsightTab(viewModel: viewModel)
                    .tag(InsightTab.streams)
                TracksInsightTab(viewModel: viewModel)
                    .tag(InsightTab.tracks)
                ArtistsInsightTab(viewModel: viewModel)
                    .tag(InsightTab.artists)
                GenresInsightTab(viewModel: viewModel)
                    .tag(InsightTab.genres)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom tab bar
            bottomTabBar
        }
        .background(Color.bgPrimary)
        .preferredColorScheme(.light)
        .task {
            guard let jwt = try? KeychainManager.shared.getToken() else { return }
            await viewModel.loadStats(jwt: jwt)
        }
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        VStack(spacing: Spacing.spacing8) {
            HStack(spacing: 0) {
                ForEach(StatsPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        Haptic.selection()
                        Task {
                            await viewModel.changePeriod(to: period)
                        }
                    }) {
                        Text(period.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(viewModel.selectedPeriod == period ? .emerald900 : .textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedPeriod == period
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

            // Date range navigation
            if viewModel.selectedPeriod != .all {
                HStack(spacing: Spacing.spacing16) {
                    Button(action: {
                        Haptic.selection()
                        viewModel.goToPreviousSelectedPeriod()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.emerald700)
                    }

                    Text(viewModel.selectedPeriodLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(minWidth: 140)

                    Button(action: {
                        Haptic.selection()
                        viewModel.goToNextSelectedPeriod()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.canGoToNextSelectedPeriod ? .emerald700 : .textTertiary.opacity(0.3))
                    }
                    .disabled(!viewModel.canGoToNextSelectedPeriod)
                }
            } else {
                Text("All Time")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: Spacing.spacing12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.emerald700)
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer()

            Text(selectedTab.title)
                .font(.h3)
                .foregroundColor(.emerald900)

            Spacer()

            // Invisible spacer for centering
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, Spacing.spacing20)
        .padding(.top, Spacing.spacing12)
        .padding(.bottom, Spacing.spacing12)
    }

    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(InsightTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    Haptic.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == tab ? .goldPrimary : .textTertiary)

                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .emerald900 : .textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.spacing8)
                }
            }
        }
        .padding(.horizontal, Spacing.spacing8)
        .padding(.top, Spacing.spacing8)
        .padding(.bottom, Spacing.spacing4)
        .background(
            Color.surfaceCard
                .shadow(color: Color.emerald900.opacity(0.08), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Tab Selector Sheet

struct TabSelectorSheet: View {
    @Binding var selectedTab: InsightTab
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.borderDefault)
                    .frame(width: 40, height: 5)
                    .padding(.top, Spacing.spacing12)
                    .padding(.bottom, Spacing.spacing16)

                // Header
                VStack(spacing: Spacing.spacing8) {
                    Text("Select View")
                        .font(.h2)
                        .foregroundColor(.emerald900)

                    Text("Choose what insights to explore")
                        .font(.bodySmall)
                        .foregroundColor(.textTertiary)
                }
                .padding(.bottom, Spacing.spacing20)

                // Tab grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Spacing.spacing12),
                    GridItem(.flexible(), spacing: Spacing.spacing12)
                ], spacing: Spacing.spacing12) {
                    ForEach(InsightTab.allCases, id: \.rawValue) { tab in
                        tabOption(tab)
                    }
                }
                .padding(.horizontal, Spacing.spacing20)

                Spacer()
            }
            .background(Color.bgPrimary)
            .navigationBarHidden(true)
        }
    }

    private func tabOption(_ tab: InsightTab) -> some View {
        let isSelected = selectedTab == tab

        return Button(action: {
            Haptic.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPresented = false
            }
        }) {
            VStack(spacing: Spacing.spacing12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.goldPrimary : Color.emerald50)
                        .frame(width: 56, height: 56)

                    Image(systemName: tab.icon + (isSelected ? ".fill" : ""))
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .emerald900 : .emerald600)
                }

                Text(tab.title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .emerald900 : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing16)
            .background(
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(isSelected ? Color.goldPrimary.opacity(0.15) : Color.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large)
                    .stroke(isSelected ? Color.goldPrimary : Color.borderDefault.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Week Navigator

struct WeekNavigator: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        HStack(spacing: Spacing.spacing16) {
            Button(action: {
                Haptic.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.goToPreviousPeriod()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.emerald700)
                    .frame(width: 36, height: 36)
                    .background(Color.emerald50)
                    .clipShape(Circle())
            }
            
            Text(viewModel.currentPeriodLabel)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(.emerald900)
                .frame(maxWidth: .infinity)
            
            Button(action: {
                Haptic.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.goToNextPeriod()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canGoNext ? .emerald700 : .textTertiary)
                    .frame(width: 36, height: 36)
                    .background(viewModel.canGoNext ? Color.emerald50 : Color.bgSecondary)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canGoNext)
        }
    }
}

// MARK: - Insight Bar Chart

struct InsightBarChart: View {
    let data: [ChartDataPoint]
    let showMinutes: Bool
    let accentColor: Color
    @State private var animateIn = false
    
    private let yAxisWidth: CGFloat = 32
    
    init(data: [ChartDataPoint], showMinutes: Bool = true, accentColor: Color = .emerald600) {
        self.data = data
        self.showMinutes = showMinutes
        self.accentColor = accentColor
    }
    
    var body: some View {
        let values = data.map { showMinutes ? $0.minutes : Double($0.trackCount) }
        let maxVal = max(values.max() ?? 1, 1)
        
        GeometryReader { geo in
            let chartWidth = geo.size.width - yAxisWidth
            let spacing: CGFloat = 4
            let barWidth = max((chartWidth - CGFloat(max(data.count - 1, 0)) * spacing) / CGFloat(max(data.count, 1)), 4)
            
            HStack(alignment: .top, spacing: 0) {
                // Y-axis
                VStack(alignment: .trailing, spacing: 0) {
                    Text(yLabel(maxVal))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text(yLabel(maxVal / 2))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text("0")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .padding(.bottom, 16)
                }
                .frame(width: yAxisWidth, height: geo.size.height)
                
                // Bars
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                        let value = showMinutes ? point.minutes : Double(point.trackCount)
                        let barHeight = max(geo.size.height * 0.75 * CGFloat(value / maxVal), 4)
                        
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)

                            Text(showMinutes ? formatBarTime(Int(value)) : "\(Int(value))")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.textTertiary)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: animateIn ? barHeight : 4)
                            
                            Text(point.dayOfWeek)
                                .font(.system(size: 9, weight: Calendar.current.isDateInToday(point.date) ? .bold : .medium))
                                .foregroundColor(Calendar.current.isDateInToday(point.date) ? .emerald800 : .textTertiary)
                                .frame(width: barWidth)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }
    
    private func yLabel(_ val: Double) -> String {
        if showMinutes {
            if val >= 60 {
                let h = Int(val / 60)
                return "\(h)h"
            }
            return "\(Int(val))m"
        }
        return "\(Int(val))"
    }

    private func formatBarTime(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            if m == 0 {
                return "\(h)h"
            }
            return "\(h):\(String(format: "%02d", m))"
        }
        return "\(minutes)m"
    }
}

// MARK: - Big Stat Display

struct BigStatDisplay: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: Spacing.spacing8) {
            ZStack {
                Circle()
                    .fill(Color.emerald50)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.emerald600)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.emerald900)
                Text(unit)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.emerald600)
            }
            
            Text(label)
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.spacing20)
    }
}

// MARK: - Callout Pill

struct CalloutPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.captionBold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Listening Tab

struct ListeningInsightTab: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var animateIn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                // Hero card
                listeningHeroCard

                // Daily breakdown chart
                dailyBreakdownSection

                // Listening patterns list
                listeningPatternsSection

                // Insights
                listeningInsightsSection
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.bottom, Spacing.spacing40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    private var listeningHeroCard: some View {
        let totalMinutes = viewModel.stats?.totalMinutes ?? 0
        let totalHours = Int(totalMinutes / 60)
        let days = totalHours / 24
        let remainingHours = totalHours % 24

        return VStack(spacing: 0) {
            VStack(spacing: Spacing.spacing12) {
                ZStack {
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.goldPrimary)
                }

                VStack(spacing: Spacing.spacing4) {
                    Text("TOTAL LISTENING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.full)

                    if days > 0 {
                        Text("\(days)d \(remainingHours)h")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(totalHours) hours")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("\(formatNumber(Int(totalMinutes))) minutes of music")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing24)

            // Bottom stats
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(totalHours)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("hours")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text("\(days)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("days")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    let avgPerDay = totalMinutes / 365
                    Text("\(Int(avgPerDay))m")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("avg/day")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.spacing12)
            .background(Color.white.opacity(0.08))
        }
        .background(
            LinearGradient(colors: [Color.emerald700, Color.emerald900], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(Radius.xLarge)
        .heroShadow()
    }

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Daily Breakdown")

            VStack(spacing: Spacing.spacing8) {
                WeekNavigator(viewModel: viewModel)

                InsightBarChart(data: viewModel.getChartData(), showMinutes: true, accentColor: .emerald600)
                    .frame(height: 140)
            }
            .premiumCard()
        }
    }

    private var listeningPatternsSection: some View {
        let chartData = viewModel.getChartData()
        let sortedByMinutes = chartData.sorted { $0.minutes > $1.minutes }
        let maxMinutes = sortedByMinutes.first?.minutes ?? 1

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "This Week's Activity")

            VStack(spacing: Spacing.spacing12) {
                ForEach(Array(sortedByMinutes.enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: Spacing.spacing12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(index < 3 ? .goldPrimary : .textTertiary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.dateLabel)
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.emerald900)
                                Spacer()
                                Text(formatMinutes(day.minutes))
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(day.minutes / maxMinutes)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.emerald50).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.emerald600, .emerald400], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: animateIn ? barWidth : 0, height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("\(day.trackCount) tracks")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    if index < sortedByMinutes.count - 1 { Divider() }
                }
            }
            .premiumCard()
        }
    }

    private var listeningInsightsSection: some View {
        let totalMinutes = viewModel.stats?.totalMinutes ?? 0
        let totalHours = Int(totalMinutes / 60)
        let chartData = viewModel.getChartData()
        let peakDay = chartData.max(by: { $0.minutes < $1.minutes })

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Listening Insights")

            VStack(spacing: Spacing.spacing12) {
                insightCard(icon: "flame.fill", iconColor: .goldPrimary, title: "Peak Listening Day",
                    description: peakDay != nil ? "\(peakDay!.dateLabel) with \(formatMinutes(peakDay!.minutes))" : "No data yet")

                insightCard(icon: "moon.stars.fill", iconColor: .emerald600, title: "Lifetime Listening",
                    description: "You've listened to \(formatNumber(totalHours)) hours of music total")

                let avgDaily = totalMinutes / max(Double(chartData.count), 1)
                insightCard(icon: "chart.line.uptrend.xyaxis", iconColor: .emerald500, title: "Daily Average",
                    description: "You listen to about \(formatMinutes(avgDaily)) of music per day")
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.spacing12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundColor(.emerald900)
                Text(description).font(.caption).foregroundColor(.textSecondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.borderDefault.opacity(0.3), lineWidth: 1))
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes / 60)
        let mins = Int(minutes) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Streams Tab

struct StreamsInsightTab: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var animateIn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                // Hero card
                streamsHeroCard

                // Daily streams chart
                dailyStreamsSection

                // Streams activity list
                streamsActivitySection

                // Insights
                streamsInsightsSection
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.bottom, Spacing.spacing40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    private var streamsHeroCard: some View {
        let totalTracks = viewModel.stats?.totalTracks ?? 0
        let uniqueTracks = viewModel.stats?.uniqueTracks ?? 0
        let uniqueArtists = viewModel.stats?.uniqueArtists ?? 0

        return VStack(spacing: 0) {
            VStack(spacing: Spacing.spacing12) {
                ZStack {
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "headphones")
                        .font(.system(size: 36))
                        .foregroundColor(.goldPrimary)
                }

                VStack(spacing: Spacing.spacing4) {
                    Text("TOTAL STREAMS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.full)

                    Text(formatNumber(totalTracks))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("songs played lifetime")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing24)

            // Bottom stats
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(formatNumber(totalTracks))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("streams")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text(formatNumber(uniqueTracks))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("unique")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text(formatNumber(uniqueArtists))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("artists")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.spacing12)
            .background(Color.white.opacity(0.08))
        }
        .background(
            LinearGradient(colors: [Color.emerald700, Color.emerald900], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(Radius.xLarge)
        .heroShadow()
    }

    private var dailyStreamsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Daily Streams")

            VStack(spacing: Spacing.spacing8) {
                WeekNavigator(viewModel: viewModel)

                InsightBarChart(data: viewModel.getChartData(), showMinutes: false, accentColor: .emerald700)
                    .frame(height: 140)
            }
            .premiumCard()
        }
    }

    private var streamsActivitySection: some View {
        let chartData = viewModel.getChartData()
        let sortedByCount = chartData.sorted { $0.trackCount > $1.trackCount }
        let maxCount = sortedByCount.first?.trackCount ?? 1

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "This Week's Streams")

            VStack(spacing: Spacing.spacing12) {
                ForEach(Array(sortedByCount.enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: Spacing.spacing12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(index < 3 ? .goldPrimary : .textTertiary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.dateLabel)
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.emerald900)
                                Spacer()
                                Text("\(day.trackCount) streams")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(day.trackCount) / CGFloat(maxCount)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.emerald50).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.emerald700, .emerald500], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: animateIn ? barWidth : 0, height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text(formatMinutes(day.minutes))
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    if index < sortedByCount.count - 1 { Divider() }
                }
            }
            .premiumCard()
        }
    }

    private var streamsInsightsSection: some View {
        let totalTracks = viewModel.stats?.totalTracks ?? 0
        let uniqueTracks = viewModel.stats?.uniqueTracks ?? 0
        let chartData = viewModel.getChartData()
        let peakDay = chartData.max(by: { $0.trackCount < $1.trackCount })
        let repeatRate = uniqueTracks > 0 ? Double(totalTracks) / Double(uniqueTracks) : 0

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Stream Insights")

            VStack(spacing: Spacing.spacing12) {
                insightCard(icon: "star.fill", iconColor: .goldPrimary, title: "Most Active Day",
                    description: peakDay != nil ? "\(peakDay!.dateLabel) with \(peakDay!.trackCount) streams" : "No data yet")

                insightCard(icon: "arrow.triangle.2.circlepath", iconColor: .emerald600, title: "Replay Rate",
                    description: "You replay songs \(String(format: "%.1f", repeatRate))x on average")

                let avgDaily = totalTracks / max(chartData.count, 1)
                insightCard(icon: "chart.bar.fill", iconColor: .emerald500, title: "Daily Average",
                    description: "You stream about \(avgDaily) songs per day")
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.spacing12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundColor(.emerald900)
                Text(description).font(.caption).foregroundColor(.textSecondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.borderDefault.opacity(0.3), lineWidth: 1))
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes / 60)
        let mins = Int(minutes) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Tracks Tab

struct TracksInsightTab: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var animateIn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                // Hero card with #1 track
                if let topTrack = viewModel.stats?.topTracks.first {
                    trackHeroCard(track: topTrack)
                }

                // Play distribution chart
                if let tracks = viewModel.stats?.topTracks, tracks.count >= 3 {
                    tracksDistributionChart(tracks: Array(tracks.prefix(5)))
                }

                // Top 25 tracks list
                if let tracks = viewModel.stats?.topTracks, tracks.count >= 3 {
                    topTracksListSection(tracks: Array(tracks.prefix(25)))
                }

                // Insights
                tracksInsightsSection
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.bottom, Spacing.spacing40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    // MARK: - Distribution Chart
    private func tracksDistributionChart(tracks: [TopTrackResponse]) -> some View {
        let total = tracks.reduce(0) { $0 + $1.playCount }
        let colors: [Color] = [.emerald600, .goldPrimary, Color(red: 0.75, green: 0.75, blue: 0.78), .emerald400, .emerald300]

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Play Distribution")

            HStack(spacing: Spacing.spacing16) {
                // Pie chart
                ZStack {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        let startAngle = tracks.prefix(index).reduce(0.0) { $0 + Double($1.playCount) / Double(total) * 360 }
                        let endAngle = startAngle + Double(track.playCount) / Double(total) * 360

                        PieSlice(startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90))
                            .fill(colors[index % colors.count])
                    }

                    Circle()
                        .fill(Color.surfaceCard)
                        .frame(width: 60, height: 60)

                    VStack(spacing: 0) {
                        Text("\(tracks.count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.emerald900)
                        Text("top")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                }
                .frame(width: 100, height: 100)

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tracks.prefix(5).enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text(track.name)
                                .font(.system(size: 11))
                                .foregroundColor(.emerald900)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(Double(track.playCount) / Double(total) * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .premiumCard()
        }
    }

    private func trackHeroCard(track: TopTrackResponse) -> some View {
        let totalTracks = viewModel.stats?.totalTracks ?? 0
        let uniqueTracks = viewModel.stats?.uniqueTracks ?? 0

        return VStack(spacing: 0) {
            VStack(spacing: Spacing.spacing12) {
                // Album art or icon
                ZStack {
                    if let imageUrl = track.albumImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.goldPrimary.opacity(0.2))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.goldPrimary.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundColor(.goldPrimary)
                    }
                }

                VStack(spacing: Spacing.spacing4) {
                    Text("#1 TRACK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.full)

                    Text(track.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(track.artistNames.joined(separator: ", "))
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.7))

                    Text("\(track.playCount) plays • \(formatDuration(track.totalMinutes))")
                        .font(.caption)
                        .foregroundColor(.goldPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing24)

            // Bottom stats
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(formatNumber(totalTracks))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("streams")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text(formatNumber(uniqueTracks))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("unique")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text("\(track.playCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("#1 plays")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.spacing12)
            .background(Color.white.opacity(0.08))
        }
        .background(
            LinearGradient(colors: [Color.emerald700, Color.emerald900], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(Radius.xLarge)
        .heroShadow()
    }

    private func topTracksListSection(tracks: [TopTrackResponse]) -> some View {
        let maxPlays = tracks.first?.playCount ?? 1

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Top 25 Tracks")

            VStack(spacing: Spacing.spacing8) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: Spacing.spacing12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(index == 0 ? .emerald600 : index == 1 ? .goldPrimary : index == 2 ? Color(red: 0.75, green: 0.75, blue: 0.78) : .textTertiary)
                            .frame(width: 24)

                        // Album art
                        ZStack {
                            if let imageUrl = track.albumImageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.emerald50)
                                }
                            } else {
                                Rectangle().fill(Color.emerald50)
                                    .overlay(Image(systemName: "music.note").foregroundColor(.emerald400))
                            }
                        }
                        .frame(width: 40, height: 40)
                        .cornerRadius(Radius.small)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(track.name)
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.emerald900)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatDuration(track.totalMinutes))
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(track.playCount) / CGFloat(maxPlays)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.emerald50).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.emerald600, .emerald400], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: animateIn ? barWidth : 0, height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack(spacing: 6) {
                                Text("\(track.playCount) plays")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                                if let genre = track.genres?.first {
                                    Text(genre.capitalized)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.emerald600)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.emerald50)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    if index < tracks.count - 1 { Divider() }
                }
            }
            .premiumCard()
        }
    }

    private var tracksInsightsSection: some View {
        let topTrack = viewModel.stats?.topTracks.first
        let uniqueTracks = viewModel.stats?.uniqueTracks ?? 0
        let totalTracks = viewModel.stats?.totalTracks ?? 0

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Track Insights")

            VStack(spacing: Spacing.spacing12) {
                if let track = topTrack {
                    insightCard(icon: "crown.fill", iconColor: .goldPrimary, title: "Most Played",
                        description: "\"\(track.name)\" with \(track.playCount) plays")
                }

                insightCard(icon: "sparkles", iconColor: .emerald600, title: "Discovery",
                    description: "You've discovered \(formatNumber(uniqueTracks)) unique songs")

                let avgPlaysPerTrack = uniqueTracks > 0 ? totalTracks / uniqueTracks : 0
                insightCard(icon: "arrow.triangle.2.circlepath", iconColor: .emerald500, title: "Replay Habits",
                    description: "You play each song \(avgPlaysPerTrack)x on average")
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.spacing12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundColor(.emerald900)
                Text(description).font(.caption).foregroundColor(.textSecondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.borderDefault.opacity(0.3), lineWidth: 1))
    }

    private func formatDuration(_ minutes: Double) -> String {
        let mins = Int(minutes)
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins)m"
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Artists Tab

struct ArtistsInsightTab: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var animateIn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                // Hero card with #1 artist
                if let topArtist = viewModel.stats?.topArtists.first {
                    artistHeroCard(artist: topArtist)
                }

                // Play distribution chart
                if let artists = viewModel.stats?.topArtists, artists.count >= 3 {
                    artistsDistributionChart(artists: Array(artists.prefix(5)))
                }

                // Top 25 artists list
                if let artists = viewModel.stats?.topArtists, artists.count >= 3 {
                    topArtistsListSection(artists: Array(artists.prefix(25)))
                }

                // Insights
                artistsInsightsSection
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.bottom, Spacing.spacing40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    // MARK: - Distribution Chart
    private func artistsDistributionChart(artists: [TopArtistResponse]) -> some View {
        let total = artists.reduce(0) { $0 + $1.playCount }
        let colors: [Color] = [.emerald600, .goldPrimary, Color(red: 0.75, green: 0.75, blue: 0.78), .emerald400, .emerald300]

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Play Distribution")

            HStack(spacing: Spacing.spacing16) {
                // Pie chart
                ZStack {
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        let startAngle = artists.prefix(index).reduce(0.0) { $0 + Double($1.playCount) / Double(total) * 360 }
                        let endAngle = startAngle + Double(artist.playCount) / Double(total) * 360

                        PieSlice(startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90))
                            .fill(colors[index % colors.count])
                    }

                    Circle()
                        .fill(Color.surfaceCard)
                        .frame(width: 60, height: 60)

                    VStack(spacing: 0) {
                        Text("\(artists.count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.emerald900)
                        Text("top")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                }
                .frame(width: 100, height: 100)

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(artists.prefix(5).enumerated()), id: \.element.id) { index, artist in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colors[index % colors.count])
                                .frame(width: 8, height: 8)
                            Text(artist.name)
                                .font(.system(size: 11))
                                .foregroundColor(.emerald900)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(Double(artist.playCount) / Double(total) * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .premiumCard()
        }
    }

    private func artistHeroCard(artist: TopArtistResponse) -> some View {
        let uniqueArtists = viewModel.stats?.uniqueArtists ?? 0
        let totalArtistPlays = viewModel.stats?.topArtists.reduce(0) { $0 + $1.playCount } ?? 0

        return VStack(spacing: 0) {
            VStack(spacing: Spacing.spacing12) {
                ZStack {
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.goldPrimary)
                }

                VStack(spacing: Spacing.spacing4) {
                    Text("#1 ARTIST")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.full)

                    Text(artist.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(artist.playCount) plays • \(formatMinutes(artist.totalMinutes))")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing24)

            // Bottom stats
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(formatNumber(uniqueArtists))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("artists")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text(formatNumber(totalArtistPlays))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("plays")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Color.goldPrimary.opacity(0.3)).frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    let percentage = totalArtistPlays > 0 ? Int((Double(artist.playCount) / Double(totalArtistPlays)) * 100) : 0
                    Text("\(percentage)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("#1 share")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.spacing12)
            .background(Color.white.opacity(0.08))
        }
        .background(
            LinearGradient(colors: [Color.emerald700, Color.emerald900], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(Radius.xLarge)
        .heroShadow()
    }

    private func topArtistsListSection(artists: [TopArtistResponse]) -> some View {
        let maxPlays = artists.first?.playCount ?? 1

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Top 25 Artists")

            VStack(spacing: Spacing.spacing8) {
                ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                    HStack(spacing: Spacing.spacing12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(index == 0 ? .emerald600 : index == 1 ? .goldPrimary : index == 2 ? Color(red: 0.75, green: 0.75, blue: 0.78) : .textTertiary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(artist.name)
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.emerald900)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatMinutes(artist.totalMinutes))
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(artist.playCount) / CGFloat(maxPlays)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.emerald50).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.emerald600, .emerald400], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: animateIn ? barWidth : 0, height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack(spacing: 6) {
                                Text("\(artist.playCount) plays")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                                if let genre = artist.genres?.first {
                                    Text(genre.capitalized)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.emerald600)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.emerald50)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    if index < artists.count - 1 { Divider() }
                }
            }
            .premiumCard()
        }
    }

    private var artistsInsightsSection: some View {
        let topArtist = viewModel.stats?.topArtists.first
        let uniqueArtists = viewModel.stats?.uniqueArtists ?? 0

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Artist Insights")

            VStack(spacing: Spacing.spacing12) {
                if let artist = topArtist {
                    insightCard(icon: "crown.fill", iconColor: .goldPrimary, title: "Top Artist",
                        description: "\(artist.name) dominates with \(artist.playCount) plays")
                }

                insightCard(icon: "person.3.fill", iconColor: .emerald600, title: "Artist Variety",
                    description: "You've listened to \(formatNumber(uniqueArtists)) different artists")

                insightCard(icon: "clock.fill", iconColor: .emerald500, title: "Top Artist Time",
                    description: "You've spent \(formatMinutes(topArtist?.totalMinutes ?? 0)) with your #1 artist")
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.spacing12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bodySmall).fontWeight(.semibold).foregroundColor(.emerald900)
                Text(description).font(.caption).foregroundColor(.textSecondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.borderDefault.opacity(0.3), lineWidth: 1))
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes / 60)
        let mins = Int(minutes) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Genres Insight Tab

struct GenresInsightTab: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var animateIn = false

    // Genre colors - #1 green, #2 gold, rest are varied
    private func colorForGenreAtIndex(_ index: Int, genre: String) -> Color {
        switch index {
        case 0:
            return Color.emerald600  // #1 - Signature green
        case 1:
            return Color.goldPrimary  // #2 - Signature gold
        case 2:
            return Color(red: 0.75, green: 0.75, blue: 0.78)  // Silver
        case 3:
            return Color(red: 1.0, green: 0.5, blue: 0.0)  // Orange
        case 4:
            return Color(red: 0.3, green: 0.4, blue: 0.9)  // Indigo
        case 5:
            return Color(red: 0.0, green: 0.7, blue: 0.7)  // Teal
        case 6:
            return Color(red: 0.9, green: 0.3, blue: 0.4)  // Rose
        case 7:
            return Color(red: 0.2, green: 0.6, blue: 0.9)  // Sky Blue
        case 8:
            return Color(red: 0.8, green: 0.4, blue: 0.6)  // Mauve
        case 9:
            return Color(red: 0.4, green: 0.7, blue: 0.5)  // Sage
        default:
            // Cycle through remaining colors
            let extraColors: [Color] = [
                Color(red: 0.7, green: 0.5, blue: 0.2),  // Amber
                Color(red: 0.5, green: 0.3, blue: 0.7),  // Violet
                Color(red: 0.2, green: 0.5, blue: 0.6),  // Steel Blue
                Color(red: 0.8, green: 0.6, blue: 0.4),  // Tan
            ]
            return extraColors[(index - 10) % extraColors.count]
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                // Hero section with top genre
                if let genres = viewModel.stats?.topGenres, let topGenre = genres.first {
                    genreHeroCard(genre: topGenre, totalPlays: genres.reduce(0) { $0 + $1.playCount })
                }

                // Genre distribution pie chart
                if let genres = viewModel.stats?.topGenres, !genres.isEmpty {
                    genreDistributionSection(genres: Array(genres.prefix(6)))
                }

                // All genres list with bars
                if let genres = viewModel.stats?.topGenres, !genres.isEmpty {
                    genreListSection(genres: genres)
                }

                // Genre insights callouts
                if let genres = viewModel.stats?.topGenres, genres.count >= 2 {
                    genreInsightsSection(genres: genres)
                }
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.bottom, Spacing.spacing40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    // MARK: - Hero Card
    private func genreHeroCard(genre: TopGenreResponse, totalPlays: Int) -> some View {
        VStack(spacing: 0) {
            // Top section with icon and genre name
            VStack(spacing: Spacing.spacing12) {
                ZStack {
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "guitars.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.goldPrimary)
                }

                VStack(spacing: Spacing.spacing4) {
                    Text("#1 GENRE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.emerald900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.full)

                    Text(genre.genre.capitalized)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(genre.playCount) plays • \(formatMinutes(genre.totalMinutes))")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing24)

            // Bottom stats strip
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(viewModel.stats?.topGenres?.count ?? 0)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("genres")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.goldPrimary.opacity(0.3))
                    .frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    Text("\(totalPlays)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("total plays")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.goldPrimary.opacity(0.3))
                    .frame(width: 1, height: 32)

                VStack(spacing: 2) {
                    let percentage = totalPlays > 0 ? Int((Double(genre.playCount) / Double(totalPlays)) * 100) : 0
                    Text("\(percentage)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.goldPrimary)
                    Text("top genre")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.spacing12)
            .background(Color.white.opacity(0.08))
        }
        .background(
            LinearGradient(
                colors: [Color.emerald700, Color.emerald900],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(Radius.xLarge)
        .heroShadow()
    }

    // MARK: - Distribution Section (Visual Ring)
    private func genreDistributionSection(genres: [TopGenreResponse]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Genre Distribution")

            HStack(spacing: Spacing.spacing16) {
                // Ring chart
                ZStack {
                    let total = Double(genres.reduce(0) { $0 + $1.playCount })

                    ForEach(Array(genres.enumerated().reversed()), id: \.element.genre) { index, genre in
                        let startAngle = angleForIndex(index, genres: genres, total: total)
                        let endAngle = angleForIndex(index + 1, genres: genres, total: total)

                        Circle()
                            .trim(from: startAngle, to: animateIn ? endAngle : startAngle)
                            .stroke(
                                colorForGenreAtIndex(index, genre: genre.genre),
                                style: StrokeStyle(lineWidth: 24, lineCap: .butt)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animateIn)
                    }

                    VStack(spacing: 2) {
                        Text("\(genres.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.emerald800)
                        Text("genres")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                    }
                }
                .frame(width: 120, height: 120)

                // Legend
                VStack(alignment: .leading, spacing: Spacing.spacing8) {
                    ForEach(Array(genres.enumerated()), id: \.element.genre) { index, genre in
                        HStack(spacing: Spacing.spacing8) {
                            Circle()
                                .fill(colorForGenreAtIndex(index, genre: genre.genre))
                                .frame(width: 10, height: 10)

                            Text(genre.genre.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.emerald900)
                                .lineLimit(1)

                            Spacer()

                            let total = genres.reduce(0) { $0 + $1.playCount }
                            let pct = total > 0 ? Int((Double(genre.playCount) / Double(total)) * 100) : 0
                            Text("\(pct)%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.spacing16)
            .premiumCard(padding: 0)
        }
    }

    private func angleForIndex(_ index: Int, genres: [TopGenreResponse], total: Double) -> CGFloat {
        guard total > 0 else { return 0 }
        let sum = genres.prefix(index).reduce(0) { $0 + $1.playCount }
        return CGFloat(Double(sum) / total)
    }

    // MARK: - Genre List with Bars
    private func genreListSection(genres: [TopGenreResponse]) -> some View {
        let maxCount = Double(genres.map { $0.playCount }.max() ?? 1)

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "All Genres")

            VStack(spacing: Spacing.spacing12) {
                ForEach(Array(genres.enumerated()), id: \.element.genre) { index, genre in
                    HStack(spacing: Spacing.spacing12) {
                        // Rank
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(index < 3 ? .goldPrimary : .textTertiary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(genre.genre.capitalized)
                                    .font(.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.emerald900)

                                Spacer()

                                Text("\(genre.playCount) plays")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                    .monospacedDigit()
                            }

                            // Progress bar
                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(Double(genre.playCount) / maxCount)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.emerald50)
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [colorForGenreAtIndex(index, genre: genre.genre), colorForGenreAtIndex(index, genre: genre.genre).opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animateIn ? barWidth : 0, height: 6)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05), value: animateIn)
                                }
                            }
                            .frame(height: 6)

                            Text(formatMinutes(genre.totalMinutes))
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }
                    }

                    if index < genres.count - 1 {
                        Divider()
                    }
                }
            }
            .premiumCard()
        }
    }

    // MARK: - Insights Section
    private func genreInsightsSection(genres: [TopGenreResponse]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Genre Insights")

            VStack(spacing: Spacing.spacing12) {
                // Top genre insight
                if let top = genres.first {
                    insightCard(
                        icon: "crown.fill",
                        iconColor: .goldPrimary,
                        title: "Favorite Genre",
                        description: "\(top.genre.capitalized) dominates your listening with \(top.playCount) plays"
                    )
                }

                // Variety insight
                let genreCount = genres.count
                insightCard(
                    icon: "sparkles",
                    iconColor: .emerald600,
                    title: "Genre Variety",
                    description: "You've explored \(genreCount) different genre\(genreCount == 1 ? "" : "s") recently"
                )

                // Time insight
                if let top = genres.first {
                    let hours = Int(top.totalMinutes / 60)
                    let mins = Int(top.totalMinutes) % 60
                    insightCard(
                        icon: "clock.fill",
                        iconColor: .emerald500,
                        title: "Time in \(top.genre.capitalized)",
                        description: hours > 0 ? "You've spent \(hours)h \(mins)m listening to \(top.genre.capitalized)" : "You've spent \(mins) minutes listening to \(top.genre.capitalized)"
                    )
                }
            }
        }
    }

    private func insightCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.spacing12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.emerald900)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large)
                .stroke(Color.borderDefault.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes / 60)
        let mins = Int(minutes) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }
}

// MARK: - Pie Slice Shape

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView(initialTab: .listening)
    }
}
