//
//  AsyncDispatchQueue.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation

/**
 Create a new DispatchQueue that is able to manage async/await code in their execute function.
 All call to execute will wait the previous call to be finished
 */
class AsyncDispatchQueue {
    private var _isCancelled: Bool = false
    private let executorQueue: DispatchQueue
    private var executorTask: Task<Void, any Error>?

    init(label: String) {
        executorQueue = DispatchQueue(label: "sync-queue")
        executorTask = nil
    }

    func isCancelled() -> Bool {
        var cancelled = false
        executorQueue.sync {
            cancelled = self._isCancelled
        }
        return cancelled
    }

    func sync(_ fct: @escaping () -> Void) {
        executorQueue.sync(execute: fct)
    }

    func execute(_ fct: @escaping () async throws -> Void) async throws {
        var waitTask: Task<Void, any Error>?
        executorQueue.sync {
            self._isCancelled = false
        }

        repeat {
            waitTask = nil

            executorQueue.sync {
                if self.executorTask != nil {
                    waitTask = self.executorTask
                } else {
                    self.executorTask = Task(priority: .high, operation: fct)
                }
            }

            if self.isCancelled() {
                return
            }

            if waitTask != nil {
                // If there was a previous call, wait for it to finish
                try? await waitTask?.value

                if self.isCancelled() {
                    return
                }
            }
        } while waitTask != nil

        defer {
            executorQueue.sync {
                self.executorTask = nil
            }
        }
        try await self.executorTask?.value
    }

    /**
     Execute the fct fonction, but if a task was already running, directly execute fallback
     */
    func executeOrFallback(_ fct: @escaping () async throws -> Void, fallback: @escaping () async throws -> Void) async throws {
        var waitTask: Task<Void, any Error>?

        executorQueue.sync {
            if self.executorTask != nil {
                waitTask = self.executorTask
            } else {
                self.executorTask = Task(priority: .high, operation: fct)
            }
        }

        if waitTask != nil {
            try await fallback()
            return
        }

        defer {
            executorQueue.sync {
                self.executorTask = nil
            }
        }
        try await self.executorTask?.value
    }

    func cancel() {
        executorQueue.sync {
            _isCancelled = true
        }
        executorTask?.cancel()
    }
}
