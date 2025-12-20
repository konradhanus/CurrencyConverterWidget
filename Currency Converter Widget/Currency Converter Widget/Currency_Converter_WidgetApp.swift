//
//  Currency_Converter_WidgetApp.swift
//  Currency Converter Widget
//
//  Created by Konrad Hanus on 17/12/2025.
//

import SwiftUI

@main
struct Currency_Converter_WidgetApp: App {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localizationManager)
        }
    }
}
