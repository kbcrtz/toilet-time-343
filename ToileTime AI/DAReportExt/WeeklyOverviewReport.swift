import DeviceActivity
import SwiftUI
import Charts

struct DayUsage: Identifiable {
    let id = UUID()
    let weekday: String
    let minutes: Int
}

struct WeeklyOverviewChart: View {
    let days: [DayUsage]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.weekday),
                y: .value("Minutes", day.minutes)
            )
            .foregroundStyle(Color.yellow.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 180)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

struct WeeklyOverviewReport: DeviceActivityReportScene {

    let context: DeviceActivityReport.Context = .weeklyOverview

    let content: ([DayUsage]) -> WeeklyOverviewChart = { days in
        WeeklyOverviewChart(days: days)
    }


    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> [DayUsage] {

        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: .now)

        let last7Dates: [Date] = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .sorted()


        var minutesArray: [Int] = []
        for await entry in data {
            let secondsForDay = await entry.activitySegments.reduce(0) {
                $0 + $1.totalActivityDuration
            }
            minutesArray.append(Int(secondsForDay / 60))
        }


        while minutesArray.count < 7 {
            minutesArray.insert(0, at: 0)
        }

        let symbols = calendar.shortWeekdaySymbols         
        return zip(last7Dates, minutesArray).map { date, minutes in
            let label = symbols[calendar.component(.weekday, from: date) - 1]
            return DayUsage(weekday: label, minutes: minutes)
        }
    }
}
