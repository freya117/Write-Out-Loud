// File: Views/CharacterSelectionView.swift
import SwiftUI

// MARK: - Character Selection Bar
struct CharacterSelectionView: View {
    @Binding var selectedIndex: Int
    let characters: [Character]
    var onSelect: (Int) -> Void // Closure to call when a character is selected

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(characters.indices, id: \.self) { index in
                    CharacterTile(
                        character: characters[index],
                        isSelected: index == selectedIndex
                    )
                    .onTapGesture {
                        selectedIndex = index
                        onSelect(index)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}

// MARK: - Character Tile Helper View
struct CharacterTile: View {
    let character: Character
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(character.character)
                .font(isSelected ? .title : .title2)
                .frame(minWidth: 50, minHeight: 50)
                .lineLimit(1)
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
        .cornerRadius(10)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Preview Provider
struct CharacterSelectionView_Previews: PreviewProvider {
    static let sampleCharacters = [
        Character(
            id: "1", character: "口", pinyin: "kǒu", meaning: "mouth",
            strokes: [], difficulty: 1, tags: [],
            normalImageName: "kou_normal", traceImageName: "kou_trace", animationImageName: "kou_anim"
        ),
        Character(
            id: "2", character: "日", pinyin: "rì", meaning: "sun/day",
            strokes: [], difficulty: 1, tags: [],
            normalImageName: "ri_normal", traceImageName: "ri_trace", animationImageName: "ri_anim"
        )
    ]

    @State static var previewSelectedIndex = 0

    static var previews: some View {
        CharacterSelectionView(
            selectedIndex: $previewSelectedIndex,
            characters: sampleCharacters,
            onSelect: { index in
                previewSelectedIndex = index
                print("Preview selected index: \(index)")
            }
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
