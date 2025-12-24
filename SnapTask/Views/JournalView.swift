import SwiftUI
import PhotosUI
import AVFoundation
import Combine

struct JournalView: View {
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var manager = JournalManager.shared
    @StateObject private var voiceMemoService = VoiceMemoService()

    @State private var currentDate: Date = Date()
    @State private var titleText: String = ""
    @State private var text: String = ""
    @State private var worthItText: String = ""
    @State private var isWorthItHidden: Bool = false
    @State private var selectedMood: MoodType?
    @State private var newTagText: String = ""
    @State private var tags: [String] = []
    
    // Photo states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fullScreenPhoto: JournalPhoto?
    @State private var showingCameraPicker = false
    @State private var showPhotoSourceDialog = false
    @State private var showingPhotoLibraryPicker = false
    
    // Voice memo states
    @State private var isRecordingVoice = false
    @State private var showMicDeniedAlert = false
    @State private var meterCancellable: AnyCancellable?
    @State private var isEditingVoiceMemo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mainEditorCard
                    worthItCard
                    attachmentsSection
                    tagsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .themedBackground()
            .navigationTitle("journal".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) {
                        manager.endEditing(for: currentDate, shouldSync: false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) {
                        manager.endEditing(for: currentDate, shouldSync: true)
                        dismiss()
                    }
                        .font(.body.weight(.semibold))
                }
            }
            .onAppear {
                currentDate = Calendar.current.startOfDay(for: date)
                manager.beginEditing(for: currentDate)
                loadEntry()
                UITextView.appearance().backgroundColor = .clear
            }
            .onChange(of: currentDate) { oldValue, newValue in
                manager.endEditing(for: oldValue, shouldSync: false)
                manager.beginEditing(for: newValue)
                loadEntry()
            }
            .onChange(of: titleText) { _, newValue in
                manager.updateTitle(for: currentDate, title: newValue)
            }
            .onChange(of: text) { _, newValue in
                manager.updateText(for: currentDate, text: newValue)
            }
            .onChange(of: worthItText) { _, newValue in
                manager.updateWorthItText(for: currentDate, worthItText: newValue)
            }
            .onChange(of: isWorthItHidden) { _, newValue in
                manager.setWorthItHidden(for: currentDate, isHidden: newValue)
            }
            .onChange(of: selectedMood) { _, newValue in
                manager.setMood(for: currentDate, mood: newValue)
            }
            .sheet(item: $fullScreenPhoto) { photo in
                NavigationStack {
                    VStack {
                        Spacer()
                        if let image = AttachmentService.loadImage(from: photo.photoPath) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()
                        }
                        Spacer()
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("close".localized) {
                                fullScreenPhoto = nil
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCameraPicker) {
                CameraImagePicker { image in
                    handleCapturedImage(image)
                }
            }
            .sheet(isPresented: $showingPhotoLibraryPicker) {
                let remaining = MediaLimits.remainingJournalPhotos(currentCount: currentPhotos.count)
                PhotoLibraryPicker(selectionLimit: remaining) { images in
                    Task {
                        await handleCapturedImages(images)
                    }
                }
            }
            .confirmationDialog("add_photos".localized, isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("take_photo".localized) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCameraPicker = true
                    } else {
                        showingPhotoLibraryPicker = true
                    }
                }
                Button("add_photos".localized) {
                    showingPhotoLibraryPicker = true
                }
                Button("cancel".localized, role: .cancel) {}
            }
            .alert("microphone_access_denied_title".localized, isPresented: $showMicDeniedAlert) {
                Button("ok".localized, role: .cancel) {}
            } message: {
                Text("microphone_access_denied_message".localized)
            }
        }
    }

    // MARK: - Main Card (Date + Title+Mood + Editor)

    private var mainEditorCard: some View {
        VStack(spacing: 12) {
            dateRow
            titleAndMoodRow
            Divider()
                .background(theme.borderColor)
            editor
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 3, x: 0, y: 2)
        )
    }

    private var dateRow: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.primaryColor.opacity(0.1)))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(formattedDate(currentDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textColor)
                Text(weekdayString(currentDate))
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.primaryColor.opacity(0.1)))
            }
        }
    }

    private var titleAndMoodRow: some View {
        HStack(spacing: 10) {
            TextField("journal_page_title".localized, text: $titleText)
                .font(.headline)
                .themedPrimaryText()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.surfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.borderColor, lineWidth: 1)
                        )
                )

            Menu {
                Button {
                    selectedMood = nil
                } label: {
                    Label("remove_mood".localized, systemImage: "slash.circle")
                }
                Divider()
                ForEach(MoodType.allCases, id: \.self) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        HStack {
                            Text(mood.emoji)
                            Text(localizedName(for: mood))
                        }
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.primaryColor.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: 52, height: 40)
                    Group {
                        if let mood = selectedMood {
                            Text(mood.emoji)
                                .font(.title2)
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(theme.primaryColor)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.automatic)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            textEditorClearBackground(text: $text)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .frame(minHeight: 300)
                .background(Color.clear)
                .themedPrimaryText()

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("journal_placeholder".localized)
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.clear)
    }

    private var worthItCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("worth_it_title".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textColor)
                Spacer()
                Toggle(
                    "show_worth_it_section".localized,
                    isOn: Binding(
                        get: { !isWorthItHidden },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isWorthItHidden = !newValue
                            }
                        }
                    )
                )
                .labelsHidden()
            }

            if !isWorthItHidden {
                Divider()
                    .background(theme.borderColor)

                ZStack(alignment: .topLeading) {
                    textEditorClearBackground(text: $worthItText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .frame(minHeight: 120)
                        .background(Color.clear)
                        .themedPrimaryText()

                    if worthItText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("worth_it_subtitle".localized)
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.22), value: isWorthItHidden)
    }

    // MARK: - Attachments Section

    private var attachmentsSection: some View {
        VStack(spacing: 16) {
            photosCard
            voiceMemosCard
        }
    }

    private var currentPhotos: [JournalPhoto] {
        manager.entry(for: currentDate).photos
    }
    
    private var currentVoiceMemos: [JournalVoiceMemo] {
        manager.entry(for: currentDate).voiceMemos
    }
    
    private var canAddMorePhotos: Bool {
        MediaLimits.canAddJournalPhoto(currentCount: currentPhotos.count)
    }
    
    private var canAddMoreVoiceMemos: Bool {
        MediaLimits.canAddJournalVoiceMemo(currentCount: currentVoiceMemos.count)
    }
    
    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                Text("photos".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textColor)
                Spacer()
                // Photo count indicator
                Text("\(currentPhotos.count)/\(MediaLimits.maxPhotosPerJournal)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            let currentEntry = manager.entry(for: currentDate)
            
            if !currentEntry.photos.isEmpty {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(currentEntry.photos) { photo in
                        ZStack(alignment: .topTrailing) {
                            if let image = AttachmentService.loadImage(from: photo.thumbnailPath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 90)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(10)
                                    .onTapGesture {
                                        fullScreenPhoto = photo
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 90)
                            }
                            
                            Button {
                                removePhoto(photo)
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 16, height: 16)
                                            .opacity(0.001)
                                    )
                            }
                            .padding(6)
                        }
                    }
                }
                
                if canAddMorePhotos {
                    Button {
                        showPhotoSourceDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("add_photos".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            } else {
                Button {
                    showPhotoSourceDialog = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("add_photos".localized)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
    }

    private var voiceMemosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(.pink)
                Text("voice_memos".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textColor)
                Spacer()
                // Voice memo count indicator
                Text("\(currentVoiceMemos.count)/\(MediaLimits.maxVoiceMemosPerJournal)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            if canAddMoreVoiceMemos || isRecordingVoice {
                HStack(spacing: 12) {
                    Button {
                        if isRecordingVoice {
                            if let memo = voiceMemoService.stopJournalRecording() {
                                manager.addVoiceMemo(memo, for: currentDate)
                            }
                            isRecordingVoice = false
                        } else {
                            Task {
                                let granted = await voiceMemoService.requestPermission()
                                if !granted {
                                    showMicDeniedAlert = true
                                    return
                                }
                                do {
                                    let entryId = manager.entry(for: currentDate).id
                                    try voiceMemoService.startJournalRecording(for: entryId)
                                    isRecordingVoice = true
                                } catch {
                                    isRecordingVoice = false
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: isRecordingVoice ? "stop.circle.fill" : "record.circle.fill")
                                .font(.system(size: 16))
                            Text(isRecordingVoice ? "stop".localized : "record".localized)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isRecordingVoice ? Color.orange : Color.red)
                        )
                    }
                    .frame(minWidth: 110)
                    
                    Spacer()
                }
            }
            
            if isRecordingVoice {
                VStack(alignment: .leading, spacing: 6) {
                    WaveformView(levels: voiceMemoService.meterLevels, color: .pink)
                        .frame(height: 40)
                    Text("recording".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .transition(.opacity)
            }

            let currentEntry = manager.entry(for: currentDate)
            if currentEntry.voiceMemos.isEmpty {
                Text("no_voice_memos_yet".localized)
                    .font(.subheadline)
                    .themedSecondaryText()
            } else {
                VStack(spacing: 8) {
                    ForEach(currentEntry.voiceMemos) { memo in
                        JournalVoiceMemoRow(
                            memo: memo,
                            onDelete: {
                                removeVoiceMemo(memo)
                            },
                            onRename: { newName in
                                renameMemo(memo, to: newName)
                            },
                            onEditingStateChanged: { editing in
                                isEditingVoiceMemo = editing
                            }
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("tags".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textColor)

            if tags.isEmpty {
                Text("tags_description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                            Button {
                                removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(theme.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(theme.surfaceColor)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.primaryColor.opacity(0.25), lineWidth: 1)
                                )
                        )
                        .shadow(color: theme.shadowColor, radius: 1, x: 0, y: 1)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("add_tag".localized, text: $newTagText, onCommit: commitTag)
                    .textFieldStyle(.roundedBorder)
                Button {
                    commitTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(theme.accentColor)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Photo Helpers
    
    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else { return }
        let entryId = manager.entry(for: currentDate).id
        let id = UUID()
        let createdAt = Date()
        if let photo = AttachmentService.addJournalPhoto(for: entryId, imageData: data, id: id, createdAt: createdAt) {
            manager.addPhoto(photo, for: currentDate)
        }
        showingCameraPicker = false
    }
    
    private func handleCapturedImages(_ images: [UIImage]) async {
        let entryId = manager.entry(for: currentDate).id
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else { continue }
            let id = UUID()
            let createdAt = Date()
            if let photo = AttachmentService.addJournalPhoto(for: entryId, imageData: data, id: id, createdAt: createdAt) {
                await MainActor.run {
                    manager.addPhoto(photo, for: currentDate)
                }
            }
        }
    }
    
    private func removePhoto(_ photo: JournalPhoto) {
        CloudKitService.shared.deleteJournalPhoto(on: currentDate, photo: photo)
    }

    // MARK: - Voice Memo Helpers
    
    private func removeVoiceMemo(_ memo: JournalVoiceMemo) {
        CloudKitService.shared.deleteJournalVoiceMemo(on: currentDate, memo: memo)
    }
    
    private func renameMemo(_ memo: JournalVoiceMemo, to newName: String) {
        manager.updateVoiceMemoName(newName, forMemoId: memo.id, date: currentDate)
    }

    // MARK: - Helpers

    private func formattedDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: d)
    }

    private func weekdayString(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "EEEE"
        return df.string(from: d).capitalized
    }

    private func localizedName(for mood: MoodType) -> String {
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        if langCode == "it" {
            return mood.italianName.capitalized
        } else {
            switch mood {
            case .awful: return "Awful"
            case .bad: return "Bad"
            case .poor: return "Poor"
            case .neutral: return "Neutral"
            case .good: return "Good"
            case .great: return "Great"
            case .excellent: return "Excellent"
            }
        }
    }

    private func loadEntry() {
        let entry = manager.entry(for: currentDate)
        titleText = entry.title
        text = entry.text
        worthItText = entry.worthItText
        isWorthItHidden = entry.isWorthItHidden
        selectedMood = entry.mood
        tags = entry.tags
    }

    private func commitTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        manager.addTag(tag, for: currentDate)
        tags.append(tag)
        newTagText = ""
    }

    private func removeTag(_ tag: String) {
        manager.removeTag(tag, for: currentDate)
        tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
}

// MARK: - TextEditor background helper
private func textEditorClearBackground(text: Binding<String>) -> some View {
    let editor = TextEditor(text: text)
    #if compiler(>=5.7)
    if #available(iOS 16.0, *) {
        return AnyView(editor.scrollContentBackground(.hidden).background(Color.clear))
    } else {
        return AnyView(editor.background(Color.clear))
    }
    #else
    return AnyView(editor.background(Color.clear))
    #endif
}