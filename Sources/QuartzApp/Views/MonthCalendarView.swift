import QuartzKit
import SwiftUI

struct MonthCalendarView: View {
    @EnvironmentObject private var model: AppModel
    let palette: StonePalette
    @Binding var isPresented: Bool
    @State private var displayedMonth: Date = Date()
    private let calendar = Calendar.french

    var body: some View {
        VStack(spacing: 13) {
            HStack {
                Button {
                    moveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()

                Button {
                    moveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(palette.text)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(height: 20)
                }

                ForEach(gridDates, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: model.selectedDate)
                    let inMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                    Button {
                        model.select(date)
                        isPresented = false
                    } label: {
                        ZStack {
                            if selected {
                                Circle().fill(palette.accent)
                            } else if calendar.isDateInToday(date) {
                                Circle().stroke(palette.vein, lineWidth: 1)
                            }
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                                .foregroundStyle(
                                    selected ? Color.white : palette.text.opacity(inMonth ? 1 : 0.36)
                                )
                            let notes = model.postIts(on: date)
                            if !notes.isEmpty {
                                HStack(spacing: 1) {
                                    ForEach(Array(notes.prefix(3))) { note in
                                        Circle()
                                            .fill(note.tone.paperColor.opacity(inMonth ? 1 : 0.42))
                                            .frame(width: 2.5, height: 2.5)
                                    }
                                }
                                .offset(y: 11)
                            }
                        }
                        .frame(width: 29, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityDate(date))
                }
            }

            Button("Aujourd’hui") {
                model.goToToday()
                displayedMonth = model.selectedDate
                isPresented = false
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 282)
        .background(palette.surface)
        .onAppear { displayedMonth = model.selectedDate }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private var gridDates: [Date] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard
            let first = calendar.date(from: components),
            let firstWeekday = calendar.dateComponents([.weekday], from: first).weekday
        else { return [] }
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: first) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func moveMonth(_ value: Int) {
        if let date = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = date
        }
    }

    private func accessibilityDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}
