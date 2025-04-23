// File: Utils/TimestampSynchronizer.swift
import Foundation

/**
 Utility to analyze and compare timestamp ranges between stroke writing and speech events.
 Provides functions to calculate temporal overlap and synchronization metrics.
 */
struct TimestampSynchronizer {
    
    /// Calculates how much two time ranges overlap, using Jaccard similarity
    /// Returns a value between 0.0 (no overlap) and 1.0 (perfect overlap)
    /// - Parameters:
    ///   - startTime1: Start timestamp of the first range
    ///   - endTime1: End timestamp of the first range
    ///   - startTime2: Start timestamp of the second range
    ///   - endTime2: End timestamp of the second range
    /// - Returns: Overlap ratio as a value between 0 and 1
    static func calculateOverlapRatio(
        startTime1: Date,
        endTime1: Date,
        startTime2: Date,
        endTime2: Date
    ) -> Double {
        // Convert to TimeIntervals for easier calculation
        let start1 = startTime1.timeIntervalSince1970
        let end1 = endTime1.timeIntervalSince1970
        let start2 = startTime2.timeIntervalSince1970
        let end2 = endTime2.timeIntervalSince1970
        
        // Check if ranges are valid
        if start1 > end1 || start2 > end2 {
            print("Warning: Invalid time ranges detected.")
            return 0.0
        }
        
        // Calculate intersection (overlap)
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)
        
        if overlapStart > overlapEnd {
            // No overlap
            return 0.0
        }
        
        let overlapDuration = overlapEnd - overlapStart
        
        // Calculate union (total span)
        let span1 = end1 - start1
        let span2 = end2 - start2
        
        // Jaccard similarity: intersection divided by union
        // For time ranges, this is:
        // overlap duration / (span1 + span2 - overlap duration)
        let unionDuration = span1 + span2 - overlapDuration
        
        if unionDuration <= 0 {
            // This should not happen with valid ranges
            print("Warning: Invalid union duration calculated.")
            return 0.0
        }
        
        return overlapDuration / unionDuration
    }
    
    /// Calculates if speech started before, during, or after the stroke drawing
    /// - Parameters:
    ///   - strokeStartTime: Start timestamp of the stroke
    ///   - strokeEndTime: End timestamp of the stroke
    ///   - speechStartTime: Start timestamp of the speech
    /// - Returns: Int representing the timing relationship:
    ///   -1: Speech started before stroke
    ///    0: Speech started during stroke (ideal)
    ///    1: Speech started after stroke
    static func speechStartRelationToStroke(
        strokeStartTime: Date,
        strokeEndTime: Date,
        speechStartTime: Date
    ) -> Int {
        if speechStartTime < strokeStartTime {
            return -1 // Speech started before stroke
        } else if speechStartTime > strokeEndTime {
            return 1  // Speech started after stroke
        } else {
            return 0  // Speech started during stroke (good)
        }
    }
    
    /// Calculates the lead-lag relationship between speech and stroke events
    /// - Parameters:
    ///   - strokeStartTime: When the stroke drawing began
    ///   - speechStartTime: When the speech utterance began
    /// - Returns: Time difference in seconds. Positive = speech lagged behind stroke,
    ///   negative = speech led before stroke, 0 = perfect synchronization
    static func calculateSpeechLag(strokeStartTime: Date, speechStartTime: Date) -> TimeInterval {
        return speechStartTime.timeIntervalSince(strokeStartTime)
    }
    
    /// Calculates synchronization score based on overlap and timing alignment
    /// More sophisticated than simple overlap ratio - factors in ideal timing
    /// - Parameters:
    ///   - strokeStartTime: Start timestamp of the stroke
    ///   - strokeEndTime: End timestamp of the stroke
    ///   - speechStartTime: Start timestamp of the speech
    ///   - speechEndTime: End timestamp of the speech
    /// - Returns: Synchronization score 0-100
    static func calculateSynchronizationScore(
        strokeStartTime: Date,
        strokeEndTime: Date,
        speechStartTime: Date,
        speechEndTime: Date
    ) -> Double {
        // First get basic overlap
        let overlapRatio = calculateOverlapRatio(
            startTime1: strokeStartTime,
            endTime1: strokeEndTime,
            startTime2: speechStartTime,
            endTime2: speechEndTime
        )
        
        // Calculate speech lag
        let speechLag = calculateSpeechLag(strokeStartTime: strokeStartTime, speechStartTime: speechStartTime)
        let strokeDuration = strokeEndTime.timeIntervalSince(strokeStartTime)
        
        // Calculate timing penalty - ideally speech should start very close to stroke start
        // Best is 0, worst is 1
        let relativeDelay = min(abs(speechLag) / max(strokeDuration, 0.1), 1.0)
        let timingPenalty = relativeDelay * 0.3 // Scale penalty to max 30%
        
        // Final score: overlap ratio with timing penalty, converted to 0-100 scale
        let score = (overlapRatio * (1.0 - timingPenalty)) * 100.0
        return max(0.0, min(100.0, score)) // Clamp to 0-100 range
    }
}
