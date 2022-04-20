//
//  IMCenter.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/13.
//

import Foundation
import UIKit
import SwiftUI

class AsyncTask {
 
    var action: () -> Void
    
    init(action: @escaping ()->Void) {
        self.action = action
    }
    deinit {
        action()
    }
    
    func npAction() {}
}

class Locker {}

class HistoryCheckpoint {
    var ts:Int64 = 0
    var desc = false
}

struct OpenInfoData: Codable {
    var nickname: String
    var imageUrl: String
    var showInfo: String
}

struct ErrorInfo {
    var title = ""
    var desc = ""
    var code = 0
}

class IMCenter {
    static var viewSharedInfo: ViewSharedInfo = ViewSharedInfo()
    static var imEventProcessor: IMEventProcessor = IMEventProcessor()
    static var client: RTMClient? = nil
    static var db = DBOperator()
    static var locker = Locker()
    static var errorInfo = ErrorInfo()
    
    class func sortSessions(sessions: [SessionItem]) -> [SessionItem] {
        if sessions.count <= 1 {
            return sessions
        }
        
        return sessions.sorted(by: { (s1, s2) -> Bool in
            
            if s1.lastMessage.unread && !s2.lastMessage.unread {
                return true
            }
            
            if !s1.lastMessage.unread && s2.lastMessage.unread {
                return false
            }
            
            if s1.lastMessage.timestamp > s2.lastMessage.timestamp {
                return true
            }
            
            if s1.lastMessage.timestamp == s2.lastMessage.timestamp {
                return s1.lastMessage.mid > s2.lastMessage.mid
            }
            return false
        })
    }
    
    private class func sortContacts(contacts: [ContactInfo]) -> [ContactInfo] {
        if contacts.count <= 1 {
            return contacts
        }
        
        return contacts.sorted(by: { (c1, c2) -> Bool in
            
            if c1.nickname < c2.nickname {
                return true
            }
            
            if c1.nickname == c2.nickname {
                if c1.xname < c2.xname {
                    return true
                }
                
                if c1.xname == c2.xname {
                    return c1.xid < c2.xid
                }
            }
            return false
        })
    }
    
    private class func soreChatMessages(messages: [ChatMessage]) -> [ChatMessage] {
        if messages.count <= 1 {
            return messages
        }
        
        return messages.sorted(by: { (m1, m2) -> Bool in
            if m1.mtime < m2.mtime {
                return true
            }
            
            if m1.mtime == m2.mtime {
                if m1.mid < m2.mid {
                    return true
                }
            }
            return false
        })
    }
    
    private class func prepareContactList(contacts:[ContactInfo]) -> [Int: [ContactInfo]] {
        var contactList: [Int: [ContactInfo]] = [:]
        contactList[ContactKind.Friend.rawValue] = [ContactInfo]()
        contactList[ContactKind.Group.rawValue] = [ContactInfo]()
        contactList[ContactKind.Room.rawValue] = [ContactInfo]()
        
        for contact in contacts {
            if contact.kind == ContactKind.Friend.rawValue {
                contactList[ContactKind.Friend.rawValue]?.append(contact)
            } else if contact.kind == ContactKind.Group.rawValue {
                contactList[ContactKind.Group.rawValue]?.append(contact)
            } else if contact.kind == ContactKind.Room.rawValue {
                contactList[ContactKind.Room.rawValue]?.append(contact)
            }
        }
        
        for idx in ContactKind.Friend.rawValue...ContactKind.Room.rawValue {
            if contactList[idx]!.count > 1 {
                let tmp = contactList[idx]!
                contactList[idx] = sortContacts(contacts: tmp)
            }
        }

        return contactList
    }
    
    private class func appendContactsForSessionView(contacts: [ContactInfo]) {
        if contacts.isEmpty { return }
        
        var oldSessions = IMCenter.viewSharedInfo.sessions
        
        for contact in contacts {
            let sessionItem = SessionItem(contact: contact)
            oldSessions.append(sessionItem)
        }
        
        IMCenter.viewSharedInfo.sessions = sortSessions(sessions: oldSessions)
    }
    
    private class func appendContactsForContactView(contacts: [ContactInfo]) {
        if contacts.isEmpty { return }
        
        var oldContactList = IMCenter.viewSharedInfo.contactList
        
        for contact in contacts {
            oldContactList[contact.kind]?.append(contact)
        }
        
        for idx in ContactKind.Friend.rawValue...ContactKind.Room.rawValue {
            if oldContactList[idx]!.count > 1 {
                let tmp = oldContactList[idx]!
                oldContactList[idx] = sortContacts(contacts: tmp)
            }
        }
        
        IMCenter.viewSharedInfo.contactList = oldContactList
    }
    
    class func RTMLoginSuccess() {
        db.openDatabase(userId: IMCenter.client!.userId)
        
        querySelfInfo()
        
        let contacts = db.loadContentInfos()
        var sessions = db.loadLastMessage(contactList: contacts)
        sessions = IMCenter.sortSessions(sessions: sessions)
        
        let contactList = prepareContactList(contacts:contacts)
        
        DispatchQueue.main.async {
            IMCenter.viewSharedInfo.sessions = sessions
            IMCenter.viewSharedInfo.contactList = contactList
            IMCenter.viewSharedInfo.currentPage = .SessionView
            
            DispatchQueue.global(qos: .default).async {
                checkContactsUpdate(contactList: contactList)
            }
        }
        
        checkNewSessions(contacts: contacts)
        
        for contact in contacts {
            if contact.imagePath.isEmpty && contact.imageUrl.isEmpty == false {
                downloadImage(contactInfo: contact)
            }
        }
    }
    
    private class func getAllSessions(success: @escaping (_ answer: RTMP2pGroupMemberAnswer?)->Void) {
        
        client!.getAllSessions(withTimeout: 0, success: success, fail: {
            
            errorAnswer in
            
            if errorAnswer?.code == 200010 {
                sleep(2)
                getAllSessions(success: success)
            }
            
        })
    }
    
    private class func checkNewSessions(contacts: [ContactInfo]) -> Void {
    
        let asyncTask = AsyncTask(action: { IMCenter.checkUnreadMessage() })
        
        getAllSessions(success: { sessionInfos in
            guard sessionInfos != nil else { return }
            
            var localUids = Set<Int64>()
            var localGids = Set<Int64>()
            
            for index in 0..<contacts.count {
                let info = contacts[index]
                if info.kind == ContactKind.Friend.rawValue {
                    localUids.insert(info.xid)
                } else if info.kind == ContactKind.Group.rawValue {
                    localGids.insert(info.xid)
                }
            }
            
            var newUids = [NSNumber]()
            var newGids = [NSNumber]()
            
            for v in sessionInfos!.p2pArray {
                if let uid = v as? NSNumber {
                    if localUids.contains(uid.int64Value) == false {
                        newUids.append(uid)
                    }
                }
            }
            
            for v in sessionInfos!.groupArray {
                if let gid = v as? NSNumber {
                    if localGids.contains(gid.int64Value) == false {
                        newGids.append(gid)
                    }
                }
            }
            
            if newUids.isEmpty == false {
                fetchNewP2PSessions(uids: newUids, asyncTask: asyncTask)
            }
            
            if newGids.isEmpty == false {
                fetchNewGroupSessions(gids: newGids, asyncTask: asyncTask)
            }
            
        })
    }
    
    private class func decodeOpenInfo(contact: inout ContactInfo, json: String) -> Void {
        do {
            let info = try JSONDecoder().decode(OpenInfoData.self, from: json.data(using: .utf8)!)
            contact.nickname = info.nickname
            contact.imageUrl = info.imageUrl
            contact.showInfo = info.showInfo
        } catch {
            print("Error during JSON serialization: " + json)
        }
    }
    
    private class func addNewSession(contact: ContactInfo, message: RTMMessage?) {
        db.storeNewContact(contact: contact)
        downloadImage(contactInfo: contact)
        
        var contacts = [ContactInfo]()
        contacts.append(contact)
        
        DispatchQueue.main.async {
            IMCenter.appendContactsForContactView(contacts: contacts)
            
            var oldSessions = IMCenter.viewSharedInfo.sessions
            
            let sessionItem = SessionItem(contact: contact)
            if message != nil {
                sessionItem.lastMessage.message = extraChatMessage(rtmMessage: message!)
                sessionItem.lastMessage.mid = message!.messageId
                sessionItem.lastMessage.timestamp = message!.modifiedTime
                sessionItem.lastMessage.unread = true
            }
            oldSessions.append(sessionItem)
            
            IMCenter.viewSharedInfo.sessions = sortSessions(sessions: oldSessions)
            
            DispatchQueue.global(qos: .default).async {
                checkContactsUpdate(type: contact.kind, contacts: contacts)
            }
        }
    }
    
    class func addNewSessionByMenuActionInMainThread(contact: ContactInfo) {
        
        var contacts = [ContactInfo]()
        contacts.append(contact)
        
        IMCenter.appendContactsForSessionView(contacts: contacts)
        IMCenter.appendContactsForContactView(contacts: contacts)
        
        DispatchQueue.global(qos: .default).async {
            downloadImage(contactInfo: contact)
            checkContactsUpdate(type: contact.kind, contacts: contacts)
        }
    }
    
    private class func addNewSessions(contacts: [ContactInfo], asyncTask: AsyncTask) {
        if contacts.isEmpty { return }
        
        for contact in contacts {
            db.storeNewContact(contact: contact)
        }
        
        DispatchQueue.main.async {
            IMCenter.appendContactsForSessionView(contacts: contacts)
            IMCenter.appendContactsForContactView(contacts: contacts)
            
            DispatchQueue.global(qos: .default).async {
                
                asyncTask.npAction()
                
                for contact in contacts {
                    downloadImage(contactInfo: contact)
                }
                checkContactsUpdate(type: contacts.first!.kind, contacts: contacts)
            }
        }
    }
    
    private class func decodeAttributeAnswer(type: Int, attriAnswer: RTMAttriAnswer) -> [ContactInfo] {
        var contacts = [ContactInfo]()
        
        for (key, value) in  attriAnswer.atttriDictionary {
            if let keyStr = key as? String, let jsonStr = value as? String {
                if jsonStr.isEmpty {
                    continue
                }
                
                var contact = ContactInfo(type: type, xid: Int64(keyStr)!)
                decodeOpenInfo(contact: &contact, json: jsonStr)
                contacts.append(contact)
            }
        }

        return contacts
    }
    
    private class func decodeNewSession(type: Int, xids:[NSNumber], attriAnswer: RTMAttriAnswer, asyncTask: AsyncTask) {
        
        let dic = attriAnswer.atttriDictionary
        var contacts = [ContactInfo]()
            
        for number in xids {
            let xid = number.int64Value
            if let info = dic[String(xid)] {
                if let openInfo = info as? String {
                    if openInfo.isEmpty {
                        contacts.append(ContactInfo(type: type, xid: xid))
                    } else {
                        var contact = ContactInfo(type:type, xid: xid)
                        decodeOpenInfo(contact: &contact, json: openInfo)
                        contacts.append(contact)
                    }
                } else {
                    contacts.append(ContactInfo(type: type, xid: xid))
                }
                
            } else {
                contacts.append(ContactInfo(type: type, xid: xid))
            }
        }
            
        addNewSessions(contacts: contacts, asyncTask: asyncTask)
    }
    
    private class func fetchNewP2PSessions(uids: [NSNumber], asyncTask: AsyncTask) -> Void {
        IMCenter.client?.getUserOpenInfo(uids, timeout: 0, success: {
            attriAnswer in
            
            if attriAnswer != nil {
                decodeNewSession(type: ContactKind.Friend.rawValue, xids:uids, attriAnswer: attriAnswer!, asyncTask: asyncTask)
            }
            
        }, fail: {
            errorAnswer in
            
            if errorAnswer?.code == 200010 {
                sleep(2)
                fetchNewP2PSessions(uids: uids, asyncTask: asyncTask)
            }
        })
    }
    
    private class func fetchNewGroupSessions(gids: [NSNumber], asyncTask: AsyncTask) -> Void {
        IMCenter.client?.getGroupsOpenInfo(withId: gids, timeout: 0, success: {
            attriAnswer in
            
            if attriAnswer != nil {
                decodeNewSession(type: ContactKind.Group.rawValue, xids:gids, attriAnswer: attriAnswer!, asyncTask: asyncTask)
            }
    
        }, fail: {
            errorAnswer in
            
            if errorAnswer?.code == 200010 {
                sleep(2)
                fetchNewGroupSessions(gids: gids, asyncTask: asyncTask)
            }
        })
    }
    
    private class func updateUnreadStatus(p2pUids: [Int64], groupIds: [Int64]) {
        
        DispatchQueue.main.async {
            var sessions = IMCenter.viewSharedInfo.sessions
            
            for uid in p2pUids {
                for session in sessions {
                    if session.contact.kind == ContactKind.Friend.rawValue
                        && session.contact.xid == uid {
                        session.lastMessage.unread = true
                    }
                }
            }
            
            for gid in groupIds {
                for session in sessions {
                    if session.contact.kind == ContactKind.Group.rawValue
                        && session.contact.xid == gid {
                        session.lastMessage.unread = true
                    }
                }
            }
            
            sessions = sortSessions(sessions: sessions)
            IMCenter.viewSharedInfo.sessions = sessions
        }
    }
    
    
    class func checkUnreadMessage() {
        IMCenter.client!.getUnreadMessages(withClear: true, timeout: 0, success: {
            unreadArrays in
            
            guard unreadArrays != nil else { return }
            
            var p2pIds = [Int64]()
            var groupIds = [Int64]()
            
            for v in unreadArrays!.p2pArray {
                if let uid = v as? NSNumber {
                    p2pIds.append(uid.int64Value)
                }
            }
            
            for v in unreadArrays!.groupArray {
                if let gid = v as? NSNumber {
                    groupIds.append(gid.int64Value)
                }
            }
            
            updateUnreadStatus(p2pUids: p2pIds, groupIds: groupIds)
            fetchUnreadMessage(p2pUids: p2pIds, groupIds: groupIds)
            
        }, fail: {
            error in
            if error?.code == 200010 {
                sleep(2)
                checkUnreadMessage()
            } else {
                print("RTM: Get unread chat message faield. Error info: \(String(describing: error?.ex))")
            }
        })
    }
    
    private class func syncFetchUnreadP2PChat(uid:Int64) {
        let answer = IMCenter.client?.getP2PHistoryMessageChat(withUserId: NSNumber(value:uid), desc: true, num: NSNumber(value: 10), begin: nil, end: nil, lastid: nil, timeout: 0)
         
        var insertCheckoutPoint = true
        if let unreads = answer?.history.messageArray {
            for rtmMessage in unreads {
                //-- 暂不考虑二进制消息，和开启自动翻译后的翻译消息
                if IMCenter.db.insertChatMessage(type: ContactKind.Friend.rawValue, xid: uid, sender: rtmMessage.fromUid, mid: rtmMessage.messageId, message: rtmMessage.stringMessage, mtime: rtmMessage.modifiedTime) == false {
                    insertCheckoutPoint = false
                    break
                }
            }
            
            if unreads.count > 0 {
                
                //-- Insert check point
                if insertCheckoutPoint {
                    let rtmMessage = unreads.last!
                    IMCenter.db.insertCheckPoint(type: ContactKind.Friend.rawValue, xid: uid, ts:rtmMessage.modifiedTime, desc:true)
                }
                
                //-- Update unread info for SessionsView
                DispatchQueue.main.async {
                    var sessions = IMCenter.viewSharedInfo.sessions
                    
                    for session in sessions {
                        if session.contact.kind == ContactKind.Friend.rawValue
                            && session.contact.xid == uid {
                            session.lastMessage.unread = true
                            session.lastMessage.message = unreads.first!.stringMessage
                            break
                        }
                    }
                    
                    sessions = sortSessions(sessions: sessions)
                    IMCenter.viewSharedInfo.sessions = sessions
                }
            }
        }
    }
    
    private class func syncFetchUnreadGroupChat(gid:Int64) {
        let answer = IMCenter.client?.getGroupHistoryMessageChat(withGroupId: NSNumber(value:gid), desc: true, num: NSNumber(value: 10), begin: nil, end: nil, lastid: nil, timeout: 0)
        
        var insertCheckoutPoint = true
        var lastMessage = LastMessage()
        if let unreads = answer?.history.messageArray {
            for rtmMessage in unreads {
                //-- 暂不考虑二进制消息，和开启自动翻译后的翻译消息
                if rtmMessage.messageType == 30 {
                    if IMCenter.db.insertChatMessage(type: ContactKind.Group.rawValue, xid: gid, sender: rtmMessage.fromUid, mid: rtmMessage.messageId, message: rtmMessage.stringMessage, mtime: rtmMessage.modifiedTime) == false {
                        insertCheckoutPoint = false
                        break
                    } else {
                        lastMessage.message = rtmMessage.stringMessage
                        lastMessage.mid = rtmMessage.messageId
                        lastMessage.timestamp = rtmMessage.modifiedTime
                        lastMessage.unread = true
                    }
                } else {
                    if IMCenter.db.insertChatCmd(type: ContactKind.Group.rawValue, xid: gid, sender: rtmMessage.fromUid, mid: rtmMessage.messageId, message: rtmMessage.stringMessage, mtime: rtmMessage.modifiedTime) == false {
                        insertCheckoutPoint = false
                        break
                    }
                }
            }
            if unreads.count > 0 {
                
                //-- Insert check point
                if insertCheckoutPoint {
                    let rtmMessage = unreads.last!
                    IMCenter.db.insertCheckPoint(type: ContactKind.Group.rawValue, xid: gid, ts:rtmMessage.modifiedTime, desc:true)
                }
                
                if lastMessage.unread {
                    DispatchQueue.main.async {
                        var sessions = IMCenter.viewSharedInfo.sessions
                        
                        for session in sessions {
                            if session.contact.kind == ContactKind.Group.rawValue
                                && session.contact.xid == gid {
                                session.lastMessage = lastMessage
                                break
                            }
                        }
                        
                        sessions = sortSessions(sessions: sessions)
                        IMCenter.viewSharedInfo.sessions = sessions
                    }
                }
            }
        }
    }
        
    private class func fetchUnreadMessage(p2pUids: [Int64], groupIds: [Int64]) {
        
        for uid in p2pUids {
            syncFetchUnreadP2PChat(uid: uid)
        }
        
        for gid in groupIds {
            syncFetchUnreadGroupChat(gid: gid)
        }
    }
    
    //-- 存储用户属性
    class func storeUserProfile(key: String, value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    //-- 获取用户属性
    class func fetchUserProfile(key: String) -> String {
        let value = UserDefaults.standard.string(forKey: key)
        return ((value == nil) ? "" : value!)
    }
    
    class func getContactDisplayName(contact:ContactInfo) ->String {
        if contact.nickname.isEmpty == false {
            return contact.nickname
        }
        
        if contact.xname.isEmpty == false {
            return contact.xname
        }
        
        return "ID: \(contact.xid)"
    }
    
    class func getSelfDispalyName() -> String {
        var dispalyname = fetchUserProfile(key: "nickname")
        if dispalyname.isEmpty {
            dispalyname = fetchUserProfile(key: "username")
        }
        
        return dispalyname
    }
    
    class func loadUIIMage(path:String)-> UIImage {
                
        let fullPath = NSHomeDirectory() + "/Documents/" + path
        let fileUrl = URL(fileURLWithPath:fullPath)
        let data = try? Data(contentsOf: fileUrl)
        if data == nil {
            print("load image from disk failed. path: \(fileUrl)")
            return UIImage(named: IMDemoUIConfig.defaultIcon)!
        }
        return UIImage(data: data!)!
    }
    
    private class func storeImage(type: Int, xid: Int64, image: Data) -> String? {
        
        let uid: Int64 = IMCenter.client!.userId
        var path = NSHomeDirectory() + "/Documents/user_\(uid)/"
        var relativePath = "user_\(uid)/"
        
        switch type {
        case 1:
            path.append("user/")
            relativePath.append("user/")
        case 2:
            path.append("group/")
            relativePath.append("group/")
        case 3:
            path.append("room/")
            relativePath.append("room/")
        default:
            //-- 陌生人，或者自己
            path.append("user/")
            relativePath.append("user/")
        }
        
        try! FileManager.default.createDirectory(at: URL(string: "file://" + path)!, withIntermediateDirectories: true, attributes: nil)

        let filePath = path + String(xid) + ".img"
        relativePath += String(xid) + ".img"
        do {
            try image.write(to: URL(fileURLWithPath: filePath))
            return relativePath
            
        } catch {
            return nil
        }
    }
    
    private class func updateViewsImageUrl(contactInfo: ContactInfo, newPath: String) {
        
        if let contacts = IMCenter.viewSharedInfo.contactList[contactInfo.kind] {
            for idx in 0..<contacts.count {
                if contacts[idx].kind == contactInfo.kind && contacts[idx].xid == contactInfo.xid {
                    contacts[idx].imagePath = newPath
                }
            }
        }
    }
    
    private class func downloadImage(contactInfo: ContactInfo, completedAction: @escaping (_ path:String, _ contactInfo: ContactInfo)->Void, failedAction: @escaping()->Void) {
        
        if contactInfo.imageUrl.isEmpty {
            failedAction()
            return
        }
        
        URLSession.shared.dataTask(with: URL(string:contactInfo.imageUrl)!) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil
                else {
                    print("Download image error:\(String(describing: error))")
                    failedAction()
                    return
                }
            
            if let path = IMCenter.storeImage(type: contactInfo.kind, xid: contactInfo.xid, image: data) {
                completedAction(path, contactInfo)
            } else {
                failedAction()
            }
            
            }.resume()
    }
    
    private class func downloadImage(contactInfo: ContactInfo) {
        downloadImage(contactInfo: contactInfo, completedAction: {
            (path, contactInfo) in
            
            IMCenter.db.updateImageStoreInfo(type: contactInfo.kind, xid: contactInfo.xid, filePath: path)
            
            DispatchQueue.main.async { updateViewsImageUrl(contactInfo: contactInfo, newPath: path) }
        }, failedAction: {})
    }
    
    class func updateUserProfile(nickname: String, imgUrl: String, showInfo: String, completedAction: @escaping (_ path:String)->Void) {
        
        let info = OpenInfoData(nickname: nickname, imageUrl: imgUrl, showInfo: showInfo)
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(info)
        let jsonStr = String(data: jsonData!, encoding: .utf8)
        
        DispatchQueue.global(qos: .default).async {
            
            //-- 暂时忽略错误处理
            IMCenter.client!.setUserInfoWithOpenInfo(jsonStr, privteinfo: nil, timeout: 0, success:{}, fail: { _ in })
            
            let contact = ContactInfo()
            contact.kind = ContactKind.Friend.rawValue
            contact.xid = IMCenter.client!.userId
            contact.xname = IMCenter.fetchUserProfile(key: "username")
            contact.imageUrl = imgUrl
            
            downloadImage(contactInfo: contact, completedAction: {
                (path, contactInfo) in
                
                let username = IMCenter.fetchUserProfile(key: "username")
                
                IMCenter.storeUserProfile(key: "\(username)-image-url", value: imgUrl)
                IMCenter.storeUserProfile(key: "\(username)-image", value: path)
                IMCenter.storeUserProfile(key: "nickname", value: nickname)
                IMCenter.storeUserProfile(key: "showInfo", value: showInfo)
                
                DispatchQueue.main.async {
                    completedAction(path)
                    IMCenter.viewSharedInfo.inProcessing = false
                }
            }, failedAction:{
                
                IMCenter.storeUserProfile(key: "nickname", value: nickname)
                IMCenter.storeUserProfile(key: "showInfo", value: showInfo)

                DispatchQueue.main.async {
                    completedAction("")
                    IMCenter.viewSharedInfo.inProcessing = false
                }
            })
        }
    }
    
    class func genGroupOrRoomProfileChangedNotifyMessage(type: Int) -> String {
        
        if type == ContactKind.Group.rawValue {
            return "\(getSelfDispalyName()) 修改了本群信息"
        } else if type == ContactKind.Room.rawValue {
            return "\(getSelfDispalyName()) 修改了本房间信息"
        } else {
            return "\(getSelfDispalyName()) 修改了信息"
        }
    }
    
    class func updateGroupOrRoomProfile(contact: ContactInfo, orgImageUrl: String, completedAction: @escaping (_ path:String)->Void) {
        
        let info = OpenInfoData(nickname: contact.nickname, imageUrl: contact.imageUrl, showInfo: contact.showInfo)
        let jsonEncoder = JSONEncoder()
        let jsonData = try? jsonEncoder.encode(info)
        let jsonStr = String(data: jsonData!, encoding: .utf8)
        
        DispatchQueue.global(qos: .default).async {
            
            //-- 暂时忽略错误处理
            if contact.kind == ContactKind.Group.rawValue {
                IMCenter.client!.setGroupInfoWithId(NSNumber(value: contact.xid), openInfo: jsonStr, privateInfo: nil, timeout: 0, success: {}, fail: { _ in })
            } else if contact.kind == ContactKind.Room.rawValue {
                IMCenter.client!.setRoomInfoWithId(NSNumber(value: contact.xid), openInfo: jsonStr, privateInfo: nil, timeout: 0, success: {}, fail: { _ in })
            } else { return }
        
            if contact.imageUrl == orgImageUrl {
                
                DispatchQueue.main.async {
                    completedAction("")
                    IMCenter.viewSharedInfo.inProcessing = false
                }
                return
            }
            
            downloadImage(contactInfo: contact, completedAction: {
                (path, contactInfo) in
                
                contact.imagePath = path
                IMCenter.db.updatePublicInfo(contact: contact)
                sendCmd(contact: contact, message: genGroupOrRoomProfileChangedNotifyMessage(type: contact.kind))
                
                DispatchQueue.main.async {
                    completedAction(path)
                    IMCenter.viewSharedInfo.inProcessing = false
                }
            }, failedAction:{
                IMCenter.db.updatePublicInfo(contact: contact)
                sendCmd(contact: contact, message: genGroupOrRoomProfileChangedNotifyMessage(type: contact.kind))
                
                DispatchQueue.main.async {
                    completedAction("")
                    IMCenter.viewSharedInfo.inProcessing = false
                }
            })
        }
    }
    
    private class func extraChatMessage(rtmMessage: RTMMessage) -> String {
        
        if rtmMessage.translatedInfo.targetText.isEmpty == false {
            return rtmMessage.translatedInfo.targetText
        }
        
        if rtmMessage.translatedInfo.sourceText.isEmpty == false {
            return rtmMessage.translatedInfo.sourceText
        }
        
        if rtmMessage.stringMessage.isEmpty == false {
            return rtmMessage.stringMessage
        }
        
        return ""
    }
    
    class func receiveNewNessage(type:Int, rtmMessage: RTMMessage) {
        
        _ = db.insertChatMessage(type: type, xid: rtmMessage.toId, sender: rtmMessage.fromUid, mid: rtmMessage.messageId, message: extraChatMessage(rtmMessage: rtmMessage), mtime: rtmMessage.modifiedTime)
        
        DispatchQueue.main.async {
            let sessions = IMCenter.viewSharedInfo.sessions
            
            DispatchQueue.global(qos: .default).async {
                for session in sessions {
                    let matchXid = (session.contact.kind == ContactKind.Friend.rawValue) ? rtmMessage.fromUid : rtmMessage.toId
                    if session.contact.kind == type && session.contact.xid == matchXid {
                        //-- 已有的 session
                        session.lastMessage.mid = rtmMessage.messageId
                        session.lastMessage.message = extraChatMessage(rtmMessage: rtmMessage)
                        session.lastMessage.timestamp = rtmMessage.modifiedTime
                        session.lastMessage.unread = true
                        
                        DispatchQueue.main.async {
                            let sessions2 = sortSessions(sessions: sessions)
                            IMCenter.viewSharedInfo.sessions = sessions2
                            
                            if let currContact = IMCenter.viewSharedInfo.targetContact {
                                if currContact.kind == type && currContact.xid == matchXid {
                                    
                                    var dialogueMesssages = IMCenter.viewSharedInfo.dialogueMesssages
                                    let chatMsg = ChatMessage(sender: rtmMessage.fromUid, mid: rtmMessage.messageId, mtime: rtmMessage.modifiedTime, message: extraChatMessage(rtmMessage: rtmMessage))
                                    dialogueMesssages.append(chatMsg)
                                    
                                    dialogueMesssages = soreChatMessages(messages: dialogueMesssages)
                                    
                                    IMCenter.viewSharedInfo.dialogueMesssages = dialogueMesssages
                                    IMCenter.viewSharedInfo.newMessageReceived = true
                                }
                            }
                        }
                        return
                    }
                }
                
                //-- new Session
                var newContact: ContactInfo? = nil
                if type == ContactKind.Group.rawValue || type == ContactKind.Room.rawValue {
                    newContact = ContactInfo(type: type, uniqueId: rtmMessage.toId, uniqueName: "", nickname: "")
                } else {
                    newContact = ContactInfo(type: type, uniqueId: rtmMessage.fromUid, uniqueName: "", nickname: "")
                }
                
                addNewSession(contact: newContact!, message: rtmMessage)
            }
        }
    }
    
    class func receiveNewChatCmd(type:Int, rtmMessage: RTMMessage) {

        _ = db.insertChatCmd(type: type, xid: rtmMessage.toId, sender: rtmMessage.fromUid, mid: rtmMessage.messageId, message: rtmMessage.stringMessage, mtime: rtmMessage.modifiedTime)
        
        DispatchQueue.main.async {
            
            //-- 更新当前对话列表信息
            if let currContact = IMCenter.viewSharedInfo.targetContact {
                if currContact.kind == type && currContact.xid == rtmMessage.toId {
                    
                    var dialogueMesssages = IMCenter.viewSharedInfo.dialogueMesssages
                    let chatMsg = ChatMessage(sender: rtmMessage.fromUid, mid: rtmMessage.messageId, mtime: rtmMessage.modifiedTime, message: rtmMessage.stringMessage)
                    chatMsg.isChat = false
                    dialogueMesssages.append(chatMsg)
                    
                    dialogueMesssages = soreChatMessages(messages: dialogueMesssages)
                    
                    IMCenter.viewSharedInfo.dialogueMesssages = dialogueMesssages
                    return
                }
            }
        }
    }
    
    private class func syncCheckSessionsInfoUpdate(type: Int, contacts:[ContactInfo]) {
        
        var queryIds = [NSNumber]()
        for contact in contacts {
            queryIds.append(NSNumber(value: contact.xid))
        }
        
        var attriAnswer: RTMAttriAnswer? = nil
        if type == ContactKind.Friend.rawValue {
            attriAnswer = IMCenter.client!.getUserOpenInfo(queryIds, timeout: 0)
        } else if type == ContactKind.Group.rawValue {
            attriAnswer = IMCenter.client!.getGroupsOpenInfo(withId: queryIds, timeout: 0)
        } else if type == ContactKind.Room.rawValue {
            attriAnswer = IMCenter.client!.getRoomsOpenInfo(withId: queryIds, timeout: 0)
        } else { return }
        
        if attriAnswer != nil {
            let contacts = decodeAttributeAnswer(type: type, attriAnswer: attriAnswer!)
            
            DispatchQueue.main.async {
                for contact in contacts {
                    updateContactCustomInfos(contact: contact)
                }
            }
        }
    }
    
    class func querySelfInfo() {
        
        IMCenter.client!.getUserInfo(withTimeout: 0, success: {
            infoAnswer in
            
            if let openInfo = infoAnswer?.openInfo {
                var contact = ContactInfo(type: 0, xid: IMCenter.client!.userId)
                decodeOpenInfo(contact: &contact, json: openInfo)
            
                IMCenter.storeUserProfile(key: "nickname", value: contact.nickname)
                IMCenter.storeUserProfile(key: "showInfo", value: contact.showInfo)
                
                let username = IMCenter.fetchUserProfile(key: "username")
                IMCenter.storeUserProfile(key: "\(username)-image-url", value: contact.imageUrl)

                downloadImage(contactInfo: contact, completedAction: {
                    (path, contactInfo) in
                    
                    let username = IMCenter.fetchUserProfile(key: "username")
                    IMCenter.storeUserProfile(key: "\(username)-image", value: path)
                
                }, failedAction:{})
            }
            
        }, fail: {
            errorAnswer in
            
            if errorAnswer?.code == 200010 {
                sleep(2)
                querySelfInfo()
            }
        })
    }
    
    private class func updateContactXname(contact: ContactInfo) {
        if let contacts = IMCenter.viewSharedInfo.contactList[contact.kind] {
            for user in contacts {
                if contact.xid == user.xid {
                    if user.xname != contact.xname {
                        user.xname = contact.xname
                        db.updateXname(contact: user)
                    }
                }
            }
        }
    }
    
    private class func updateContactCustomInfos(contact: ContactInfo) {
        if let contacts = IMCenter.viewSharedInfo.contactList[contact.kind] {
            for user in contacts {
                if contact.xid == user.xid {
                    
                    if user.imageUrl != contact.imageUrl {
                        user.imagePath = ""
                    }
                        
                    user.nickname = contact.nickname
                    user.imageUrl = contact.imageUrl
                    user.showInfo = contact.showInfo

                    db.updatePublicInfo(contact: user)
                    downloadImage(contactInfo: user)
                }
            }
        }
    }
    
    private class func checkContactsUpdate(type:Int, contacts:[ContactInfo]) {
        var contactList = [Int:[ContactInfo]]()
        contactList[type] = contacts
        checkContactsUpdate(contactList: contactList)
    }

    private class func checkContactsUpdate(contactList:[Int:[ContactInfo]]) {
        
        //-- 查询 xname
        var uids = [Int64]()
        var gids = [Int64]()
        var rids = [Int64]()
        
        if let contacts = contactList[ContactKind.Friend.rawValue] {
            for contact in contacts {
                uids.append(contact.xid)
            }
        }
        
        if let contacts = contactList[ContactKind.Group.rawValue] {
            for contact in contacts {
                gids.append(contact.xid)
            }
        }
        
        if let contacts = contactList[ContactKind.Room.rawValue] {
            for contact in contacts {
                rids.append(contact.xid)
            }
        }
        
        BizClient.lookup(users: nil, groups: nil, rooms: nil, uids: uids, gids: gids, rids: rids, completedAction: {
            lookupData in
            
            var friends = [ContactInfo]()
            for (key, value) in lookupData.users {
                let contact = ContactInfo(type: ContactKind.Friend.rawValue, xid: value)
                contact.xname = key
                
                friends.append(contact)
            }
            
            var groups = [ContactInfo]()
            for (key, value) in lookupData.groups {
                let contact = ContactInfo(type: ContactKind.Group.rawValue, xid: value)
                contact.xname = key
                
                groups.append(contact)
            }
            
            var rooms = [ContactInfo]()
            for (key, value) in lookupData.rooms {
                let contact = ContactInfo(type: ContactKind.Room.rawValue, xid: value)
                contact.xname = key
                
                rooms.append(contact)
            }
            
            DispatchQueue.main.async {
                for user in friends {
                    updateContactXname(contact: user)
                }
                for group in groups {
                    updateContactXname(contact: group)
                }
                for room in rooms {
                    updateContactXname(contact: room)
                }
            }
        }, errorAction: { _ in })
        
        //-- 查询展示信息
        if let contacts = contactList[ContactKind.Friend.rawValue] {
            if contacts.count < 100 {
                syncCheckSessionsInfoUpdate(type: ContactKind.Friend.rawValue, contacts: contacts)
            } else {
                var queryContacts = [ContactInfo]()
                
                for contact in contacts {
                    queryContacts.append(contact)
                    if queryContacts.count == 99 {
                        syncCheckSessionsInfoUpdate(type: ContactKind.Friend.rawValue, contacts: queryContacts)
                        queryContacts.removeAll()
                    }
                }
                
                if queryContacts.count > 0 {
                    syncCheckSessionsInfoUpdate(type: ContactKind.Friend.rawValue, contacts: queryContacts)
                }
            }
        }
        
        if let contacts = contactList[ContactKind.Group.rawValue] {
            if contacts.count < 100 {
                syncCheckSessionsInfoUpdate(type: ContactKind.Group.rawValue, contacts: contacts)
            } else {
                var queryContacts = [ContactInfo]()
                
                for contact in contacts {
                    queryContacts.append(contact)
                    if queryContacts.count == 99 {
                        syncCheckSessionsInfoUpdate(type: ContactKind.Group.rawValue, contacts: queryContacts)
                        queryContacts.removeAll()
                    }
                }
                
                if queryContacts.count > 0 {
                    syncCheckSessionsInfoUpdate(type: ContactKind.Group.rawValue, contacts: queryContacts)
                }
            }
        }
        
        if let contacts = contactList[ContactKind.Room.rawValue] {
            if contacts.count < 100 {
                syncCheckSessionsInfoUpdate(type: ContactKind.Room.rawValue, contacts: contacts)
            } else {
                var queryContacts = [ContactInfo]()
                
                for contact in contacts {
                    queryContacts.append(contact)
                    if queryContacts.count == 99 {
                        syncCheckSessionsInfoUpdate(type: ContactKind.Room.rawValue, contacts: queryContacts)
                        queryContacts.removeAll()
                    }
                }
                
                if queryContacts.count > 0 {
                    syncCheckSessionsInfoUpdate(type: ContactKind.Room.rawValue, contacts: queryContacts)
                }
            }
        }
    }
    
    private class func syncQueryUsersInfos(type: Int, contacts:[ContactInfo]) {
        
        var queryIds = [NSNumber]()
        for contact in contacts {
            queryIds.append(NSNumber(value: contact.xid))
        }
        
        let attriAnswer = IMCenter.client!.getUserOpenInfo(queryIds, timeout: 0)
        let strangers = decodeAttributeAnswer(type: type, attriAnswer: attriAnswer)
        
        DispatchQueue.main.async {
            for stranger in strangers {
                if let contact = IMCenter.viewSharedInfo.strangerContacts[stranger.xid] {
                    contact.nickname = stranger.nickname
                    contact.imageUrl = stranger.imageUrl
                    contact.showInfo = stranger.showInfo
                } else {
                    IMCenter.viewSharedInfo.strangerContacts[stranger.xid] = stranger
                }
            }
        }
    }
    
    private class func pickupUnknownContacts(messages:[ChatMessage]) -> [ContactInfo] {
        
        var uids: Set<Int64> = []
        for msg in messages {
            if msg.sender != IMCenter.client!.userId {
                uids.insert(msg.sender)
            }
        }
        
        var contacts = [ContactInfo]()
        if uids.isEmpty == false {
            let allUsers = IMCenter.db.loadAllUserContactInfos()
            
            for uid in uids {
                if let contact = allUsers[uid] {
                    if contact.nickname.isEmpty || contact.imageUrl.isEmpty {
                        contacts.append(contact)
                    }
                } else {
                    contacts.append(ContactInfo(xid: uid))
                }
            }
        }
        
        return contacts
    }
    
    private class func cleanUnknownContacts(unknownContacts:[ContactInfo]) {
        
        //-- 查询 xname
        var uids = [Int64]()
        for contact in unknownContacts {
            uids.append(contact.xid)
        }
        BizClient.lookup(users: nil, groups: nil, rooms: nil, uids: uids, gids: nil, rids: nil, completedAction: {
            lookupData in
            
            var strangers = [ContactInfo]()
            for (key, value) in lookupData.users {
                let contact = ContactInfo(type: ContactKind.Stranger.rawValue, xid: value)
                contact.xname = key
                
                strangers.append(contact)
            }
            
            DispatchQueue.main.async {
                for stranger in strangers {
                    if let contact = IMCenter.viewSharedInfo.strangerContacts[stranger.xid] {
                        contact.xname = stranger.xname
                    } else {
                        IMCenter.viewSharedInfo.strangerContacts[stranger.xid] = stranger
                    }
                }
            }
        }, errorAction: { _ in })
        
        //-- 查询展示信息
        if unknownContacts.count < 100 {
            syncQueryUsersInfos(type: ContactKind.Stranger.rawValue, contacts: unknownContacts)
        } else {
            var queryContacts = [ContactInfo]()
            
            for contact in unknownContacts {
                queryContacts.append(contact)
                if queryContacts.count == 99 {
                    syncQueryUsersInfos(type: ContactKind.Stranger.rawValue, contacts: queryContacts)
                    queryContacts.removeAll()
                }
            }
            
            if queryContacts.count > 0 {
                syncQueryUsersInfos(type: ContactKind.Stranger.rawValue, contacts: queryContacts)
            }
        }
    }
    
    private class func sortHistoryCheckpoint(checkpoints:[HistoryCheckpoint]) -> [HistoryCheckpoint] {
        if checkpoints.count < 2 {
            return checkpoints
        }
        
        return checkpoints.sorted(by: { (c1, c2) -> Bool in
            if c1.ts > c2.ts {
                return true
            }
            if c1.ts == c2.ts {
                return c1.desc
            }
            return false
        })
    }
    
    private class func refillHistoryMessage(contact:ContactInfo) {
        var historyAnswer: RTMHistoryMessageAnswer? = nil
        var begin: Int64 = 0
        var end: Int64 = 0
        var lastId: Int64 = 0
        
        let fetchCount = 10
        let nsXid = NSNumber(value: contact.xid)
        let nsCount = NSNumber(value: fetchCount)
        
        var checkpoints = db.loadAllHistoryMessageCheckpoints(contact:contact)
        checkpoints = sortHistoryCheckpoint(checkpoints: checkpoints)
        
        while (true)
        {
            if contact.kind == ContactKind.Friend.rawValue {
                historyAnswer = IMCenter.client!.getP2PHistoryMessageChat(withUserId: nsXid, desc: true, num: nsCount, begin: NSNumber(value: begin), end: NSNumber(value: end), lastid: NSNumber(value: lastId), timeout: 0)
            } else if contact.kind == ContactKind.Group.rawValue {
                historyAnswer = IMCenter.client!.getGroupHistoryMessageChat(withGroupId: nsXid, desc: true, num: nsCount, begin: NSNumber(value: begin), end: NSNumber(value: end), lastid: NSNumber(value: lastId), timeout: 0)
            } else if contact.kind == ContactKind.Room.rawValue {
                historyAnswer = IMCenter.client!.getRoomHistoryMessageChat(withRoomId: nsXid, desc: true, num: nsCount, begin: NSNumber(value: begin), end: NSNumber(value: end), lastid: NSNumber(value: lastId), timeout: 0)
            } else { return }
            
            if historyAnswer != nil && historyAnswer!.error.code == 0 {
                
                var chatMessages = [ChatMessage]()
                for message in historyAnswer!.history.messageArray {
                    
                    if message.messageType == 30 {
                        if IMCenter.db.insertChatMessage(type: contact.kind, xid: contact.xid, sender: message.fromUid, mid: message.messageId, message: message.stringMessage, mtime: message.modifiedTime, printError: false) == false {
                            break
                        }
                    } else {
                        if IMCenter.db.insertChatCmd(type: contact.kind, xid: contact.xid, sender: message.fromUid, mid: message.messageId, message: message.stringMessage, mtime: message.modifiedTime, printError: false) == false {
                            break
                        }
                    }
                    
                    let chatMsg = ChatMessage(sender: message.fromUid, mid: message.messageId, mtime: message.modifiedTime, message: message.stringMessage)
                    
                    if message.messageType != 30 {
                        chatMsg.isChat = false
                    }
                    
                    chatMessages.append(chatMsg)
                }
                
                if chatMessages.count > 0 {
                    
                    DispatchQueue.global(qos: .default).async {
                        
                        let unknownContacts = pickupUnknownContacts(messages:chatMessages)
                        cleanUnknownContacts(unknownContacts: unknownContacts)
                    }
                    
                    var continueLoading = true

                    DispatchQueue.main.sync {
                        if IMCenter.viewSharedInfo.targetContact == nil
                            || IMCenter.viewSharedInfo.targetContact!.xid != contact.xid
                            || IMCenter.viewSharedInfo.targetContact!.kind != contact.kind {
                            continueLoading = false
                        } else {
                            var oldDialogues = IMCenter.viewSharedInfo.dialogueMesssages
                            
                            for chatMsg in chatMessages {
                                oldDialogues.append(chatMsg)
                            }
                            
                            oldDialogues = soreChatMessages(messages: oldDialogues)
                            IMCenter.viewSharedInfo.dialogueMesssages = oldDialogues
                        }
                    }

                    if continueLoading == false {
                        IMCenter.db.insertCheckPoint(type: contact.kind, xid: contact.xid, ts:historyAnswer!.history.end, desc:true)
                        return
                    }
                }
                
                if historyAnswer!.history.messageArray.count < fetchCount {
                    IMCenter.db.clearAllHistoryMessageCheckpoints(contact: contact)
                    return
                }
                
                if chatMessages.count == fetchCount {
                    
                    begin = historyAnswer!.history.begin
                    end = historyAnswer!.history.end
                    lastId = historyAnswer!.history.lastid
                    
                } else {
                    while (true) {
                        if checkpoints.count == 0 { return }
                        
                        if checkpoints.first!.ts >= end {
                            checkpoints.removeFirst()
                        } else {
                            begin = 0
                            end = Int64(checkpoints.first!.ts)
                            lastId = 0
                            
                            break
                        }
                    }
                }
            } else if historyAnswer != nil && historyAnswer!.error.code == 200010 {
                var continueLoading = true
                DispatchQueue.main.sync {
                    if IMCenter.viewSharedInfo.targetContact == nil
                        || IMCenter.viewSharedInfo.targetContact!.xid != contact.xid
                        || IMCenter.viewSharedInfo.targetContact!.kind != contact.kind {
                        continueLoading = false
                    }
                }
                
                if continueLoading == false {
                    IMCenter.db.insertCheckPoint(type: contact.kind, xid: contact.xid, ts:end, desc:true)
                    return
                }
                
                sleep(2)
            } else {
                return
            }
        }
    }
    
    class func prepareDialogueMesssageInfos(contact:ContactInfo) {
        
        if contact.kind == ContactKind.Room.rawValue {
            DispatchQueue.global(qos: .default).async {
                IMCenter.client!.enterRoom(withId: NSNumber(value: contact.xid), timeout: 0, success: {
                    
                    DispatchQueue.main.sync {
                        
                        sendCmd(contact: contact, message: "\(getSelfDispalyName()) 进入房间")
                    }

                }, fail: { _ in })
            }
        }
        
        let chatMessages = IMCenter.db.loadAllMessages(contact:contact)
        IMCenter.viewSharedInfo.dialogueMesssages = soreChatMessages(messages: chatMessages)
        
        DispatchQueue.global(qos: .default).async {
            let unknownContacts = pickupUnknownContacts(messages:chatMessages)
            cleanUnknownContacts(unknownContacts: unknownContacts)
        }
        
        DispatchQueue.global(qos: .default).async {
            refillHistoryMessage(contact:contact)
        }
    }
    
    private class func sendP2PMessage(contact:ContactInfo, message:String) {
        IMCenter.client!.sendP2PMessageChat(withId: NSNumber(value: contact.xid), message: message, attrs: "", timeout:0, success: {
            answer in
            _ = IMCenter.db.insertChatMessage(type: ContactKind.Friend.rawValue, xid: contact.xid, sender: IMCenter.client!.userId, mid: answer.messageId, message: message, mtime: answer.mtime)
        }, fail: {
            _ in
            //-- 这里应该在UI上显示红色圆形底叹号，但IMDemo为演示目的，这里从略
        })
    }
    
    private class func sendGroupMessage(contact:ContactInfo, message:String) {
        IMCenter.client!.sendGroupMessageChat(withId: NSNumber(value: contact.xid), message: message, attrs: "", timeout:0, success: {
            answer in
            _ = IMCenter.db.insertChatMessage(type: ContactKind.Group.rawValue, xid: contact.xid, sender: IMCenter.client!.userId, mid: answer.messageId, message: message, mtime: answer.mtime)
        }, fail: {
            _ in
            //-- 这里应该在UI上显示红色圆形底叹号，但IMDemo为演示目的，这里从略
        })
    }
    
    private class func sendRoomMessage(contact:ContactInfo, message:String) {
        IMCenter.client!.sendRoomMessageChat(withId: NSNumber(value: contact.xid), message: message, attrs: "", timeout:0, success: {
            answer in
            _ = IMCenter.db.insertChatMessage(type: ContactKind.Room.rawValue, xid: contact.xid, sender: IMCenter.client!.userId, mid: answer.messageId, message: message, mtime: answer.mtime)
        }, fail: {
            _ in
            //-- 这里应该在UI上显示红色圆形底叹号，但IMDemo为演示目的，这里从略
        })
    }
    
    private class func sendGroupCmd(contact:ContactInfo, message:String) {
        IMCenter.client!.sendGroupCmdMessageChat(withId: NSNumber(value: contact.xid), message: message, attrs: "", timeout:0, success: { _ in
        }, fail: {
            _ in
        })
    }
    
    private class func sendRoomCmd(contact:ContactInfo, message:String) {
        IMCenter.client!.sendRoomCmdMessageChat(withId: NSNumber(value: contact.xid), message: message, attrs: "", timeout:0, success: { _ in
        }, fail: {
            _ in
        })
    }

    static var fakeMid:Int64 = 1
    
    class func sendMessage(contact:ContactInfo, message:String) {
        if contact.kind == ContactKind.Friend.rawValue {
            sendP2PMessage(contact:contact, message:message)
        } else if contact.kind == ContactKind.Group.rawValue {
            sendGroupMessage(contact:contact, message:message)
        }else if contact.kind == ContactKind.Room.rawValue {
            sendRoomMessage(contact:contact, message:message)
        } else { return }
        
        objc_sync_enter(locker)
        let mid = fakeMid
        fakeMid += 1
        objc_sync_exit(locker)
        
        let curr = Date().timeIntervalSince1970 * 1000
        
        let chatMessage = ChatMessage(sender: IMCenter.client!.userId, mid: mid, mtime: Int64(curr), message: message)
        
        var chats = IMCenter.viewSharedInfo.dialogueMesssages
        chats.append(chatMessage)
        
        IMCenter.viewSharedInfo.dialogueMesssages = chats
    }
    
    class func sendCmd(contact:ContactInfo, message:String) {
        if contact.kind == ContactKind.Group.rawValue {
            sendGroupCmd(contact:contact, message:message)
        }else if contact.kind == ContactKind.Room.rawValue {
            sendRoomCmd(contact:contact, message:message)
        } else { return }
        
        objc_sync_enter(locker)
        let mid = fakeMid
        fakeMid += 1
        objc_sync_exit(locker)
        
        let curr = Date().timeIntervalSince1970 * 1000
        
        let chatMessage = ChatMessage(sender: IMCenter.client!.userId, mid: mid, mtime: Int64(curr), message: message)
        chatMessage.isChat = false
        
        var chats = IMCenter.viewSharedInfo.dialogueMesssages
        chats.append(chatMessage)
        
        IMCenter.viewSharedInfo.dialogueMesssages = chats
    }
    
    class func findContact(chatMessage: ChatMessage) -> ContactInfo {
        //-- 好友列表中查找
        for contact in IMCenter.viewSharedInfo.contactList[ContactKind.Friend.rawValue]! {
            if contact.xid == chatMessage.sender {
                return contact
            }
        }
        
        //-- 陌生人中查找
        if let contact = IMCenter.viewSharedInfo.strangerContacts[chatMessage.sender] {
            return contact
        }
        
        let contact = ContactInfo(type: ContactKind.Stranger.rawValue, xid: chatMessage.sender)
        
        if chatMessage.sender == IMCenter.client!.userId {
            let username = IMCenter.fetchUserProfile(key: "username")
            contact.imageUrl = IMCenter.fetchUserProfile(key: "\(username)-image-url")
            contact.imagePath = IMCenter.fetchUserProfile(key: "\(username)-image")
        } else {
            IMCenter.viewSharedInfo.strangerContacts[chatMessage.sender] = contact
            
            DispatchQueue.global(qos: .default).async {
                
                var unknownContacts = [ContactInfo]()
                unknownContacts.append(contact)
                cleanUnknownContacts(unknownContacts: unknownContacts)
            }
        }
        
        return contact
    }
    
    class func showDialogueView(contact: ContactInfo) {
        
        //-- 仅能在主线程中调用
        IMCenter.viewSharedInfo.targetContact = contact
        
        IMCenter.viewSharedInfo.strangerContacts.removeAll()
        
        IMCenter.prepareDialogueMesssageInfos(contact: contact)
        
        IMCenter.viewSharedInfo.lastPage = IMCenter.viewSharedInfo.currentPage
        
        IMCenter.viewSharedInfo.currentPage = .DialogueView
    }
    
    class func addFriendInMainThread(xname: String, existAction: @escaping (_ contact: ContactInfo)->Void, successAction: @escaping (_ contact: ContactInfo)->Void, errorAction: @escaping (_ errorInfo: ErrorInfo)->Void) {
        
        var contact = db.loadContentInfo(type: ContactKind.Friend.rawValue, xname: xname)
        if contact != nil {
            existAction(contact!)
            showDialogueView(contact: contact!)
            return
        } else {
            contact = db.loadContentInfo(type: ContactKind.Stranger.rawValue, xname: xname)
            if contact != nil {
                existAction(contact!)
                db.changeStrangerToFriend(xid: contact!.xid)
                addNewSessionByMenuActionInMainThread(contact: contact!)
                showDialogueView(contact: contact!)
                return
            }
        }
        
        var users = [String]()
        users.append(xname)
        
        BizClient.lookup(users: users, groups: nil, rooms: nil, uids: nil, gids: nil, rids: nil, completedAction: {
            respon in
            if let uid = respon.users[xname] {
                let contact = ContactInfo(type: ContactKind.Friend.rawValue, uniqueId: uid, uniqueName: xname, nickname: "")
                
                DispatchQueue.main.async {
                    successAction(contact)
                }
                return
            } else {
                var errInfo = ErrorInfo()
                errInfo.title = "用户不存在"
                errInfo.desc = "被添加的用户尚未注册！"
                
                DispatchQueue.main.async {
                    errorAction(errInfo)
                }
            }
        }, errorAction: { errorMessage in
            
            var errInfo = ErrorInfo()
            
            errInfo.title = "添加好友失败"
            errInfo.desc = errorMessage
            
            DispatchQueue.main.async {
                errorAction(errInfo)
            }
        })
    }
    
    class func createGroupInMainThread(xname: String, existAction: @escaping (_ contact: ContactInfo)->Void, successAction: @escaping (_ contact: ContactInfo)->Void, errorAction: @escaping (_ errorInfo: ErrorInfo)->Void) {
        
        let contact = db.loadContentInfo(type: ContactKind.Group.rawValue, xname: xname)
        if contact != nil {
            existAction(contact!)
            showDialogueView(contact: contact!)
            return
        }
        
        BizClient.createGroup(uniqueName: xname, completedAction: {
            gid in
            
            let contact = ContactInfo(type: ContactKind.Group.rawValue, uniqueId: gid, uniqueName: xname, nickname: "")
            
            DispatchQueue.main.async {
                successAction(contact)
            }
            
        }, errorAction: {
            errorMessage in
            
            var errInfo = ErrorInfo()
            
            errInfo.title = "创建群组失败"
            errInfo.desc = errorMessage
            
            DispatchQueue.main.async {
                errorAction(errInfo)
            }
        })
    }
    
    class func joinGroupInMainThread(xname: String, existAction: @escaping (_ contact: ContactInfo)->Void, successAction: @escaping (_ contact: ContactInfo)->Void, errorAction: @escaping (_ errorInfo: ErrorInfo)->Void) {
        
        let contact = db.loadContentInfo(type: ContactKind.Group.rawValue, xname: xname)
        if contact != nil {
            existAction(contact!)
            showDialogueView(contact: contact!)
            return
        }
        
        BizClient.joinGroup(uniqueGroupName: xname, completedAction: {
            gid in
            
            let contact = ContactInfo(type: ContactKind.Group.rawValue, uniqueId: gid, uniqueName: xname, nickname: "")
            
            DispatchQueue.main.async {
                successAction(contact)
            }
            
        }, errorAction: {
            errorMessage in
            
            var errInfo = ErrorInfo()
            
            errInfo.title = "加入群组失败"
            errInfo.desc = errorMessage
            
            DispatchQueue.main.async {
                errorAction(errInfo)
            }
        })
    }
    
    class func createRoomInMainThread(xname: String, existAction: @escaping (_ contact: ContactInfo)->Void, successAction: @escaping (_ contact: ContactInfo)->Void, errorAction: @escaping (_ errorInfo: ErrorInfo)->Void) {
        
        let contact = db.loadContentInfo(type: ContactKind.Room.rawValue, xname: xname)
        if contact != nil {
            existAction(contact!)
            showDialogueView(contact: contact!)
            return
        }
        
        BizClient.createRoom(uniqueName: xname, completedAction: {
            rid in
            
            let contact = ContactInfo(type: ContactKind.Room.rawValue, uniqueId: rid, uniqueName: xname, nickname: "")
            
            DispatchQueue.main.async {
                successAction(contact)
            }
            
        }, errorAction: {
            errorMessage in
            
            var errInfo = ErrorInfo()
            
            errInfo.title = "创建房间失败"
            errInfo.desc = errorMessage
            
            DispatchQueue.main.async {
                errorAction(errInfo)
            }
        })
    }
    
    class func joinRoomInMainThread(xname: String, existAction: @escaping (_ contact: ContactInfo)->Void, successAction: @escaping (_ contact: ContactInfo)->Void, errorAction: @escaping (_ errorInfo: ErrorInfo)->Void) {
        
        let contact = db.loadContentInfo(type: ContactKind.Room.rawValue, xname: xname)
        if contact != nil {
            existAction(contact!)
            showDialogueView(contact: contact!)
            return
        }
        
        var rooms = [String]()
        rooms.append(xname)
        
        BizClient.lookup(users: nil, groups: nil, rooms: rooms, uids: nil, gids: nil, rids: nil, completedAction: {
            respon in
            if let rid = respon.rooms[xname] {
                let contact = ContactInfo(type: ContactKind.Room.rawValue, uniqueId: rid, uniqueName: xname, nickname: "")
                
                DispatchQueue.main.async {
                    successAction(contact)
                }
                return
            } else {
                var errInfo = ErrorInfo()
                errInfo.title = "房间不存在"
                errInfo.desc = "房间尚未被创建！"
                
                DispatchQueue.main.async {
                    errorAction(errInfo)
                }
            }
        }, errorAction: { errorMessage in
            
            var errInfo = ErrorInfo()
            
            errInfo.title = "进入房间失败"
            errInfo.desc = errorMessage
            
            DispatchQueue.main.async {
                errorAction(errInfo)
            }
        })
    }
}
