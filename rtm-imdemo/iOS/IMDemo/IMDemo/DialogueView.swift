//
//  DialogueView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct DialogueHeaderView: View {
    let title: String
    let infoAction: ()-> Void
    
    init(title: String, infoAction: @escaping ()->Void) {
        self.title = title
        self.infoAction = infoAction
    }
    
    func updateSessionState() {
        for session in IMCenter.viewSharedInfo.sessions {
            if session.contact.kind == IMCenter.viewSharedInfo.targetContact!.kind && session.contact.xid == IMCenter.viewSharedInfo.targetContact!.xid {
                session.lastMessage.unread = false
                
                for idx in 0..<IMCenter.viewSharedInfo.dialogueMesssages.count {
                    let realIdx = IMCenter.viewSharedInfo.dialogueMesssages.count - 1 - idx
                    if IMCenter.viewSharedInfo.dialogueMesssages[realIdx].isChat {
                        
                        let message = IMCenter.viewSharedInfo.dialogueMesssages[realIdx]
                        session.lastMessage.message = message.message
                        session.lastMessage.mid = message.mid
                        session.lastMessage.timestamp = message.mtime
                        
                        let oldSessions = IMCenter.viewSharedInfo.sessions
                        IMCenter.viewSharedInfo.sessions = IMCenter.sortSessions(sessions: oldSessions)
                        
                        return
                    }
                }
                
                session.lastMessage.message = ""
                session.lastMessage.mid = 0
                session.lastMessage.timestamp = 0
                
                let oldSessions = IMCenter.viewSharedInfo.sessions
                IMCenter.viewSharedInfo.sessions = IMCenter.sortSessions(sessions: oldSessions)
                
                return
            }
        }
    }
    
    var body: some View {
        HStack {
            Image("button_back")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                .onTapGesture {
                    updateSessionState()
                    
                    IMCenter.viewSharedInfo.currentPage = IMCenter.viewSharedInfo.lastPage
                }
 
            Spacer()
            
            Text(title).bold()
            
            Spacer()
                
            Image("button_info")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                .onTapGesture {
                    infoAction()
                }
        }
    }
}

struct DialogueFooterView: View {
    @State private var message: String = ""
    
    @ObservedObject var viewInfo: ViewSharedInfo
    var contact: ContactInfo
    
    var body: some View {
        HStack {
            TextField("说点什么吧……", text: $message)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Image("button_send")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                .onTapGesture {
                    
                    IMCenter.viewSharedInfo.newMessageReceived = false
                    
                    if self.message.isEmpty {
                        viewInfo.newestMessage = IMCenter.viewSharedInfo.dialogueMesssages.last!
                        hideKeyboard()
                        return
                    }
                    
                    IMCenter.sendMessage(contact: contact, message: self.message)
                    self.message = ""
                    
                    hideKeyboard()
                    viewInfo.newestMessage = IMCenter.viewSharedInfo.dialogueMesssages.last!
                }
        }
    }
}

struct DialogueCmdItemView: View {
    private var message: ChatMessage
    
    init(message:ChatMessage) {
        self.message = message
    }
    
    func getTimeString() -> String {
        
        let dateFormatter = DateFormatter()
        let now = Date().timeIntervalSince1970
        
        if Int64(now) - self.message.mtime/1000 < 4 * 3600 {    //-- 4 个小时前显示日期部分
            dateFormatter.dateFormat = "HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        
       return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(self.message.mtime)/1000))
    }
    
    func buildShowInfo() ->String {
        let info = "\(getTimeString())\n\(self.message.message)"
        return info
    }
    
    var body: some View {
        HStack {
        
                Spacer()
                
                Text(buildShowInfo()).font(.system(size: 12)).foregroundColor(.gray)
            
                Spacer()
            
        }
    }
}

struct DialogueItemView: View {
    private var contact: ContactInfo
    private var message: ChatMessage
    private var isSelf: Bool
    private var infoAction: (_ contact: ContactInfo)->Void
    
    
    init(cotact:ContactInfo, message:ChatMessage, isSelf: Bool, infoAction: @escaping (_ contact: ContactInfo)->Void) {
        self.contact = cotact
        self.message = message
        self.isSelf = isSelf
        self.infoAction = infoAction
    }
    
    func getTimeString() -> String {
        
        let dateFormatter = DateFormatter()
        let now = Date().timeIntervalSince1970
        
        if Int64(now) - self.message.mtime/1000 < 4 * 3600 {    //-- 4 个小时前显示日期部分
            dateFormatter.dateFormat = "HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        
       return dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(self.message.mtime)/1000))
    }
    
    var body: some View {
        HStack {
            if isSelf {
                Spacer()
                
                Text(getTimeString()).font(.system(size: 12)).foregroundColor(.gray)
                
                Text(self.message.message).padding(10)
                    .background(.cyan)
                    .cornerRadius(10)
            }
            
            if contact.imagePath.isEmpty == false {
                Image(uiImage: IMCenter.loadUIIMage(path:contact.imagePath))
                    .resizable()
                    .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                    .cornerRadius(10)
                    .onTapGesture {
                        infoAction(contact)
                    }
                
            } else if contact.imageUrl.isEmpty {
                Image(IMDemoUIConfig.defaultIcon)
                    .resizable()
                    .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                    .cornerRadius(10)
                    .onTapGesture {
                        infoAction(contact)
                    }
                
            } else {
                AsyncImage(url: URL(string: contact.imageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                .cornerRadius(10)
                .onTapGesture {
                    infoAction(contact)
                }
            }
            
            if self.isSelf == false {
                Text(self.message.message).padding(10)
                    .background(.mint)
                    .cornerRadius(10)
                
                Text(getTimeString()).font(.system(size: 12)).foregroundColor(.gray)
            
                Spacer()
            }
            
        }
    }
}

struct DialogueView: View {
    private var contact: ContactInfo
    private var selfId: Int64
    
    @ObservedObject var viewInfo: ViewSharedInfo
    @State var showInfoPage = false
    @State var contactForInfoPage: ContactInfo
    
    init() {
        self.contact = IMCenter.viewSharedInfo.targetContact!
        self.selfId = IMCenter.client!.userId
        self.viewInfo = IMCenter.viewSharedInfo
        self.contactForInfoPage = self.contact
    }
    
    var body: some View {
        ZStack {
            VStack {
                DialogueHeaderView(title: IMCenter.getContactDisplayName(contact: contact), infoAction: {
                    self.showInfoPage = true
                })
                
                Divider()
                
                ScrollViewReader { scrollViewReader in
                    
                    ScrollView {
                        
                        ForEach(viewInfo.dialogueMesssages) {
                            chatMessage in
                            
                            if chatMessage.isChat {
                                DialogueItemView(cotact: IMCenter.findContact(chatMessage: chatMessage), message: chatMessage, isSelf: (chatMessage.sender == selfId), infoAction: {
                                    contact in
                                    self.contactForInfoPage = contact
                                    self.showInfoPage = true
                                })
                            } else {
                                DialogueCmdItemView(message: chatMessage)
                            }
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width)
                    .onReceive(viewInfo.$newestMessage) {
                        sentMesssage in
                        if sentMesssage.mtime != 0 {
                            scrollViewReader.scrollTo(sentMesssage.id)
                        }
                    }
                    .onAppear {
                        if IMCenter.viewSharedInfo.dialogueMesssages.last != nil {
                            viewInfo.newestMessage = IMCenter.viewSharedInfo.dialogueMesssages.last!
                        }
                    }
                }
                
                Spacer()
                
                Divider()
                
                DialogueFooterView(viewInfo: viewInfo, contact: contact)
            }
            //-- ZStack Area
            
            if self.viewInfo.newMessageReceived {
                HStack {
                    Spacer()
                    
                    Image("button_received")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                        .padding()
                        .onTapGesture {
                            viewInfo.newMessageReceived = false
                            hideKeyboard()
                            viewInfo.newestMessage = IMCenter.viewSharedInfo.dialogueMesssages.last!
                        }
                }
            }
            
            //-- ZStack Area

            if self.showInfoPage {
                ContactInfoView(contct: self.contactForInfoPage, viewInfo: IMCenter.viewSharedInfo, backAction: {
                    self.contactForInfoPage = self.contact
                    self.showInfoPage = false
                })
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

struct DialogueView_Previews: PreviewProvider {
    static var previews: some View {
        DialogueView()
    }
}
