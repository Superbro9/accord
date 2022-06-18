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

var allowReconnection: Bool = false
var reachability: Reachability? = {
     var reachability = try? Reachability()
     reachability?.whenReachable = { status in
         concurrentQueue.async {
             if wss?.connection?.state != .preparing && allowReconnection {
                 wss?.reset()
             }
         }
     }
    reachability?.whenUnreachable = {
        print($0, "unreachable")
    }
    try? reachability?.startNotifier()
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        allowReconnection = true
    }
    return reachability
}()

@main
struct AccordApp: App {
    @State var loaded: Bool = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var popup: Bool = false
    @State var token = Globals.token
    
    private enum Tabs: Hashable {
        case general, rpc
    }
    
    init() {
             _ = reachability
         }
    
    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            if self.token == "" {
                LoginView()
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoggedIn"))) { _ in
                        self.token = Globals.token
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
                                    RegexExpressions.precompute()
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
}

