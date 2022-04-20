//
//  TopNavigationView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct TopNavigationView: View {
    let title: String
    let cornerIcon: String
    let buttonAction: ()-> Void
    let enableMenu: Bool
    
    init(title: String, icon: String) {
        self.title = title
        self.cornerIcon = icon
        self.buttonAction = {}
        self.enableMenu = true
    }
    
    init(title: String, icon: String, buttonAction action: @escaping ()->Void) {
        self.title = title
        self.cornerIcon = icon
        self.buttonAction = action
        self.enableMenu = false
    }
    var body: some View {
        HStack {
 
            Spacer()
            
            Text(title).position(x: UIScreen.main.bounds.width/2, y: IMDemoUIConfig.topNavigationHight/2)
            
            if self.enableMenu {
                Menu {
                    Section{
                        Button("添加联系人", action:{
                            IMCenter.viewSharedInfo.menuAction = .AddFriend
                        })
                    }
                    Section{
                        Button("创建群组", action:{
                            IMCenter.viewSharedInfo.menuAction = .CreateGroup
                        })
                        Button("加入群组", action:{
                            IMCenter.viewSharedInfo.menuAction = .JoinGroup
                        })
                    }
                    Section{
                        Button("创建房间", action:{
                            IMCenter.viewSharedInfo.menuAction = .CreateRoom
                        })
                        Button("加入房间", action:{
                            IMCenter.viewSharedInfo.menuAction = .EnterRoom
                        })
                    }
                } label: {
                    Image(cornerIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                        .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                }
            } else {
                Image(cornerIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                    .padding((IMDemoUIConfig.topNavigationHight - IMDemoUIConfig.navigationIconEdgeLen)/2)
                    .onTapGesture {
                        buttonAction()
                    }
            }
        }
    }
}

struct TopNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        TopNavigationView(title:"test page", icon: "button_info")
    }
}
