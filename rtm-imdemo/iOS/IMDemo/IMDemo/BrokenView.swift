//
//  BrokenView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct BrokenView: View {
    var info: String
    
    var body: some View {
        VStack {
            Text("连接断开")
                .font(.title)
            
            Text(info).padding()
            
            Button("确定") {
                IMCenter.viewSharedInfo.currentPage = .LoginView
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

struct BrokenView_Previews: PreviewProvider {
    static var previews: some View {
        BrokenView(info: "测试")
    }
}
