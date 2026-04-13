import SwiftUI

struct TaskCardView: View {

    let task: ButlerTask
    var onComplete: () -> Void
    var onDelete: () -> Void

    @State private var showDetail = false
    @State private var offset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Delete background
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .padding(.trailing, 24)
                    .opacity(offset < -40 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))

            // Card content
            cardContent
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -100)
                                isDragging = true
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -70 {
                                    offset = -UIScreen.main.bounds.width
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onDelete()
                                    }
                                } else {
                                    offset = 0
                                }
                                isDragging = false
                            }
                        }
                )
        }
        .sheet(isPresented: $showDetail) {
            TaskDetailView(task: task, onComplete: onComplete)
        }
    }

    // MARK: - Card Content

    var cardContent: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 14) {

                // Complete button
                Button {
                    withAnimation(.spring()) {
                        onComplete()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.forPriority(task.priority).opacity(0.6), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        if task.status == .completed {
                            Circle()
                                .fill(Color.forPriority(task.priority))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(task.status == .completed ? .white.opacity(0.4) : .white)
                            .strikethrough(task.status == .completed)
                            .lineLimit(2)

                        Spacer()

                        // Source badge
                        sourceBadge
                    }

                    HStack(spacing: 8) {
                        // Category
                        Label(task.category.rawValue, systemImage: task.category.icon)
                            .font(.caption2)
                            .foregroundColor(Color.forCategory(task.category).opacity(0.8))

                        if let time = task.timeDisplay {
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                            Label(time, systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        if let duration = task.estimatedDuration {
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                            Text("\(duration)m")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        // Overdue indicator
                        if task.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else if task.isAIGenerated {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }
                }
            }
            .padding(Constants.UI.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                            .stroke(
                                task.priority == .urgent
                                    ? Color.red.opacity(0.4)
                                    : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Badge

    var sourceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: task.source.icon)
                .font(.caption2)
            Text(task.source.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.forSource(task.source).opacity(0.15))
        .foregroundColor(Color.forSource(task.source))
        .clipShape(Capsule())
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let task: ButlerTask
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Priority & Source header
                        HStack {
                            Label(task.priority.rawValue, systemImage: task.priority.icon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.forPriority(task.priority).opacity(0.2))
                                .foregroundColor(Color.forPriority(task.priority))
                                .clipShape(Capsule())

                            Label(task.source.rawValue, systemImage: task.source.icon)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.forSource(task.source).opacity(0.15))
                                .foregroundColor(Color.forSource(task.source))
                                .clipShape(Capsule())

                            Spacer()
                        }

                        // Title
                        Text(task.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        // Metadata
                        VStack(spacing: 12) {
                            if let due = task.dueDate {
                                DetailRow(icon: "calendar", label: "Due", value: due.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let duration = task.estimatedDuration {
                                DetailRow(icon: "clock", label: "Duration", value: "\(duration) minutes")
                            }
                            DetailRow(icon: task.category.icon, label: "Category", value: task.category.rawValue)
                            DetailRow(icon: "clock.badge.checkmark", label: "Created", value: task.createdAt.timeAgoDisplay)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if let original = task.originalMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Original Message")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                Text(original)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // Complete button
                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(task.status == .completed)
                        .opacity(task.status == .completed ? 0.5 : 1)
                    }
                    .padding()
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.purple)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .work
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var estimatedDuration = 30

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section("Task") {
                        TextField("Title", text: $title)
                        TextField("Description (optional)", text: $description, axis: .vertical)
                            .lineLimit(3)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Details") {
                        Picker("Priority", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        Picker("Category", selection: $category) {
                            ForEach(TaskCategory.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c)
                            }
                        }
                        Stepper("Duration: \(estimatedDuration) min", value: $estimatedDuration, in: 5...480, step: 5)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Due Date") {
                        Toggle("Set due date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red.opacity(0.8))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let task = ButlerTask(
                            title: title,
                            description: description,
                            priority: priority,
                            category: category,
                            source: .manual,
                            dueDate: hasDueDate ? dueDate : nil,
                            estimatedDuration: estimatedDuration
                        )
                        viewModel.addTask(task)
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Source filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Source")
                            .font(.headline)
                            .foregroundColor(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            sourceButton(nil, label: "All Sources")
                            ForEach(NotificationSource.allCases, id: \.self) { source in
                                sourceButton(source, label: source.rawValue)
                            }
                        }
                    }
                    .padding()

                    Toggle("Show completed tasks", isOn: $viewModel.showCompletedTasks)
                        .padding(.horizontal)
                        .tint(.purple)
                        .foregroundColor(.white)

                    Spacer()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    func sourceButton(_ source: NotificationSource?, label: String) -> some View {
        let isSelected = viewModel.selectedSource == source
        return Button {
            viewModel.selectedSource = source
        } label: {
            HStack {
                if let source = source {
                    Image(systemName: source.icon)
                }
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.purple : Color.white.opacity(0.08))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
