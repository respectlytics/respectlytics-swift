//
//  EventQueue.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Network

/// Manages event batching and automatic flushing.
///
/// Event queue is RAM-only by design. No data is written to device storage
/// (no UserDefaults, no files, no Keychain) for analytics purposes. If the app
/// is force-quit before the next flush, unsent events are lost. This is a
/// deliberate privacy-first design choice — zero bytes are written to the
/// user's device for analytics purposes.
///
/// The SDK auto-flushes every 30 seconds, on 10 queued events, and when the
/// app enters background, so the loss window is narrow.
///
/// A 401 stops sending for the rest of the app's run, until `start()` is called
/// again by `configure`: a wrong or revoked app key cannot be fixed by a retry,
/// and every refused request counts toward the server's block of the device's
/// address (10 in 15 minutes, shared with other sites at Cloudflare), so
/// retrying would get the app's own users blocked.
final class EventQueue {

    static let unauthorizedMessage = "[Respectlytics] The app key was refused (401). Check it in your app's Settings on respectlytics.com. No events are sent until the app starts again."

    private var events: [Event] = []
    private var flushTimer: Timer?
    private let networkClient: NetworkClient
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true
    /// Set by a 401: nothing is queued or sent until `start()`.
    private var refused = false

    private let maxQueueSize = 10
    private let flushInterval: TimeInterval = 30

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.respectlytics.eventQueue")

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
        setupNetworkMonitor()
        setupBackgroundObserver()
    }

    deinit {
        flushTimer?.invalidate()
        networkMonitor.cancel()
    }

    /// Start, or after `configure` is called again, resume sending.
    func start() {
        lock.lock()
        refused = false
        lock.unlock()
        scheduleFlush()
    }

    /// Add an event to the in-memory queue. Ignored after a 401.
    func add(_ event: Event) {
        lock.lock()
        guard !refused else {
            lock.unlock()
            return
        }
        events.append(event)
        let shouldFlush = events.count >= maxQueueSize
        lock.unlock()

        if shouldFlush {
            flush()
        }
    }

    /// Force flush all queued events.
    ///
    /// Events are sent one at a time, in order. When one fails in a way worth
    /// trying again, it and the events after it go back to the queue; the ones the
    /// server already accepted are never sent twice.
    ///
    /// - Returns: The task that sends the batch (tests wait on it), or nil when
    ///   there was nothing to send, the device is offline, or a 401 stopped sending.
    @discardableResult
    func flush() -> Task<Void, Never>? {
        lock.lock()
        guard !refused, !events.isEmpty else {
            lock.unlock()
            return nil
        }

        guard isOnline else {
            lock.unlock()
            return nil
        }

        let batch = events
        events = []
        lock.unlock()

        return Task {
            var sent = 0
            do {
                for event in batch {
                    // A 401 in another flush stopped sending: the rest is dropped
                    guard !isRefused else { return }
                    try await networkClient.send(event)
                    sent += 1
                }
            } catch NetworkError.unauthorized {
                stopForUnauthorized()
            } catch {
                // Re-add only the events not yet sent to the in-memory queue for retry
                requeue(Array(batch.dropFirst(sent)))
                print("[Respectlytics] Failed to send events, will retry later")
            }
        }
    }

    /// Events waiting to be sent.
    var queuedEvents: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    /// Whether a 401 stopped sending until the next `start()`.
    var isRefused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return refused
    }

    /// Put events that were not sent back at the front of the in-memory queue,
    /// unless a 401 stopped sending meanwhile.
    /// A synchronous method, so the lock is never taken directly in the async task.
    private func requeue(_ batch: [Event]) {
        lock.lock()
        if !refused {
            events.insert(contentsOf: batch, at: 0)
        }
        lock.unlock()
    }

    /// After a 401: drop every queued event, refuse new ones, and say so once.
    private func stopForUnauthorized() {
        lock.lock()
        let first = !refused
        refused = true
        events = []
        lock.unlock()
        if first {
            print(EventQueue.unauthorizedMessage)
        }
    }

    // MARK: - Private Helpers

    private func scheduleFlush() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flushTimer?.invalidate()
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.flushInterval, repeats: true) { [weak self] _ in
                self?.flush()
            }
        }
    }

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let wasOffline = !(self?.isOnline ?? true)
            self?.isOnline = path.status == .satisfied

            // If we just came online, try to flush
            if wasOffline && path.status == .satisfied {
                self?.flush()
            }
        }
        networkMonitor.start(queue: queue)
    }

    private func setupBackgroundObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flush()
        }
        #endif
    }
}
