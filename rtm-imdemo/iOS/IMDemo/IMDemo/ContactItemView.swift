//
//  ContactItemView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct ContactItemView: View {
    
    var contactInfo: ContactInfo
    var lastMesssage: LastMessage? = nil
    
    var body: some View {
        HStack {
            
            if contactInfo.imagePath.isEmpty == false {
                Image(uiImage: IMCenter.loadUIIMage(path:contactInfo.imagePath))
                    .resizable()
                    .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                    .cornerRadius(10)
                
            } else if contactInfo.imageUrl.isEmpty {
                Image(IMDemoUIConfig.defaultIcon)
                    .resizable()
                    .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                    .cornerRadius(10)
                
            } else {
                AsyncImage(url: URL(string: contactInfo.imageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                .cornerRadius(10)
            }
            
            if self.lastMesssage == nil {
                Text(IMCenter.getContactDisplayName(contact: contactInfo))
            } else {
                VStack(alignment: .leading) {
                    Text(IMCenter.getContactDisplayName(contact: contactInfo))
                    Text(lastMesssage!.message).foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let unread = self.lastMesssage?.unread {
                if unread {
                    Image("button_mail")
                        .resizable()
                        .frame(width: IMDemoUIConfig.contactItemImageEdgeLen, height: IMDemoUIConfig.contactItemImageEdgeLen)
                        .cornerRadius(10)
                }
            }
            
        }.onTapGesture {
            IMCenter.showDialogueView(contact: contactInfo)
        }
    }
}

struct ContactItemView_Previews: PreviewProvider {
    static var previews: some View {
        ContactItemView(contactInfo: ContactInfo())
    }
}
