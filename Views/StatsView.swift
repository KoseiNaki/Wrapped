// File: Views/StatsView.swift
import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @StateObject private var appState = AppState.shared
    @State private var selectedPeriod = "4 Weeks"
    @Environment(\.dismiss) private var dismiss
    @State private var contentAppeared = false

    private let periods = ["4 Weeks", "6 Months", "All Time"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.spacing24) {
                headerSection

                if let topArtist = viewModel.stats?.topArtists.first {
                    topArtistHero(artist: topArtist)
                }

                PeriodPicker(selection: $selectedPeriod, options: periods)
                    .padding(.horizontal)

                // Genre breakdown
                if let genres = viewModel.stats?.topGenres, !genres.isEmpty {
                    genreBreakdownSection(genres: Array(genres.prefix(5)))
                }

                topArtistsSection

                topTracksSection

                listeningTrendSection
            }
            .padding(.bottom, Spacing.spacing32)
        }
        .background(Color.bgPrimary)
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
        .preferredColorScheme(.light)
        .task {
            guard let jwt = try? KeychainManager.shared.getToken() else { return }
            await viewModel.loadStats(jwt: jwt)
            withAnimation(.easeOut(duration: 0.4)) { contentAppeared = true }
        }
        .onChange(of: selectedPeriod) { newValue in
            let period = periodToStatsPeriod(newValue)
            Task {
                await viewModel.changePeriod(to: period)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing4) {
            Text("YOUR STATS")
                .font(.labelSmall)
                .foregroundColor(.goldPrimary)
            Text("Deep Dive")
                .font(.displayLarge)
                .foregroundColor(.emerald900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, Spacing.spacing8)
    }

    // MARK: - Top Artist Hero
    private func topArtistHero(artist: TopArtistResponse) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            if let imageUrl = artist.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.emerald800)
                }
            } else {
                Rectangle().fill(
                    LinearGradient(colors: [.emerald700, .emerald900], startPoint: .top, endPoint: .bottom)
                )
            }

            // 3-stop gradient overlay
            LinearGradient(
                colors: [
                    .clear,
                    Color.emerald900.opacity(0.5),
                    Color.emerald900.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: Spacing.spacing8) {
                // Badge
                Text("#1 ARTIST")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.emerald900)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.goldPrimary)
                    .cornerRadius(Radius.full)

                Text(artist.name)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                HStack(spacing: Spacing.spacing16) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                        Text("\(artist.playCount) streams")
                            .font(.bodySmall)
                    }
                    .foregroundColor(.goldPrimary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(formatMinutes(artist.totalMinutes))
                            .font(.bodySmall)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(Spacing.spacing20)
        }
        .frame(height: 280)
        .cornerRadius(Radius.xLarge)
        .padding(.horizontal)
        .heroShadow()
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 20)
    }

    // MARK: - Genre Breakdown
    private func genreBreakdownSection(genres: [TopGenreResponse]) -> some View {
        let maxCount = Double(genres.map { $0.playCount }.max() ?? 1)
        
        return VStack(alignment: .leading, spacing: Spacing.spacing16) {
            SectionHeader(title: "Top Genres")
                .padding(.horizontal)

            VStack(spacing: Spacing.spacing12) {
                ForEach(Array(genres.enumerated()), id: \.element.genre) { index, genre in
                    HStack(spacing: Spacing.spacing12) {
                        Text(genre.genre.capitalized)
                            .font(.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(.emerald900)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            let barWidth = geo.size.width * CGFloat(Double(genre.playCount) / maxCount)
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.emerald50)
                                    .frame(height: 24)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.emerald600, Color.emerald700],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: barWidth, height: 24)
                                    .overlay(
                                        // Gold tip
                                        HStack {
                                            Spacer()
                                            Circle()
                                                .fill(Color.goldPrimary)
                                                .frame(width: 6, height: 6)
                                                .padding(.trailing, 6)
                                        }
                                    )
                            }
                        }
                        .frame(height: 24)
                        
                        Text("\(genre.playCount)")
                            .font(.captionBold)
                            .foregroundColor(.textSecondary)
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .premiumCard()
            .padding(.horizontal)
        }
    }

    // MARK: - Top Artists List
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Top Artists")
                .padding(.horizontal)

            VStack(spacing: 0) {
                if let artists = viewModel.stats?.topArtists {
                    ForEach(Array(artists.dropFirst().prefix(5).enumerated()), id: \.element.id) { index, artist in
                        TrackRow(
                            rank: index + 2,
                            imageUrl: artist.imageUrl,
                            title: artist.name,
                            subtitle: formatMinutes(artist.totalMinutes),
                            trailing: formatNumber(artist.playCount),
                            trailingLabel: "streams",
                            isHighlighted: index == 0
                        )
                        .padding(.horizontal, Spacing.spacing4)

                        if index < min(artists.count - 2, 4) {
                            Divider().padding(.leading, 80)
                        }
                    }
                } else {
                    ForEach(0..<3, id: \.self) { _ in ShimmerRow() }
                }
            }
            .premiumCard()
            .padding(.horizontal)
        }
    }

    // MARK: - Top Tracks List
    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Top Tracks")
                .padding(.horizontal)

            VStack(spacing: 0) {
                if let tracks = viewModel.stats?.topTracks {
                    ForEach(Array(tracks.prefix(6).enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            rank: index + 1,
                            imageUrl: track.albumImageUrl,
                            title: track.name,
                            subtitle: track.artistNames.joined(separator: ", "),
                            trailing: formatDuration(track.totalMinutes),
                            trailingLabel: nil,
                            isHighlighted: index == 0
                        )
                        .padding(.horizontal, Spacing.spacing4)

                        if index < min(tracks.count - 1, 5) {
                            Divider().padding(.leading, 80)
                        }
                    }
                } else {
                    ForEach(0..<3, id: \.self) { _ in ShimmerRow() }
                }
            }
            .premiumCard()
            .padding(.horizontal)
        }
    }

    // MARK: - Listening Trend
    private var listeningTrendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            SectionHeader(title: "Listening Trend")
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: Spacing.spacing12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity Over Time")
                            .font(.h3)
                            .foregroundColor(.emerald900)
                        Text("Daily listening minutes")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                }

                InteractiveChartView(data: viewModel.getChartData())
                    .frame(height: 140)
            }
            .premiumCard()
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers
    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 { return String(format: "%.1fk", Double(num) / 1000) }
        return "\(num)"
    }

    private func formatDuration(_ minutes: Double) -> String {
        let mins = Int(minutes)
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins)m"
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes / 60)
        let mins = Int(minutes) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }

    private func periodToStatsPeriod(_ period: String) -> StatsPeriod {
        switch period {
        case "4 Weeks": return .month
        case "6 Months": return .year
        case "All Time": return .all
        default: return .month
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { StatsView() }
    }
}
