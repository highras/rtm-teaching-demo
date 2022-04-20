//
//  SessionView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct SessionView: View {
    
    @ObservedObject var viewInfo: ViewSharedInfo
    
    var body: some View {
        ZStack {
            VStack {
                TopNavigationView(title: "会话列表", icon: "button_add").frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.topNavigationHight), alignment: .center)
                
                Divider()
                
                List(viewInfo.sessions) { session in
                    
                    ContactItemView(contactInfo: session.contact, lastMesssage: session.lastMessage)
                }//.listStyle(.plain)
                
                Spacer()
                
                Divider()
                
                BottomNavigationView().frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.bottomNavigationHight), alignment: .center)
            }
            
            //-- ZStack Area
            if viewInfo.menuAction != .HideMode {
                MenuActionView(viewInfo: IMCenter.viewSharedInfo)
            }
        }
        
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(viewInfo: ViewSharedInfo())
    }
}
