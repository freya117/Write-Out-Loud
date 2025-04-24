// File: Views/ReferenceView.swift
// VERSION: Adjusted image/GIF sizes and spacing (Image Larger, GIF Smaller, White GIF BG)

import SwiftUI

/**
 Displays the reference information for the current character, including a
 static image, pinyin, meaning, and an animated GIF showing stroke order.
 */
struct ReferenceView: View {
    // MARK: - Properties
    let character: Character?

    // Access DataManager to load images and GIF data
    @EnvironmentObject var characterDataManager: CharacterDataManager

    // MARK: - Body
    var body: some View {
        // Use GeometryReader to make GIF size relative if needed
        GeometryReader { geometry in
            VStack(spacing: 0) { // Remove default spacing, control manually
                if let character = character {

                    // --- Header: Static Image, Pinyin, Meaning ---
                    characterInfoHeader(character: character)
                         // Give header padding at bottom
                        .padding(.bottom, geometry.size.height * 0.05) // e.g., 5% of height

                    // --- Animated GIF Area ---
                    gifAnimationArea(character: character, containerSize: geometry.size) // Pass size
                         // Use remaining flexible space for the GIF container
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom) // Padding below GIF

                    Spacer() // Pushes content towards top

                } else {
                    // Placeholder if no character selected
                    Spacer()
                    Text("Select a character")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding() // Padding for the whole VStack content
            .frame(width: geometry.size.width, height: geometry.size.height) // Fill the geometry reader
        }
    }

    // MARK: - Subviews

    /// Displays the static reference image, pinyin, and meaning.
    @ViewBuilder
    private func characterInfoHeader(character: Character) -> some View {
        VStack(alignment: .center, spacing: 10) {
            // --- Static Reference Image ---
            Group {
                if let uiImage = characterDataManager.getCharacterImage(character, type: .normal) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        // Keep larger frame size
                        .frame(maxWidth: 440, maxHeight: 440)
                } else {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(UIColor.systemGray6)) // Keep header background subtle gray
            .cornerRadius(10)

            // --- Pinyin and Meaning ---
            Text("\(character.pinyin) - \(character.meaning)")
                .font(.title2)
                .foregroundColor(.primary)
                .padding(.top, 5)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Displays the animated GIF using the GifImageView wrapper.
    @ViewBuilder
    private func gifAnimationArea(character: Character, containerSize: CGSize) -> some View {
         // Keep smaller GIF size
         let gifSize = min(containerSize.width, containerSize.height) * 0.35

        ZStack { // Use ZStack for centering
             // Background container
             RoundedRectangle(cornerRadius: 12)
                 // *** SET BACKGROUND TO WHITE ***
                 .fill(Color.white)
                 // Use slightly darker border for contrast on white
                 .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))

             // The GIF view itself
            Group {
                if let gifData = characterDataManager.getCharacterGifData(character) {
                    GifImageView(data: gifData)
                        .frame(width: gifSize, height: gifSize) // Apply smaller frame

                } else {
                    // Placeholder if GIF data loading fails
                     VStack {
                         Image(systemName: "film.slash")
                             .font(.largeTitle)
                             .foregroundColor(.secondary)
                         Text("Animation N/A")
                             .font(.caption)
                             .foregroundColor(.secondary)
                     }
                     .frame(width: gifSize, height: gifSize) // Apply frame to placeholder too
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow ZStack container to expand
    }
} // End of struct ReferenceView
