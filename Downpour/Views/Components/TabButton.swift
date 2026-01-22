//
//  TabButton.swift
//  Downpour
//

import SwiftUI

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
