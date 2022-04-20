//
//  RegisterView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct RegisterView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var passwordAgain: String = ""
    
    @State private var alertTitle: String = ""
    @State private var errorMessage: String = ""
    @State private var showAlert = false
    @State private var showLoginingHint = false
    @State private var loginFailed = false
    
    func changeToLoginView() {
        IMCenter.viewSharedInfo.currentPage = .LoginView
    }
    
    func userRegister(){
        
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
        
        if passwordAgain.isEmpty {
            self.alertTitle = "无效输入"
            self.errorMessage = "确认密码不能为空！"
            self.showAlert = true
            
            return
        }
        
        if password != passwordAgain {
            self.alertTitle = "无效输入"
            self.errorMessage = "确认密码不匹配！"
            self.showAlert = true
            
            return
        }

        self.showLoginingHint = true
        
        BizClient.register(username: username, password: password, errorAction: {
                    (message) in
                    
                    self.showLoginingHint = false
                    self.errorMessage = message
                    self.loginFailed = true
                })
    }
    
    var body: some View {
        VStack(alignment: .center){
            Image(IMDemoUIConfig.defaultIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width/2, alignment: .center)
                .padding()
            
            HStack(alignment: .center){
                Spacer()
                Text("注册用户:")
                    .padding()
                TextField("注册用户名称", text: $username)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }
            HStack(alignment: .center){
                Spacer()
                Text("登陆密码:")
                    .padding()
                SecureField("登陆密码", text: $password)
                    .padding()
                Spacer()
            }
            HStack(alignment: .center){
                Spacer()
                Text("确认密码:")
                    .padding()
                SecureField("确认密码", text: $passwordAgain)
                    .padding()
                Spacer()
            }
            HStack(alignment: .center){
                Button("注 册"){
                    hideKeyboard()
                    userRegister()
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
                        Text("注册中，请等待....")
                            .font(.title)
                    
                        ProgressView()
                    }
                }
                .fullScreenCover(isPresented: $loginFailed, onDismiss: {
                    //-- Do nothing.
                }) {
                    VStack {
                        Text("注册失败")
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
                
                Button("登陆"){
                    changeToLoginView()
                }
                .padding(10)
                
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
}
