// EnhancedChartView.swift
// Comprehensive chart with animations and details

import SwiftUI

struct EnhancedChartView: View {
    let data: [ChartDataPoint]
    @State private var animatedValues: [Double] = []
    @State private var selectedIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: Spacing.spacing16) {
            // Chart with interaction
            ZStack(alignment: .bottom) {
                // Background grid
                chartGrid
                
                // Line chart with gradient fill
                chartPath
                    .stroke(
                        LinearGradient(
                            colors: [Color.emerald600, Color.emerald700],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                
                // Gradient fill under line
                chartPath
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.emerald500.opacity(0.3),
                                Color.emerald600.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Data points
                dataPoints
            }
            .frame(height: 140)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(at: value.location)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3)) {
                            selectedIndex = nil
                        }
                    }
            )
            
            // X-axis labels
            HStack {
                ForEach(data.indices, id: \.self) { index in
                    Text(data[index].dayOfWeek)
                        .font(.caption)
                        .foregroundColor(selectedIndex == index ? .goldPrimary : .textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            animateIn()
        }
    }
    
    private var chartGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4) { _ in
                Divider()
                    .background(Color.borderDefault.opacity(0.3))
                Spacer()
            }
        }
    }
    
    private var chartPath: Path {
        Path { path in
            guard !data.isEmpty else { return }
            let maxValue = data.map { $0.minutes }.max() ?? 1
            let width = UIScreen.main.bounds.width - (Spacing.spacing20 * 2) - Spacing.spacing40
            let spacing = width / CGFloat(data.count - 1)
            
            for (index, point) in animatedValues.enumerated() {
                let x = CGFloat(index) * spacing
                let normalizedValue = CGFloat(point / maxValue)
                let y = 140 * (1 - normalizedValue)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // Close path for fill
            if let lastX = animatedValues.indices.last {
                let spacing = width / CGFloat(data.count - 1)
                path.addLine(to: CGPoint(x: CGFloat(lastX) * spacing, y: 140))
                path.addLine(to: CGPoint(x: 0, y: 140))
            }
        }
    }
    
    private var dataPoints: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.minutes }.max() ?? 1
            let width = geometry.size.width
            let spacing = width / CGFloat(data.count - 1)
            
            ForEach(data.indices, id: \.self) { index in
                let normalizedValue = CGFloat(animatedValues[safe: index] ?? 0) / CGFloat(maxValue)
                let x = CGFloat(index) * spacing
                let y = 140 * (1 - normalizedValue)
                
                ZStack {
                    // Outer ring (when selected)
                    if selectedIndex == index {
                        Circle()
                            .stroke(Color.goldPrimary.opacity(0.3), lineWidth: 12)
                            .frame(width: 20, height: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Data point
                    Circle()
                        .fill(selectedIndex == index ? Color.goldPrimary : Color.emerald600)
                        .frame(width: selectedIndex == index ? 12 : 6, height: selectedIndex == index ? 12 : 6)
                        .shadow(color: Color.emerald600.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    // Value label (when selected)
                    if selectedIndex == index {
                        Text("\(Int(data[index].minutes)) min")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.emerald900)
                                    .shadow(color: Color.emerald900.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                            .offset(y: -30)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .position(x: x, y: y)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
            }
        }
    }
    
    private func animateIn() {
        animatedValues = Array(repeating: 0, count: data.count)
        
        for index in data.indices {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05)) {
                animatedValues[index] = data[index].minutes
            }
        }
    }
    
    private func updateSelection(at location: CGPoint) {
        let width = UIScreen.main.bounds.width - (Spacing.spacing20 * 2) - Spacing.spacing40
        let spacing = width / CGFloat(data.count - 1)
        let index = Int((location.x / spacing).rounded())
        
        if index >= 0 && index < data.count {
            withAnimation(.spring(response: 0.3)) {
                selectedIndex = index
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
