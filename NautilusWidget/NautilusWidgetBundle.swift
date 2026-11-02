//
//  NautilusWidgetBundle.swift
//  NautilusWidget
//
//  WidgetKit entry point for the Nautilus home-screen widgets.
//

import WidgetKit
import SwiftUI

@main
struct NautilusWidgetBundle: WidgetBundle {
    var body: some Widget {
        NautilusStatusWidget()
    }
}
