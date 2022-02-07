//
//  RestartAppView.swift
//  Accord
//
//  Created by Hugo Mason on 06/02/2022.
//

//import SwiftUI
//import UserNotifications
//import Darwin
//
//struct RestartAppView: View {
//    @State private var showConfirm = false
//
//    var body: some View {
//        VStack {
//            Button(action: {
//                self.showConfirm = true
//            }) {
//                Text("Update Configuration")
//            }
//        }.alert(isPresented: $showConfirm, content: { confirmChange })
//    }
//
//    var confirmChange: Alert {
//        Alert(title: Text("Change Configuration?"), message: Text("This application needs to restart to update the //configuration.\n\nDo you want to restart the application?"),
//              primaryButton: .default (Text("Yes")) {
//            restartApplication()
//        },
//              secondaryButton: .cancel(Text("No"))
//        )
//    }
//    func restartApplication(){
//        var localUserInfo: [AnyHashable : Any] = [:]
//        localUserInfo["pushType"] = "restart"
//
//        let content = UNMutableNotificationContent()
//        content.title = "Configuration Update Complete"
//        content.body = "Tap to reopen the application"
//        content.sound = UNNotificationSound.default
//        content.userInfo = localUserInfo
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
//
//        let identifier = "com.domain.restart"
//        let request = UNNotificationRequest.init(identifier: identifier, content: content, trigger: trigger)
//        let center = UNUserNotificationCenter.current()
//
//        center.add(request)
//        exit(0)
//    }
//}
