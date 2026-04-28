//
//  ForeWidgets.swift
//  ForeWidgets (extension @main)
//
//  Bundle declaration for the three Fore widgets. The boilerplate
//  ConfigurationAppIntent / Provider / SimpleEntry / Live Activity / Control
//  Widget that came from the Xcode template have been replaced with
//  Fore-specific implementations split across SmallWidget.swift,
//  MediumWidget.swift, LargeWidget.swift, ForeWidgetEntry.swift, and
//  WidgetAppButton.swift.
//

import SwiftUI
import WidgetKit

@main
struct ForeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ForeSmallWidget()
        ForeMediumWidget()
        ForeLargeWidget()
    }
}
