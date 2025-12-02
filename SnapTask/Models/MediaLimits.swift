import Foundation

/// Centralized media limits for tasks and journal
enum MediaLimits {
    // MARK: - Task Limits
    
    /// Maximum number of photos per task
    static let maxPhotosPerTask = 3
    
    /// Maximum number of voice memos per task
    static let maxVoiceMemosPerTask = 3
    
    // MARK: - Journal Limits
    
    /// Maximum number of photos per journal entry
    static let maxPhotosPerJournal = 5
    
    /// Maximum number of voice memos per journal entry
    static let maxVoiceMemosPerJournal = 3
    
    // MARK: - Common Limits
    
    /// Maximum duration for a single voice memo in seconds (5 minutes)
    static let maxVoiceMemoDuration: TimeInterval = 5 * 60
    
    /// Maximum character count for completion notes (generous limit for UX)
    static let maxCompletionNoteCharacters = 10_000
    
    // MARK: - Task Helper Methods
    
    static func canAddPhoto(currentCount: Int) -> Bool {
        return currentCount < maxPhotosPerTask
    }
    
    static func canAddVoiceMemo(currentCount: Int) -> Bool {
        return currentCount < maxVoiceMemosPerTask
    }
    
    static func remainingPhotos(currentCount: Int) -> Int {
        return max(0, maxPhotosPerTask - currentCount)
    }
    
    static func remainingVoiceMemos(currentCount: Int) -> Int {
        return max(0, maxVoiceMemosPerTask - currentCount)
    }
    
    // MARK: - Journal Helper Methods
    
    static func canAddJournalPhoto(currentCount: Int) -> Bool {
        return currentCount < maxPhotosPerJournal
    }
    
    static func canAddJournalVoiceMemo(currentCount: Int) -> Bool {
        return currentCount < maxVoiceMemosPerJournal
    }
    
    static func remainingJournalPhotos(currentCount: Int) -> Int {
        return max(0, maxPhotosPerJournal - currentCount)
    }
    
    static func remainingJournalVoiceMemos(currentCount: Int) -> Int {
        return max(0, maxVoiceMemosPerJournal - currentCount)
    }
    
    static func formattedMaxDuration() -> String {
        let minutes = Int(maxVoiceMemoDuration) / 60
        return "\(minutes) min"
    }
}
