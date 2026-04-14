import SwiftUI

struct NotificationsView: View {

    @EnvironmentObject var vm: NotificationViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var showSourcePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Source filter header
                    sourceFilterHeader

                    if vm.filteredNotifications.isEmpty {
                        emptyState
                    } else {
                        notificationsList
                    }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.unreadCount > 0 {
                        Button("Mark All Read") {
                            vm.markAllRead()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.refreshAll() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.purple).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.purple)
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .onAppear { vm.onAppear() }
        .refreshable { await vm.refreshAll() }
    }

    // MARK: - Source Filter Header

    var sourceFilterHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sourceChip(nil, label: "All", count: vm.notifications.filter { !$0.isRead }.count)

                ForEach(NotificationSource.allCases, id: \.self) { source in
                    let count = vm.notifications.filter { $0.source == source && !$0.isRead }.count
                    sourceChip(source, label: source.rawValue, count: count)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.03))
    }

    func sourceChip(_ source: NotificationSource?, label: String, count: Int) -> some View {
        let isSelected = vm.selectedSource == source
        return Button {
            withAnimation(.spring()) { vm.selectedSource = source }
        } label: {
            HStack(spacing: 5) {
                if let source = source {
                    Image(systemName: source.icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.forSource(source ?? .manual).opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.forSource(source ?? .manual) : Color.white.opacity(0.07))
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .clipShape(Capsule())
        }
    }

    // MARK: - Notifications List

    var notificationsList: some View {
        List {
            ForEach(groupedByDate, id: \.0) { date, items in
                Section(header:
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                ) {
                    ForEach(items) { notification in
                        NotificationRowView(
                            notification: notification,
                            onRead: { vm.markAsRead(notification) },
                            onCreateTask: {
                                let task = ButlerTask(
                                    title: String(notification.body.prefix(80)),
                                    description: notification.body,
                                    priority: .medium,
                                    category: notification.source == .slack || notification.source == .email ? .work : .personal,
                                    source: notification.source,
                                    sourceID: notification.sourceMessageID,
                                    isAIGenerated: false,
                                    originalMessage: notification.body
                                )
                                dashboardVM.addTask(task)
                            }
                        )
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { vm.delete(items[$0]) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Grouped by Date

    var groupedByDate: [(String, [NotificationItem])] {
        let grouped = Dictionary(grouping: vm.filteredNotifications) { notification in
            notification.receivedAt.dateHeaderString
        }
        return grouped.sorted { a, b in
            let aDate = vm.filteredNotifications.first(where: { $0.receivedAt.dateHeaderString == a.0 })?.receivedAt ?? Date.distantPast
            let bDate = vm.filteredNotifications.first(where: { $0.receivedAt.dateHeaderString == b.0 })?.receivedAt ?? Date.distantPast
            return aDate > bDate
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.2))

            Text("No notifications")
                .font(.title3)
                .foregroundColor(.white.opacity(0.4))

            Text("Pull to refresh or connect your accounts in Settings to start monitoring messages.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Notification Row

struct NotificationRowView: View {

    let notification: NotificationItem
    let onRead: () -> Void
    let onCreateTask: () -> Void

    @State private var showActions = false

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(notification.isRead ? Color.clear : Color.forSource(notification.source))
                .frame(width: 8, height: 8)

            // Source icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.forSource(notification.source).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: notification.source.icon)
                    .font(.caption)
                    .foregroundColor(Color.forSource(notification.source))
            }

            // Content
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(notification.sender)
                        .font(.subheadline)
                        .fontWeight(notification.isRead ? .regular : .semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text(notification.receivedAt.timeAgoDisplay)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

                if let channel = notification.channel {
                    Text(channel)
                        .font(.caption2)
                        .foregroundColor(Color.forSource(notification.source).opacity(0.7))
                }

                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.white.opacity(notification.isRead ? 0.4 : 0.7))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onRead()
            showActions = true
        }
        .confirmationDialog("Notification Actions", isPresented: $showActions) {
            Button("Create Task") { onCreateTask() }
            Button("Mark as Read") { onRead() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
