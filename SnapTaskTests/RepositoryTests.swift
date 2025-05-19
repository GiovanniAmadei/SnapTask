import XCTest
@testable import SnapTask

final class RepositoryTests: XCTestCase {
    
    // Test repository
    class MockTaskRepository: TaskRepository {
        var tasks: [TodoTask] = []
        var onTasksUpdated: (() -> Void)?
        var callRecord: [String] = []
        
        func getTasks() -> [TodoTask] {
            callRecord.append("getTasks")
            return tasks
        }
        
        func getTask(id: UUID) -> TodoTask? {
            callRecord.append("getTask")
            return tasks.first { $0.id == id }
        }
        
        func saveTasks(_ tasks: [TodoTask]) {
            callRecord.append("saveTasks")
            self.tasks = tasks
            onTasksUpdated?()
        }
        
        func saveTask(_ task: TodoTask) {
            callRecord.append("saveTask")
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = task
            } else {
                tasks.append(task)
            }
            onTasksUpdated?()
        }
        
        func deleteTask(_ task: TodoTask) {
            callRecord.append("deleteTask")
            deleteTaskWithId(task.id)
        }
        
        func deleteTaskWithId(_ id: UUID) {
            callRecord.append("deleteTaskWithId")
            tasks.removeAll { $0.id == id }
            onTasksUpdated?()
        }
        
        func toggleTaskCompletion(taskId: UUID, on date: Date) -> TodoTask? {
            callRecord.append("toggleTaskCompletion")
            guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
            
            var task = tasks[index]
            let startOfDay = date.startOfDay
            
            if let completion = task.completions[startOfDay] {
                task.completions[startOfDay] = TaskCompletion(
                    isCompleted: !completion.isCompleted,
                    completedSubtasks: completion.completedSubtasks
                )
            } else {
                task.completions[startOfDay] = TaskCompletion(
                    isCompleted: true, 
                    completedSubtasks: []
                )
            }
            
            tasks[index] = task
            onTasksUpdated?()
            return task
        }
        
        func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID, on date: Date) -> TodoTask? {
            callRecord.append("toggleSubtaskCompletion")
            guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
            
            var task = tasks[index]
            let startOfDay = date.startOfDay
            
            var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
            
            if completion.completedSubtasks.contains(subtaskId) {
                completion.completedSubtasks.remove(subtaskId)
            } else {
                completion.completedSubtasks.insert(subtaskId)
            }
            
            task.completions[startOfDay] = completion
            tasks[index] = task
            onTasksUpdated?()
            return task
        }
        
        func resetCallRecord() {
            callRecord = []
        }
    }
    
    var repository: MockTaskRepository!
    var taskManager: TaskManager!
    
    override func setUp() {
        super.setUp()
        repository = MockTaskRepository()
        taskManager = TaskManager(repository: repository)
    }
    
    override func tearDown() {
        taskManager = nil
        repository = nil
        super.tearDown()
    }
    
    func testAddTask() {
        // Given
        let task = TodoTask(name: "Test Task", startTime: Date())
        
        // When
        taskManager.addTask(task)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["saveTask"])
        XCTAssertEqual(repository.tasks.count, 1)
        XCTAssertEqual(repository.tasks[0].name, "Test Task")
    }
    
    func testUpdateTask() {
        // Given
        let task = TodoTask(name: "Task 1", startTime: Date())
        repository.saveTask(task)
        repository.resetCallRecord()
        
        // When
        var updatedTask = task
        updatedTask.name = "Updated Task"
        taskManager.updateTask(updatedTask)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["saveTask"])
        XCTAssertEqual(repository.tasks.count, 1)
        XCTAssertEqual(repository.tasks[0].name, "Updated Task")
    }
    
    func testDeleteTask() {
        // Given
        let task = TodoTask(name: "Task to delete", startTime: Date())
        repository.saveTask(task)
        repository.resetCallRecord()
        
        // When
        taskManager.removeTask(task)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["deleteTask", "deleteTaskWithId"])
        XCTAssertEqual(repository.tasks.count, 0)
    }
    
    func testToggleTaskCompletion() {
        // Given
        let task = TodoTask(name: "Task to complete", startTime: Date())
        repository.saveTask(task)
        repository.resetCallRecord()
        let today = Date().startOfDay
        
        // When
        taskManager.toggleTaskCompletion(task.id, on: today)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["toggleTaskCompletion"])
        XCTAssertTrue(repository.tasks[0].completions[today]?.isCompleted ?? false)
        
        // Toggle again to uncomplete
        repository.resetCallRecord()
        taskManager.toggleTaskCompletion(task.id, on: today)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["toggleTaskCompletion"])
        XCTAssertFalse(repository.tasks[0].completions[today]?.isCompleted ?? true)
    }
    
    func testToggleSubtaskCompletion() {
        // Given
        var task = TodoTask(name: "Task with subtask", startTime: Date())
        let subtask = Subtask(name: "Subtask 1")
        task.subtasks = [subtask]
        repository.saveTask(task)
        repository.resetCallRecord()
        let today = Date().startOfDay
        
        // When
        taskManager.toggleSubtask(taskId: task.id, subtaskId: subtask.id, on: today)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["toggleSubtaskCompletion"])
        XCTAssertTrue(repository.tasks[0].completions[today]?.completedSubtasks.contains(subtask.id) ?? false)
        
        // Toggle again to uncomplete
        repository.resetCallRecord()
        taskManager.toggleSubtask(taskId: task.id, subtaskId: subtask.id, on: today)
        
        // Then
        XCTAssertEqual(repository.callRecord, ["toggleSubtaskCompletion"])
        XCTAssertFalse(repository.tasks[0].completions[today]?.completedSubtasks.contains(subtask.id) ?? false)
    }
    
    func testUpdateRepository() {
        // Given
        let task = TodoTask(name: "Task 1", startTime: Date())
        repository.saveTask(task)
        
        let newRepository = MockTaskRepository()
        
        // When
        taskManager.updateRepository(newRepository)
        
        // Then
        XCTAssertEqual(newRepository.tasks.count, 1)
        XCTAssertEqual(newRepository.tasks[0].name, "Task 1")
    }
} 