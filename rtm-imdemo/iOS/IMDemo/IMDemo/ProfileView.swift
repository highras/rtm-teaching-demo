//
//  ProfileView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct ProfileView: View {
    @State private var editMode = false
    @State private var newNickname = ""
    @State private var newImageUrl = ""
    @State private var newShowInfo = ""
    
    @ObservedObject var viewInfo: ViewSharedInfo
    
    @State private var userImagePath: String
    private var userImageUrl: String
    private var username: String
    @State private var nickname: String
    @State private var showInfo: String
    
    init(viewInfo: ViewSharedInfo) {
        self.viewInfo = viewInfo
        self.username = IMCenter.fetchUserProfile(key: "username")
        self.userImagePath = IMCenter.fetchUserProfile(key: "\(self.username)-image")
        self.userImageUrl = IMCenter.fetchUserProfile(key: "\(self.username)-image-url")
        self.nickname = IMCenter.fetchUserProfile(key: "nickname")
        self.showInfo = IMCenter.fetchUserProfile(key: "showInfo")
        
        self.newNickname = self.nickname
        self.newImageUrl = self.userImageUrl
        self.newShowInfo = self.showInfo
    }
    
    func updateCallback(imagePath: String) {
        if self.newNickname.isEmpty == false {
            self.nickname = self.newNickname
        }
        
        if self.newShowInfo.isEmpty == false {
            self.showInfo = self.newShowInfo
        }
        
        if imagePath.isEmpty == false {
            self.userImagePath = imagePath
            IMCenter.storeUserProfile(key: "\(self.username)-image-url", value: imagePath)
        }
    }
    
    var body: some View {
        ZStack {
        VStack {
            if self.editMode == false {
                TopNavigationView(title: "我的信息", icon: "button_edit", buttonAction: {
                    
                    self.editMode = true
                    
                }).frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.topNavigationHight), alignment: .center)
            } else {
                TopNavigationView(title: "修改我的信息", icon: "button_ok", buttonAction: {
                    
                    self.editMode = false
                    self.viewInfo.inProcessing = true
                    
                    if self.newNickname.isEmpty {
                        self.newNickname = self.nickname
                    }
                    
                    if self.newImageUrl.isEmpty {
                        self.newImageUrl = self.userImageUrl
                    }
                    
                    if self.newShowInfo.isEmpty {
                        self.newShowInfo = self.showInfo
                    }
                    
                    IMCenter.updateUserProfile(nickname: self.newNickname, imgUrl: self.newImageUrl, showInfo: self.newShowInfo, completedAction: updateCallback)
                    
                }).frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.topNavigationHight), alignment: .center)
            }
            
            
            Divider()
            
            Spacer()
            
            VStack {
                
                Spacer()
                
                if self.userImagePath.isEmpty {
                    Image(IMDemoUIConfig.defaultIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                        .padding()
                } else {
                    Image(uiImage: IMCenter.loadUIIMage(path: self.userImagePath))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                        .padding()
                }
                
                LazyVGrid(columns:[GridItem(.fixed(UIScreen.main.bounds.width * 0.4)), GridItem()]) {
                    HStack {
                        Spacer()
                        Text("用户ID:")
                            .padding()
                    }
                    HStack {
                        Text(String(IMCenter.client!.userId))
                            .padding()
                        Spacer()
                    }
                    
                    
                    HStack {
                        Spacer()
                        Text("用户名:")
                            .padding()
                    }
                    HStack {
                        Text(self.username)
                            .padding()
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Text("用户昵称:")
                            .padding()
                    }
                    HStack {
                        if self.editMode == false {
                            if self.nickname.isEmpty {
                                Text(self.username)
                                    .padding()
                            } else {
                                Text(self.nickname)
                                    .padding()
                            }
                            
                        } else {
                            TextField(self.nickname.isEmpty ? "给自己取个昵称" : self.nickname, text: $newNickname)
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
                            Text("头像地址:")
                                .padding()
                        }
                        HStack {
                            TextField(self.userImageUrl.isEmpty ? "更改头像地址" : self.userImageUrl, text: $newImageUrl)
                                .autocapitalization(.none)
                                .frame(width: UIScreen.main.bounds.width/3,
                                height: nil)
                                .padding()
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text("用户签名:")
                            .padding()
                    }
                    HStack {
                        if self.editMode == false {
                            TextEditor(text: $showInfo).disabled(true)
                                    .padding()
                        } else {
                            TextEditor(text: $showInfo)
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
                
                if self.editMode == false {
                    Button("退出登录") {
                        
                        DispatchQueue.global(qos: .default).async {
                            IMCenter.client!.closeConnect()
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width/4,
                    height: nil)
                    .padding(10)
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            
            Spacer()
            
            Divider()
            
            BottomNavigationView().frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.bottomNavigationHight), alignment: .center)
        }
        .onTapGesture {
            hideKeyboard()
        }
         
            if self.viewInfo.inProcessing {
                ProcessingView(info: "更新中，请等待……")
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(viewInfo: ViewSharedInfo())
    }
}
