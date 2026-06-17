//
//  NetworkMonitor.swift
//  PetHub
//
//  Created by Han Min Thant on 17/6/26.
//

import Foundation
import Network
import SwiftUI
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }

        monitor.start(queue: queue)
    }
}
