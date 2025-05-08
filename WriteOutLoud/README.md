# Write Out Loud

## Project Information

**Repository:** [https://github.com/junruren/Write-Out-Loud](https://github.com/junruren/Write-Out-Loud)

**Course:** MIT 6.8510 Intelligent Multimodal User Interfaces

**Description:** A multimodal Chinese character learning application that combines handwriting input with speech recognition to provide an immersive learning experience.

## Setup Instructions

### Requirements

- **Hardware:**
  - iPad with Apple Pencil support
  - Mac computer for development

- **Software:**
  - macOS 13.0+ (Ventura or newer)
  - Xcode 14.0+ (with iOS/iPadOS SDK 14.0+)
  - Git (for cloning the repository)

### Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/junruren/Write-Out-Loud.git
   cd Write-Out-Loud
   ```

2. **Open the project in Xcode:**
   ```bash
   open WriteOutLoud/WriteOutLoud.xcodeproj
   ```

3. **Configure development team:**
   - In Xcode, select the WriteOutLoud project in the Navigator
   - Select the WriteOutLoud target
   - Under the Signing & Capabilities tab, select your development team

4. **Connect your iPad:**
   - Connect your iPad to your Mac
   - In Xcode, select your iPad as the deployment target

5. **Build and run:**
   - Click the Run button in Xcode or press Cmd+R
   - The app will be installed and launched on your iPad

### Required Permissions

The app requires the following permissions which you'll need to grant when prompted:
- Microphone access (for speech recognition)
- Speech recognition

## Files and Directory Structure

The project follows a standard Model-View-Controller (MVC) inspired pattern, adapted for SwiftUI's declarative nature, with additional utility and controller components.

<pre>
```text
WriteOutLoud/
├── Models/
│   ├── Character.swift           # Defines the main data structure for a Chinese character (incl. strokeCount).
│   ├── Stroke.swift              # Defines the data structure for a single stroke within a character.
│   ├── StrokeType.swift          # Enum defining basic and compound stroke types (raw values match JSON).
│   └── CharacterDataManager.swift# Manages loading, storing, and providing character data (from JSON or samples), including images and GIFs.
│
├── Views/
│   ├── MainView.swift            # Central coordinating view. Manages controllers, state (completion, interaction), delegates, and subviews. Creates final colored feedback drawing.
│   ├── ReferenceView.swift       # Displays character info (static image, pinyin, meaning) and animated stroke order GIF (Left Panel).
│   ├── WritingPaneView.swift     # Container for the writing area. Includes StrokeInfoBar, StrokeNamePill, trace image guide, transcript display, and the main canvas area. Handles tap-to-reset.
│   ├── CanvasView.swift          # SwiftUI wrapper for the interactive PKCanvasView.
│   ├── GifImageView.swift        # SwiftUI wrapper for WKWebView to display animated GIFs from Data.
│   ├── CharacterSelectionView.swift# Horizontal scroll view for selecting characters.
│   ├── StrokeView.swift          # Used for displaying and drawing individual strokes.
│   ├── ButtonStyles.swift        # Custom SwiftUI ButtonStyle definitions.
│   └── GuideView.swift           # Guide view for displaying stroke information.
│
├── Controllers/
│   ├── StrokeInputController.swift # Manages PKCanvasView interaction, captures stroke points and timings. Tracks current expected stroke index.
│   ├── SpeechRecognitionController.swift # Manages microphone input, audio processing, and speech recognition via SFSpeechRecognizer. Includes continuous recording, speech segmentation, and similar-sounding word matching.
│   ├── ConcurrencyAnalyzer.swift # Analyzes stroke accuracy, speech correctness (name match), and timing overlap. Calculates scores and stores analysis history.
│   └── FeedbackController.swift  # Simplified: Manages final score calculation state, plays feedback sounds. Does not directly drive UI views.
│
├── Utils/
│   ├── StrokeAnalysis.swift      # Logic for detailed stroke accuracy calculation (shape, direction, position, proportion).
│   ├── TimestampSynchronizer.swift # Helper functions for calculating overlap and lag between time intervals (stroke vs. speech).
│   ├── PathUtils.swift           # Utility functions for CGPoint array processing (scaling, bounding box, etc.).
│   ├── SpeechSynthesizer.swift   # Utility for text-to-speech functionality to pronounce stroke names.
│   └── Extensions.swift          # Useful Swift extensions (safe subscripting, CGRect diagonal).
│
└── Other/
├── WriteOutLoudApp.swift     # Main application entry point (SwiftUI App lifecycle).
├── Assets.xcassets           # Stores static images (character references, trace guides, app icons).
├── Characters/               # (Suggested) Folder for GIF animation files (e.g., kou_order.gif) - Add to Target Membership.
├── Sounds/                   # (Suggested) Folder for sound files (e.g., excellent_sound.mp3) - Add to Target Membership.
└── characters.json           # Optional: JSON file for character data if not using only sample data. Must include strokeCount.
```
</pre>

**File Details:**

* **Models:** Define core data. `CharacterDataManager` loads `Character` objects, images (Assets), and GIF data (Bundle). `Character` now requires `strokeCount`.
* **Views:** Handle UI.
    * `MainView`: Orchestrates the flow, manages key state (`isCharacterPracticeComplete`, `isCanvasInteractionEnabled`, `finalDrawingWithFeedback`), handles delegate callbacks, creates the final colored drawing.
    * `ReferenceView`: Shows static info and GIF animation.
    * `WritingPaneView`: Contains the writing area, including `StrokeInfoBar` and `StrokeNamePill` implementations, trace image, real-time transcript display, interactive canvas (during practice) or static canvas (for feedback). Handles tap-to-reset gesture. Controlled by `isInteractionEnabled`.
    * `CanvasView`: Wrapper for the interactive `PKCanvasView`.
    * `StaticCanvasView`: Helper to display the final, non-interactive colored drawing.
* **Controllers:** Manage logic.
    * `StrokeInputController`: Handles drawing input via `PKCanvasViewDelegate`.
    * `SpeechRecognitionController`: Handles voice input via `SFSpeechRecognizer`. Now features continuous recording during character practice, speech segmentation based on stroke timing, and similar-sounding word matching for Chinese pronunciations.
    * `ConcurrencyAnalyzer`: Performs analysis, stores results in `analysisHistory`.
    * `FeedbackController`: Simplified; calculates final scores, plays sounds.
* **Utils:** Helper functions.
    * `SpeechSynthesizer`: Provides text-to-speech functionality for pronouncing stroke names.
* **Other:** App entry, Assets, optional JSON data, GIF/Sound file locations.

## 1. Introduction

Write Out Loud is an iPadOS application designed to help users learn Chinese characters through a multimodal approach. It combines handwriting input (using Apple Pencil) with simultaneous speech input (vocalizing stroke names). The app provides feedback *after* the user completes writing the entire character, focusing on reinforcing stroke order memory and improving handwriting quality.

The reference panel (left) shows a static image of the character, its pinyin/meaning, and an animated GIF demonstrating the correct stroke order. The writing panel (right) contains the drawing canvas where the user writes. During practice, a top bar displays the sequence of stroke names ("Number. Pinyin ChineseChar") and the current transcript. After completion, this bar shows vocalization feedback (correct/incorrect icons), and the user's drawn strokes on the canvas are colored based on accuracy (inaccurate strokes turn red). Tapping the canvas after feedback resets the attempt.

This project is built using SwiftUI for the user interface and leverages Apple's PencilKit for handwriting input and the Speech framework for voice recognition.

## 2. Project Structure and File Descriptions

The project follows a standard Model-View-Controller (MVC) inspired pattern, adapted for SwiftUI's declarative nature, with additional utility and controller components.

## 3. Logic and Pipeline

The application allows users to select a character and practice writing it stroke by stroke while attempting to vocalize the stroke name concurrently. Feedback is provided only *after* the entire character is completed.

1.  **Initialization & Character Selection:**
    * `CharacterDataManager` loads character data (JSON or samples).
    * `MainView` initializes controllers and sets delegates. `CharacterSelectionView` displays choices.
    * User selects a character.
    * `CharacterDataManager` updates `@Published var currentCharacter`.
    * `MainView.handleCharacterChange` is triggered:
        * Resets state (`isCharacterPracticeComplete = false`, `finalDrawingWithFeedback = nil`).
        * Calls `resetForNewCharacterAttempt`.
        * Enables canvas interaction (`isCanvasInteractionEnabled = true`).
        * Configures controllers (`StrokeInputController`, `SpeechRecognitionController`, `ConcurrencyAnalyzer`, `FeedbackController`) for the selected character.
        * Prepares `SpeechRecognitionController` for the first stroke's name.
    * `ReferenceView` updates.
    * `WritingPaneView` shows the trace image and enables the interactive `CanvasView`. `StrokeInfoBar` shows the stroke sequence, highlighting the first stroke.

2.  **Stroke and Speech Input Loop (Per Stroke):**
    * User starts drawing the `currentStrokeIndex` stroke on the `PKCanvasView`.
    * `StrokeInputController` detects `canvasViewDidBeginUsingTool`.
    * `MainView` (delegate `strokeBegan`):
        * Clears previous temporary data (`currentStrokeAttemptData`).
        * Calls `speechRecognitionController.startRecording()`.
    * User draws the stroke and speaks the name.
    * `StrokeInputController` captures points. `SpeechRecognitionController` processes audio continuously.
    * User finishes drawing the stroke.
    * `StrokeInputController` detects `canvasViewDidEndUsingTool`.
    * `MainView` (delegate `strokeEnded`):
        * Creates `currentStrokeAttemptData` with drawn points, timing, etc.
        * Calls `speechRecognitionController.processStrokeCompletion()` which segments speech based on stroke timing.
        * If speech wasn't detected, calls `processCompletedStrokeAttempt` immediately. Otherwise, waits for speech result.
    * **Speech Result:** `SpeechRecognitionController` calls `speechTranscriptionFinalized` delegate in `MainView`, providing matched speech segments for each stroke.
    * `MainView` (speech delegate methods): Updates `currentStrokeAttemptData` with speech results. Calls `processCompletedStrokeAttempt()`.
    * **Processing:** `MainView.processCompletedStrokeAttempt`: Retrieves `StrokeAttemptData`, calls `StrokeAnalysis.calculateAccuracy`, packages data into `StrokeAnalysisInput`, calls `concurrencyAnalyzer.analyzeStroke`.
    * **Concurrency Analysis:** `ConcurrencyAnalyzer.analyzeStroke`: Calculates scores, stores results in `analysisHistory`, calls `strokeAnalysisCompleted` delegate in `MainView`.
    * **Post-Analysis:** `MainView` (delegate `strokeAnalysisCompleted`):
        * Stores feedback text internally (optional).
        * Clears `currentStrokeAttemptData`.
        * Calls `moveToNextStrokeAction` to advance the state (`strokeInputController.checkCompletionAndAdvance`).
        * If more strokes remain, `prepareForSpeech` is called for the next stroke index. `StrokeInfoBar` updates highlight.
        * If **last stroke** was just analyzed:
            * `strokeInputController.checkCompletionAndAdvance` calls the `allStrokesCompleted` delegate in `MainView`.

3.  **End of Character & Final Feedback:**
    * `MainView` (delegate `allStrokesCompleted`):
        * Sets `isCanvasInteractionEnabled = false` immediately.
        * Calls `showFinalResultsAction`.
    * `MainView.showFinalResultsAction`: Calls `concurrencyAnalyzer.calculateFinalCharacterScore`.
    * `ConcurrencyAnalyzer` calculates final scores and calls `overallAnalysisCompleted` delegate in `MainView`.
    * `MainView` (delegate `overallAnalysisCompleted`):
        * Gets the final `PKDrawing` from the interactive `pkCanvasView`.
        * Iterates through `concurrencyAnalyzer.analysisHistory`. For each analyzed stroke:
            * Finds the corresponding stroke in the `PKDrawing`.
            * Creates a *new* `PKStroke` based on the drawn one.
            * If accuracy < threshold (60%), sets the new stroke's ink color to red. Otherwise, sets it to green for correct strokes.
            * Appends the recolored new stroke to a list.
        * Appends any extra drawn strokes (beyond the expected count) with their original color.
        * Creates `finalFeedbackDrawing = PKDrawing(strokes: coloredStrokes)`.
        * Calls `feedbackController.calculateAndPresentOverallFeedback` (plays sound).
        * Sets `finalDrawingWithFeedback` state variable.
        * Sets `isCharacterPracticeComplete = true`.
    * **UI Update:**
        * `WritingPaneView` detects `isCharacterPracticeComplete = true`.
        * It hides the interactive `CanvasView` and displays the static `finalDrawingWithFeedback` using `StaticCanvasView`.
        * `StrokeInfoBar` detects `isCharacterPracticeComplete = true` and switches to showing vocalization feedback icons based on `analysisHistory`.

4.  **Resetting for New Attempt:**
    * The `WritingPaneView` (specifically the `GeometryReader` containing the `ZStack`) has an `.onTapGesture`.
    * If `isPracticeComplete` is true, tapping this area calls the `onTapToWriteAgain` closure provided by `MainView`.
    * `MainView.onTapToWriteAgain` (which is `resetForNewCharacterAttempt`):
        * Resets all controllers and state variables (`finalDrawingWithFeedback = nil`, `isCharacterPracticeComplete = false`).
        * Clears the interactive `pkCanvasView.drawing`.
        * Re-enables canvas interaction (`isCanvasInteractionEnabled = true`).
        * Prepares for the first stroke of the current character.

## 4. Dependencies and Assets

**Frameworks:**

* SwiftUI (UI Framework)
* PencilKit (Handwriting Input & Canvas)
* Speech (Speech Recognition)
* AVFoundation (Audio Engine & Session Management for Speech, Sound Playback, Text-to-Speech)
* Combine (Used for `@Published` properties and reactive UI updates)
* CoreGraphics (Used for CGPoint, CGRect etc.)
* WebKit (Used by `GifImageView` to display animated GIFs)
* UIKit (Used for `UIColor`, `UIImage`)

**Required Assets:**

* **Character Data (`characters.json`):** (Optional, if not using samples) Needs to be in the app bundle, formatted according to the `Character` and `Stroke` Codable implementation. Must include `normalImageName`, `traceImageName`, `animationImageName`, and `strokeCount` fields for each character. Stroke paths and bounding boxes should be defined appropriately.
* **Static Images (`Assets.xcassets`):** Character images (`normalImageName`, `traceImageName` referenced in Character data) should be placed in `Assets.xcassets`. The Image Set names must exactly match those specified in the character data. Placeholders are used if images are missing.
* **Animated GIFs (Project Bundle / `Characters/`):** Stroke order animation GIFs (e.g., `kou_order.gif`). The base filename (without `.gif`) must match the `animationImageName` specified in the character data. These files need to be added to the project and included in the Target Membership.
* **Sounds (Project Bundle / `Sounds/`):** Feedback sounds (`excellent_sound.mp3`, `good_sound.mp3`, `ok_sound.mp3`, `try_again_sound.mp3` referenced in `FeedbackController`) need to be added to the project bundle and included in the Target Membership.

**Permissions:**

The app requires user permission for Microphone Access and Speech Recognition. Ensure the `Info.plist` (or Target Info tab) contains the necessary keys and descriptions:

* `NSSpeechRecognitionUsageDescription`: Explain why the app needs speech recognition (e.g., "To recognize spoken stroke names for practice feedback.").
* `NSMicrophoneUsageDescription`: Explain why the app needs microphone access (e.g., "To capture audio for recognizing spoken stroke names.").

## 5. Important Notes for Collaborators

* **Continuous Speech Recognition:** The app now maintains a continuous recording session during character practice, rather than stopping/starting between strokes. This provides a more natural experience and better handles speech that spans stroke boundaries.

* **Speech Segmentation:** Speech is now segmented based on stroke timing. The `SpeechRecognitionController` intelligently assigns recognized speech to the appropriate strokes based on when each stroke was drawn.

* **Similar-Sounding Word Recognition:** The app now recognizes similar-sounding Chinese words and treats them as correct matches. For example, saying "树" (shù) will be recognized as a match for "竖" (shù) since they have the same pronunciation.

* **Real-time Transcript Display:** The transcript is now displayed in real-time below the instruction "Vocalize your stroke while writing" and remains visible throughout the practice session. The "Show Real-time Transcript" toggle is positioned on the right side with the label next to the switch.

* **Playable Stroke Names:** The speaker icon in the `StrokeNamePill` component now allows users to hear the pronunciation of each stroke name at any time, including in the results page.

* **UI Improvements:** The "Characters Selection" title is now left-aligned for better readability, and the transcript container maintains a stable frame even when toggled off to prevent layout shifts.

* **Color Coding:** Correct stroke pronunciations are now displayed in green, incorrect in red, and undetected in gray (previously orange) in both the transcript history and stroke info bar.

* **Delayed Feedback:** All visual feedback (stroke coloring, pronunciation icons) is intentionally delayed until the *entire* character writing attempt is complete. No per-stroke visual feedback is shown during writing.

* **Final Drawing Coloring:** `MainView` is responsible for creating the final `PKDrawing` with colored strokes in the `overallAnalysisCompleted` delegate. It iterates through the *analysis history* and colors the corresponding strokes in a *copy* of the user's drawing.

* **Stroke Accuracy Threshold:** The accuracy threshold for coloring strokes has been lowered from 70% to 60% to be more accommodating of slight variations in stroke shape.

* **Reduced Processing Delay:** The delay after stroke completion has been reduced from 0.6 seconds to 0.3 seconds to enhance responsiveness during fast writing while still allowing time for speech processing.

* **Background Processing:** Heavy stroke analysis calculations are now performed on a background thread to prevent UI blockage and improve the app's responsiveness during fast writing.

* **Stroke Info Bar:** The `StrokeInfoBar` in `WritingPaneView` displays the stroke sequence ("Number. Pinyin ChineseChar") during practice and switches to vocalization icons (checkmark/cross/question mark) after completion. Text color adjusts properly for dark mode.

* **Interaction Lock & Reset:** The canvas is disabled (`allowsHitTesting(false)`) via `isCanvasInteractionEnabled` state in `MainView` immediately after the last stroke ends and during final feedback display. Tapping the writing pane *after* feedback is shown triggers a reset via the `onTapToWriteAgain` closure passed from `MainView`.

* **Stroke Count Mismatch Handling:** The final feedback coloring logic in `MainView` now handles cases where the number of strokes drawn by the user doesn't exactly match the number of analyzed strokes, preventing crashes. Extra drawn strokes are shown with their original color.

* **Data Source:** Ensure `characters.json` (or sample data) is correctly formatted and includes the `strokeCount` field. Verify asset names match those used in the data.

* **Error Handling:** Basic error handling logs messages. Speech recognition errors (like no speech detected) are handled gracefully by marking the attempt as failed/unavailable. Consider adding more user-facing alerts for critical issues (e.g., permission denial, data loading failures).

* **SwiftUI State Management:** The app uses `@StateObject`, `@EnvironmentObject`, `@State`, and delegate patterns for state management and communication. Pay attention to main thread updates (`DispatchQueue.main.async`) when updating UI-related state from background threads or delegate callbacks.

* **Asset Inclusion:** Double-check that all required images (`.png`/`.jpg` in Assets), GIFs (`.gif` in Bundle), and Sounds (`.mp3` in Bundle) are correctly added to the Xcode project and included in the Target Membership for the main application target.

