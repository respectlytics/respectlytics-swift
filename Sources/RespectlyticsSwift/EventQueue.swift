//
//  EventQueue.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Network

/// Manages event batching, persistence, and automatic flushing
final class EventQueue {
    
    private var events: [Event] = []
    private var flushTimer: Timer?
    private let networkClient: NetworkClient
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true
    
    private let maxQueueSize = 10
    private let flushInterval: TimeInterval = 30
    private let persistenceKey = "com.respectlytics.eventQueue"
    
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.respectlytics.eventQueue")
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
        loadPersistedQueue()
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
    
    /// Add an event to the queue
    func add(_ event: Event) {
        lock.lock()
        events.append(event)
        persistQueue()
        let shouldFlush = events.count >= maxQueueSize
        lock.unlock()
        
        if shouldFlush {
            flush()
        }
    }
    
    /// Force flush all queued events
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
        persistQueue()
        lock.unlock()
        
        Task {
            do {
                try await networkClient.send(events: batch)
            } catch {
                // Re-add failed events to queue
                lock.lock()
                events.insert(contentsOf: batch, at: 0)
                persistQueue()
                lock.unlock()
                print("[Respectlytics] Failed to send events, will retry later")
            }
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
    
    private func persistQueue() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadPersistedQueue() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let persisted = try? JSONDecoder().decode([Event].self, from: data) else {
            return
        }
        events = persisted
    }
}
