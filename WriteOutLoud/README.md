# Write Out Loud - README

## 1. Introduction

Write Out Loud is an iPadOS application designed to help users learn Chinese characters through a multimodal approach. It combines handwriting input (using Apple Pencil) with simultaneous speech input (vocalizing stroke names). The app provides real-time feedback on stroke accuracy, stroke order adherence (implicitly through the guided process), and the correctness and timing of the spoken stroke names. The primary goal is to reinforce stroke order memory and improve handwriting quality, rather than focusing on perfect pronunciation.

This project is built using SwiftUI for the user interface and leverages Apple's PencilKit for handwriting input and the Speech framework for voice recognition.

## 2. Project Structure and File Descriptions

The project follows a standard Model-View-Controller (MVC) inspired pattern, adapted for SwiftUI's declarative nature, with additional utility and controller components.

<pre>
```text
WriteOutLoud/
├── Models/
│   ├── Character.swift               # Defines the main data structure for a Chinese character.
│   ├── Stroke.swift                  # Defines the data structure for a single stroke within a character.
│   ├── StrokeType.swift              # Enum defining basic stroke types (heng, shu, pie, etc.).
│   └── CharacterDataManager.swift    # Manages loading, storing, and providing character data (from JSON or samples).
│
├── Views/
│   ├── MainView.swift                # The central coordinating view, managing controllers and subviews. Acts as delegate.
│   ├── ReferenceView.swift           # Displays character info, stroke animation, and current stroke details (Left Panel).
│   ├── WritingPaneView.swift         # Container for the drawing area, including the guide and canvas (Right Panel).
│   ├── CanvasView.swift              # SwiftUI wrapper for PKCanvasView (the actual drawing surface).
│   ├── GuideView.swift               # Displays the faint background guide strokes for tracing.
│   ├── StrokeView.swift              # Renders a single stroke path, capable of animation.
│   ├── FeedbackView.swift            # Displays stroke-by-stroke or overall character feedback to the user.
│   ├── CharacterSelectionView.swift  # Horizontal scroll view for selecting characters.
│   └── ButtonStyles.swift            # Custom SwiftUI ButtonStyle definitions for consistent UI.
│
├── Controllers/
│   ├── StrokeInputController.swift   # Manages PKCanvasView interaction, captures stroke points and timings.
│   ├── SpeechRecognitionController.swift  # Manages microphone input, audio processing, and speech transcription via SFSpeechRecognizer.
│   ├── ConcurrencyAnalyzer.swift     # Analyzes stroke accuracy, speech correctness (name match), and timing overlap. Calculates scores and generates feedback messages.
│   └── FeedbackController.swift      # Manages the state and presentation logic for the FeedbackView, including audio feedback.
│
├── Utils/
│   ├── StrokeAnalysis.swift          # Logic for detailed stroke accuracy calculation (shape, direction, etc.).
│   ├── TimestampSynchronizer.swift   # Helper functions for calculating overlap and lag between time intervals (stroke vs. speech).
│   ├── PathUtils.swift               # Utility functions for CGPoint array processing (scaling, smoothing, bounding box, etc.).
│   └── Extensions.swift              # Useful Swift extensions (safe subscripting, CGRect diagonal, Character.empty).
│
└── Other/
    ├── WriteOutLoudApp.swift         # Main application entry point (SwiftUI App lifecycle).
    ├── Assets.xcassets               # Images, trace guides, app icons, sound files.
    └── characters.json               # Optional: JSON file for character data if not using only sample data.
```
</pre>

**File Details:**

* **Models:** Define the core data structures. `CharacterDataManager` is key for loading and providing the `Character` objects that the rest of the app uses.
* **Views:** Handle the UI presentation. `MainView` is the root, composing other views like `ReferenceView` and `WritingPaneView`. Specialized views like `StrokeView` and `FeedbackView` handle specific rendering tasks.
* **Controllers:** Manage input, analysis, and feedback logic.
    * `StrokeInputController`: Interfaces with PencilKit.
    * `SpeechRecognitionController`: Interfaces with Speech framework.
    * `ConcurrencyAnalyzer`: Performs the core comparison and scoring based on data from the input controllers.
    * `FeedbackController`: Mediates between the `ConcurrencyAnalyzer` and the `FeedbackView`.
* **Utils:** Contain reusable helper functions and algorithms, separating complex calculations (like stroke analysis) from the controllers.

## 3. Logic and Pipeline

The application operates on a per-stroke basis within a selected character.

1.  **Initialization & Character Selection:**
    * `CharacterDataManager` loads character data (JSON or samples) on app launch.
    * `MainView` initializes, sets up its controllers, and displays the UI.
    * The user selects a character using `CharacterSelectionView`.
    * `CharacterDataManager` updates `@Published var currentCharacter`.
    * `MainView` detects the change (via `.onChange`) and calls `handleCharacterChange`, which resets the state and configures all controllers (`StrokeInputController`, `SpeechRecognitionController`, `ConcurrencyAnalyzer`, `FeedbackController`) for the selected character using `resetForNewCharacterAttempt`.
    * `ReferenceView` updates to show the new character info and animation guide. `WritingPaneView` shows the new character's trace guide.
    * `MainView` calls `prepareForStrokeIndex(0)` to ready the `SpeechRecognitionController` for the first stroke's name.

2.  **Stroke and Speech Input Loop (Per Stroke):**
    * The user starts drawing the *current* stroke (`strokeInputController.currentStrokeIndex`) on the `PKCanvasView` within `WritingPaneView`.
    * `StrokeInputController` detects `canvasViewDidBeginUsingTool`.
    * It notifies `MainView` via the `strokeBegan` delegate method.
    * `MainView.strokeBegan`:
        * Clears any previous temporary data (`currentStrokeAttemptData`).
        * Calls `prepareForStrokeIndex` again (ensures correct expected name).
        * Calls `speechRecognitionController.startRecording()`.
    * `SpeechRecognitionController`:
        * Sets up `AVAudioEngine`, `SFSpeechAudioBufferRecognitionRequest`.
        * Starts capturing audio.
        * Notifies `MainView` via `speechRecordingStarted` delegate (stores `speechStartTime` in `currentStrokeAttemptData`).
    * The user draws the stroke and simultaneously speaks the stroke name (e.g., "héng").
        * `StrokeInputController` captures points via `canvasViewDrawingDidChange`.
        * `SpeechRecognitionController` receives audio buffers and sends them to `SFSpeechRecognizer`, potentially updating `recognizedTextFragment` via `@Published`.
    * The user finishes drawing the stroke (lifts the Pencil).
    * `StrokeInputController` detects `canvasViewDidEndUsingTool`.
    * It notifies `MainView` via the `strokeEnded` delegate method, passing the end time, drawn points, expected stroke details, and the stroke index.
    * `MainView.strokeEnded`:
        * Creates a `StrokeAttemptData` object holding the stroke index, expected stroke, start/end times, and drawn points.
        * Calls `speechRecognitionController.stopRecording()`.
    * `SpeechRecognitionController`:
        * Stops the `AVAudioEngine`, removes the audio tap.
        * Finalizes the `SFSpeechRecognitionTask`.
        * The task's completion handler is triggered.

3.  **Analysis and Feedback:**
    * **Speech Result:**
        * If speech recognition succeeds, the `SpeechRecognitionController`'s task completion handler calls the `speechTranscriptionFinalized` delegate method in `MainView`.
        * `MainView.speechTranscriptionFinalized`: Updates the `currentStrokeAttemptData` with the speech end time, transcription text, match status (does transcription contain expected name?), and confidence. It then calls `processCompletedStrokeAttempt()`.
        * If speech recognition fails (or is stopped before finalizing), the `speechRecognitionErrorOccurred` (or `speechRecordingStopped` timeout) delegate method is called.
        * `MainView.speechRecognitionErrorOccurred`: Updates `currentStrokeAttemptData` to indicate missing/invalid speech results and calls `processCompletedStrokeAttempt()`.
    * **Processing:**
        * `MainView.processCompletedStrokeAttempt`:
            * Retrieves the `StrokeAttemptData`.
            * Calls `StrokeAnalysis.calculateAccuracy` (using the *detailed* function, not the placeholder) to get the stroke accuracy score.
            * Packages all stroke and speech data (times, points, accuracy, transcription, match status) into a `StrokeAnalysisInput` struct.
            * Calls `concurrencyAnalyzer.analyzeStroke(input:)`.
            * Clears `currentStrokeAttemptData`.
    * **Concurrency Analysis:**
        * `ConcurrencyAnalyzer.analyzeStroke`:
            * Calculates the `concurrencyScore` using `TimestampSynchronizer.calculateOverlapRatio`.
            * Stores the results (`StrokeTimingData`).
            * Generates feedback messages (`StrokeFeedback`) for stroke, speech, and concurrency.
            * Calls the `strokeAnalysisCompleted` delegate method in `MainView`.
    * **Feedback Display:**
        * `MainView.strokeAnalysisCompleted`: Calls `feedbackController.presentStrokeFeedback`.
        * `FeedbackController`: Updates its `@Published` properties (`currentStrokeFeedback`, `feedbackType = .stroke`, `showFeedbackView = true`). Plays an appropriate sound.
        * `MainView`'s body detects the change in `feedbackController.showFeedbackView` and displays the `FeedbackView` overlay.
        * `FeedbackView` shows the specific messages for the completed stroke.

4.  **Advancing:**
    * The user interacts with the `FeedbackView`.
        * Tapping "Continue": `FeedbackView` calls `onContinue` -> `MainView.moveToNextStrokeAction`.
        * Tapping "Close" (or background for stroke feedback): `FeedbackView` calls `onClose` -> `feedbackController.dismissFeedback()`.
    * `MainView.moveToNextStrokeAction`:
        * Checks if analysis is pending (it shouldn't be if feedback was shown).
        * If not the last stroke, calls `strokeInputController.moveToNextStroke()` (increments index, clears canvas) and `prepareForStrokeIndex()` for the *new* index.
        * If it *was* the last stroke, it calls `strokeInputController.moveToNextStroke()` which triggers the `allStrokesCompleted` delegate and sets the state so the "Show Results" button becomes active.

5.  **Final Results:**
    * After the last stroke's feedback is dismissed (or "Continue" is pressed on the last stroke feedback), the "Next Stroke" button in `MainView` changes to "Show Results".
    * The user taps "Show Results".
    * `MainView.showFinalResultsAction`:
        * Calls `concurrencyAnalyzer.calculateFinalCharacterScore()`.
    * `ConcurrencyAnalyzer.calculateFinalCharacterScore`:
        * Averages the scores from `analysisHistory`.
        * Calculates the final weighted `overallScore` and `ScoreBreakdown`.
        * Generates an `overallFeedback` message.
        * Calls the `overallAnalysisCompleted` delegate method in `MainView`.
    * `MainView.overallAnalysisCompleted`: Calls `feedbackController.presentOverallFeedback`.
    * `FeedbackController`: Updates its `@Published` properties (`overallScore`, `scoreBreakdown`, `overallScoreMessage`, `feedbackType = .overall`, `showFeedbackView = true`). Plays a final sound.
    * `FeedbackView` displays the overall score, breakdown, and summary message.
    * User can "Try Again" (calls `resetForNewCharacterAttempt`) or "Close".

## 4. Dependencies and Assets

* **Frameworks:**
    * SwiftUI (UI Framework)
    * PencilKit (Handwriting Input & Canvas)
    * Speech (Speech Recognition)
    * AVFoundation (Audio Engine & Session Management for Speech)
    * Combine (Used for `@Published` properties and reactive UI updates)
    * CoreGraphics (Used for CGPoint, CGRect etc.)
* **Required Assets:**
    * **Character Data (`characters.json`):** (Optional, if not using samples) Needs to be in the app bundle, formatted according to the `Character` and `Stroke` `Codable` implementation. Specifically:
        * `strokes`: An array of stroke objects.
        * `stroke.path`: An array of arrays, where each inner array is `[Double, Double]` representing `[x, y]`.
        * `stroke.boundingBox`: An array of 4 Doubles `[x, y, width, height]`.
    * **Images:** Character images (`normalImageName`, `traceImageName`, `animationImageName` referenced in `Character` data) should be placed in `Assets.xcassets`. The names must match those specified in the character data (JSON or samples). A default placeholder `UIImage(systemName: "photo")` is used if an image is missing.
    * **Sounds:** Feedback sounds (`excellent_sound.mp3`, `good_sound.mp3`, `ok_sound.mp3`, `try_again_sound.mp3` referenced in `FeedbackController`) need to be added to the project bundle.
* **Permissions:**
    * The app will require user permission for **Microphone Access** and **Speech Recognition**. The `SpeechRecognitionController` handles requesting this authorization. Ensure the `Info.plist` file contains the necessary keys and descriptions:
        * `NSSpeechRecognitionUsageDescription`: Explain why the app needs speech recognition (e.g., "To recognize spoken stroke names for interactive learning.").
        * `NSMicrophoneUsageDescription`: Explain why the app needs microphone access (e.g., "To capture spoken stroke names during practice.").

## 5. Important Notes for Collaborators

* **Stroke Accuracy Logic:** The core stroke comparison happens in `StrokeAnalysis.calculateAccuracy`. Review and potentially tune the weights and algorithms within `StrokeAnalysis` based on testing.
* **Data Source:** Ensure the `characters.json` file is correctly formatted and included, or rely on the sample data within `CharacterDataManager`. Verify that image and sound asset names match those used in the code/data.
* **Error Handling:** Basic error handling (e.g., speech errors) logs messages. Consider adding more user-facing alerts or UI states to inform the user about issues like permission denial or data loading failures.
* **SwiftUI State Management:** The app primarily uses `@StateObject` for controllers/managers owned by `MainView`, `@EnvironmentObject` for shared data (`CharacterDataManager`), and `@Binding` / delegate patterns for communication between views and controllers.
* **Concurrency:** Pay attention to `DispatchQueue.main.async` calls when updating state (`@Published` properties or UI-related variables) from background threads or delegate callbacks to prevent UI freezes or crashes.
