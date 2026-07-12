//
//  DockKitAccessoryService.swift
//  ASMR Walk
//

import Foundation
import Observation
#if canImport(DockKit)
import DockKit
#endif

@MainActor
@Observable
final class DockKitAccessoryService {
    private(set) var isAccessoryConnected = false
    private(set) var accessoryName: String?
    private(set) var errorMessage: String?

    private var stateTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var lastShutterEventTime = Date.distantPast

    func start(
        shutterAction: @escaping @MainActor @Sendable () -> Void,
        zoomAction: @escaping @MainActor @Sendable (_ factor: Double) -> Void
    ) {
#if canImport(DockKit)
        guard stateTask == nil else {
            return
        }

        stateTask = Task { @MainActor [weak self] in
            await self?.observeAccessoryState(
                shutterAction: shutterAction,
                zoomAction: zoomAction
            )
        }
#endif
    }

    func stop() {
        stateTask?.cancel()
        eventTask?.cancel()
        stateTask = nil
        eventTask = nil
        isAccessoryConnected = false
        accessoryName = nil
    }

#if canImport(DockKit)
    private func observeAccessoryState(
        shutterAction: @escaping @MainActor @Sendable () -> Void,
        zoomAction: @escaping @MainActor @Sendable (_ factor: Double) -> Void
    ) async {
        do {
            await disableSystemTracking()

            for await stateChange in try DockAccessoryManager.shared.accessoryStateChanges {
                guard Task.isCancelled == false else {
                    return
                }

                switch stateChange.state {
                case .docked:
                    guard let accessory = stateChange.accessory else {
                        continue
                    }
                    isAccessoryConnected = true
                    accessoryName = accessory.identifier.name
                    errorMessage = nil
                    await disableSystemTracking()
                    subscribeToEvents(
                        from: accessory,
                        shutterAction: shutterAction,
                        zoomAction: zoomAction
                    )
                case .undocked:
                    eventTask?.cancel()
                    eventTask = nil
                    isAccessoryConnected = false
                    accessoryName = nil
                @unknown default:
                    break
                }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disableSystemTracking() async {
        do {
            guard DockAccessoryManager.shared.isSystemTrackingEnabled else {
                return
            }

            try await DockAccessoryManager.shared.setSystemTrackingEnabled(false)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to disable DockKit system tracking: \(error.localizedDescription)"
        }
    }

    private func subscribeToEvents(
        from accessory: DockAccessory,
        shutterAction: @escaping @MainActor @Sendable () -> Void,
        zoomAction: @escaping @MainActor @Sendable (_ factor: Double) -> Void
    ) {
        eventTask?.cancel()
        eventTask = Task { @MainActor [weak self] in
            do {
                for await event in try accessory.accessoryEvents {
                    guard Task.isCancelled == false else {
                        return
                    }
                    self?.handle(
                        event,
                        shutterAction: shutterAction,
                        zoomAction: zoomAction
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func handle(
        _ event: DockAccessory.AccessoryEvent,
        shutterAction: @MainActor @Sendable () -> Void,
        zoomAction: @MainActor @Sendable (_ factor: Double) -> Void
    ) {
        switch event {
        case .cameraShutter:
            guard Date.now.timeIntervalSince(lastShutterEventTime) > 0.2 else {
                return
            }
            lastShutterEventTime = .now
            shutterAction()
        case .cameraZoom(factor: let factor):
            zoomAction(factor)
        default:
            break
        }
    }
#endif
}
