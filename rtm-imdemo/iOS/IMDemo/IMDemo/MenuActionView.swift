//
//  MenuActionView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct AddFriendView: View {
    @State private var username: String = ""
    @Binding var showProcessing: Bool
    @Binding var showError: Bool
    
    func checkInput() -> Bool {
        if username.isEmpty {
            let error = ErrorInfo(title: "无效的输入", desc: "用户名不能为空！")
            IMCenter.errorInfo = error
            
            return false
        }
        return true
    }
    
    var body: some View {
        
        VStack {
            Text("添加好友").font(.system(size: 20.0)).bold()
            
            HStack(alignment: .center){
                Spacer()
                Text("好友用户名:")
                    .padding()
                TextField("好友用户名", text: $username)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.75)
        
            Button("添加") {
                
                if !checkInput() {
                    showError = true
                    return
                }
                
                showProcessing = true
                IMCenter.addFriendInMainThread(xname: self.username, existAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                }, successAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                    IMCenter.db.storeNewContact(contact: contact)
                    IMCenter.addNewSessionByMenuActionInMainThread(contact: contact)
                    IMCenter.showDialogueView(contact: contact)
                    
                }, errorAction: {
                    errorInfo in
                    
                    IMCenter.errorInfo = errorInfo
                    
                    showProcessing = false
                    showError = true
                })
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct CreateGroupView: View {
    @State private var groupname: String = ""
    @Binding var showProcessing: Bool
    @Binding var showError: Bool
    
    func checkInput() -> Bool {
        if groupname.isEmpty {
            let error = ErrorInfo(title: "无效的输入", desc: "群组唯一名称不能为空！")
            IMCenter.errorInfo = error
            
            return false
        }
        return true
    }
    
    var body: some View {
        
        VStack {
            Text("创建群组").font(.system(size: 20.0)).bold()
            
            HStack(alignment: .center){
                Spacer()
                Text("群组唯一名:")
                    .padding()
                TextField("群组唯一名称", text: $groupname)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.75)
        
            Button("创建") {
                if !checkInput() {
                    showError = true
                    return
                }
                
                showProcessing = true
                IMCenter.createGroupInMainThread(xname: self.groupname, existAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                }, successAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                    IMCenter.db.storeNewContact(contact: contact)
                    IMCenter.addNewSessionByMenuActionInMainThread(contact: contact)
                    IMCenter.showDialogueView(contact: contact)
                    
                }, errorAction: {
                    errorInfo in
                    
                    IMCenter.errorInfo = errorInfo
                    
                    showProcessing = false
                    showError = true
                })
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct JoinGroupView: View {
    @State private var groupname: String = ""
    @Binding var showProcessing: Bool
    @Binding var showError: Bool
    
    func checkInput() -> Bool {
        if groupname.isEmpty {
            let error = ErrorInfo(title: "无效的输入", desc: "群组唯一名称不能为空！")
            IMCenter.errorInfo = error
            
            return false
        }
        return true
    }
    
    var body: some View {
        
        VStack {
            Text("加入群组").font(.system(size: 20.0)).bold()
            
            HStack(alignment: .center){
                Spacer()
                Text("群组唯一名:")
                    .padding()
                TextField("群组唯一名称", text: $groupname)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.75)
        
            Button("加入") {
                if !checkInput() {
                    showError = true
                    return
                }
                
                showProcessing = true
                IMCenter.joinGroupInMainThread(xname: self.groupname, existAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                }, successAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                    IMCenter.db.storeNewContact(contact: contact)
                    IMCenter.addNewSessionByMenuActionInMainThread(contact: contact)
                    IMCenter.showDialogueView(contact: contact)
                    
                }, errorAction: {
                    errorInfo in
                    
                    IMCenter.errorInfo = errorInfo
                    
                    showProcessing = false
                    showError = true
                })
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct CreateRoomView: View {
    @State private var roomname: String = ""
    @Binding var showProcessing: Bool
    @Binding var showError: Bool
    
    func checkInput() -> Bool {
        if roomname.isEmpty {
            let error = ErrorInfo(title: "无效的输入", desc: "房间唯一名称不能为空！")
            IMCenter.errorInfo = error
            
            return false
        }
        return true
    }
    
    var body: some View {
        
        VStack {
            Text("创建房间").font(.system(size: 20.0)).bold()
            
            HStack(alignment: .center){
                Spacer()
                Text("房间唯一名:")
                    .padding()
                TextField("房间唯一名称", text: $roomname)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.75)
        
            Button("创建") {
                if !checkInput() {
                    showError = true
                    return
                }
                
                showProcessing = true
                IMCenter.createRoomInMainThread(xname: self.roomname, existAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                }, successAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                    IMCenter.db.storeNewContact(contact: contact)
                    IMCenter.addNewSessionByMenuActionInMainThread(contact: contact)
                    IMCenter.showDialogueView(contact: contact)
                    
                }, errorAction: {
                    errorInfo in
                    
                    IMCenter.errorInfo = errorInfo
                    
                    showProcessing = false
                    showError = true
                })
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct EnterRoomView: View {
    @State private var roomname: String = ""
    @Binding var showProcessing: Bool
    @Binding var showError: Bool
    
    func checkInput() -> Bool {
        if roomname.isEmpty {
            let error = ErrorInfo(title: "无效的输入", desc: "房间唯一名称不能为空！")
            IMCenter.errorInfo = error
            
            return false
        }
        return true
    }
    
    var body: some View {
        
        VStack {
            Text("加入房间").font(.system(size: 20.0)).bold()
            
            HStack(alignment: .center){
                Spacer()
                Text("房间唯一名:")
                    .padding()
                TextField("房间唯一名称", text: $roomname)
                    .autocapitalization(.none)
                    .padding()
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.75)
        
            Button("加入") {
                if !checkInput() {
                    showError = true
                    return
                }
                
                showProcessing = true
                IMCenter.joinRoomInMainThread(xname: self.roomname, existAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                }, successAction: {
                    contact in
                    
                    showProcessing = false
                    IMCenter.viewSharedInfo.menuAction = .HideMode
                    
                    IMCenter.db.storeNewContact(contact: contact)
                    IMCenter.addNewSessionByMenuActionInMainThread(contact: contact)
                    IMCenter.showDialogueView(contact: contact)
                    
                }, errorAction: {
                    errorInfo in
                    
                    IMCenter.errorInfo = errorInfo
                    
                    showProcessing = false
                    showError = true
                })
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct ErrorHintView: View {
    
    var errorInfo: ErrorInfo
    var sureAction: () -> Void
    
    var body: some View {
        Color.gray.opacity(0.5).edgesIgnoringSafeArea(.all)
        Color.white.frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height * 0.24, alignment: .center).cornerRadius(20)
        
        VStack {
            Text(errorInfo.title)
                .font(.title)
            
            Text(errorInfo.desc).padding()
            
            Button("确定") {
                sureAction()
            }
            .frame(width: UIScreen.main.bounds.width/4,
            height: nil)
            .padding(10)
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(10)
        }
    }
}

struct MenuActionView: View {
    
    @State var showProcessing = false
    @State var showError = false
    @ObservedObject var viewInfo: ViewSharedInfo
    
    var body: some View {
        Color.gray.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture {
            IMCenter.viewSharedInfo.menuAction = .HideMode
        }
        Color.white.frame(width: UIScreen.main.bounds.width * 0.80, height: UIScreen.main.bounds.height * 0.22, alignment: .center).cornerRadius(20)
        
        if viewInfo.menuAction == .AddFriend {
            AddFriendView(showProcessing: self.$showProcessing, showError: self.$showError)
        } else if viewInfo.menuAction == .CreateGroup {
            CreateGroupView(showProcessing: self.$showProcessing, showError: self.$showError)
        } else if viewInfo.menuAction == .JoinGroup {
            JoinGroupView(showProcessing: self.$showProcessing, showError: self.$showError)
        } else if viewInfo.menuAction == .CreateRoom {
            CreateRoomView(showProcessing: self.$showProcessing, showError: self.$showError)
        } else if viewInfo.menuAction == .EnterRoom {
            EnterRoomView(showProcessing: self.$showProcessing, showError: self.$showError)
        }
        
        if self.showProcessing {
            ProcessingView(info: "处理中，请等待……")
        }
        
        if self.showError {
            ErrorHintView(errorInfo: IMCenter.errorInfo, sureAction: {
                self.showProcessing = false
                self.showError = false
            })
        }
    }
}

struct MenuActionView_Previews: PreviewProvider {
    static var previews: some View {
        MenuActionView(viewInfo: ViewSharedInfo())
    }
}
