// File: Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var statsViewModel = StatsViewModel()
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showHistory = false
    @State private var showInsights = false
    @State private var insightsTab: InsightTab = .listening
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var showSyncAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var contentAppeared = false
    @State private var heroPeriod: ChartViewMode = .days
    @State private var profileImage: UIImage? = nil

    // Local profile image URL
    private var localProfileImageURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("profile_image.jpg")
    }

    private func loadProfileImage() {
        if FileManager.default.fileExists(atPath: localProfileImageURL.path),
           let data = try? Data(contentsOf: localProfileImageURL),
           let image = UIImage(data: data) {
            profileImage = image
        } else {
            profileImage = nil
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.bgPrimary.ignoresSafeArea()

            // Sticky blur header (fades in on scroll)
            stickyHeader
                .zIndex(100)

            // Main scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.spacing24) {
                    headerSection
                        .padding(.top, Spacing.spacing8)

                    heroStatsCard

                    statsCardsSection

                    quickActionsSection
                }
                .padding(.horizontal, Spacing.spacing20)
                .padding(.bottom, Spacing.spacing40)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("homeScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView { SettingsView() }
        }
        .sheet(isPresented: $showProfile, onDismiss: {
            // Reload profile image when returning from profile
            loadProfileImage()
        }) {
            ProfileView()
        }
        .sheet(isPresented: $showHistory) {
            NavigationView { HistoryView() }
        }
        .sheet(isPresented: $showInsights) {
            InsightsView(initialTab: insightsTab)
        }
        .alert("Sync Result", isPresented: $showSyncAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncMessage ?? "")
        }
        .preferredColorScheme(.light)
        .task {
            guard let jwt = try? KeychainManager.shared.getToken() else { return }
            await statsViewModel.loadStats(jwt: jwt)
        }
        .onAppear {
            loadProfileImage()
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Sticky Header
    private var stickyHeader: some View {
        let opacity = min(max(-scrollOffset / 100, 0), 1)
        return VStack(spacing: 0) {
            HStack {
                Text(appState.currentUser?.displayName ?? "Wrapped")
                    .font(.h3)
                    .foregroundColor(.emerald900)
                Spacer()
                Button(action: { showProfile = true }) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.emerald700)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.goldPrimary)
                            )
                    }
                }
            }
            .padding(.horizontal, Spacing.spacing20)
            .padding(.top, 52)
            .padding(.bottom, Spacing.spacing12)
            .background(.ultraThinMaterial.opacity(opacity))

            Divider().opacity(opacity)
        }
        .opacity(opacity)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Spacing.spacing4) {
                Text(getGreeting().uppercased())
                    .font(.labelSmall)
                    .foregroundColor(.textTertiary)

                Text(appState.currentUser?.displayName ?? "Welcome")
                    .font(.displayLarge)
                    .foregroundColor(.emerald900)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            // History button
            Button(action: { Haptic.light(); showHistory = true }) {
                HStack(spacing: Spacing.spacing6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .medium))
                    Text("History")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.emerald800)
                .padding(.horizontal, Spacing.spacing12)
                .padding(.vertical, Spacing.spacing8)
                .background(Color.emerald50)
                .cornerRadius(Radius.full)
            }

            Button(action: { Haptic.light(); showProfile = true }) {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.goldPrimary, lineWidth: 2)
                        )
                        .shadow(color: Color.emerald700.opacity(0.25), radius: 8, x: 0, y: 4)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.emerald700, Color.emerald800],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.goldPrimary)
                        )
                        .shadow(color: Color.emerald700.opacity(0.25), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    // MARK: - Hero Stats Card
    private var heroStatsCard: some View {
        // Compute period-specific minutes from chart data
        let periodChartData = heroChartData()
        let periodMinutes = periodChartData.reduce(0) { $0 + $1.minutes }
        let periodTracks = periodChartData.reduce(0) { $0 + $1.trackCount }
        let hours = Int(periodMinutes / 60)
        let mins = Int(periodMinutes) % 60

        return VStack(spacing: 0) {
            // Period toggle
            HStack(spacing: 0) {
                ForEach(ChartViewMode.allCases, id: \.rawValue) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            Haptic.selection()
                            heroPeriod = mode
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(heroPeriod == mode ? .emerald900 : .white.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Group {
                                    if heroPeriod == mode {
                                        Capsule().fill(Color.goldPrimary)
                                    }
                                }
                            )
                    }
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .padding(.top, Spacing.spacing16)
            .padding(.bottom, Spacing.spacing4)

            // Main stat area
            VStack(spacing: Spacing.spacing8) {
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.goldPrimary.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hours > 0 ? "\(hours)" : "\(Int(periodMinutes))")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(hours > 0 ? "hr" : "min")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if hours > 0 && mins > 0 {
                        Text("\(mins)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("min")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Text(heroPeriodLabel())
                    .font(.bodySmall)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing16)

            // Bottom stats strip - all period-specific
            HStack(spacing: 0) {
                let activeDays = periodChartData.filter { $0.minutes > 0 }.count
                let periodHours = periodMinutes / 60

                heroMiniStat(
                    value: formatNumber(periodTracks),
                    label: "streams"
                )

                Rectangle()
                    .fill(Color.goldPrimary.opacity(0.3))
                    .frame(width: 1, height: 32)

                heroMiniStat(
                    value: periodHours >= 1 ? String(format: "%.1fh", periodHours) : "\(Int(periodMinutes))m",
                    label: "listened"
                )

                Rectangle()
                    .fill(Color.goldPrimary.opacity(0.3))
                    .frame(width: 1, height: 32)

                heroMiniStat(
                    value: "\(activeDays)",
                    label: activeDays == 1 ? "day active" : "days active"
                )
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
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 20)
        .onTapGesture {
            Haptic.light()
            insightsTab = .listening
            showInsights = true
        }
    }

    /// Returns chart data for the hero card's selected period without mutating ViewModel state
    private func heroChartData() -> [ChartDataPoint] {
        statsViewModel.getChartData(mode: heroPeriod, offset: 0)
    }

    /// Label for the hero card subtitle
    private func heroPeriodLabel() -> String {
        switch heroPeriod {
        case .days: return "listened today"
        case .weeks: return "listened this week"
        case .months: return "listened this month"
        case .years: return "listened this year"
        }
    }

    private func heroMiniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.goldPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Cards Section
    private var statsCardsSection: some View {
        let stats = statsViewModel.stats
        let totalMinutes = stats?.totalMinutes ?? 0

        return VStack(alignment: .leading, spacing: Spacing.spacing12) {
            // Section header
            HStack {
                Image(systemName: "infinity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.goldPrimary)
                Text("Lifetime Stats")
                    .font(.h3)
                    .foregroundColor(.emerald900)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.spacing12),
                GridItem(.flexible(), spacing: Spacing.spacing12)
            ], spacing: Spacing.spacing12) {
                StatCard(
                    icon: "clock",
                    value: formatHours(totalMinutes),
                    label: "Hours",
                    sublabel: "listened",
                    onTap: { insightsTab = .listening; showInsights = true }
                )
                StatCard(
                    icon: "headphones",
                    value: formatNumber(stats?.totalTracks ?? 0),
                    label: "Streams",
                    sublabel: "total plays",
                    onTap: { insightsTab = .streams; showInsights = true }
                )
                StatCard(
                    icon: "opticaldisc",
                    value: formatNumber(stats?.uniqueTracks ?? 0),
                    label: "Tracks",
                    sublabel: "discovered",
                    onTap: { insightsTab = .tracks; showInsights = true }
                )
                StatCard(
                    icon: "person.2",
                    value: formatNumber(stats?.uniqueArtists ?? 0),
                    label: "Artists",
                    sublabel: "explored",
                    onTap: { insightsTab = .artists; showInsights = true }
                )
            }
        }
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        // Sync button
        Button(action: {
            Haptic.medium()
            Task { await syncNow() }
        }) {
            HStack(spacing: Spacing.spacing8) {
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .goldPrimary))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.goldPrimary)
                }
                Text(isSyncing ? "Syncing..." : "Sync Now")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.emerald900)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .premiumCard(padding: 0)
        }
        .disabled(isSyncing)
    }

    // MARK: - Helpers

    private func formatHours(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        if hours > 0 { return "\(hours)h" }
        return "\(Int(minutes))m"
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000)
        }
        return "\(num)"
    }

    private func syncNow() async {
        isSyncing = true
        do {
            let syncResponse = try await appState.performAuthenticatedRequest { jwt in
                try await APIClient.shared.devSyncNow(jwt: jwt)
            }
            if syncResponse.success {
                let inserted = syncResponse.eventsInserted ?? 0
                let skipped = syncResponse.duplicatesSkipped ?? 0
                syncMessage = "Success! Inserted \(inserted) new events, skipped \(skipped) duplicates."
                Haptic.success()
                if let jwt = try? KeychainManager.shared.getToken() {
                    await statsViewModel.loadStats(jwt: jwt)
                }
            } else {
                syncMessage = syncResponse.reason ?? "Sync failed"
            }
            showSyncAlert = true
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
            showSyncAlert = true
        }
        isSyncing = false
    }
}

// MARK: - Scroll Offset Key
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Interactive Chart View
struct InteractiveChartView: View {
    let data: [ChartDataPoint]
    @State private var selectedIndex: Int? = nil
    @State private var lineProgress: CGFloat = 0

    private let yAxisWidth: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let maxMin = max(data.map { $0.minutes }.max() ?? 1, 1)
            let chartWidth = geo.size.width - yAxisWidth
            let h = geo.size.height - 28

            // Calculate nice grid intervals based on max value
            let gridInterval = calculateGridInterval(maxValue: maxMin)
            let gridLevels = Int(ceil(maxMin / gridInterval))
            let adjustedMax = Double(gridLevels) * gridInterval

            HStack(alignment: .top, spacing: 0) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach((1...gridLevels).reversed(), id: \.self) { level in
                        let val = gridInterval * Double(level)
                        Text(yAxisLabel(val))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textTertiary)
                            .frame(height: h / CGFloat(gridLevels + 1))
                    }
                    Spacer()
                    Text("0")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .padding(.bottom, 18)
                }
                .frame(width: yAxisWidth)

                // Chart area
                ZStack(alignment: .bottom) {
                    // Horizontal grid lines at consistent time intervals
                    ForEach(1...gridLevels, id: \.self) { level in
                        let val = gridInterval * Double(level)
                        let y = h - (CGFloat(val / adjustedMax) * h)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: chartWidth, y: y))
                        }
                        .stroke(Color.emerald700.opacity(0.25), style: StrokeStyle(lineWidth: 1))
                    }

                    // Vertical grid lines for each data point
                    if data.count > 1 {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, _ in
                            let x = chartWidth * CGFloat(index) / CGFloat(data.count - 1)
                            Path { p in
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: h))
                            }
                            .stroke(Color.emerald700.opacity(0.2), style: StrokeStyle(lineWidth: 1))
                        }
                    }

                    if data.count > 1 {
                        // Gradient fill
                        chartFillPath(width: chartWidth, height: h, maxVal: adjustedMax)
                            .fill(
                                LinearGradient(
                                    colors: [Color.emerald500.opacity(0.25), Color.emerald500.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Line
                        chartLinePath(width: chartWidth, height: h, maxVal: adjustedMax)
                            .trim(from: 0, to: lineProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.emerald600, Color.goldPrimary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )

                        // Data points
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                            let x = chartWidth * CGFloat(index) / CGFloat(data.count - 1)
                            let y = h - (CGFloat(point.minutes / adjustedMax) * h)

                            Circle()
                                .fill(selectedIndex == index ? Color.goldPrimary : Color.emerald700)
                                .frame(width: selectedIndex == index ? 10 : 6, height: selectedIndex == index ? 10 : 6)
                                .shadow(color: Color.emerald700.opacity(0.3), radius: 3, x: 0, y: 2)
                                .position(x: x, y: y)
                        }

                        // Selected tooltip
                        if let idx = selectedIndex, idx < data.count {
                            let x = chartWidth * CGFloat(idx) / CGFloat(data.count - 1)
                            let y = h - (CGFloat(data[idx].minutes / adjustedMax) * h)

                            Path { p in
                                p.move(to: CGPoint(x: x, y: y + 8))
                                p.addLine(to: CGPoint(x: x, y: h))
                            }
                            .stroke(Color.goldPrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            VStack(spacing: 1) {
                                Text("\(Int(data[idx].minutes))m")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(data[idx].dateLabel)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.emerald800)
                            .cornerRadius(8)
                            .position(x: max(30, min(chartWidth - 30, x)), y: max(20, y - 28))
                        }
                    }

                    // X-axis labels
                    HStack(spacing: 0) {
                        ForEach(Array(xAxisPoints().enumerated()), id: \.offset) { index, point in
                            let isToday = point.dataIndex < data.count && Calendar.current.isDateInToday(data[point.dataIndex].date)
                            let isSelected = selectedIndex == point.dataIndex
                            Text(point.label)
                                .font(.system(size: 10, weight: isSelected || isToday ? .bold : .regular))
                                .foregroundColor(isSelected ? .goldPrimary : (isToday ? .emerald800 : .textTertiary))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .offset(y: 16)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard data.count > 1 else { return }
                            let step = chartWidth / CGFloat(data.count - 1)
                            let idx = Int(round(value.location.x / step))
                            let clamped = max(0, min(data.count - 1, idx))
                            if clamped != selectedIndex {
                                Haptic.selection()
                                selectedIndex = clamped
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                selectedIndex = nil
                            }
                        }
                )
            }
        }
        .onAppear {
            lineProgress = 0
            withAnimation(.easeOut(duration: 1.2)) {
                lineProgress = 1
            }
        }
    }

    /// Produces abbreviated x-axis labels (skip some if there are too many points)
    private func xAxisPoints() -> [(label: String, dataIndex: Int)] {
        guard !data.isEmpty else { return [] }
        if data.count <= 7 {
            return data.enumerated().map { (label: $0.element.dayOfWeek, dataIndex: $0.offset) }
        }
        // For month/year views, show ~7 evenly-spaced labels
        let step = max(data.count / 7, 1)
        var result: [(String, Int)] = []
        for i in stride(from: 0, to: data.count, by: step) {
            result.append((data[i].dayOfWeek, i))
        }
        if let last = result.last, last.1 != data.count - 1 {
            result.append((data[data.count - 1].dayOfWeek, data.count - 1))
        }
        return result.map { (label: $0.0, dataIndex: $0.1) }
    }

    private func yAxisLabel(_ val: Double) -> String {
        if val >= 60 {
            let h = Int(val / 60)
            let m = Int(val) % 60
            return m > 0 ? "\(h)h\(m)" : "\(h)h"
        }
        return "\(Int(val))m"
    }

    /// Calculate nice round grid intervals (15m, 30m, 1h, 2h, etc.)
    private func calculateGridInterval(maxValue: Double) -> Double {
        let niceIntervals: [Double] = [15, 30, 60, 90, 120, 180, 240, 300, 360, 480, 600]
        // Find an interval that gives us 2-4 grid lines
        for interval in niceIntervals {
            let levels = Int(ceil(maxValue / interval))
            if levels >= 2 && levels <= 4 {
                return interval
            }
        }
        // Fallback: divide max into ~3 parts
        return ceil(maxValue / 3 / 15) * 15
    }

    private func chartLinePath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            let points = data.enumerated().map { index, point -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(data.count - 1)
                let y = height - (CGFloat(point.minutes / maxVal) * height)
                return CGPoint(x: x, y: y)
            }
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                path.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
            }
        }
    }

    private func chartFillPath(width: CGFloat, height: CGFloat, maxVal: Double) -> Path {
        Path { path in
            let points = data.enumerated().map { index, point -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(data.count - 1)
                let y = height - (CGFloat(point.minutes / maxVal) * height)
                return CGPoint(x: x, y: y)
            }
            guard points.count > 1 else { return }
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midX = (prev.x + curr.x) / 2
                path.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
            }
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
