import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var vm: DashboardViewModel
    @EnvironmentObject var appState: AppState
    @State private var showAddTask = false
    @State private var showFilterSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color(red: 0.07, green: 0.05, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header
                        headerSection

                        // Stats Row
                        StatsOverviewView()
                            .padding(.horizontal)

                        // Filter chips
                        filterChips

                        // Sync status bar
                        if vm.isSyncing {
                            syncingIndicator
                        }

                        // Work Tasks Section
                        if !vm.workTasks.isEmpty {
                            taskSection(title: "Work", icon: "briefcase.fill", color: AppTheme.workColor, tasks: vm.workTasks)
                        }

                        // Personal Tasks Section
                        if !vm.personalTasks.isEmpty {
                            taskSection(title: "Personal", icon: "person.fill", color: AppTheme.personalColor, tasks: vm.personalTasks)
                        }

                        // Empty state
                        if vm.filteredTasks.isEmpty && !vm.isSyncing {
                            emptyState
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await vm.syncAll()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(vm.greetingMessage)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.purple)
                        }

                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(viewModel: vm)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterView(viewModel: vm)
        }
        .onAppear {
            vm.onAppear()
        }
    }

    // MARK: - Header

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .pulsing()

                    Text(vm.lastSyncText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()

            Button {
                Task { await vm.syncAll() }
            } label: {
                Label("Sync", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Filter Chips

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        icon: filter.icon,
                        isSelected: vm.selectedFilter == filter
                    ) {
                        withAnimation(.spring()) {
                            vm.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Task Section

    func taskSection(title: String, icon: String, color: Color, tasks: [ButlerTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundColor(color)
                    .padding(.horizontal)

                Spacer()

                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal)
            }

            ForEach(tasks) { task in
                TaskCardView(task: task) {
                    vm.completeTask(task)
                } onDelete: {
                    vm.deleteTask(task)
                }
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4), value: tasks)
    }

    // MARK: - Syncing Indicator

    var syncingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.purple)
                .scaleEffect(0.8)
            Text(TaskPlannerService.shared.processingStatus)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.6))

            Text("All clear!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("No tasks matching your current filters.\nPull down to sync or add a task manually.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple : Color.white.opacity(0.08))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .clipShape(Capsule())
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
