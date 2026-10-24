//
//  StubURLProtocol.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation

/// Answers every request with the status `status` picks for its JSON body (201
/// unless told otherwise) and keeps the body, so a test sees what the SDK sent.
final class StubURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var received: [Data] = []
    private static var status: ([String: Any]) -> Int = { _ in 201 }
    private static var onReceive: ((Data) -> Void)?

    /// A session whose every request goes to this stub.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func start(status handler: @escaping ([String: Any]) -> Int = { _ in 201 },
                      onReceive callback: ((Data) -> Void)? = nil) {
        lock.lock()
        received = []
        status = handler
        onReceive = callback
        lock.unlock()
    }

    static func stop() {
        lock.lock()
        status = { _ in 201 }
        onReceive = nil
        lock.unlock()
    }

    static func bodies() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? Self.read(request.httpBodyStream)
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]

        Self.lock.lock()
        Self.received.append(body)
        let code = Self.status(json)
        let handler = Self.onReceive
        Self.lock.unlock()

        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
        handler?(body)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream?) -> Data {
        guard let stream = stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
