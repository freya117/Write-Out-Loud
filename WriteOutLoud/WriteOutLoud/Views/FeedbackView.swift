// File: Views/FeedbackView.swift
import SwiftUI
import UIKit // Needed for UIColor access

// Assumes ButtonStyles are defined elsewhere (e.g., Views/ButtonStyles.swift)

// MARK: - Main Feedback View
struct FeedbackView: View {
    // Observe the FeedbackController provided by the environment
    @EnvironmentObject var feedbackController: FeedbackController

    // Actions passed from the parent view (MainView)
    var onContinue: () -> Void // Action after dismissing stroke feedback
    var onTryAgain: () -> Void // Action after dismissing overall feedback (to restart char)
    var onClose: () -> Void    // Action for explicit close button

    var body: some View {
        VStack(spacing: 20) {
            // Dynamically display content based on feedback type
            mainFeedbackContent()
                .padding(.bottom) // Add some space before buttons

            // Action buttons
            actionButtons()
        }
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24)) // Adjust padding
        .frame(maxWidth: 500) // Limit width for better readability on iPad
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            alignment: .topTrailing // Position close button
        ) {
            // Optional explicit close button for overall feedback
             if feedbackController.feedbackType == .overall {
                 CloseButton {
                     feedbackController.dismissFeedback()
                     onClose() // Trigger the specific close action
                 }
                 .padding()
             }
        }
         // Use systemGray6 for stroke for subtle separation
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(UIColor.systemGray4), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
        // Apply transitions for appear/disappear
        .transition(.scale(scale: 0.9, anchor: .center).combined(with: .opacity))
         // Animate based on the showFeedbackView flag
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: feedbackController.showFeedbackView)
    }

    // MARK: - View Builders for Content

    @ViewBuilder
    private func mainFeedbackContent() -> some View {
        // Group ensures modifiers apply correctly to the chosen view
        Group {
            switch feedbackController.feedbackType {
            case .stroke:
                if let feedback = feedbackController.currentStrokeFeedback {
                    strokeFeedbackContent(feedback)
                } else {
                    // Placeholder if stroke feedback data is somehow missing
                    Text("Loading stroke feedback...")
                        .foregroundColor(.secondary)
                        .frame(minHeight: 100) // Ensure some height
                }
            case .overall:
                overallFeedbackContent()
            }
        }
    }

    @ViewBuilder
    private func strokeFeedbackContent(_ feedback: StrokeFeedback) -> some View {
        VStack(spacing: 15) {
            Text("Stroke Feedback")
                .font(.title2).bold()
                .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 12) {
                // Only show rows if the message is not empty
                if !feedback.strokeMessage.isEmpty {
                    FeedbackMessageRow(iconName: "pencil.and.outline", iconColor: .orange, message: feedback.strokeMessage)
                }
                if !feedback.speechMessage.isEmpty {
                    FeedbackMessageRow(iconName: "mic", iconColor: .blue, message: feedback.speechMessage)
                }
                if !feedback.concurrencyMessage.isEmpty {
                    FeedbackMessageRow(iconName: "timer", iconColor: .green, message: feedback.concurrencyMessage)
                }
            }
            .font(.body) // Use body font for messages
            .padding()
             // Use a slightly less prominent background for stroke details
            .background(Color(UIColor.systemGray6).opacity(0.7))
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private func overallFeedbackContent() -> some View {
        VStack(spacing: 15) {
            Text("Character Complete!")
                .font(.title2).bold()
                .padding(.bottom, 5)

            // Circular progress bar for overall score
            overallScoreCircle()
                .padding(.bottom, 10)

            // Overall text message
            Text(feedbackController.overallScoreMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true) // Allow text wrapping

            // Detailed score breakdown
            scoreBreakdownList()
                .padding(.top)
        }
    }

    @ViewBuilder
    private func overallScoreCircle() -> some View {
        let score = feedbackController.overallScore
        // Ensure progress is clamped between 0 and 1
        let progress = min(max(score / 100.0, 0.0), 1.0)
        ZStack {
            // Background track
            Circle()
                 .stroke(lineWidth: 12)
                 .opacity(0.2)
                 .foregroundColor(scoreColor(score)) // Use score color for track too

            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                .foregroundColor(scoreColor(score))
                .rotationEffect(Angle(degrees: -90)) // Start from top
                .animation(.easeInOut(duration: 0.8).delay(0.1), value: progress) // Animate progress change

            // Score text inside
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                     // Make score text larger
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("%") // Percentage sign slightly smaller and secondary
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .offset(y: -3) // Adjust vertical offset
            }
        }
        .frame(width: 130, height: 130) // Slightly larger circle
    }

    @ViewBuilder
    private func scoreBreakdownList() -> some View {
        VStack(alignment: .leading, spacing: 15) { // Increased spacing
            Text("Breakdown:")
                .font(.subheadline).bold().foregroundColor(.secondary)
                .padding(.leading) // Indent title slightly

            // Use the helper FeedbackRow for each breakdown item
            FeedbackRow(label: "Stroke Accuracy", score: feedbackController.scoreBreakdown.strokeAccuracy, description: "How well you drew the shapes.")
            FeedbackRow(label: "Stroke Naming", score: feedbackController.scoreBreakdown.speechCorrectness, description: "Correctly saying the stroke names.")
             // Only show concurrency if relevant (based on attempts in analyzer)
             // This requires passing attempt count or using the score itself as indicator
             if feedbackController.scoreBreakdown.concurrencyScore > 0 || feedbackController.overallScoreMessage.contains("sync") { // Heuristic
                 FeedbackRow(label: "Timing Sync", score: feedbackController.scoreBreakdown.concurrencyScore, description: "Speaking while drawing.")
             }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 8) // Reduce bottom padding inside breakdown
         .background(Color(UIColor.systemGray6).opacity(0.7)) // Match stroke feedback background
        .cornerRadius(10)
    }

    // MARK: - Action Buttons ViewBuilder

    @ViewBuilder
    private func actionButtons() -> some View {
        HStack(spacing: 15) {
            // Show appropriate primary action based on feedback type
            if feedbackController.feedbackType == .stroke {
                // For stroke feedback, primary action is "Continue"
                Button("Continue") {
                    feedbackController.dismissFeedback() // Dismiss first
                    onContinue() // Then call the action
                }
                .buttonStyle(PrimaryButtonStyle()) // Assumes defined elsewhere
                .frame(maxWidth: .infinity) // Allow button to expand

            } else {
                // For overall feedback, primary action is "Try Again"
                Button("Try Again") {
                    feedbackController.dismissFeedback()
                    onTryAgain()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)

                 // Optionally add a "Next Character" button if applicable
                 // Button("Next Character") { /* Action */ }
                 // .buttonStyle(SecondaryButtonStyle())
                 // .frame(maxWidth: .infinity)
            }
        }
         // No explicit close button here; rely on background tap for stroke,
         // or the X button overlay for overall feedback.
    }

    // MARK: - Helper Functions

    /// Determines the color based on the score value.
    private func scoreColor(_ score: Double) -> Color {
        let clampedScore = max(0.0, min(100.0, score))
        switch clampedScore {
        case 0..<50: return .red
        case 50..<75: return .orange
        case 75..<90: return .blue // Use blue for good scores
        default: return .green // Use green for excellent scores
        }
    }
}

// MARK: - Helper Views

/// Displays a single row of feedback with an icon and text message.
struct FeedbackMessageRow: View {
    let iconName: String
    let iconColor: Color
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) { // Increased spacing
            Image(systemName: iconName)
                .font(.headline) // Slightly larger icon
                .foregroundColor(iconColor)
                .frame(width: 22, alignment: .center) // Ensure consistent width
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
                 .fixedSize(horizontal: false, vertical: true) // Allow text wrapping
        }
    }
}

/// Displays a labeled score row with a progress bar and description.
struct FeedbackRow: View {
    let label: String
    let score: Double
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Label and Score
            HStack {
                Text(label)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(Int(score.rounded()))%")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(scoreColor(score))
            }
            // Progress Bar
            progressBar()
                .frame(height: 8) // Slightly thicker bar
                .padding(.top, 2) // Add tiny space above bar

            // Description (Optional)
            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true) // Allow wrapping
                    .padding(.top, 2)
            }
        }
    }

    /// Creates the progress bar view.
    @ViewBuilder
    private func progressBar() -> some View {
        let progress = CGFloat(min(max(score / 100.0, 0.0), 1.0)) // Clamped progress 0-1
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track of the bar
                 Capsule()
                     .frame(width: geometry.size.width)
                     // Use lighter shade of score color for track
                     .foregroundColor(scoreColor(score).opacity(0.3))

                // Filled portion of the bar
                Capsule()
                     // Animate width change based on progress
                    .frame(width: progress * geometry.size.width)
                    .foregroundColor(scoreColor(score))
                    .animation(.easeInOut, value: score) // Animate based on score value
            }
        }
    }

    /// Determines the color based on the score value (duplicated for encapsulation).
    private func scoreColor(_ score: Double) -> Color {
        let clampedScore = max(0.0, min(100.0, score))
        switch clampedScore {
        case 0..<50: return .red
        case 50..<75: return .orange
        case 75..<90: return .blue
        default: return .green
        }
    }
}

/// Simple Close Button View
struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.gray.opacity(0.6))
                 .background(Color.white.opacity(0.01)) // Ensure tappable area
        }
        .buttonStyle(.plain) // Remove default button styling
    }
}


// MARK: - Preview Provider (If needed)
struct FeedbackView_Previews: PreviewProvider {
     // ... (Keep existing preview provider logic, ensure it uses updated structs/initializers) ...
     // Example preview setup (replace with your actual preview data)
     static func createController(type: FeedbackController.FeedbackType) -> FeedbackController {
         let controller = FeedbackController()
         controller.feedbackType = type
         controller.showFeedbackView = true

         if type == .stroke {
             controller.currentStrokeFeedback = StrokeFeedback(
                 strokeMessage: "Good stroke formation (75%)",
                 speechMessage: "Heard 'héng', expected 'héngzhé'.",
                 concurrencyMessage: "Good timing synchronization (70%)"
             )
         } else { // Overall
             controller.overallScore = 68.0
             controller.overallScoreMessage = "Good effort! Practice makes perfect."
             controller.scoreBreakdown = ScoreBreakdown(
                 strokeAccuracy: 75.0,
                 speechCorrectness: 40.0, // Assuming 2/4 correct for example
                 concurrencyScore: 70.0
             )
         }
         return controller
     }

     static var previews: some View {
         let strokeController = createController(type: .stroke)
         let overallController = createController(type: .overall)

         return Group {
             FeedbackView(onContinue: {}, onTryAgain: {}, onClose: {})
                 .environmentObject(strokeController)
                 .previewDisplayName("Stroke Feedback")
                 .padding()
                 .background(Color.blue.opacity(0.1)) // Add background for visibility


             FeedbackView(onContinue: {}, onTryAgain: {}, onClose: {})
                 .environmentObject(overallController)
                 .previewDisplayName("Overall Feedback")
                 .padding()
                 .background(Color.green.opacity(0.1))

         }
          // Preview on an iPad layout
          .previewDevice("iPad pro (11-inch) (4th generation)")
     }
}
