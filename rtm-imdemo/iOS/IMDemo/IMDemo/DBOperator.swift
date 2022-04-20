//
//  DBOperator.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import Foundation
import SQLite3

class DBOperator {
    
    var db: OpaquePointer?
    
    init() {
        db = nil
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    func openDatabase(userId:Int64) {

        let DocumentsPath =  NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first!
        
        var databasePath = DocumentsPath + "/user_\(userId)"
        try! FileManager.default.createDirectory(at: URL(string: "file://" + databasePath)!, withIntermediateDirectories: true, attributes: nil)
        
        databasePath += "/database.sql3"
        
        let requireCreateTables = !(FileManager.default.fileExists(atPath: databasePath))
        
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            if requireCreateTables {
                createContactTable()
            }
        } else {
            print("Open database at " + databasePath + " failed.")
        }
    }
    
    private func createContactTable() {
        
        //-- Contact Kind： 0: 非联系人用户；1: 联系人用户；2: 群组；3: 房间。
        let contactSQL = """
    CREATE TABLE IF NOT EXISTS Contact(
        kind int not null,
        xid bigint not null,
        xname varchar(255) not null,
        nickname varchar(255) not null,
        imgUrl varchar(255) not null,
        imgPath varchar(255) not null,
        info varchar(255) not null,
        unique(kind, xid)
    )
"""
        
        let messageSQL = """
        CREATE TABLE IF NOT EXISTS message(
            kind int not null,
            xid bigint not null,
            senderUid bigint not null,
            isCmd tinyint not null default 0,
            mid bigint not null,
            message varchar(255) not null,
            mtime bigint not null,
            unique(kind, xid, senderUid, mid)
        )
"""
        let historyCheckpointSQL = """
        CREATE TABLE IF NOT EXISTS checkpoint(
            kind int not null,
            xid bigint not null,
            ts bigint not null,
            desc int not null,
            unique(kind, xid, ts, desc)
        )
"""
        
        _ = executeSQL(sql: contactSQL)
        _ = executeSQL(sql: messageSQL)
        _ = executeSQL(sql: historyCheckpointSQL)
    }
    
    private func executeSQL(sql: String, printError: Bool = true) -> Bool {
        
        if (sqlite3_exec(db, sql.cString(using: String.Encoding.utf8)!, nil, nil, nil) == SQLITE_OK) {
            return true
        } else {
            if printError, let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
            return false
        }
    }
    
    //-- 保存新收到的聊天消息
    func insertChatMessage(type:Int, xid:Int64, sender:Int64, mid:Int64, message:String, mtime:Int64, printError: Bool = true) -> Bool {
        let sql = """
        insert into message (kind, xid, senderUid, mid, message, mtime) values
            (\(type), \(xid), \(sender), \(mid), '\(message)', \(mtime))
"""
        
        objc_sync_enter(self)
        let status = executeSQL(sql:sql, printError: printError)
        objc_sync_exit(self)
        
        return status
    }
    
    //-- 保存新收到的系统通知
    func insertChatCmd(type:Int, xid:Int64, sender:Int64, mid:Int64, message:String, mtime:Int64, printError: Bool = true) -> Bool {
        let sql = """
        insert into message (kind, xid, senderUid, mid, message, mtime, isCmd) values
            (\(type), \(xid), \(sender), \(mid), '\(message)', \(mtime), 1)
"""
        objc_sync_enter(self)
        let status = executeSQL(sql:sql, printError: printError)
        objc_sync_exit(self)
        
        return status
    }
    
    //-- 插入历史消息检查点
    func insertCheckPoint(type:Int, xid:Int64, ts:Int64, desc:Bool) {
        let sql = """
        insert into checkpoint (kind, xid, ts, desc) values
            (\(type), \(xid), \(ts), \(desc ? 1 : 0))
"""
        objc_sync_enter(self)
        _ = executeSQL(sql: sql)
        objc_sync_exit(self)
    }
    
    //-- 更新头像本地存储信息
    func updateImageStoreInfo(type: Int, xid: Int64, filePath: String) {
        let sql = "update Contact set imgPath='\(filePath)' where kind=\(type) and xid=\(xid)"
        
        objc_sync_enter(self)
        _ = executeSQL(sql: sql)
        objc_sync_exit(self)
    }
    
    //-- 保存新的联系人信息
    private func insertNewContact(contact: ContactInfo, printError: Bool = true) -> Bool {
        let sql = """
        insert into Contact (kind, xid, xname, nickname, imgUrl, imgPath, info) values (
            \(contact.kind), \(contact.xid), '\(contact.xname)', '\(contact.nickname)',
            '\(contact.imageUrl)', '\(contact.imagePath)', '\(contact.showInfo)')
"""

        return executeSQL(sql: sql, printError: printError)
    }
    
    //-- 保存新的联系人信息
    func storeNewContact(contact: ContactInfo) {
        let updateSQL = """
        update Contact set nickname='\(contact.nickname)', imgUrl='\(contact.imageUrl)',
        imgPath='\(contact.imagePath)', info='\(contact.showInfo)'
        where kind=\(contact.kind) and xid=\(contact.xid)
"""
        
        objc_sync_enter(self)
        if (insertNewContact(contact: contact, printError: false)) {
        } else if (sqlite3_exec(db, updateSQL.cString(using: String.Encoding.utf8)!, nil, nil, nil) == SQLITE_OK) {
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        objc_sync_exit(self)
    }
    
    //-- 当添加好友时，如果对方已经作为陌生人被保存在联系人数据表中，则修改陌生人状态为好友状态
    func changeStrangerToFriend(xid:Int64) {
        let sql = """
        update Contact set kind=\(ContactKind.Friend.rawValue) where kind=\(ContactKind.Stranger.rawValue) and xid=\(xid)
"""
        objc_sync_enter(self)
        _ = executeSQL(sql:sql)
        objc_sync_exit(self)
    }
    
    //-- 更新全剧唯一的联系人注册名称
    func updateXname(contact: ContactInfo) {
        let sql = """
        update Contact set xname='\(contact.xname)' where kind=\(contact.kind) and xid=\(contact.xid)
"""
        objc_sync_enter(self)
        if (sqlite3_exec(db, sql.cString(using: String.Encoding.utf8)!, nil, nil, nil) == SQLITE_OK) {
        } else if (insertNewContact(contact: contact, printError: false)) {
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        objc_sync_exit(self)
    }
    
    //-- 更新联系人公开信息：包含 昵称/展示名、头像地址、头像本地存储路径、用户签名/群组公告
    func updatePublicInfo(contact: ContactInfo) {
        let sql = """
        update Contact set nickname='\(contact.nickname)', imgUrl='\(contact.imageUrl)', imgPath='\(contact.imagePath)', info='\(contact.showInfo)'
        where kind=\(contact.kind) and xid=\(contact.xid)
"""
        
        objc_sync_enter(self)
        if (sqlite3_exec(db, sql.cString(using: String.Encoding.utf8)!, nil, nil, nil) == SQLITE_OK) {
        } else if (insertNewContact(contact: contact, printError: false)) {
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        objc_sync_exit(self)
    }
    
    //-- 从数据库获取所有联系人信息，陌生人除外
    func loadContentInfos() -> [ContactInfo] {
        
        let sql = """
    select kind, xid, xname, nickname, imgUrl, imgPath, info from Contact where kind <> 0
"""
        var result: [ContactInfo] = []
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let info = ContactInfo()
                
                info.kind = Int(sqlite3_column_int(statement, 0))
                info.xid = sqlite3_column_int64(statement, 1)
                
                var chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 2))
                info.xname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 3))
                info.nickname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 4))
                info.imageUrl = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 5))
                info.imagePath = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 6))
                info.showInfo = String.init(cString: chars!)
                
                result.append(info)
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)
        return result
    }
    
    //-- 按类别从数据库获取所有陌联系人和好友信息
    func loadAllUserContactInfos() -> [Int64:ContactInfo] {
        
        let sql = """
    select kind, xid, xname, nickname, imgUrl, imgPath, info from Contact where kind in (0, 1)
"""
        var result: [Int64:ContactInfo] = [:]
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let info = ContactInfo()
                
                info.kind = Int(sqlite3_column_int(statement, 0))
                info.xid = sqlite3_column_int64(statement, 1)
                
                var chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 2))
                info.xname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 3))
                info.nickname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 4))
                info.imageUrl = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 5))
                info.imagePath = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 6))
                info.showInfo = String.init(cString: chars!)
                
                result[info.xid] = info
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)
        return result
    }
    
    //-- 从数据库获取特定联系人的信息
    func loadContentInfo(type:Int, uid:Int64) -> ContactInfo? {
        
        let sql = """
    select xname, nickname, imgUrl, imgPath, info from Contact where kind=\(type) and xid=\(uid)
"""
        var contact: ContactInfo? = nil
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let info = ContactInfo()
                
                info.kind = type
                info.xid = uid
                
                var chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 0))
                info.xname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 1))
                info.nickname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 2))
                info.imageUrl = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 3))
                info.imagePath = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 4))
                info.showInfo = String.init(cString: chars!)
                
                contact = info
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)
        return contact
    }
    
    //-- 从数据库获取特定联系人的信息
    func loadContentInfo(type:Int, xname:String) -> ContactInfo? {
        
        let sql = """
    select xid, nickname, imgUrl, imgPath, info from Contact where kind=\(type) and xname='\(xname)'
"""
        var contact: ContactInfo? = nil
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let info = ContactInfo()
                
                info.kind = type
                info.xname = xname
                
                info.xid = sqlite3_column_int64(statement, 0)
                
                var chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 1))
                info.nickname = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 2))
                info.imageUrl = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 3))
                info.imagePath = String.init(cString: chars!)
                
                chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 4))
                info.showInfo = String.init(cString: chars!)
                
                contact = info
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)
        return contact
    }
    
    //-- 从数据库获取特定联系人在本地存储的最新一条历史消息
    private func loadLastMessage(type: Int, xid: Int64) -> LastMessage {

        let sql = "select mid, message, mtime from message where kind=\(type) and xid=\(xid) and isCmd=0"
        var lastMessage = LastMessage()
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                lastMessage.mid = sqlite3_column_int64(statement, 0)
                
                let chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 1))
                lastMessage.message = String.init(cString: chars!)

                lastMessage.timestamp = sqlite3_column_int64(statement, 2)
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)
        
        return lastMessage
    }
    
    //-- 从数据库获取指定的联系人在本地存储的最新一条历史消息，并将结果以会话列表的形式返回
    func loadLastMessage(contactList: [ContactInfo]) -> [SessionItem] {
        
        var sessions = [SessionItem]()
        
        for contact in contactList {
            let sessionItem = SessionItem(contact: contact)
            sessionItem.lastMessage = loadLastMessage(type: contact.kind, xid: contact.xid)
            sessions.append(sessionItem)
        }

        return sessions
    }
    
    //-- 从数据库获取指定联系人在本地保存的所有历史聊天记录
    func loadAllMessages(contact:ContactInfo) -> [ChatMessage] {
        let sql = """
        select senderUid, mid, message, mtime, isCmd from message where kind=\(contact.kind) and xid=\(contact.xid) order by mtime asc
"""
        
        var messages = [ChatMessage]()
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let senderUid = sqlite3_column_int64(statement, 0)
                let mid = sqlite3_column_int64(statement, 1)
                
                let chars = UnsafePointer<CUnsignedChar>(sqlite3_column_text(statement, 2))
                let messageContent = String.init(cString: chars!)

                let mtime = sqlite3_column_int64(statement, 3)
                
                let message = ChatMessage(sender: senderUid, mid: mid, mtime: mtime, message: messageContent)
                if sqlite3_column_int(statement, 4) != 0 {
                    message.isChat = false
                }
                
                messages.append(message)
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)

        return messages
    }
    
    //-- 获取指定联系人所有的历史消息检查点信息
    func loadAllHistoryMessageCheckpoints(contact:ContactInfo) -> [HistoryCheckpoint] {
        let sql = """
        select ts, desc from checkpoint where kind=\(contact.kind) and xid=\(contact.xid)
"""
        
        var checkpoints = [HistoryCheckpoint]()
        var statement: OpaquePointer? = nil
        
        objc_sync_enter(self)
        
        if sqlite3_prepare_v2(db, sql.cString(using: String.Encoding.utf8)!, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                
                let checkpoint = HistoryCheckpoint()
                
                checkpoint.ts = sqlite3_column_int64(statement, 0)
                checkpoint.desc = (sqlite3_column_int(statement, 1) > 0) ? true : false
                
                checkpoints.append(checkpoint)
            }
        } else {
            if let error = String(validatingUTF8:sqlite3_errmsg(db)) {
                print("SQL execute failed. Error: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        objc_sync_exit(self)

        return checkpoints
    }
    
    //-- 清除指定联系人所有的历史消息检查点信息
    func clearAllHistoryMessageCheckpoints(contact:ContactInfo) {
        let sql = """
        delete from checkpoint where kind=\(contact.kind) and xid=\(contact.xid)
"""
        
        objc_sync_enter(self)
        _ = executeSQL(sql: sql)
        objc_sync_exit(self)
    }
}
