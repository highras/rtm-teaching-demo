//
//  IMDemoApp.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/13.
//

import SwiftUI

enum IMViewType {
    case LoginView
    case RegisterView
    case SessionView
    case ContactView
    case ProfileView
    case DialogueView
    case BrokenView
}

enum MenuActionType {
    case AddFriend
    case CreateGroup
    case JoinGroup
    case CreateRoom
    case EnterRoom
    case HideMode
}

enum ContactKind: Int {
    case Stranger = 0
    case Friend = 1
    case Group = 2
    case Room = 3
}

struct LastMessage {
    var timestamp: Int64 = 0
    var mid: Int64 = 0
    var message = ""
    var unread = false
}

class ContactInfo {
    var kind = ContactKind.Friend.rawValue
    var xid: Int64 = 0
    var xname = ""
    var nickname = ""
    var imageUrl = ""
    var imagePath = ""
    var showInfo = ""
    
    init() {}
    init(xid:Int64) {
        self.kind = ContactKind.Stranger.rawValue
        self.xid = xid
    }
    init(type:Int, xid:Int64) {
        self.kind = type
        self.xid = xid
    }
    init(type: Int, uniqueId: Int64, uniqueName: String, nickname: String) {
        self.kind = type
        self.xid = uniqueId
        self.xname = uniqueName
        self.nickname = nickname
    }
    convenience init(type: Int, uniqueId: Int64, uniqueName: String, nickname: String, imageUrl: String) {
        self.init(type: type, uniqueId: uniqueId, uniqueName: uniqueName, nickname: nickname)
        self.imageUrl = imageUrl
    }
    convenience init(type: Int, uniqueId: Int64, uniqueName: String, nickname: String, imageUrl: String, imagePath: String) {
        self.init(type: type, uniqueId: uniqueId, uniqueName: uniqueName, nickname: nickname, imageUrl:imageUrl)
        self.imagePath = imagePath
    }
}

class SessionItem: Identifiable {
    var lastMessage = LastMessage()
    var contact: ContactInfo
    
    init(contact: ContactInfo) {
        self.contact = contact
    }
}

class ChatMessage: Identifiable {
    var sender: Int64
    var mid: Int64
    var mtime: Int64
    var message: String
    var isChat = true
    
    init(sender:Int64, mid:Int64, mtime:Int64, message:String) {
        self.sender = sender
        self.mid = mid
        self.mtime = mtime
        self.message = message
    }
}

class ViewSharedInfo: ObservableObject {
    @Published var currentPage: IMViewType = .LoginView
    @Published var inProcessing = false
    @Published var newMessageReceived = false
    @Published var menuAction: MenuActionType = .HideMode
    @Published var dialogueMesssages: [ChatMessage] = []
    @Published var sessions:[SessionItem] = []
    var contactList: [Int: [ContactInfo]] = [:]
    var brokenInfo = ""
    var lastPage: IMViewType = .SessionView
    
    var targetContact: ContactInfo? = nil
    var strangerContacts: [Int64:ContactInfo] = [:]
    @Published var newestMessage = ChatMessage(sender: 0, mid: 0, mtime: 0, message: "")
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

@main
struct IMDemoApp: App {
    
    @StateObject var sharedInfo: ViewSharedInfo = IMCenter.viewSharedInfo
    
    var body: some Scene {
        WindowGroup {
            switch sharedInfo.currentPage {
            case .LoginView:
                LoginView()
            case .RegisterView:
                RegisterView()
            case .SessionView:
                SessionView(viewInfo: IMCenter.viewSharedInfo)
            case .ContactView:
                ContactView(viewInfo: IMCenter.viewSharedInfo)
            case .ProfileView:
                ProfileView(viewInfo: IMCenter.viewSharedInfo)
            case .DialogueView:
                DialogueView()
            case .BrokenView:
                BrokenView(info: IMCenter.viewSharedInfo.brokenInfo)
            }
        }
    }
}
