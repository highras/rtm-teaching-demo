//
//  LoginView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/13.
//

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    
    @State private var alertTitle: String = ""
    @State private var errorMessage: String = ""
    @State private var showAlert = false
    @State private var showLoginingHint = false
    @State private var loginFailed = false
    
    @State private var userImage: String
    
    init() {
        let username = IMCenter.fetchUserProfile(key: "username")
        self.userImage = IMCenter.fetchUserProfile(key: "\(username)-image")
    }
    
    func changeToRegisterView() {
        IMCenter.viewSharedInfo.currentPage = .RegisterView
    }
    
    func userLogin(){
        
        if username.isEmpty {
            
            self.alertTitle = "无效输入"
            self.errorMessage = "用户名不能为空！"
            self.showAlert = true
            
            return
        }
        
        if password.isEmpty {
            
            self.alertTitle = "无效输入"
            self.errorMessage = "用户密码不能为空！"
            self.showAlert = true
            
            return
        }
        
        self.showLoginingHint = true
        
        BizClient.login(username: username, password: password, errorAction: {
            (message) in
            
            self.showLoginingHint = false
            self.errorMessage = message
            self.loginFailed = true
        })
    }
    func usernameEditing(editing: Bool) {
        if editing == false {
            self.userImage = IMCenter.fetchUserProfile(key: "\(self.username)-image")
        }
    }
    
    var body: some View {
        VStack(alignment: .center){
            
            if self.userImage.isEmpty {
                Image(IMDemoUIConfig.defaultIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                    .padding()
            } else {
                Image(uiImage: IMCenter.loadUIIMage(path: self.userImage))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                    .padding()
            }
            
            HStack(alignment: .center){
                Spacer()
                Text("用户名:")
                    .padding()
                TextField("用户名", text: $username, onEditingChanged: usernameEditing)
                    .autocapitalization(.none)
                    .onAppear() {
                        self.username = IMCenter.fetchUserProfile(key: "username")
                    }
                    .padding()
                Spacer()
            }
            HStack(alignment: .center){
                Spacer()
                Text("密 码:")
                    .padding()
                SecureField("登陆密码", text: $password)
                    .padding()
                Spacer()
            }
            HStack(alignment: .center){
                Button("登 陆"){
                    hideKeyboard()
                    userLogin()
                }.frame(width: UIScreen.main.bounds.width/4,
                height: nil)
                .padding(10)
                .foregroundColor(.white)
                .background(.blue)
                .cornerRadius(10)
                .alert(alertTitle, isPresented: $showAlert) {
                    Button("确认") {
                        self.showAlert = false
                    }
                } message: {
                    Text(errorMessage)
                }
                .fullScreenCover(isPresented: $showLoginingHint, onDismiss: {
                    //-- Do nothing.
                }) {
                    VStack {
                        Text("登录中，请等待....")
                            .font(.title)
                    
                        ProgressView()
                    }
                }
                .fullScreenCover(isPresented: $loginFailed, onDismiss: {
                    //-- Do nothing.
                }) {
                    VStack {
                        Text("登录失败")
                            .font(.title)
                        
                        Text(errorMessage).padding()
                        
                        Button("确定") {
                            self.loginFailed = false
                        }
                        .frame(width: UIScreen.main.bounds.width/4,
                        height: nil)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(.blue)
                        .cornerRadius(10)
                    }
                }
                
                Button("注册"){
                    changeToRegisterView()
                }
                .padding(10)
                
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
