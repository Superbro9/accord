//
//  AccordIOSApp.swift
//  AccordIOS
//
//  Created by Hugo Mason on 06/02/2022.
//

import UIKit
import Foundation
import SwiftUI
import UserNotifications

@main
struct AccordApp: App {
    @State var loaded: Bool = false
    @State var popup: Bool = false
    @State var token = AccordCoreVars.token
    var body: some Scene {
        WindowGroup {
            if self.token == "" {
                LoginView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoggedIn"))) { _ in
                        self.token = AccordCoreVars.token
                        print("posted", self.token)
                    }
            } else {
                GeometryReader { reader in
                    ContentView(loaded: $loaded)
                        .onAppear {
                            // AccordCoreVars.loadVersion()
                            // DispatchQueue(label: "socket").async {
                            //     let rpc = IPC().start()
                            // }
                            concurrentQueue.async {
                                NetworkCore.shared = NetworkCore()
                            }
                            DispatchQueue.global(qos: .background).async {
                                Regex.precompute()
                            }
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
                                granted, error in
                                if !granted {
                                    print(error)
                                }
                            }
                        }
                        .preferredColorScheme(darkMode ? .dark : nil)
                        .sheet(isPresented: $popup, onDismiss: {}) {
                            SearchView()
                        }
                }
            }
        }
    }
}
