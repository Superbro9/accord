//
//  NetworkHandler.swift
//  Accord
//
//  Created by evelyn on 2021-02-27.
//

import UIKit
import Combine
import Foundation
import Network
import SwiftUI

public enum RequestTypes: String {
    case DELETE = "DELETE"
    case GET = "GET"
    case HEAD = "HEAD"
    case PATCH = "PATCH"
    case POST = "POST"
    case PUT = "PUT"
}

final class DiscordError: Codable {
    var code: Int
    var message: String?
}

extension String {
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        Data(utf8).base64EncodedString()
    }
}

func logOut() {
    //KeychainManager.save(key: keychainItemName, data: Data())
    UserDefaults.standard.set(Data(), forKey: "tokenKeyUserDefault")
    exit(0)
}

final class Headers {
    init (
        userAgent: String = discordUserAgent,
        contentType: String? = nil,
        token: String? = nil,
        bodyObject: [String: Any]? = nil,
        type: RequestTypes,
        discordHeaders: Bool = false,
        referer: String? = nil,
        empty: Bool = false,
        json: Bool = false,
        cached: Bool = false
    ) {
        self.userAgent = userAgent
        self.contentType = contentType
        self.token = token
        self.bodyObject = bodyObject
        self.type = type
        self.discordHeaders = discordHeaders
        self.referer = referer
        self.empty = empty
        self.json = json
        self.cached = cached
    }

    var userAgent: String
    var contentType: String?
    var token: String?
    var bodyObject: [String: Any]?
    var type: RequestTypes
    var discordHeaders: Bool
    var referer: String?
    var empty: Bool?
    var json: Bool
    var cached: Bool
    var superProps: String? {
        let json: [String: Any] = [
            "os": "Mac OS X",
            "browser": "Discord Client",
            "release_channel": "stable",
            "client_version": "0.0.266",
            "os_version": "21.2.0",
            "os_arch": "x64",
            "system_locale": "\(NSLocale.current.languageCode ?? "en")-\(NSLocale.current.regionCode ?? "US")",
            "client_build_number": dscVersion,
            "client_event_source": NSNull(),
        ]
        return try? JSONSerialization.data(withJSONObject: json, options: []).base64EncodedString()
    }
    
    func set(
        request: inout URLRequest,
        config: inout URLSessionConfiguration
    ) throws {
        if cached {
            config.requestCachePolicy = .returnCacheDataElseLoad
        }
        if let contentType = contentType, !(self.json) {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let token = token {
            request.addValue(token, forHTTPHeaderField: "Authorization")
        }
        if json {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject ?? [:], options: [])
        } else if let bodyObject = bodyObject {
            if type == .GET {
                request.url = request.url?.appendingQueryParameters(bodyObject as? [String: String] ?? [:])
            } else {
                let bodyString = bodyObject.queryParameters
                request.httpBody = bodyString.data(using: .utf8, allowLossyConversion: true)
            }
        }
        if discordHeaders {
            request.addValue("discord.com", forHTTPHeaderField: ":authority")
            request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.addValue("https://discord.com", forHTTPHeaderField: "origin")
            request.addValue("empty", forHTTPHeaderField: "sec-fetch-dest")
            request.addValue("cors", forHTTPHeaderField: "sec-fetch-mode")
            request.addValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
            if let superProps = superProps {
                request.addValue(superProps, forHTTPHeaderField: "X-Super-Properties")
            } else {
                wss.close(.protocolCode(.abnormalClosure))
                fatalError("We cannot skip the X-Super-Properties. What are you trying to do, get banned?")
            }
            config.httpAdditionalHeaders = [
                "User-Agent": userAgent,
                "x-discord-locale": "\(NSLocale.current.languageCode ?? "en")-\(NSLocale.current.regionCode ?? "US")",
            ]
        }
        if let referer = referer {
            request.addValue(referer, forHTTPHeaderField: "referer")
        }

        request.httpMethod = type.rawValue
    }
}

var standardHeaders = Headers(
    contentType: nil,
    token: Globals.token,
    type: .GET,
    discordHeaders: true,
    referer: "https://discord.com/channels/@me"
)

public final class Request {
    // MARK: - Empty Decodable

    class AnyDecodable: Decodable {}

    enum FetchErrors: Error {
        case invalidRequest
        case invalidForm
        case badResponse(URLResponse?)
        case notRequired
        case decodingError(String, Error?)
        case noData
        case discordError(code: Int?, message: String?)
    }
    
    struct DiscordError: Decodable {
        var code: Int
        var message: String?
    }
    
    // MARK: - Perform request with completion handler
    
    class func fetch<T: Decodable>(
        _: T.Type,
        request: URLRequest? = nil,
        url: URL? = nil,
        headers: Headers? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let request: URLRequest? = {
            if let request = request {
                return request
            } else if let url = url {
                return URLRequest(url: url)
            } else {
                print("You need to provide a request method")
                return nil
            }
        }()
        guard var request = request else { return completion(.failure(FetchErrors.invalidRequest)) }
        var config = URLSessionConfiguration.default
        
        guard !(wss != nil && headers?.discordHeaders == true && wss?.connection?.state != NWConnection.State.ready) else {
            print("No active websocket connection")
            return
        }
        // Set headers
        do { try headers?.set(request: &request, config: &config) } catch { return completion(.failure(error)) }
        
        URLSession(configuration: config).dataTask(with: request, completionHandler: { data, response, error in
            if let data = data {
                guard error == nil else {
                    print(error?.localizedDescription ?? "Unknown Error")
                    return completion(.failure(FetchErrors.badResponse(response)))
                }
                if T.self == AnyDecodable.self {
                    return completion(.failure(FetchErrors.notRequired)) // Bail out if we don't ask for a type
                }
                do {
                    let value = try JSONDecoder().decode(T.self, from: data)
                    return completion(.success(value))
                } catch {
                    guard let error = try? JSONDecoder().decode(DiscordError.self, from: data) else {
                        guard let strError = String(data: data, encoding: .utf8) else { return }
                        return completion(.failure(FetchErrors.decodingError(strError, error)))
                    }
                    if let message = error.message, message.contains("Unauthorized") {
                        logOut()
                    }
                }
            }
        }).resume()
    }
    
    // MARK: - Perform data request with completion handler
    class func fetch(
        request: URLRequest? = nil,
        url: URL? = nil,
        headers: Headers? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let request: URLRequest? = {
            if let request = request {
                return request
            } else if let url = url {
                return URLRequest(url: url)
            } else {
                print("You need to provide a request method")
                return nil
            }
        }()
        guard var request = request else { return completion(.failure(FetchErrors.invalidRequest)) }
        var config = URLSessionConfiguration.default
       
        guard !(wss != nil && headers?.discordHeaders == true && wss?.connection?.state != NWConnection.State.ready) else {
            print("No active websocket connection")
            return
        }

        // Set headers
        do { try headers?.set(request: &request, config: &config) } catch { return completion(.failure(error)) }

        URLSession(configuration: config).dataTask(with: request, completionHandler: { data, _, error in
            if let data = data {
                return completion(.success(data))
            } else if let error = error {
                return completion(.failure(error))
            }
        }).resume()
    }
    
    // MARK: - fetch() wrapper for empty requests without completion handlers
    class func ping(
        request: URLRequest? = nil,
        url: URL? = nil,
        headers: Headers? = nil
    ) {
        fetch(AnyDecodable.self, request: request, url: url, headers: headers) { _ in }
    }
    
    // MARK: - Image getter
    
    class func image(
        url: URL?,
        to size: CGSize? = nil,
        completion: @escaping ((_ value: UIImage?) -> Void)
    ) {
        guard let url = url else { return completion(nil) }
        let request = URLRequest(url: url)
        if let cachedImage = cache.cachedResponse(for: request) {
            return completion(UIImage(data: cachedImage.data) ?? UIImage())
        }
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            guard let data = data,
                  let imageData = UIImage(data: data)?.downsample(image: UIImage(data: data)!, to: size),
                  let image = UIImage(data: imageData)
            else {
                print(error?.localizedDescription ?? "unknown error")
                if let data = data {
                    cache.storeCachedResponse(CachedURLResponse(response: response!, data: data), for: request)
                    return completion(UIImage(data: data))
                } else {
                    print("load failed")
                    return completion(nil)
                }
            }
            cache.storeCachedResponse(CachedURLResponse(response: response!, data: imageData), for: request)
            return completion(image)
        }).resume()
    }

class func fetch(
    url: URL?,
    with payloadJson: [String:Any]? = nil,
    fileURL: String? = nil,
    boundary: String = "Boundary-\(UUID().uuidString)",
    headers: Headers? = nil,
    completion: @escaping (Result<(Data?, HTTPURLResponse?), Error>) -> Void = { _ in }
) {
    let request: URLRequest? = {
        if let url = url {
            return URLRequest(url: url)
        } else {
            print("You need to provide a request method")
            return nil
        }
    }()
    guard var request = request else { return }
    var config = URLSessionConfiguration.default
 
    guard !(wss != nil && headers?.discordHeaders == true && wss?.connection?.state != NWConnection.State.ready) else {
        print("No active websocket connection")
        return
    }

    // Set headers
    do { try headers?.set(request: &request, config: &config) } catch { return }
    request.httpBody = try? Request.createMultipartBody(with: try payloadJson?.jsonString(), fileURLs: [fileURL].compactMap(\.self), boundary: boundary)
    request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    URLSession(configuration: config).dataTask(with: request, completionHandler: { data, response, error in
        print(response as? HTTPURLResponse)
        if let data = data {
            return completion(.success((data, response as? HTTPURLResponse)))
        } else if let error = error {
            return completion(.failure(error))
        }
    }).resume()
}

class func createMultipartBody(
    with payloadJson: String?,
    fileURLs: [String] = [],
    boundary: String = "Boundary-\(UUID().uuidString)",
    fileData: [Data] = []
) throws -> Data {
    var body = Data()
    
    body.append("--\(boundary)\r\n")
    
    if let payloadJson = payloadJson {
        body.append(
            "Content-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n"
        )
        body.append("\(payloadJson)\r\n")
    }
    
    try fileURLs
        .compactMap { URL.init(string: $0) }
        .enumerated()
        .forEach { idx, url in
            let filename = url.lastPathComponent
            let data = try fileData[safe: idx] ?? Data(contentsOf: url)
            let mimetype = url.mimeType()
            
            body.append("--\(boundary)\r\n")
            body.append(
                "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
            )
            body.append("Content-Type: \(mimetype)\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
    
    body.append("--\(boundary)--\r\n")
    print(String(data: body, encoding: .utf8))
    return body
}
    /*
     ------WebKitFormBoundaryeDoDxVailL1LpUnN
     Content-Disposition: form-data; name="payload_json"
     
     {"type":2,"application_id":"836759847357251604","guild_id":"815369174096412692","channel_id":"839005662931189801","session_id":"0f77b7545645d1991d11e54cccfa8425","data":{"version":"847239978559078431","id":"847239978559078430","name":"minesweeper","type":1,"options":[],"application_command":{"application_id":"836759847357251604","default_member_permissions":null,"default_permission":true,"description":"play minesweeper on a 5-5-5 board","dm_permission":null,"id":"847239978559078430","name":"minesweeper","permissions":[],"type":1,"version":"847239978559078431"},"attachments":[]},"nonce":"946208314188890112"}
     ------WebKitFormBoundaryeDoDxVailL1LpUnN--
     */
}

public final class RequestPublisher {
    static var EmptyImagePublisher: AnyPublisher<UIImage, Error> = {
        Empty<UIImage, Error>.init().eraseToAnyPublisher()
    }()
    
    enum ImageErrors: Error {
        case noImage
    }

    // MARK: - Get a publisher for the request

    class func fetch<T: Decodable>(
        _: T.Type,
        url: URL? = nil,
        headers: Headers? = nil,
        retry: Int = 2
    ) -> AnyPublisher<T, Error> {
        let request: URLRequest? = {
            if let url = url {
                return URLRequest(url: url)
            } else {
                print("You need to provide a request method")
                return nil
            }
        }()
        guard var request = request else { return Empty(completeImmediately: true).eraseToAnyPublisher() }
        var config = URLSessionConfiguration.default
        if (wss != nil && headers?.discordHeaders == true && wss?.connection?.state != NWConnection.State.ready) {
            print("No active websocket connection")
            wss.reset()
        }
        // Set headers
        do { try headers?.set(request: &request, config: &config) } catch { return Empty(completeImmediately: true).eraseToAnyPublisher() }

        return URLSession(configuration: config).dataTaskPublisher(for: request)
            .retry(retry)
            .tryMap { data, response throws -> T in
                guard let httpResponse = response as? HTTPURLResponse else { throw Request.FetchErrors.badResponse(response) }
                if (200..<300).contains(httpResponse.statusCode) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
                    return try decoder.decode(T.self, from: data)
                } else {
                    let discordError = try JSONDecoder().decode(DiscordError.self, from: data)
                    throw Request.FetchErrors.discordError(code: discordError.code, message: discordError.message)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Combine Image getter

    class func image(
        url: URL?,
        to size: CGSize? = nil
    ) -> AnyPublisher<UIImage, Error> {
        guard let url = url else { return EmptyImagePublisher }
        let request = URLRequest(url: url)
        if let cachedImage = cache.cachedResponse(for: request), let img = UIImage(data: cachedImage.data) {
            return Just(img).eraseToAny()
        }
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> UIImage in
                if let size = size, let downsampled = data.downsample(to: size), let image = UIImage(data: downsampled) {
                    cache.storeCachedResponse(CachedURLResponse(response: response, data: downsampled), for: request)
                    return image
                } else if let image = UIImage(data: data) {
                    cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
                    return image
                } else { throw ImageErrors.noImage }
            }
            .eraseToAny()
    }
}

enum DateDecodingErrors: Error {
    case badDate(String)
}

let ISO8601FormatterGlobal: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
    return formatter
}()


extension JSONDecoder.DateDecodingStrategy {
    static let iso8601withFractionalSeconds = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        let date = ISO8601FormatterGlobal.date(from: string)
        if let date = date {
            return date
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = .withInternetDateTime
            let date = formatter.date(from: string)
            if let date = date {
                return date
            }
        }
        throw DateDecodingErrors.badDate(string)
    }
}
