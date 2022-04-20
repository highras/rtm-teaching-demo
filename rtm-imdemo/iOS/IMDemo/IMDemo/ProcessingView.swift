//
//  ProcessingView.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/14.
//

import SwiftUI

struct ProcessingView: View {
    private var showInfo: String
    
    init(info: String) {
        self.showInfo = info
    }
    var body: some View {
        Color.gray.opacity(0.5).edgesIgnoringSafeArea(.all)
        Color.white.frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height * 0.16, alignment: .center).cornerRadius(20)
        VStack {
            Text(showInfo)
        
            ProgressView()
        }
    }
}

struct ProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        ProcessingView(info: "更新中，请等待……")
    }
}
