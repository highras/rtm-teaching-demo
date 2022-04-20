//
//  ContactInfoView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct ContactInfoHeaderView: View {
    let title: String
    let backAction: ()-> Void
    let editAction: (_ editing: Bool)-> Void
    let canBeEdit: Bool
    
    @State private var editMode = false
    
    init(title: String, canBeEdit: Bool, backAction: @escaping ()->Void, editAction: @escaping (_ editing: Bool)->Void) {
        self.title = title
        self.backAction = backAction
        self.editAction = editAction
        self.canBeEdit = canBeEdit
    }
    
    var body: some View {
        HStack {
            Image("button_back")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                .onTapGesture {
                    backAction()
                }
 
            Spacer()
            
            Text(title).bold()
            
            Spacer()
            
            if canBeEdit {
                if editMode == false {
                    Image("button_edit")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                        .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                        .onTapGesture {
                            editMode = true
                            editAction(true)
                        }
                } else {
                    Image("button_ok")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                        .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                        .onTapGesture {
                            editMode = false
                            editAction(false)
                        }
                }
            }
        }
    }
}

struct ContactInfoView: View {
    var contact:ContactInfo
    let backAction: ()->Void
    
    @State private var editMode = false
    @State private var newNickname = ""
    @State private var newImageUrl = ""
    @State private var newShowInfo = ""
    
    @ObservedObject var viewInfo: ViewSharedInfo
    
    init(contct:ContactInfo, viewInfo: ViewSharedInfo, backAction: @escaping ()->Void) {
        self.contact = contct
        self.backAction = backAction
        
        self.newNickname = self.contact.nickname
        self.newImageUrl = self.contact.imageUrl
        self.newShowInfo = self.contact.showInfo
        
        self.viewInfo = viewInfo
    }
    
    func getXidTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "群组ID:"
        case ContactKind.Room.rawValue:
            return "房间ID:"
        default:
            return "用户ID:"
        }
    }
    
    func getXnameTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "群组注册名:"
        case ContactKind.Room.rawValue:
            return "房间注册名:"
        default:
            return "用户名:"
        }
    }
    
    func getNicknameTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "群组名称:"
        case ContactKind.Room.rawValue:
            return "房间名称:"
        default:
            return "用户昵称:"
        }
    }
    
    func getShowInfoTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "群组描述:"
        case ContactKind.Room.rawValue:
            return "房间描述:"
        default:
            return "用户签名:"
        }
    }
    
    func getNicknameHint() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "给群组取个名称"
        case ContactKind.Room.rawValue:
            return "给房间取个名称"
        default:
            return "给自己取个昵称"
        }
    }
    
    func getImageUrlTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "群组标志地址:"
        case ContactKind.Room.rawValue:
            return "房间标志地址:"
        default:
            return "头像地址:"
        }
    }
    
    func getImageUrlChangeTitle() -> String {
        switch self.contact.kind {
        case ContactKind.Group.rawValue:
            return "更改群组标志地址"
        case ContactKind.Room.rawValue:
            return "更改房间标志地址"
        default:
            return "更改头像地址"
        }
    }
    
    func updateCallback(imagePath: String) {
        if self.newNickname.isEmpty == false {
            self.contact.nickname = self.newNickname
        }
        
        if self.newShowInfo.isEmpty == false {
            self.contact.showInfo = self.newShowInfo
        }
        
        if imagePath.isEmpty == false {
            self.contact.imagePath = imagePath
        }
    }
    
    var body: some View {
        ZStack {
            
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack {
                ContactInfoHeaderView(title: IMCenter.getContactDisplayName(contact: contact), canBeEdit: (contact.kind == ContactKind.Group.rawValue || contact.kind == ContactKind.Room.rawValue), backAction: {
                    backAction()
                }, editAction: {
                    inEditing in
                    
                    self.editMode = inEditing
                    
                    
                    if inEditing == false {
                        self.viewInfo.inProcessing = true
                        
                        let newContact = ContactInfo()
                        newContact.kind = contact.kind
                        newContact.xid = contact.xid
                        newContact.xname = contact.xname
                        newContact.nickname = self.newNickname.isEmpty ? contact.nickname : self.newNickname
                        newContact.showInfo = self.newShowInfo.isEmpty ? contact.showInfo : self.newShowInfo
                        
                        if self.newImageUrl.isEmpty {
                            newContact.imageUrl = self.contact.imageUrl
                        } else {
                            newContact.imageUrl = self.newImageUrl
                        }
    
                        IMCenter.updateGroupOrRoomProfile(contact: newContact, orgImageUrl:self.contact.imageUrl, completedAction: updateCallback)
                    }
                })
                
                Divider()
                
                Spacer()
                
                if self.contact.imagePath.isEmpty == false {
                    Image(uiImage: IMCenter.loadUIIMage(path:contact.imagePath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                        .cornerRadius(10)
                        .padding()
                    
                } else if self.contact.imageUrl.isEmpty {
                    Image(IMDemoUIConfig.defaultIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                        .cornerRadius(10)
                        .padding()
                    
                } else {
                    AsyncImage(url: URL(string: contact.imageUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        ProgressView()
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                    .cornerRadius(10)
                    .padding()
                }
                
                LazyVGrid(columns:[GridItem(.fixed(UIScreen.main.bounds.width * 0.4)), GridItem()]) {
                    HStack {
                        Spacer()
                        
                        Text(getXidTitle())
                            .padding()
                    }
                    HStack {
                        Text(String(self.contact.xid))
                            .padding()
                        Spacer()
                    }
                    
                    
                    HStack {
                        Spacer()
                        Text(getXnameTitle())
                            .padding()
                    }
                    HStack {
                        Text(self.contact.xname)
                            .padding()
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Text(getNicknameTitle())
                            .padding()
                    }
                    HStack {
                        if self.editMode == false {
                            if self.contact.nickname.isEmpty {
                                Text(self.contact.xname)
                                    .padding()
                            } else {
                                Text(self.contact.nickname)
                                    .padding()
                            }
                            
                        } else {
                            TextField(self.contact.nickname.isEmpty ? getNicknameHint() : self.contact.nickname, text: $newNickname)
                                .autocapitalization(.none)
                                .frame(width: UIScreen.main.bounds.width/3,
                                height: nil)
                                .padding()
                        }
                        
                        Spacer()
                    }
                    
                    if self.editMode {
                        HStack {
                            
                            Spacer()
                            Text(getImageUrlTitle())
                                .padding()
                        }
                        HStack {
                            TextField(self.contact.imageUrl.isEmpty ? getImageUrlChangeTitle() : self.contact.imageUrl, text: $newImageUrl)
                                .autocapitalization(.none)
                                .frame(width: UIScreen.main.bounds.width/3,
                                height: nil)
                                .padding()
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text(getShowInfoTitle())
                            .padding()
                    }
                    HStack {
                        if self.editMode == false {
                            TextEditor(text: $newShowInfo).disabled(true)
                                    .padding()
                        } else {
                            TextEditor(text: $newShowInfo)
                                .frame(width: UIScreen.main.bounds.width/3,
                                height: 80)
                                .ignoresSafeArea(.keyboard)
                                .padding()
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary).opacity(0.5))
                        }
                        
                        Spacer()
                    }
                }
                            
                Spacer()
            }
            .onTapGesture {
                hideKeyboard()
            }
            
            //--------- processing view ----------//
            
            if self.viewInfo.inProcessing {
                ProcessingView(info: "更新中，请等待……")
            }
        }
    }
}

struct ContactInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ContactInfoView(contct: ContactInfo(), viewInfo: ViewSharedInfo(), backAction: {})
    }
}
