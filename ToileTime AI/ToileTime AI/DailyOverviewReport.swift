import DeviceActivity
import SwiftUI

struct DailyOverviewModel: Identifiable {
    let id = UUID()
    let totalMinutes: Int
}
//shows time spent on phone during the day
struct DailyOverviewView: View {
    let model: DailyOverviewModel
    private var hours: Int   { model.totalMinutes / 60 }
    private var minutes: Int { model.totalMinutes % 60 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .shadow(radius: 8)
            
            VStack(spacing: 8) {
                Text("Today's Screen‑Time")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("\(hours)h  \(minutes)min")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
struct DailyOverviewReport: DeviceActivityReportScene {

    let context: DeviceActivityReport.Context = .dailyOverview

    let content: (DailyOverviewModel) -> DailyOverviewView = { model in
        DailyOverviewView(model: model)
    }

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DailyOverviewModel {

        let seconds = await data
            .flatMap { $0.activitySegments }
            .reduce(0) { $0 + $1.totalActivityDuration }

        return DailyOverviewModel(totalMinutes: Int(seconds / 60))
    }
}
