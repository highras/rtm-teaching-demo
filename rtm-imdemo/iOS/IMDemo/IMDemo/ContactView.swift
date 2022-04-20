//
//  ContactView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct ContactView: View {
    
    @ObservedObject var viewInfo: ViewSharedInfo
    
    var body: some View {
        ZStack {
            VStack {
                TopNavigationView(title: "联系人列表", icon: "button_add").frame(width: UIScreen.main.bounds.width, height: CGFloat(IMDemoUIConfig.topNavigationHight), alignment: .center)
                
                Divider()
                
                List {
                    Section("联系人") {
                        let friends = viewInfo.contactList[ContactKind.Friend.rawValue]!
                        
                        if friends.count > 0 {
                            ForEach (0..<friends.count) {
                                idx in
                                ContactItemView(contactInfo: friends[idx])
                            }
                        }
                    }
                    
                    Section("群组") {
                        let groups = viewInfo.contactList[ContactKind.Group.rawValue]!
                        
                        if groups.count > 0 {
                            ForEach (0..<groups.count) {
                                idx in
                                ContactItemView(contactInfo: groups[idx])
                            }
                        }
                    }
                    
                    Section("房间") {
                        let rooms = viewInfo.contactList[ContactKind.Room.rawValue]!
                        
                        if rooms.count > 0 {
                            ForEach (0..<rooms.count) {
                                idx in
                                ContactItemView(contactInfo: rooms[idx])
                            }
                        }
                    }
                }.listStyle(.plain)
                
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

struct ContactView_Previews: PreviewProvider {
    static var previews: some View {
        ContactView(viewInfo: ViewSharedInfo())
    }
}
