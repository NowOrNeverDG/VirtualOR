//
//  AppModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "AppModel")

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    enum LoadingState {
        case idle
        case loading
        case loaded
        case failed(Error)
    }
    var loadingState = LoadingState.idle

    func fetchInitialData() async {
        guard case .idle = loadingState else { return }
        loadingState = .loading

        do {
            // TODO: Replace with actual endpoint and response model
            // let config: YourResponseModel = try await APIService.shared.request(
            //     APIEndpoint(path: "/config")
            // )
            loadingState = .loaded
        } catch {
            logger.error("Failed to fetch initial data: \(error.localizedDescription)")
            loadingState = .failed(error)
        }
    }
}
