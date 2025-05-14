import DeviceActivity
import SwiftUI

@main
struct DAReportExt: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DailyOverviewReport()
    }
       
}

