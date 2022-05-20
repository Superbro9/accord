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

var reachability: Reachability?

@main
struct AccordApp: App {
    @State var loaded: Bool = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var popup: Bool = false
    @State var token = AccordCoreVars.token
    
    private enum Tabs: Hashable {
        case general, rpc
    }
    
    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            if self.token == "" {
                LoginView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoggedIn"))) { _ in
                        self.token = AccordCoreVars.token
                        print("posted", self.token)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        wss?.reset()
                        print("applicationDidBecomeActive")
                    }
            } else {
                ContentView(loaded: $loaded)
                    .onDisappear {
                        loaded = false
                    }
                    .preferredColorScheme(darkMode ? .dark : nil)
                    .sheet(isPresented: $popup, onDismiss: {}) {
                        SearchView()
                            .onAppear {
                                DispatchQueue.global().async {
                                    NetworkCore.shared = NetworkCore()
                                }
                                DispatchQueue.global(qos: .background).async {
                                    Regex.precompute()
                                }
                                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
                                    granted, error in
                                }
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        wss?.reset()
                        print("applicationDidBecomeActive")
                    }
            }
        }
    }
}


final class AppDelegate: NSObject, UIApplicationDelegate {
    
    func applicationWillTerminate(_ application: UIApplication) {
        wss?.close(.protocolCode(.noStatusReceived))
        print("application terminated")
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        reachability = try? Reachability()
                 reachability?.whenReachable = { status in
                     print("reconnecting reachable")
                     concurrentQueue.async {
                         wss?.reset()
                     }
                 }
                 reachability?.whenUnreachable = {
                     print($0, "unreachable")
                 }
                 try? reachability?.startNotifier()
    }
}

