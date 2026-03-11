//
//  ToggleImmersiveSpaceButton.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import os

private let immersiveLogger = Logger(subsystem: "com.app.VirtualOR", category: "ImmersiveSpace")

struct ToggleImmersiveSpaceButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button {
            Task { @MainActor in
                await toggleImmersiveSpace()
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition)
        .fontWeight(.semibold)
    }
}

private extension ToggleImmersiveSpaceButton {
    func toggleImmersiveSpace() async {
        switch appModel.immersiveSpaceState {
            case .open:
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
                // Don't set immersiveSpaceState to .closed because there
                // are multiple paths to ImmersiveView.onDisappear().
                // Only set .closed in ImmersiveView.onDisappear().

            case .closed:
                appModel.immersiveSpaceState = .inTransition
                let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                immersiveLogger.info("openImmersiveSpace result: \(String(describing: result))")
                switch result {
                    case .opened:
                        immersiveLogger.info("Immersive space opened successfully")
                        break

                    case .userCancelled, .error:
                        immersiveLogger.error("Immersive space failed to open: \(String(describing: result))")
                        fallthrough
                    @unknown default:
                        appModel.immersiveSpaceState = .closed
                }

            case .inTransition:
                // This case should not ever happen because button is disabled for this case.
                break
        }
    }
}
