import SwiftUI

struct DayPlannerView: View {

    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.14)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if let plan = dashboardVM.dayPlan {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // AI Summary Card
                            if let summary = plan.aiSummary {
                                aiSummaryCard(summary)
                                    .padding()
                            }

                            // Plan stats
                            planStatsRow(plan)
                                .padding(.horizontal)
                                .padding(.bottom, 16)

                            // Timeline
                            ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { idx, block in
                                TimelineRow(block: block, isLast: idx == plan.blocks.count - 1)
                                    .padding(.horizontal)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            Spacer(minLength: 80)
                        }
                    }
                } else {
                    emptyPlanState
                }
            }
            .navigationTitle("Day Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            isGenerating = true
                            await dashboardVM.regenerateDayPlan()
                            isGenerating = false
                        }
                    } label: {
                        if isGenerating {
                            ProgressView().tint(.purple).scaleEffect(0.8)
                        } else {
                            Label("Regenerate", systemImage: "sparkles")
                                .foregroundColor(.purple)
                        }
                    }
                    .disabled(isGenerating)
                }
            }
        }
    }

    // MARK: - AI Summary Card

    func aiSummaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Daily Brief")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Spacer()
            }
            Text(summary)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(4)
        }
        .padding(14)
        .background(Color.purple.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Plan Stats

    func planStatsRow(_ plan: DayPlan) -> some View {
        HStack(spacing: 16) {
            planStat(
                value: "\(plan.totalFocusMinutes / 60)h \(plan.totalFocusMinutes % 60)m",
                label: "Focus",
                icon: "brain.head.profile",
                color: .blue
            )
            planStat(
                value: "\(plan.blocks.count)",
                label: "Blocks",
                icon: "square.stack.3d.up.fill",
                color: .purple
            )
            planStat(
                value: "\(Int(plan.completionPercentage * 100))%",
                label: "Done",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    func planStat(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    var emptyPlanState: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.6))

            Text("No plan yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Let Butler AI plan your day based on your current tasks and priorities.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 40)

            Button {
                Task {
                    isGenerating = true
                    await dashboardVM.regenerateDayPlan()
                    isGenerating = false
                }
            } label: {
                if isGenerating {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Planning...").foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Label("Generate Day Plan", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {

    let block: TimeBlock
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Time column
            VStack(alignment: .trailing, spacing: 0) {
                Text(block.startTime.shortTimeString)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 54, alignment: .trailing)
            }
            .padding(.top, 14)

            // Line
            VStack(spacing: 0) {
                Circle()
                    .fill(block.isCurrentBlock ? Color.purple : (block.isPast ? Color.white.opacity(0.2) : Color.white.opacity(0.3)))
                    .frame(width: 10, height: 10)
                    .overlay(
                        block.isCurrentBlock
                            ? Circle().stroke(Color.purple, lineWidth: 2).frame(width: 16, height: 16)
                            : nil
                    )
                    .padding(.top, 18)

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            // Block content
            blockCard
                .padding(.bottom, 10)
        }
        .frame(minHeight: 64)
    }

    var blockCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(block.isPast ? .white.opacity(0.5) : .white)
                    .strikethrough(block.isPast)

                Spacer()

                if block.isCurrentBlock {
                    Text("NOW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                Text(block.timeRangeDisplay)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))

                Text("·")
                    .foregroundColor(.white.opacity(0.3))

                Text("\(block.durationMinutes)m")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))

                if block.isBreak {
                    Label("Break", systemImage: "cup.and.saucer.fill")
                        .font(.caption2)
                        .foregroundColor(.green.opacity(0.7))
                } else if block.isFocusTime {
                    Label("Focus", systemImage: "brain.head.profile")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.7))
                }

                if let note = block.note {
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(block.isCurrentBlock
                    ? Color.purple.opacity(0.15)
                    : (block.isBreak ? Color.green.opacity(0.05) : Color.white.opacity(0.05)))
                .overlay(
                    block.isCurrentBlock
                        ? RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.4), lineWidth: 1)
                        : nil
                )
        )
    }
}
