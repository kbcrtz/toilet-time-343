import SwiftUI
import DeviceActivity

@available(iOS 16.0, *)
//view to show screentime during day
struct ScreenTimeDashboard: View {
    var body: some View {
        DeviceActivityReport(
            .dailyOverview,
            filter: DeviceActivityFilter(
                segment: .daily(
                    during: Calendar.current
                        .dateInterval(of: .day, for: .now)!
                )))
        .navigationTitle("Screen Time")
        .padding()
    }
}
