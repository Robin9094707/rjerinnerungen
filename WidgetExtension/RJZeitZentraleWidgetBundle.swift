import SwiftUI
import WidgetKit

@main
struct RJZeitZentraleWidgetBundle: WidgetBundle {
    var body: some Widget {
        RJAlarmLiveActivityWidget()
        QuickTimerWidget()
        QuickCaptureWidget()
        FiveMinuteControl()
        PomodoroControl()
    }
}
