//
//  LoginView.swift
//  Accord
//
//  Created by Évelyne on 2021-05-23.
//

import SwiftUI
import WebKit
import UIKit
import Darwin
import UserNotifications

public var captchaPublicKey: String = "error"

var confirmChange: Alert {
    Alert(title: Text("Change Configuration?"), message: Text("This application needs to restart to update the configuration.\n\nDo you want to restart the application?"),
          primaryButton: .default (Text("Yes")) {
        restartApplication()
    },
          secondaryButton: .cancel(Text("No"))
    )
}
func restartApplication(){
    var localUserInfo: [AnyHashable : Any] = [:]
    localUserInfo["pushType"] = "restart"
    
    let content = UNMutableNotificationContent()
    content.title = "Configuration Update Complete"
    content.body = "Tap to reopen the application"
    content.sound = UNNotificationSound.default
    content.userInfo = localUserInfo
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
    
    let identifier = "com.domain.restart"
    let request = UNNotificationRequest.init(identifier: identifier, content: content, trigger: trigger)
    let center = UNUserNotificationCenter.current()
    
    center.add(request)
    exit(0)
}

enum LoginState {
    case initial
    case captcha
    case twofactor
}

enum DiscordLoginErrors: Error {
    case invalidForm
    case missingFields
}

extension UIApplication {
    func restart() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "LoggedIn"), object: nil, userInfo: [:])
        }
    }
}

struct LoginView: View {
    @State var email: String = ""
    @State var password: String = ""
    @State var twofactor: String = ""
    @State var token: String = ""
    @State var captcha: Bool = false
    @State var captchaVCKey: String?
    @State var captchaPayload: String?
    @State var proxyIP: String = ""
    @State var proxyPort: String = ""
    @State var state: LoginState = .initial
    @State var notif: [String: Any] = [:]
    @State var error: String?
    @State private var showConfirm = false
    @StateObject var viewModel = LoginViewViewModel()
    var body: some View {
        VStack {
            switch viewModel.state {
            case .initial:
                VStack {
                    Text("Welcome to Accord")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 5)
                        .padding(.top)
                    Text("Choose how you want to login")
                        .foregroundColor(Color.secondary)
                        .padding(.bottom)
                    TextField("Email", text: $email)
                        .frame(width: 1)
                    SecureField("Password", text: $password)
                    TextField("Token (optional)", text: $token)
                    TextField("Proxy IP (optional)", text: $proxyIP)
                    TextField("Proxy Port (optional)", text: $proxyPort)
                    if let error = error {
                        Text(error)
                            .foregroundColor(Color.red)
                            .font(.subheadline)
                    }
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            exit(EXIT_SUCCESS)
                        }
                        .controlSize(.large)
                        Button("Login") {
                            UserDefaults.standard.set(self.proxyIP, forKey: "proxyIP")
                            UserDefaults.standard.set(self.proxyPort, forKey: "proxyPort")
                            if token != "" {
                                UserDefaults.standard.set(token.data(using: String.Encoding.utf8) ?? Data(), forKey: "tokenKeyUserDefault")
                               
                                AccordCoreVars.token = String(decoding:  UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
                              //  KeychainManager.save(key: keychainItemName, data: token.data(using: String.Encoding.utf8) ?? Data())
                               // AccordCoreVars.token = String(decoding: KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
                                UIApplication.shared.restart()
                            } else {
                                do {
                                    try viewModel.login(email, password, twofactor)
                                } catch {
                                    switch error {
                                    case DiscordLoginErrors.invalidForm:
                                        self.error = "Invalid login and/or password"
                                    default:
                                        self.error = "An error occured"
                                    }
                                }
                            }
                            print("logging in")
                        }
                        .controlSize(.large)
                    }
                    .padding(.top, 5)
                }
                .transition(AnyTransition.moveAway)
                //.textFieldStyle(RoundedBorderTextFieldStyle())
                
            case .captcha:
                CaptchaViewControllerSwiftUI(token: captchaPublicKey)
                    .transition(AnyTransition.moveAway)
            case .twofactor:
                VStack {
                    Spacer()
                    Text("Enter your two-factor code here.")
                        .font(.title3)
                        .fontWeight(.medium)
                    SecureField("Six-digit MFA code", text: $twofactor)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Login") {
                            if let ticket = viewModel.ticket {
                                Request.fetch(LoginResponse.self, url: URL(string: "https://discord.com/api/v9/auth/mfa/totp"), headers: Headers(userAgent: discordUserAgent,
                                                                                                                                                 token: AccordCoreVars.token,
                                                                                                                                                 bodyObject: ["code": twofactor, "ticket": ticket],
                                                                                                                                                 type: .POST,
                                                                                                                                                 discordHeaders: true,
                                                                                                                                                 json: true))
                                { value, error in
                                    if let token = value?.token {
                                        UserDefaults.standard.set(token.data(using: String.Encoding.utf8) ?? Data(), forKey: "tokenKeyUserDefault")
                                       
                                        AccordCoreVars.token = String(decoding:  UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
                                       // KeychainManager.save(key: keychainItemName, data: token.data(using: .utf8) ?? Data())
                                       // AccordCoreVars.token = String(decoding: KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
                                        self.captcha = false
                                        print("got 2fa code 1")
                                        UIApplication.shared.restart()
                                    } else if let error = error {
                                        print(error)
                                    }
                                }
                                return
                            }
                            self.captchaPayload = notif["key"] as? String ?? ""
                            Request.fetch(LoginResponse.self, url: URL(string: "https://discord.com/api/v9/auth/login"), headers: Headers(
                                userAgent: discordUserAgent,
                                bodyObject: [
                                    "email": email,
                                    "password": password,
                                    "captcha_key": captchaPayload ?? "",
                                ],
                                type: .POST,
                                discordHeaders: true,
                                json: true
                            )) { response, _ in
                                if let token = response?.token {
                                    UserDefaults.standard.set(token.data(using: String.Encoding.utf8) ?? Data(), forKey: "tokenKeyUserDefault")
                                   
                                    AccordCoreVars.token = String(decoding:  UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
                                    //KeychainManager.save(key: keychainItemName, data: token.data(using: String.Encoding.utf8) ?? Data())
                                   // AccordCoreVars.token = String(decoding: KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
                                    self.captcha = false
                                    print("got 2fa code 2")
                                    UIApplication.shared.restart()
                                }
                                if let response = response, let ticket = response.ticket {
                                    Request.fetch(LoginResponse.self, url: URL(string: "https://discord.com/api/v9/auth/mfa/totp"), headers: Headers(userAgent: discordUserAgent,
                                                                                                                                                     contentType: "application/json",
                                                                                                                                                     token: AccordCoreVars.token,
                                                                                                                                                     bodyObject: ["code": twofactor, "ticket": ticket],
                                                                                                                                                     type: .POST,
                                                                                                                                                     discordHeaders: true,
                                                                                                                                                     json: true))
                                    { value, _ in
                                        if let token = value?.token {
                                            UserDefaults.standard.set(token.data(using: String.Encoding.utf8) ?? Data(), forKey: "tokenKeyUserDefault")
                                           
                                            AccordCoreVars.token = String(decoding:  UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
                                          //  KeychainManager.save(key: keychainItemName, data: token.data(using: String.Encoding.utf8) ?? Data())
                                           // AccordCoreVars.token = String(decoding: KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
                                            self.captcha = false
                                            print("my token is \(token)")
                                            print("got 2fa code 3")
                                            UIApplication.shared.restart()
                                        }
                                    }
                                }
                            }
                        }
                        .controlSize(.large)
                    }
                }
            }
        }
        .frame(width: 500, height: 275)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("Captcha"))) { notif in
            self.viewModel.state = .twofactor
            self.notif = notif.userInfo as? [String: Any] ?? [:]
            print(notif)
        }
        .padding()
    }
}

final class LoginViewViewModel: ObservableObject {
    @Published var state: LoginState = .initial
    @Published var captcha: Bool = false
    @Published var captchaVCKey: String?
    @Published var captchaPayload: String?
    @Published var ticket: String? = nil

    init() {}

    func login(_ email: String, _ password: String, _: String) throws {
        var loginError: Error?
        Request.fetch(LoginResponse.self, url: URL(string: "https://discord.com/api/v9/auth/login"), headers: Headers(
            userAgent: discordUserAgent,
            contentType: "application/json",
            bodyObject: [
                "email": email,
                "password": password,
            ],
            type: .POST,
            discordHeaders: true,
            json: true
        )) { response, error in
            if let response = response {
                if let error = response.message {
                    switch error {
                    case "Invalid Form Body":
                        loginError = DiscordLoginErrors.invalidForm
                    default:
                        loginError = DiscordLoginErrors.invalidForm
                    }
                }
                if let checktoken = response.token {
                    UserDefaults.standard.set(checktoken.data(using: String.Encoding.utf8) ?? Data(), forKey: "tokenKeyUserDefault")
                   
                    AccordCoreVars.token = String(decoding:  UserDefaults.standard.data(forKey: "tokenKeyUserDefault") ?? Data(), as: UTF8.self)
                   
                   // KeychainManager.save(key: keychainItemName, data: checktoken.data(using: String.Encoding.utf8) ?? Data())
                    //AccordCoreVars.token = String(decoding: KeychainManager.load(key: keychainItemName) ?? Data(), as: UTF8.self)
                    exit(EXIT_SUCCESS)
                } else {
                    if let captchaKey = response.captcha_sitekey {
                        DispatchQueue.main.async {
                            self.captchaVCKey = captchaKey
                            captchaPublicKey = self.captchaVCKey!
                            self.state = .captcha
                        }
                    } else if let ticket = response.ticket {
                        self.state = .twofactor
                        self.ticket = ticket
                        print("[Login debug] Got ticket")
                    }
                }
            } else if let error = error {
                print(error)
                loginError = error
            }
        }
        if let loginError = loginError {
            throw loginError
        }
    }
}

extension AnyTransition {
    static var moveAway: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
    }
}

struct CaptchaViewControllerSwiftUI: UIViewRepresentable {
    
    init(token: String) {
        siteKey = token
        print(token, siteKey)
    }

    let siteKey: String

    func makeUIView(context _: Context) -> WKWebView {
        var webView = WKWebView()
        let webConfiguration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        let scriptHandler = ScriptHandler()
        contentController.add(scriptHandler, name: "hCaptcha")
        webConfiguration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: webConfiguration)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.centerXAnchor.constraint(equalTo: webView.centerXAnchor).isActive = true
        webView.centerYAnchor.constraint(equalTo: webView.centerYAnchor).isActive = true
        webView.widthAnchor.constraint(equalToConstant: 500).isActive = true
        webView.heightAnchor.constraint(equalToConstant: 400).isActive = true
        
        if siteKey != "" {
            webView.loadHTMLString(generateHTML, baseURL: URL(string: "https://discord.com")!)
        }
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

final class ScriptHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "Captcha"), object: nil, userInfo: ["key": message.body as! String])
        }
    }
}

extension CaptchaViewControllerSwiftUI {
    private var generateHTML: String {
        """
        <html>
            <head>
            <title>Discord Login Captcha</title>
            <script src="https://hcaptcha.com/1/api.js?onload=renderCaptcha&render=explicit" async defer></script>
            <script type="text/javascript">
                function post(value) {
                    window.webkit.messageHandlers.hCaptcha.postMessage(value);
                }
                function onSubmit(token) {
                    var hcaptchaVal = document.getElementsByName("h-captcha-response")[0].value;
                    window.webkit.messageHandlers.hCaptcha.postMessage(hcaptchaVal);
                }
                function renderCaptcha() {
                    var options = { sitekey: "${sitekey}", callback: "onSubmit", size: "compact" };
                    if (window?.matchMedia("(prefers-color-scheme: dark)")?.matches) {
                        options["theme"] = "dark";
                    }
                    hcaptcha.render("captcha", options);
                }
            </script>
            <style>
                @media (prefers-color-scheme: dark) {
                    body {
                        background-color: #2f2f2f;
                    }
                }
                @media (prefers-color-scheme: light) {
                    body {
                        background-color: #c0c0c0;
                    }
                }
                .center {
                    margin: 0;
                    position: absolute;
                    top: 50%;
                    left: 50%;
                    -ms-transform: translate(-50%, -50%);
                    transform: translate(-50%, -50%);
                }
                .h-captcha {
                    transform-origin: center;
                    -webkit-transform-origin: center;
                    display: inline-block;
                }
            </style>
            </head>
            <body>
                <div class="center">
                      <div id="captcha" class="h-captcha" data-sitekey="${sitekey}" data-callback="onSubmit"></div>
                </div>
                  <br />
            </body>
        </html>
        """.replacingOccurrences(of: "${sitekey}", with: siteKey)
    }
}
