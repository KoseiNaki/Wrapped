// ScrollOffsetPreferenceKey.swift
// Tracks scroll position for blur effects

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetModifier: ViewModifier {
    let coordinateSpace: String
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named(coordinateSpace)).minY
                    )
                }
            )
    }
}

extension View {
    func readScrollOffset(in coordinateSpace: String) -> some View {
        modifier(ScrollOffsetModifier(coordinateSpace: coordinateSpace))
    }
}
