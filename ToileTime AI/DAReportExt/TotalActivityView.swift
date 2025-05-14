import SwiftUI

struct TotalActivityView: View {
    let totalActivity: String
    
    var body: some View {
        Text(totalActivity)
    }
}
#Preview {
    TotalActivityView(totalActivity: "1h 23m")
}
