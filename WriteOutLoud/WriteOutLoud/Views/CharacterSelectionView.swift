// File: Views/CharacterSelectionView.swift
import SwiftUI

// MARK: - Character Selection Bar
struct CharacterSelectionView: View {
    @Binding var selectedIndex: Int
    let characters: [Character] // Expects the array of characters
    var onSelect: (Int) -> Void // Closure to call when a character is selected

    var body: some View {
        // Use a ScrollView to allow horizontal scrolling if many characters exist
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) { // Spacing between character tiles
                // Iterate over the indices of the characters array
                ForEach(characters.indices, id: \.self) { index in
                    // Display a tile for each character
                    CharacterTile(
                        character: characters[index], // Pass the character data
                        isSelected: index == selectedIndex // Highlight if selected
                    )
                    .onTapGesture {
                        // Update the selected index and call the callback when tapped
                        selectedIndex = index
                        onSelect(index)
                        print("CharacterSelectionView: Tapped index \(index)")
                    }
                }
            }
            .padding(.horizontal) // Add padding at the ends of the HStack
        }
        .frame(height: 80) // Set a fixed height for the selection bar
        // Add a background to make it visually distinct
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Character Tile Helper View
struct CharacterTile: View {
    let character: Character
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) { // Vertical stack for character and maybe pinyin later
            Text(character.character) // Display the Chinese character
                .font(isSelected ? .title : .title2) // Slightly larger font if selected
                .frame(minWidth: 50, minHeight: 50) // Ensure minimum size for tap target
                .lineLimit(1) // Prevent wrapping
        }
        .padding(8) // Padding inside the tile
        // Change background based on selection state
        .background(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
        .cornerRadius(10) // Rounded corners
        .scaleEffect(isSelected ? 1.05 : 1.0) // Slight scale effect when selected
        // Animate changes smoothly
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview Provider (Corrected Sample Data Initializer)
struct CharacterSelectionView_Previews: PreviewProvider {
    // Sample data for previewing
    // *** CORRECTED: Added strokeCount argument to initializer calls ***
    static let sampleCharacters = [
        Character(
            id: "1", character: "口", pinyin: "kǒu", meaning: "mouth",
            strokeCount: 3, // Added (value doesn't strictly matter for preview if strokes empty)
            strokes: [],
            normalImageName: "kou_normal", traceImageName: "kou_trace", animationImageName: "kou_anim"
        ),
        Character(
            id: "2", character: "日", pinyin: "rì", meaning: "sun/day",
            strokeCount: 4, // Added
            strokes: [],
            normalImageName: "ri_normal", traceImageName: "ri_trace", animationImageName: "ri_anim"
        ),
        Character(
            id: "3", character: "人", pinyin: "rén", meaning: "person",
            strokeCount: 2, // Added
            strokes: [],
            normalImageName: "ren_normal", traceImageName: "ren_trace", animationImageName: "ren_anim"
        )
    ]
    // *** END CORRECTION ***


    // State variable for the preview's selected index
    @State static var previewSelectedIndex = 0

    static var previews: some View {
        CharacterSelectionView(
            selectedIndex: $previewSelectedIndex, // Bind to the preview state
            characters: sampleCharacters, // Use corrected sample data
            onSelect: { index in
                // Action to perform when a tile is selected in the preview
                previewSelectedIndex = index
                print("Preview selected index: \(index)")
            }
        )
        .previewLayout(.sizeThatFits) // Adjust preview layout
        .padding()
        .background(Color.gray.opacity(0.1)) // Background for preview visibility
    }
}
