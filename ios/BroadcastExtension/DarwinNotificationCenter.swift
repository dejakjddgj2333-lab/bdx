//
//  DarwinNotificationCenter.swift
//  BroadcastExtension
//
//  扩展进程与主 App 进程之间的跨进程通知（Darwin notifications）。
//  通知名须与 livekit_client 插件侧保持一致。
//

import Foundation

enum DarwinNotification: String {
    case broadcastStarted = "iOS_BroadcastStarted"
    case broadcastStopped = "iOS_BroadcastStopped"
    case broadcastRequestStop = "iOS_BroadcastRequestStop"
}

class DarwinNotificationCenter {

    static let shared = DarwinNotificationCenter()

    private let notificationCenter: CFNotificationCenter

    init() {
        notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    }

    func postNotification(_ name: DarwinNotification) {
        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(rawValue: name.rawValue as CFString), nil, nil, true)
    }
}
