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
final class EventQueue {

    private var events: [Event] = []
    private var flushTimer: Timer?
    private let networkClient: NetworkClient
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true

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

    func start() {
        scheduleFlush()
    }

    /// Add an event to the in-memory queue.
    func add(_ event: Event) {
        lock.lock()
        events.append(event)
        let shouldFlush = events.count >= maxQueueSize
        lock.unlock()

        if shouldFlush {
            flush()
        }
    }

    /// Force flush all queued events.
    func flush() {
        lock.lock()
        guard !events.isEmpty else {
            lock.unlock()
            return
        }

        guard isOnline else {
            lock.unlock()
            return
        }

        let batch = events
        events = []
        lock.unlock()

        Task {
            do {
                try await networkClient.send(events: batch)
            } catch {
                // Re-add failed events to in-memory queue for retry
                requeue(batch)
                print("[Respectlytics] Failed to send events, will retry later")
            }
        }
    }

    /// Put a batch that failed back at the front of the in-memory queue.
    /// A synchronous method, so the lock is never taken directly in the async task.
    private func requeue(_ batch: [Event]) {
        lock.lock()
        events.insert(contentsOf: batch, at: 0)
        lock.unlock()
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
