import SwiftUI

struct StatsOverviewView: View {

    @EnvironmentObject var vm: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Progress card
            progressCard

            // Stats row
            HStack(spacing: 12) {
                statCard(
                    value: "\(vm.urgentCount)",
                    label: "Urgent",
                    icon: "exclamationmark.circle.fill",
                    color: AppTheme.urgentColor
                )
                statCard(
                    value: "\(vm.todayCount)",
                    label: "Today",
                    icon: "sun.max.fill",
                    color: AppTheme.mediumColor
                )
                statCard(
                    value: "\(vm.overdueCount)",
                    label: "Overdue",
                    icon: "clock.badge.exclamationmark.fill",
                    color: vm.overdueCount > 0 ? AppTheme.highColor : Color.white.opacity(0.4)
                )
            }
        }
    }

    // MARK: - Progress Card

    var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Progress")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(Int(vm.completionToday * 100))% Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 5)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: vm.completionToday)
                        .stroke(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: vm.completionToday)

                    Text("\(vm.filteredTasks.filter { $0.status == .completed }.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Linear progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * vm.completionToday, height: 6)
                        .animation(.spring(response: 0.8), value: vm.completionToday)
                }
            }
            .frame(height: 6)
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
    }

    // MARK: - Stat Card

    func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
