import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var tasks: [ButlerTask] = []
    @Published var dayPlan: DayPlan?
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var selectedFilter: TaskFilter = .all
    @Published var selectedSource: NotificationSource? = nil
    @Published var showCompletedTasks = false
    @Published var lastSyncText = "Never synced"

    // MARK: - Computed Properties

    var filteredTasks: [ButlerTask] {
        var result = tasks

        // Source filter
        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }

        // Status filter
        if !showCompletedTasks {
            result = result.filter { $0.status != .completed && $0.status != .cancelled }
        }

        // Category filter
        switch selectedFilter {
        case .all: break
        case .work: result = result.filter { $0.category == .work }
        case .personal: result = result.filter { $0.category == .personal || $0.category == .health || $0.category == .finance }
        case .urgent: result = result.filter { $0.priority == .urgent || $0.priority == .high }
        case .today: result = result.filter { $0.isScheduledToday || ($0.dueDate != nil && Calendar.current.isDateInToday($0.dueDate!)) }
        }

        return result.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var workTasks: [ButlerTask] {
        filteredTasks.filter { $0.category == .work }
    }

    var personalTasks: [ButlerTask] {
        filteredTasks.filter { $0.category != .work }
    }

    var urgentCount: Int {
        tasks.filter { ($0.priority == .urgent || $0.priority == .high) && $0.status == .pending }.count
    }

    var overdueCount: Int {
        tasks.filter { $0.isOverdue }.count
    }

    var todayCount: Int {
        tasks.filter { $0.isScheduledToday && $0.status != .completed }.count
    }

    var completionToday: Double {
        let today = tasks.filter { $0.isScheduledToday }
        guard !today.isEmpty else { return 0 }
        let done = today.filter { $0.status == .completed }.count
        return Double(done) / Double(today.count)
    }

    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    // MARK: - Services

    private let persistence = PersistenceService.shared
    private let planner = TaskPlannerService.shared

    // MARK: - Init & Load

    func onAppear() {
        loadLocalData()
        updateLastSyncText()
    }

    func loadLocalData() {
        tasks = persistence.loadTasks()
        dayPlan = persistence.loadDayPlan()

        // Load sample data if empty (for demo)
        if tasks.isEmpty {
            tasks = ButlerTask.samples
            persistence.saveTasks(tasks)
        }

        if dayPlan == nil {
            dayPlan = DayPlanBuilder.buildFromTasks(tasks)
        }
    }

    // MARK: - Sync

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil

        do {
            let result = try await planner.syncAndProcess()
            let newTasks = result.tasks

            // Merge new tasks with existing (avoid duplicates by sourceID)
            let existingSourceIDs = Set(tasks.compactMap(\.sourceID))
            let uniqueNewTasks = newTasks.filter { task in
                guard let sid = task.sourceID else { return true }
                return !existingSourceIDs.contains(sid)
            }

            tasks.insert(contentsOf: uniqueNewTasks, at: 0)
            dayPlan = result.plan

            persistence.saveTasks(tasks)
            persistence.saveDayPlan(result.plan)
            persistence.lastSyncDate = Date()
            updateLastSyncText()

        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncing = false
    }

    private func updateLastSyncText() {
        guard let date = persistence.lastSyncDate else {
            lastSyncText = "Never synced"
            return
        }
        lastSyncText = "Last sync: \(date.timeAgoDisplay)"
    }

    // MARK: - Task Actions

    func completeTask(_ task: ButlerTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].markComplete()
        persistence.updateTask(tasks[index])
        NotificationMonitor.shared.cancelReminder(for: task.id)
    }

    func deleteTask(_ task: ButlerTask) {
        tasks.removeAll { $0.id == task.id }
        persistence.deleteTask(id: task.id)
    }

    func snoozeTask(_ task: ButlerTask, until date: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].snooze(until: date)
        persistence.updateTask(tasks[index])
    }

    func addTask(_ task: ButlerTask) {
        tasks.insert(task, at: 0)
        persistence.addTask(task)

        // Schedule reminder if task has a date
        if task.scheduledDate != nil || task.dueDate != nil {
            NotificationMonitor.shared.scheduleTaskReminder(for: task)
        }
    }

    func updateTask(_ task: ButlerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            persistence.updateTask(task)
        }
    }

    // MARK: - Day Plan

    func regenerateDayPlan() async {
        isLoading = true
        do {
            let plan = try await planner.generateDailyPlan(for: tasks.filter { $0.status == .pending })
            dayPlan = plan
            persistence.saveDayPlan(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clearCompleted() {
        tasks.removeAll { $0.status == .completed }
        persistence.saveTasks(tasks)
    }
}

// MARK: - Filter Enum

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case work = "Work"
    case personal = "Personal"
    case urgent = "Urgent"
    case today = "Today"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .urgent: return "exclamationmark.circle.fill"
        case .today: return "sun.max.fill"
        }
    }
}
