import SwiftUI

struct TimelineView: View {
    @StateObject var viewModel: TimelineViewModel
    @State private var showingNewTask = false
    @State private var selectedDayOffset = 0
    @State private var showingCalendarPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Header con mese e selettore data
                    TimelineHeaderView(
                        viewModel: viewModel,
                        selectedDayOffset: $selectedDayOffset,
                        showingCalendarPicker: $showingCalendarPicker,
                        scrollProxy: $scrollProxy
                    )
                    .background(Color(.systemBackground))
                    .zIndex(1)
                    
                    // Lista task e pulsante aggiungi
                    TaskListView(
                        viewModel: viewModel,
                        showingNewTask: $showingNewTask
                    )
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewTask) {
                TaskFormView(
                    viewModel: TaskFormViewModel(initialDate: viewModel.selectedDate),
                    onSave: { task in
                        viewModel.addTask(task)
                    }
                )
            }
            .sheet(isPresented: $showingCalendarPicker) {
                CalendarPickerView(
                    selectedDate: $viewModel.selectedDate,
                    selectedDayOffset: $selectedDayOffset,
                    viewModel: viewModel,
                    scrollProxy: scrollProxy
                )
            }
        }
    }
}

// MARK: - Header View
struct TimelineHeaderView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var showingCalendarPicker: Bool
    @Binding var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 4) {
            // Titolo mese e anno
            HStack {
                Text(viewModel.monthYearString)
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingCalendarPicker = true }) {
                    Image(systemName: "calendar")
                        .foregroundColor(.pink)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Selettore date orizzontale
            DateSelectorView(
                viewModel: viewModel,
                selectedDayOffset: $selectedDayOffset,
                scrollProxy: $scrollProxy
            )
        }
    }
}

// MARK: - Date Selector
struct DateSelectorView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var scrollProxy: ScrollViewProxy?
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Indicatore centrale fisso (rimosso il rettangolo azzurro)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(-365...365, id: \.self) { offset in
                            DayCell(
                                date: Calendar.current.date(
                                    byAdding: .day,
                                    value: offset,
                                    to: Date()
                                ) ?? Date(),
                                isSelected: offset == selectedDayOffset,
                                offset: offset
                            ) { _ in
                                withAnimation {
                                    selectedDayOffset = offset
                                    viewModel.selectDate(offset)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    
                                    // Assicurati che la data selezionata sia centrata
                                    proxy.scrollTo(offset, anchor: .center)
                                }
                            }
                            .id(offset)
                            .scaleEffect(offset == selectedDayOffset ? 1.08 : 1.0)
                            .animation(.spring(response: 0.3), value: offset == selectedDayOffset)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6) // Aggiunto padding verticale per evitare il taglio
                }
                .onAppear {
                    scrollProxy = proxy
                    // Centra la data selezionata all'avvio
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(selectedDayOffset, anchor: .center)
                        }
                    }
                }
                // Aggiornato per iOS 17+
                .onChange(of: selectedDayOffset) { _, newValue in
                    // Centra la data selezionata quando cambia
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            isDragging = false
                            let velocity = value.predictedEndLocation.x - value.location.x
                            
                            if abs(velocity) > 50 {
                                let direction = velocity > 0 ? -1 : 1
                                let newOffset = selectedDayOffset + direction
                                
                                withAnimation {
                                    selectedDayOffset = newOffset
                                    viewModel.selectDate(newOffset)
                                    proxy.scrollTo(newOffset, anchor: .center)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } else {
                                // Calcola l'offset più vicino in base alla posizione di trascinamento
                                let cellWidth: CGFloat = 62 // 50 (width) + 12 (spacing)
                                let estimatedOffset = Int(round(dragOffset / cellWidth))
                                let newOffset = selectedDayOffset - estimatedOffset
                                
                                if newOffset != selectedDayOffset {
                                    withAnimation {
                                        selectedDayOffset = newOffset
                                        viewModel.selectDate(newOffset)
                                        proxy.scrollTo(newOffset, anchor: .center)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } else {
                                    // Se non cambia l'offset, assicurati che la vista torni alla posizione centrale
                                    withAnimation {
                                        proxy.scrollTo(selectedDayOffset, anchor: .center)
                                    }
                                }
                            }
                        }
                )
            }
        }
    }
}

// MARK: - Task List View
struct TaskListView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showingNewTask: Bool
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.tasksForSelectedDate().indices, id: \.self) { index in
                        TimelineTaskCard(
                            task: viewModel.tasksForSelectedDate()[index],
                            onToggleComplete: { viewModel.toggleTaskCompletion(viewModel.tasksForSelectedDate()[index].id) },
                            onToggleSubtask: { subtaskId in
                                viewModel.toggleSubtask(taskId: viewModel.tasksForSelectedDate()[index].id, subtaskId: subtaskId)
                            },
                            viewModel: viewModel
                        )
                        .padding(.horizontal, 4)
                        .padding(.top, index == 0 ? 8 : 0)
                        .padding(.bottom, 0)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 100)
            }
            
            // Centered Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AddTaskButton(isShowingTaskForm: $showingNewTask)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Calendar Picker View
struct CalendarPickerView: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    @ObservedObject var viewModel: TimelineViewModel
    let scrollProxy: ScrollViewProxy?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("",
                          selection: $selectedDate,
                          displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                
                Button("Done") {
                    let calendar = Calendar.current
                    let today = Date()
                    if let daysDiff = calendar.dateComponents([.day], from: today, to: selectedDate).day {
                        withAnimation {
                            selectedDayOffset = daysDiff
                            viewModel.selectDate(daysDiff)
                            scrollProxy?.scrollTo(daysDiff, anchor: .center)
                        }
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
        }
    }
}

// Day Cell Component
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let offset: Int
    let action: (Int) -> Void
    
    // Explicit initializer to handle closure parameter
    init(date: Date, isSelected: Bool, offset: Int, action: @escaping (Int) -> Void) {
        self.date = date
        self.isSelected = isSelected
        self.offset = offset
        self.action = action
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : (isToday ? .pink : .secondary))
            
            Text(dayNumber)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : (isToday ? .pink : .primary))
        }
        .frame(width: 45, height: 60)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? 
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [.pink, .pink.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) :
                    (isToday ? 
                        AnyShapeStyle(Color.pink.opacity(0.1)) : 
                        AnyShapeStyle(Color.clear)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.clear : (isToday ? Color.pink.opacity(0.3) : Color.gray.opacity(0.2)), 
                            lineWidth: 1)
        )
        .onTapGesture {
            action(offset)
        }
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// Enhanced Task Card
private struct TimelineTaskCard: View {
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isExpanded = false
    @State private var showingPomodoro = false
    @State private var showingEditSheet = false
    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        let startOfDay = viewModel.selectedDate.startOfDay
        if let completion = task.completions[startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private var completionProgress: Double {
        guard !task.subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let completion = task.completions[viewModel.selectedDate.startOfDay]
        let completedCount = completion?.completedSubtasks.count ?? 0
        return Double(completedCount) / Double(task.subtasks.count)
    }
    
    private var completedSubtasks: Set<UUID> {
        task.completions[viewModel.selectedDate.startOfDay]?.completedSubtasks ?? []
    }
    
    private var subtaskCountText: String {
        if task.subtasks.isEmpty { return "" }
        let completedCount = completedSubtasks.count
        let totalCount = task.subtasks.count
        return "\(completedCount)/\(totalCount)"
    }
    
    private var currentStreak: Int {
        guard let recurrence = task.recurrence else { return 0 }
        
        // Ottieni la data selezionata
        let selectedDate = viewModel.selectedDate.startOfDay
        
        // Calcola lo streak fino alla data selezionata
        var streak = 0
        var currentDate = selectedDate
        
        // Controlla se la task è completata nella data selezionata
        let isCompletedOnSelectedDate = task.completions[selectedDate]?.isCompleted == true
        
        // Se la task è completata nella data selezionata, inizia il conteggio da 1
        if isCompletedOnSelectedDate {
            streak = 1
            // Vai indietro di un giorno per continuare il conteggio
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        // Controlla all'indietro per trovare lo streak
        while true {
            // Verifica se la data corrente è una data in cui la task dovrebbe essere eseguita
            guard recurrence.shouldOccurOn(date: currentDate) else {
                // Se la task non doveva essere eseguita in questa data, passa alla data precedente
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                continue
            }
            
            // Verifica se la task è stata completata in questa data
            if task.completions[currentDate]?.isCompleted == true {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                // Lo streak è interrotto
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        ZStack {
            // Contenuto principale della card
            VStack(alignment: .leading, spacing: 2) {
                // Task header
                HStack(alignment: .center, spacing: 8) {
                    // Barra colorata della categoria
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    task.category.map { Color(hex: $0.color) } ?? .gray,
                                    task.category.map { Color(hex: $0.color).opacity(0.7) } ?? .gray.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                        .cornerRadius(2)
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center) {
                            Text(task.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // Streak indicator migliorato
                            if task.recurrence != nil && currentStreak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                    Text("\(currentStreak)")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.15))
                                )
                            }
                            
                            Spacer()
                            
                            // Freccia per espandere se ci sono subtask
                            if !task.subtasks.isEmpty {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                            }
                        }
                        
                        if let description = task.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    if task.hasDuration && task.duration > 0 {
                        Text(task.duration.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if task.pomodoroSettings != nil {
                        Button(action: { showingPomodoro = true }) {
                            Image(systemName: "timer")
                                .foregroundColor(task.category.map { Color(hex: $0.color) } ?? .gray)
                        }
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onToggleComplete()
                        }
                    }) {
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            // Progress circle
                            if !task.subtasks.isEmpty {
                                Circle()
                                    .trim(from: 0, to: completionProgress)
                                    .stroke(Color.pink, lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completionProgress)
                            }
                            
                            // Checkmark
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted ? .green : .gray)
                                .font(.title2)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Subtasks (mostrati solo se espanso)
                if isExpanded && !task.subtasks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(task.subtasks) { subtask in
                            TimelineSubtaskRow(
                                subtask: subtask,
                                isCompleted: completedSubtasks.contains(subtask.id),
                                onToggle: { onToggleSubtask(subtask.id) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) * 2.0 {
                            // Applicare l'offset solo per drag verso sinistra con animazione interattiva
                            if value.translation.width < 0 {
                                withAnimation(.interactiveSpring()) {
                                    offset = max(-140, value.translation.width)
                                    showingActions = true
                                }
                            } else if offset < 0 {
                                // Se stiamo trascinando verso destra da uno stato aperto
                                withAnimation(.interactiveSpring()) {
                                    offset = min(0, value.translation.width - 140)
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -60 || (offset < -60 && value.translation.width > 0 && value.translation.width < 60) {
                                // Se il drag è abbastanza verso sinistra o se siamo già aperti e non c'è un significativo drag verso destra
                                offset = -140
                                showingActions = true
                            } else {
                                // Chiudi i pulsanti
                                offset = 0
                                showingActions = false
                            }
                        }
                    }
            )
            .overlay(
                ZStack {
                    // Sfondo semitrasparente che si estende dal lato destro
                    if offset < 0 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.001)) // Trasparente ma rilevabile
                            .frame(width: -offset)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    offset = 0
                                    showingActions = false
                                }
                            }
                    }
                    
                    HStack(spacing: 0) {
                        Spacer()
                        
                        // Edit button
                        Button(action: {
                            showingEditSheet = true
                            showingActions = false
                            withAnimation(.spring()) {
                                offset = 0
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 70, height: 50)
                                    .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 1)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Edit")
                                        .font(.system(.caption2, design: .rounded).bold())
                                }
                                .foregroundColor(.white)
                            }
                        }
                        
                        // Delete button
                        Button(action: {
                            withAnimation(.spring()) {
                                TaskManager.shared.removeTask(task)
                                offset = 0
                                showingActions = false
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.red.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 70, height: 50)
                                    .shadow(color: Color.red.opacity(0.2), radius: 2, x: 0, y: 1)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Delete")
                                        .font(.system(.caption2, design: .rounded).bold())
                                }
                                .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 60)
                }
                // Pulsanti fissati a destra
                .frame(width: UIScreen.main.bounds.width, alignment: .trailing)
                // Traslazione orizzontale per seguire il bordo della card
                .offset(x: min(0, offset + 140))
                , alignment: .trailing
            )
            // Tap per chiudere il menu se aperto, altrimenti espandi/collassa
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring()) {
                        offset = 0
                        showingActions = false
                    }
                } else if !task.subtasks.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                TaskFormView(initialTask: task)
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
    }
}

// Add Task Button
private struct AddTaskButton: View {
    @Binding var isShowingTaskForm: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { isShowingTaskForm = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Circle()
                            .fill(Color.pink.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: Color.pink.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                )
        }
        .padding(.horizontal, 20)
    }
}

private struct TimelineSubtaskRow: View {
    let subtask: Subtask
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                // Disable implicit animations
                withAnimation(.none) {
                    onToggle()
                }
            }) {
                SubtaskCheckmark(isCompleted: isCompleted)
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
            .frame(width: 32, height: 32)
            
            Text(subtask.name)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .secondary : .primary)
            
            Spacer()
        }
        .padding(.leading, 16) // Add more padding to move subtasks to the right
    }
} 
