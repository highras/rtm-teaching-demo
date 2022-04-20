//
//  BottomNavigationView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct BottomNavigationView: View {
    var body: some View {
        HStack {
            
            Image("button_chat")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .onTapGesture {
                    IMCenter.viewSharedInfo.currentPage = .SessionView
                }
                .padding()
            
            Spacer()
            
            Divider()
            
            Spacer()
            
            Image("button_contact")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .onTapGesture {
                    IMCenter.viewSharedInfo.currentPage = .ContactView
                }
                .padding()
            
            Spacer()
            
            Divider()
            
            Spacer()
            
            Image("button_me")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:IMDemoUIConfig.navigationIconEdgeLen, height: IMDemoUIConfig.navigationIconEdgeLen, alignment: .center)
                .onTapGesture {
                    IMCenter.viewSharedInfo.currentPage = .ProfileView
                }
                .padding()
        }
    }
}

struct BottomNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        BottomNavigationView()
    }
}
