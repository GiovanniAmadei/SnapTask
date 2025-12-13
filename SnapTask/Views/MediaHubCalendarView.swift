import SwiftUI
import AVFoundation

struct MediaHubCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    @ObservedObject var viewModel: TimelineViewModel
    let scrollProxy: ScrollViewProxy?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var taskManager = TaskManager.shared
    @ObservedObject private var journalManager = JournalManager.shared
    
    @State private var displayedMonth: Date = Date()
    @State private var selectedDayForDetail: Date? = nil
    @State private var selectedPhoto: TaskPhoto? = nil
    @State private var playingMemoId: UUID? = nil
    @StateObject private var audioPlayer = CalendarAudioPlayer()
    @State private var showingJournalEntry: JournalEntry? = nil
    
    // Multi-scope support
    @State private var calendarViewScope: TaskTimeScope = .today
    @State private var selectedWeekStart: Date? = nil
    @State private var selectedMonthStart: Date? = nil
    @State private var selectedYearStart: Date? = nil
    @State private var displayedYear: Int = Calendar.current.component(.year, from: Date())
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scope selector
                scopeSelector
                
                // Adaptive header based on scope
                adaptiveHeader
                
                // Adaptive calendar/list view based on scope
                adaptiveCalendarView
                
                Divider()
                    .padding(.vertical, 8)
                
                // Adaptive detail view based on scope
                adaptiveDetailView
            }
            .themedBackground()
            .navigationTitle("calendar".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        applySelection()
                        dismiss()
                    }
                    .themedAccent()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("today".localized) {
                        withAnimation {
                            displayedMonth = Date()
                            selectedDayForDetail = calendar.startOfDay(for: Date())
                        }
                    }
                    .themedPrimary()
                }
            }
            .onAppear {
                displayedMonth = selectedDate
                selectedDayForDetail = calendar.startOfDay(for: selectedDate)
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                FullScreenPhotoView(photo: photo)
            }
            .sheet(item: $showingJournalEntry) { entry in
                JournalView(date: entry.date)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Scope Selector
    
    private var scopeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([TaskTimeScope.today, .week, .month, .year, .longTerm], id: \.self) { scope in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            calendarViewScope = scope
                            // Reset selections when changing scope
                            if scope != .today {
                                selectedDayForDetail = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: scope.icon)
                                .font(.system(size: 12))
                            Text(scopeShortName(scope))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(calendarViewScope == scope ? theme.primaryColor : theme.surfaceColor)
                        )
                        .foregroundColor(calendarViewScope == scope ? theme.backgroundColor : theme.textColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func scopeShortName(_ scope: TaskTimeScope) -> String {
        switch scope {
        case .today: return "day".localized
        case .week: return "week".localized
        case .month: return "month".localized
        case .year: return "year".localized
        case .longTerm: return "long_term".localized
        case .all: return "all".localized
        }
    }
    
    // MARK: - Adaptive Views
    
    @ViewBuilder
    private var adaptiveHeader: some View {
        switch calendarViewScope {
        case .today:
            monthHeader
        case .week:
            monthHeader // Same month navigation for week view
        case .month:
            yearHeader
        case .year:
            decadeHeader
        case .longTerm, .all:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var adaptiveCalendarView: some View {
        switch calendarViewScope {
        case .today:
            VStack(spacing: 0) {
                weekdayHeader
                calendarGrid
            }
        case .week:
            VStack(spacing: 0) {
                weekdayHeader
                weekCalendarGrid
            }
        case .month:
            monthListView
        case .year:
            yearListView
        case .longTerm, .all:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var adaptiveDetailView: some View {
        switch calendarViewScope {
        case .today:
            if let day = selectedDayForDetail {
                dayDetailView(for: day)
            } else {
                todayPrompt
            }
        case .week:
            if let weekStart = selectedWeekStart {
                weekDetailView(for: weekStart)
            } else {
                selectWeekPrompt
            }
        case .month:
            if let monthStart = selectedMonthStart {
                monthDetailView(for: monthStart)
            } else {
                selectMonthPrompt
            }
        case .year:
            if let yearStart = selectedYearStart {
                yearDetailView(for: yearStart)
            } else {
                selectYearPrompt
            }
        case .longTerm, .all:
            longTermDetailView
        }
    }
    
    // MARK: - Year Header (for Month scope)
    
    private var yearHeader: some View {
        HStack {
            Button {
                withAnimation {
                    displayedYear -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
            
            Spacer()
            
            Text(String(displayedYear))
                .font(.headline)
                .themedPrimaryText()
            
            Spacer()
            
            Button {
                withAnimation {
                    displayedYear += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Decade Header (for Year scope)
    
    private var decadeHeader: some View {
        let decadeStart = (displayedYear / 10) * 10
        return HStack {
            Button {
                withAnimation {
                    displayedYear -= 10
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
            
            Spacer()
            
            Text("\(decadeStart) - \(decadeStart + 9)")
                .font(.headline)
                .themedPrimaryText()
            
            Spacer()
            
            Button {
                withAnimation {
                    displayedYear += 10
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
            
            Spacer()
            
            Text(monthYearString(from: displayedMonth))
                .font(.headline)
                .themedPrimaryText()
            
            Spacer()
            
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimary()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Weekday Header
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        var symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        // Adjust for locale's first day of week
        let firstWeekday = calendar.firstWeekday
        if firstWeekday > 1 {
            let rotation = firstWeekday - 1
            symbols = Array(symbols[rotation...]) + Array(symbols[..<rotation])
        }
        return symbols
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                if let day = day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = selectedDayForDetail.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let stats = dayStats(for: date)
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDayForDetail = date
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? theme.backgroundColor : (isToday ? theme.primaryColor : theme.textColor))
                
                // Media indicators
                HStack(spacing: 2) {
                    if stats.photoCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                    if stats.voiceMemoCount > 0 {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 4, height: 4)
                    }
                    if stats.hasNotes {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 4, height: 4)
                    }
                    if stats.hasJournal {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
                
                // Task count badge
                if stats.taskCount > 0 {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isSelected ? theme.backgroundColor.opacity(0.8) : theme.secondaryTextColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.primaryColor : (isToday ? theme.primaryColor.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday && !isSelected ? theme.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Day Detail View
    
    private func dayDetailView(for date: Date) -> some View {
        let stats = dayStats(for: date)
        let tasksForDay = tasksOnDate(date)
        
        return VStack(spacing: 0) {
            // Fixed sticky header - compact single row
            HStack(spacing: 6) {
                // Date
                Text(fullDateString(from: date))
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                // Task count + media badges in compact row
                HStack(spacing: 4) {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    
                    if stats.photoCount > 0 {
                        mediaBadge(icon: "photo.fill", count: stats.photoCount, color: .blue)
                    }
                    if stats.voiceMemoCount > 0 {
                        mediaBadge(icon: "waveform", count: stats.voiceMemoCount, color: .pink)
                    }
                    if stats.notesCount > 0 {
                        mediaBadge(icon: "note.text", count: stats.notesCount, color: .orange)
                    }
                    if stats.hasJournal {
                        mediaBadge(icon: "book.closed.fill", count: 1, color: .purple)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            
            // Scrollable task list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Journal entry card (if exists)
                    if let journalEntry = journalEntryForDate(date) {
                        journalCard(entry: journalEntry)
                    }
                    
                    if tasksForDay.isEmpty && journalEntryForDate(date) == nil {
                        emptyDayView
                    } else {
                        ForEach(tasksForDay, id: \.id) { task in
                            taskMediaCard(task: task, date: date)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func journalEntryForDate(_ date: Date) -> JournalEntry? {
        let startOfDay = calendar.startOfDay(for: date)
        if let entry = journalManager.entriesByDay[startOfDay], !entry.isEmpty {
            return entry
        }
        return nil
    }
    
    @ViewBuilder
    private func journalCard(entry: JournalEntry) -> some View {
        Button {
            showingJournalEntry = entry
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    
                    Text("journal".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    // Mood indicator
                    if let mood = entry.mood {
                        Text(mood.emoji)
                            .font(.system(size: 16))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Title or preview
                if !entry.title.isEmpty {
                    Text(entry.title)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                        .lineLimit(1)
                }
                
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.caption)
                        .themedSecondaryText()
                        .lineLimit(2)
                }
                
                // Media indicators
                HStack(spacing: 12) {
                    if !entry.photos.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 10))
                            Text("\(entry.photos.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if !entry.voiceMemos.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                            Text("\(entry.voiceMemos.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.pink)
                    }
                    
                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 10))
                            Text("\(entry.tags.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    
    private func mediaBadge(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
    
    private func taskMediaCard(task: TodoTask, date: Date) -> some View {
        let completionKey = task.completionKey(for: date)
        let completion = task.completions[completionKey]
        
        // Filter media by creation date - only show media created on this specific date
        let photosForDate = task.photos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
        let memosForDate = task.voiceMemos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
        let hasNotes = completion?.notes != nil && !(completion?.notes?.isEmpty ?? true)
        let hasMediaForDate = !photosForDate.isEmpty || !memosForDate.isEmpty || hasNotes
        
        return VStack(alignment: .leading, spacing: 12) {
            // Task header with category
            HStack(spacing: 8) {
                Image(systemName: task.icon)
                    .font(.system(size: 14))
                    .foregroundColor(categoryColor(for: task))
                
                Text(task.name)
                    .font(.subheadline.weight(.medium))
                    .themedPrimaryText()
                    .lineLimit(1)
                
                // Category badge next to title
                if let category = task.category {
                    Text(category.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: category.color).opacity(0.15))
                        )
                }
                
                Spacer()
                
                // Always show completion status
                Image(systemName: completion?.isCompleted == true ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completion?.isCompleted == true ? .green : .gray.opacity(0.4))
                    .font(.system(size: 16))
            }
            
            // Quick Info Section
            quickInfoSection(task: task, completion: completion, date: date)
            
            // Media Section - only show media created on this date
            if hasMediaForDate {
                VStack(alignment: .leading, spacing: 10) {
                    // Photos created on this date
                    if !photosForDate.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("photos".localized, systemImage: "photo")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.blue)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photosForDate) { photo in
                                        if let image = AttachmentService.loadImage(from: photo.thumbnailPath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .onTapGesture {
                                                    selectedPhoto = photo
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Voice memos created on this date
                    if !memosForDate.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("voice_memos".localized, systemImage: "waveform")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.pink)
                            
                            ForEach(memosForDate) { memo in
                                VoiceMemoPlayerRow(
                                    memo: memo,
                                    isPlaying: playingMemoId == memo.id && audioPlayer.isPlaying,
                                    currentTime: playingMemoId == memo.id ? audioPlayer.currentTime : 0,
                                    onTap: { togglePlayback(memo) }
                                )
                            }
                        }
                    }
                    
                    // Notes for this date's completion
                    if let notes = completion?.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("notes".localized, systemImage: "note.text")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.orange)
                            
                            Text(notes)
                                .font(.caption)
                                .themedSecondaryText()
                                .lineLimit(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }
                    }
                    
                    // Performance ratings for this date's completion
                    if let difficulty = completion?.difficultyRating, let quality = completion?.qualityRating {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("performance".localized, systemImage: "chart.bar.fill")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.purple)
                            
                            HStack(spacing: 16) {
                                // Difficulty rating
                                HStack(spacing: 4) {
                                    Image(systemName: "flame")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                    Text("difficulty".localized)
                                        .font(.system(size: 10))
                                        .themedSecondaryText()
                                    Text("\(difficulty)/10")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.red)
                                }
                                
                                // Quality rating
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                    Text("quality".localized)
                                        .font(.system(size: 10))
                                        .themedSecondaryText()
                                    Text("\(quality)/10")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.purple.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Quick Info Section
    
    @ViewBuilder
    private func quickInfoSection(task: TodoTask, completion: TaskCompletion?, date: Date) -> some View {
        let isCompleted = completion?.isCompleted ?? false
        
        // Compact grid layout
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            // Time
            compactInfoChip(icon: "clock", value: formatTime(task.startTime), color: .purple)
            
            // Duration - prefer actual tracked time, fallback to estimated
            if let actualDuration = completion?.actualDuration, actualDuration > 0 {
                // Show actual tracked duration
                compactInfoChip(icon: "hourglass", value: formatDurationFromSeconds(actualDuration), color: .green)
            } else if task.totalTrackedTime > 0 {
                // Show total tracked time
                compactInfoChip(icon: "hourglass", value: formatDurationFromSeconds(task.totalTrackedTime), color: .green)
            } else if task.hasDuration && task.duration > 0 {
                // Show estimated duration
                compactInfoChip(icon: "hourglass", value: formatDurationFromSeconds(task.duration), color: .blue)
            }
            
            // Priority
            compactInfoChip(icon: "flag.fill", value: task.priority.displayName, color: Color(hex: task.priority.color))
            
            // Points (if set)
            if task.hasRewardPoints && task.rewardPoints > 0 {
                compactInfoChip(icon: "star.fill", value: "\(task.rewardPoints)pt", color: .yellow)
            }
            
            // Streak (for recurring tasks)
            if task.recurrence != nil && task.currentStreak > 0 {
                compactInfoChip(icon: "flame.fill", value: "\(task.currentStreak)", color: .orange)
            }
        }
    }
    
    private func compactInfoChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
    
    private func formatDurationFromSeconds(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func togglePlayback(_ memo: TaskVoiceMemo) {
        if playingMemoId == memo.id && audioPlayer.isPlaying {
            audioPlayer.pause()
            playingMemoId = nil
        } else {
            audioPlayer.play(path: memo.audioPath)
            playingMemoId = memo.id
        }
    }
    
    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 40))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("no_tasks_for_day".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var todayPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("select_day_to_view_media".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var selectWeekPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("select_week_to_view".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var selectMonthPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("select_month_to_view".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var selectYearPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("select_year_to_view".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Week Calendar Grid
    
    private var weekCalendarGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                if let day = day {
                    weekDayCell(for: day, index: index)
                } else {
                    Color.clear
                        .frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 12)
    }
    
    private func weekDayCell(for date: Date, index: Int) -> some View {
        let weekStart = startOfWeek(for: date)
        let isSelectedWeek = selectedWeekStart.map { calendar.isDate($0, inSameDayAs: weekStart) } ?? false
        let isToday = calendar.isDateInToday(date)
        let isFirstDayOfWeek = index % 7 == 0
        let stats = weekStats(for: weekStart)
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedWeekStart = weekStart
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelectedWeek ? .bold : .medium))
                    .foregroundColor(isSelectedWeek ? theme.backgroundColor : (isToday ? theme.primaryColor : theme.textColor))
                
                // Show week indicators only on first day of week
                if isFirstDayOfWeek && stats.taskCount > 0 {
                    HStack(spacing: 2) {
                        if stats.photoCount > 0 {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                        }
                        if stats.voiceMemoCount > 0 {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelectedWeek ? theme.primaryColor : (isToday ? theme.primaryColor.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Month List View
    
    private var monthListView: some View {
        let months = (1...12).compactMap { month -> Date? in
            var components = DateComponents()
            components.year = displayedYear
            components.month = month
            components.day = 1
            return calendar.date(from: components)
        }
        
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(months, id: \.self) { monthDate in
                    monthCell(for: monthDate)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func monthCell(for date: Date) -> some View {
        let isSelected = selectedMonthStart.map { calendar.isDate($0, equalTo: date, toGranularity: .month) } ?? false
        let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        let stats = monthStats(for: date)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.dateFormat = "MMM"
        let monthName = formatter.string(from: date)
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonthStart = date
            }
        } label: {
            VStack(spacing: 6) {
                Text(monthName)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? theme.backgroundColor : (isCurrentMonth ? theme.primaryColor : theme.textColor))
                
                if stats.taskCount > 0 {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? theme.backgroundColor.opacity(0.8) : theme.secondaryTextColor)
                    
                    HStack(spacing: 3) {
                        if stats.photoCount > 0 {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 5, height: 5)
                        }
                        if stats.voiceMemoCount > 0 {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 5, height: 5)
                        }
                        if stats.hasNotes {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.primaryColor : (isCurrentMonth ? theme.primaryColor.opacity(0.1) : theme.surfaceColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isCurrentMonth && !isSelected ? theme.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Year List View
    
    private var yearListView: some View {
        let decadeStart = (displayedYear / 10) * 10
        let years = (decadeStart...(decadeStart + 9)).map { $0 }
        
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(years, id: \.self) { year in
                    yearCell(for: year)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func yearCell(for year: Int) -> some View {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        let yearDate = calendar.date(from: components) ?? Date()
        
        let isSelected = selectedYearStart.map { calendar.component(.year, from: $0) == year } ?? false
        let isCurrentYear = calendar.component(.year, from: Date()) == year
        let stats = yearStats(for: yearDate)
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedYearStart = yearDate
            }
        } label: {
            VStack(spacing: 6) {
                Text(String(year))
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? theme.backgroundColor : (isCurrentYear ? theme.primaryColor : theme.textColor))
                
                if stats.taskCount > 0 {
                    Text("\(stats.taskCount) " + "tasks".localized.lowercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? theme.backgroundColor.opacity(0.8) : theme.secondaryTextColor)
                    
                    HStack(spacing: 3) {
                        if stats.photoCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 9))
                                Text("\(stats.photoCount)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.blue)
                        }
                        if stats.voiceMemoCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 9))
                                Text("\(stats.voiceMemoCount)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.pink)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? theme.primaryColor : (isCurrentYear ? theme.primaryColor.opacity(0.1) : theme.surfaceColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isCurrentYear && !isSelected ? theme.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Week Detail View
    
    private func weekDetailView(for weekStart: Date) -> some View {
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let tasks = tasksForWeek(weekStart)
        let stats = weekStats(for: weekStart)
        
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(weekRangeString(from: weekStart, to: weekEnd))
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    
                    if stats.photoCount > 0 {
                        mediaBadge(icon: "photo.fill", count: stats.photoCount, color: .blue)
                    }
                    if stats.voiceMemoCount > 0 {
                        mediaBadge(icon: "waveform", count: stats.voiceMemoCount, color: .pink)
                    }
                    if stats.notesCount > 0 {
                        mediaBadge(icon: "note.text", count: stats.notesCount, color: .orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            
            // Task list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tasks.isEmpty {
                        emptyWeekView
                    } else {
                        ForEach(tasks, id: \.id) { task in
                            scopeTaskMediaCard(task: task, scope: .week, rangeStart: weekStart, rangeEnd: weekEnd)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var emptyWeekView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("no_weekly_tasks".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Month Detail View
    
    private func monthDetailView(for monthStart: Date) -> some View {
        let tasks = tasksForMonth(monthStart)
        let stats = monthStats(for: monthStart)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.dateFormat = "MMMM yyyy"
        let monthName = formatter.string(from: monthStart).capitalized
        
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(monthName)
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    
                    if stats.photoCount > 0 {
                        mediaBadge(icon: "photo.fill", count: stats.photoCount, color: .blue)
                    }
                    if stats.voiceMemoCount > 0 {
                        mediaBadge(icon: "waveform", count: stats.voiceMemoCount, color: .pink)
                    }
                    if stats.notesCount > 0 {
                        mediaBadge(icon: "note.text", count: stats.notesCount, color: .orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            
            // Task list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tasks.isEmpty {
                        emptyMonthView
                    } else {
                        ForEach(tasks, id: \.id) { task in
                            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
                            scopeTaskMediaCard(task: task, scope: .month, rangeStart: monthStart, rangeEnd: monthEnd)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var emptyMonthView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("no_monthly_tasks".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Year Detail View
    
    private func yearDetailView(for yearStart: Date) -> some View {
        let tasks = tasksForYear(yearStart)
        let stats = yearStats(for: yearStart)
        let year = calendar.component(.year, from: yearStart)
        
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(String(year))
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    
                    if stats.photoCount > 0 {
                        mediaBadge(icon: "photo.fill", count: stats.photoCount, color: .blue)
                    }
                    if stats.voiceMemoCount > 0 {
                        mediaBadge(icon: "waveform", count: stats.voiceMemoCount, color: .pink)
                    }
                    if stats.notesCount > 0 {
                        mediaBadge(icon: "note.text", count: stats.notesCount, color: .orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            
            // Task list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tasks.isEmpty {
                        emptyYearView
                    } else {
                        ForEach(tasks, id: \.id) { task in
                            scopeTaskMediaCard(task: task, scope: .year, rangeStart: yearStart, rangeEnd: yearEndDate(for: year))
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var emptyYearView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("no_yearly_tasks".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Long Term Detail View
    
    private var longTermDetailView: some View {
        let tasks = tasksForLongTerm()
        let stats = longTermStats()
        
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("long_term".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(stats.taskCount)")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    
                    if stats.photoCount > 0 {
                        mediaBadge(icon: "photo.fill", count: stats.photoCount, color: .blue)
                    }
                    if stats.voiceMemoCount > 0 {
                        mediaBadge(icon: "waveform", count: stats.voiceMemoCount, color: .pink)
                    }
                    if stats.notesCount > 0 {
                        mediaBadge(icon: "note.text", count: stats.notesCount, color: .orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
            
            // Task list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tasks.isEmpty {
                        emptyLongTermView
                    } else {
                        ForEach(tasks, id: \.id) { task in
                            scopeTaskMediaCard(task: task, scope: .longTerm, rangeStart: nil, rangeEnd: nil)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var emptyLongTermView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            
            Text("no_long_term_tasks".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Scope Task Media Card
    
    private func scopeTaskMediaCard(task: TodoTask, scope: TaskTimeScope, rangeStart: Date?, rangeEnd: Date?) -> some View {
        // Get all photos and memos for this task (for non-daily scopes, show all media)
        let photos = task.photos
        let memos = task.voiceMemos
        
        // Get completion info - for multi-day scopes, check if any completion exists
        let isCompleted = !task.completions.isEmpty && task.completions.values.contains { $0.isCompleted }
        let latestCompletion = task.completions.values.sorted(by: { ($0.completionDate ?? Date.distantPast) > ($1.completionDate ?? Date.distantPast) }).first
        
        return VStack(alignment: .leading, spacing: 12) {
            // Task header with category
            HStack(spacing: 8) {
                Image(systemName: task.icon)
                    .font(.system(size: 14))
                    .foregroundColor(categoryColor(for: task))
                
                Text(task.name)
                    .font(.subheadline.weight(.medium))
                    .themedPrimaryText()
                    .lineLimit(1)
                
                if let category = task.category {
                    Text(category.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: category.color).opacity(0.15))
                        )
                }
                
                Spacer()
                
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray.opacity(0.4))
                    .font(.system(size: 16))
            }
            
            // Scope-specific info
            HStack(spacing: 12) {
                // Priority
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                    Text(task.priority.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: task.priority.color))
                
                // Points
                if task.hasRewardPoints && task.rewardPoints > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("\(task.rewardPoints)pt")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.yellow)
                }
                
                // Tracked time
                if task.totalTrackedTime > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                        Text(formatDurationFromSeconds(task.totalTrackedTime))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.green)
                }
            }
            
            // Media Section
            if !photos.isEmpty || !memos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // Photos
                    if !photos.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(photos.count) " + "photos".localized.lowercased(), systemImage: "photo")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.blue)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photos) { photo in
                                        if let image = AttachmentService.loadImage(from: photo.thumbnailPath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .onTapGesture {
                                                    selectedPhoto = photo
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Voice memos
                    if !memos.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("\(memos.count) " + "voice_memos".localized.lowercased(), systemImage: "waveform")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.pink)
                            
                            ForEach(memos) { memo in
                                VoiceMemoPlayerRow(
                                    memo: memo,
                                    isPlaying: playingMemoId == memo.id && audioPlayer.isPlaying,
                                    currentTime: playingMemoId == memo.id ? audioPlayer.currentTime : 0,
                                    onTap: { togglePlayback(memo) }
                                )
                            }
                        }
                    }
                    
                    // Notes from latest completion
                    if let notes = latestCompletion?.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("notes".localized, systemImage: "note.text")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.orange)
                            
                            Text(notes)
                                .font(.caption)
                                .themedSecondaryText()
                                .lineLimit(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Methods
    
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        // Add empty slots for days before the first of the month
        while currentDate < monthInterval.start {
            days.append(nil)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add all days in the month
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    private func fullDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private struct DayStats {
        var taskCount: Int = 0
        var photoCount: Int = 0
        var voiceMemoCount: Int = 0
        var notesCount: Int = 0
        var hasNotes: Bool { notesCount > 0 }
        var hasJournal: Bool = false
    }
    
    private func dayStats(for date: Date) -> DayStats {
        let tasks = tasksOnDate(date)
        var stats = DayStats()
        stats.taskCount = tasks.count
        
        for task in tasks {
            // Count only media created on this specific date
            stats.photoCount += task.photos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
            stats.voiceMemoCount += task.voiceMemos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
            
            let completionKey = task.completionKey(for: date)
            if let notes = task.completions[completionKey]?.notes, !notes.isEmpty {
                stats.notesCount += 1
            }
        }
        
        // Check for journal entry on this date
        let startOfDay = calendar.startOfDay(for: date)
        if let entry = journalManager.entriesByDay[startOfDay], !entry.isEmpty {
            stats.hasJournal = true
        }
        
        return stats
    }
    
    private func tasksOnDate(_ date: Date) -> [TodoTask] {
        let startOfDay = calendar.startOfDay(for: date)
        return taskManager.tasks.filter { task in
            // Only show "today" scope tasks in the calendar
            guard task.timeScope == .today else { return false }
            
            if task.recurrence != nil {
                return task.occurs(on: startOfDay)
            } else {
                return calendar.isDate(task.startTime, inSameDayAs: startOfDay)
            }
        }
    }
    
    private func categoryColor(for task: TodoTask) -> Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return theme.primaryColor
    }
    
    // MARK: - Week/Month/Year Task Filtering
    
    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func tasksForWeek(_ weekStart: Date) -> [TodoTask] {
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        return taskManager.tasks.filter { task in
            guard task.timeScope == .week else { return false }
            
            if task.recurrence != nil {
                return task.occurs(inWeekStarting: weekStart)
            } else {
                if let taskScopeStart = task.scopeStartDate, let taskScopeEnd = task.scopeEndDate {
                    return calendar.isDate(taskScopeStart, inSameDayAs: weekStart) &&
                           calendar.isDate(taskScopeEnd, inSameDayAs: weekEnd)
                }
                return false
            }
        }
    }
    
    private func tasksForMonth(_ monthStart: Date) -> [TodoTask] {
        return taskManager.tasks.filter { task in
            guard task.timeScope == .month else { return false }
            
            if task.recurrence != nil {
                return task.occurs(inMonth: monthStart)
            } else {
                if let taskScopeStart = task.scopeStartDate {
                    return calendar.isDate(taskScopeStart, equalTo: monthStart, toGranularity: .month)
                }
                return false
            }
        }
    }
    
    private func tasksForYear(_ yearStart: Date) -> [TodoTask] {
        return taskManager.tasks.filter { task in
            guard task.timeScope == .year else { return false }
            
            if task.recurrence != nil {
                return task.occurs(inYear: yearStart)
            } else {
                if let taskScopeStart = task.scopeStartDate {
                    return calendar.isDate(taskScopeStart, equalTo: yearStart, toGranularity: .year)
                }
                return false
            }
        }
    }
    
    private func tasksForLongTerm() -> [TodoTask] {
        return taskManager.tasks.filter { $0.timeScope == .longTerm }
    }
    
    // MARK: - Stats for Scopes
    
    private func weekStats(for weekStart: Date) -> DayStats {
        let tasks = tasksForWeek(weekStart)
        var stats = DayStats()
        stats.taskCount = tasks.count
        
        for task in tasks {
            stats.photoCount += task.photos.count
            stats.voiceMemoCount += task.voiceMemos.count
            
            // Count notes from any completion
            for completion in task.completions.values {
                if let notes = completion.notes, !notes.isEmpty {
                    stats.notesCount += 1
                    break
                }
            }
        }
        
        return stats
    }
    
    private func monthStats(for monthStart: Date) -> DayStats {
        let tasks = tasksForMonth(monthStart)
        var stats = DayStats()
        stats.taskCount = tasks.count
        
        for task in tasks {
            stats.photoCount += task.photos.count
            stats.voiceMemoCount += task.voiceMemos.count
            
            for completion in task.completions.values {
                if let notes = completion.notes, !notes.isEmpty {
                    stats.notesCount += 1
                    break
                }
            }
        }
        
        return stats
    }
    
    private func yearStats(for yearStart: Date) -> DayStats {
        let tasks = tasksForYear(yearStart)
        var stats = DayStats()
        stats.taskCount = tasks.count
        
        for task in tasks {
            stats.photoCount += task.photos.count
            stats.voiceMemoCount += task.voiceMemos.count
            
            for completion in task.completions.values {
                if let notes = completion.notes, !notes.isEmpty {
                    stats.notesCount += 1
                    break
                }
            }
        }
        
        return stats
    }
    
    private func longTermStats() -> DayStats {
        let tasks = tasksForLongTerm()
        var stats = DayStats()
        stats.taskCount = tasks.count
        
        for task in tasks {
            stats.photoCount += task.photos.count
            stats.voiceMemoCount += task.voiceMemos.count
            
            for completion in task.completions.values {
                if let notes = completion.notes, !notes.isEmpty {
                    stats.notesCount += 1
                    break
                }
            }
        }
        
        return stats
    }
    
    private func weekRangeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            formatter.dateFormat = "d"
            let startStr = formatter.string(from: start)
            formatter.dateFormat = "d MMM yyyy"
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        } else {
            formatter.dateFormat = "d MMM"
            let startStr = formatter.string(from: start)
            formatter.dateFormat = "d MMM yyyy"
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        }
    }
    
    private func yearEndDate(for year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        return calendar.date(from: components) ?? Date()
    }
    
    private func applySelection() {
        if let selected = selectedDayForDetail {
            selectedDate = selected
            let today = Date()
            if let daysDiff = calendar.dateComponents([.day], from: today, to: selected).day {
                selectedDayOffset = daysDiff
                viewModel.selectDate(daysDiff)
                scrollProxy?.scrollTo(daysDiff, anchor: .center)
            }
        }
    }
}

// MARK: - Audio Player for Calendar

private final class CalendarAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func play(path: String) {
        stop()
        
        // Try to resolve the path in case it's stale
        guard let resolvedPath = AttachmentService.resolveFilePath(path) else {
            print("Could not resolve audio path: \(path)")
            return
        }
        
        let url = URL(fileURLWithPath: resolvedPath)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        stopTimer()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
}

// MARK: - Full Screen Photo View

private struct FullScreenPhotoView: View {
    let photo: TaskPhoto
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Try to load the full photo, fallback to thumbnail
            if let image = AttachmentService.loadImage(from: photo.photoPath) ?? AttachmentService.loadImage(from: photo.thumbnailPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("photo_not_found".localized)
                        .foregroundColor(.gray)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Voice Memo Player Row

private struct VoiceMemoPlayerRow: View {
    let memo: TaskVoiceMemo
    let isPlaying: Bool
    let currentTime: TimeInterval
    let onTap: () -> Void
    
    @Environment(\.theme) private var theme
    
    private var progress: Double {
        guard memo.duration > 0 else { return 0 }
        return currentTime / memo.duration
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.pink)
                    
                    Text(memo.displayName)
                        .font(.caption)
                        .themedPrimaryText()
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Time display: current / total when playing, just total otherwise
                    if isPlaying {
                        Text("\(formatTime(currentTime)) / \(formatTime(memo.duration))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.pink)
                    } else {
                        Text(formatTime(memo.duration))
                            .font(.caption.monospacedDigit())
                            .themedSecondaryText()
                    }
                }
                
                // Progress bar (only visible when playing or has progress)
                if isPlaying || currentTime > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.pink.opacity(0.2))
                                .frame(height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.pink)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPlaying ? Color.pink.opacity(0.15) : Color.pink.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isPlaying ? Color.pink.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MediaHubCalendarView(
        selectedDate: .constant(Date()),
        selectedDayOffset: .constant(0),
        viewModel: TimelineViewModel(),
        scrollProxy: nil
    )
}
