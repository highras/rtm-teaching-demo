//
//  IMEventProcessor.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/15.
//

import Foundation

@objcMembers public class IMEventProcessor: NSObject, RTMProtocol {
    public func rtmReloginWillStart(_ client: RTMClient, reloginCount: Int32) -> Bool {
        return true
    }
    
    public func rtmReloginCompleted(_ client: RTMClient, reloginCount: Int32, reloginResult: Bool, error: FPNError) {
        //-- Do nothings
    }
    
    public func rtmConnectClose(_ client: RTMClient) {
        DispatchQueue.main.async {
            IMCenter.viewSharedInfo.brokenInfo = "RTM 链接已关闭！"
            IMCenter.viewSharedInfo.currentPage = .LoginView
        }
    }
    
    public func rtmKickout(_ client: RTMClient) {
        DispatchQueue.main.async {
            IMCenter.viewSharedInfo.brokenInfo = "账号已在其他地方登陆！"
            IMCenter.viewSharedInfo.currentPage = .LoginView
        }
    }
    
    
    public func rtmPushP2PChatMessage(_ client: RTMClient, message: RTMMessage?) {
        IMCenter.receiveNewNessage(type: ContactKind.Friend.rawValue, rtmMessage: message!)
    }
    
    public func rtmPushGroupChatMessage(_ client: RTMClient, message: RTMMessage?) {
        IMCenter.receiveNewNessage(type: ContactKind.Group.rawValue, rtmMessage: message!)
    }
    
    public func rtmPushRoomChatMessage(_ client: RTMClient, message: RTMMessage?) {
        IMCenter.receiveNewNessage(type: ContactKind.Room.rawValue, rtmMessage: message!)
    }
    
    public func rtmPushGroupChatCmd(_ client: RTMClient, message: RTMMessage?) {
        if let msg = message {
            IMCenter.receiveNewChatCmd(type: ContactKind.Group.rawValue, rtmMessage: msg)
        }
    }
    
    public func rtmPushRoomChatCmd(_ client: RTMClient, message: RTMMessage?) {
        if let msg = message {
            IMCenter.receiveNewChatCmd(type: ContactKind.Room.rawValue, rtmMessage: msg)
        }
    }
}
