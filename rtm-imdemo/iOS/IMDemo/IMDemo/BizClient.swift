//
//  BizClient.swift
//  IMDemo
//
//  Created by 施王兴 on 2022/4/15.
//

import Foundation
import UIKit

struct UserLoginResponse: Codable {
    var pid: Int64
    var uid: Int64
    var token: String
}

struct CreateGroupResponse: Codable {
    var gid: Int64
}

struct CreateRoomResponse: Codable {
    var rid: Int64
}

struct FpnnErrorResponse: Codable {
    var code: Int
    var ex: String
}

struct LookupResponse: Codable {
    var users: [String:Int64]
    var groups: [String:Int64]
    var rooms: [String:Int64]
}

class BizClient {
    private class func checkUserChanged(loginName: String) {
        
        let oldName = IMCenter.fetchUserProfile(key: "username")
        var changed = false
        
        if oldName.isEmpty {
            IMCenter.storeUserProfile(key: "username", value: loginName)
            changed = false
        }
        
        if oldName != loginName {
            IMCenter.storeUserProfile(key: "username", value: loginName)
            changed = true
        }
        
        if changed {
            IMCenter.storeUserProfile(key: "nickname", value: "")
            IMCenter.storeUserProfile(key: "showInfo", value: "")
        }
    }
    
    class func createIMClient(userLoginInfo: UserLoginResponse, errorAction: @escaping (_ message: String) -> Void) {
 
        let client = RTMClient(endpoint: IMDemoConfig.RTMEndpoint, projectId: userLoginInfo.pid, userId: userLoginInfo.uid, delegate: IMCenter.imEventProcessor, config: nil, autoRelogin: true)

        IMCenter.client = client

        client?.login(withToken: userLoginInfo.token, language: nil, attribute: nil, timeout: 20, success: {
            IMCenter.RTMLoginSuccess()
        }, connectFail: { error in
            if (error != nil) {
                errorAction(error!.ex)
            } else {
                errorAction("未知错误！")
            }
        })
    }
    
    class func urlEncode(string: String) -> String {
        let encodeUrlString = string.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        return encodeUrlString ?? ""
    }
    
    class func login(username: String, password: String, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/userLogin?username=" + urlEncode(string: username) + "&pwd=" + urlEncode(string: password))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(UserLoginResponse.self, from: data!)
                    
                    checkUserChanged(loginName: username)
                    createIMClient(userLoginInfo: json, errorAction: errorAction)
                       
                } catch {
                    do {
                        let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                        errorAction(json.ex)
                    } catch {
                        errorAction("Error during JSON serialization: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        task.resume()
    }
    
    class func register(username: String, password: String, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/userRegister?username=" + urlEncode(string: username) + "&pwd=" + urlEncode(string: password))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(UserLoginResponse.self, from: data!)
                    
                    checkUserChanged(loginName: username)
                    createIMClient(userLoginInfo: json, errorAction: errorAction)
                       
                } catch {
                    do {
                        let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                        errorAction(json.ex)
                    } catch {
                        errorAction("Error during JSON serialization: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        task.resume()
    }
    
    class func createGroup(uniqueName: String, completedAction: @escaping (_ gid: Int64) -> Void, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/createGroup?uid=\(IMCenter.client!.userId)&group=" + urlEncode(string: uniqueName))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(CreateGroupResponse.self, from: data!)
                    completedAction(json.gid)
                } catch {
                    do {
                        let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                        errorAction(json.ex)
                    } catch {
                        errorAction("Error during JSON serialization: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        task.resume()
    }
    
    class func joinGroup(uniqueGroupName: String, completedAction: @escaping (_ gid: Int64) -> Void, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/joinGroup?uid=\(IMCenter.client!.userId)&group=" + urlEncode(string: uniqueGroupName))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(CreateGroupResponse.self, from: data!)
                    completedAction(json.gid)
                } catch {
                    do {
                        let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                        errorAction(json.ex)
                    } catch {
                        errorAction("Error during JSON serialization: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        task.resume()
    }

    class func dropGroup(uniqueName: String, gid:String, completedAction: @escaping () -> Void, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/dropGroup?gid=\(gid)&group=" + urlEncode(string: uniqueName))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                    errorAction(json.ex)
                } catch {
                    completedAction()
                }
            }
        })
        
        task.resume()
    }
    
    class func createRoom(uniqueName: String, completedAction: @escaping (_ rid: Int64) -> Void, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/createRoom?room=" + urlEncode(string: uniqueName))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(CreateRoomResponse.self, from: data!)
                    completedAction(json.rid)
                } catch {
                    do {
                        let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                        errorAction(json.ex)
                    } catch {
                        errorAction("Error during JSON serialization: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        task.resume()
    }
    
    class func dropRoom(uniqueName: String, rid:Int64, completedAction: @escaping () -> Void, errorAction: @escaping (_ message: String) -> Void) {
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/dropRoom?rid=\(rid)&room=" + urlEncode(string: uniqueName))!
        
        let task = URLSession.shared.dataTask(with:url, completionHandler:{
            (data, response, error) in
            
            if error != nil {
                errorAction("连接错误: \(error!.localizedDescription)")
            }
            if response != nil {
                do {
                    let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data!)
                    errorAction(json.ex)
                } catch {
                    completedAction()
                }
            }
        })
        
        task.resume()
    }

    private class func appendStringArray(str: inout String, array: [String], withKey: String) -> Void {
        
        str.append("\"")
        str.append(withKey)
        str.append("\":[")
        
        var requireComma = false
        
        for item in array {
            if requireComma {
                str.append(",\"")
            } else {
                requireComma = true
                str.append("\"")
            }
            
            str.append(item)
            str.append("\"")
        }
        
        str.append("]")
    }
    
    private class func appendInt64Array(str: inout String, array: [Int64], withKey: String) -> Void {
        
        str.append("\"")
        str.append(withKey)
        str.append("\":[")
        
        var requireComma = false
        
        for item in array {
            if requireComma {
                str.append(",")
            } else {
                requireComma = true
            }
            
            str.append(String(item))
        }
        
        str.append("]")
    }
    
    class func lookup(users:[String]?, groups:[String]?, rooms:[String]?, uids:[Int64]?, gids: [Int64]?, rids: [Int64]?, completedAction: @escaping (_ response: LookupResponse) -> Void, errorAction: @escaping (_ info: String) -> Void) {
        
        var requireComma = false
        var postJson = "{"
        
        if users != nil {
            appendStringArray(str: &postJson, array: users!, withKey: "users")
            requireComma = true
        }
        
        if groups != nil {
            if requireComma {
                postJson.append(",")
            } else {
                requireComma = true
            }
            appendStringArray(str: &postJson, array: groups!, withKey: "groups")
        }
        
        if rooms != nil {
            if requireComma {
                postJson.append(",")
            } else {
                requireComma = true
            }
            appendStringArray(str: &postJson, array: rooms!, withKey: "rooms")
        }
        
        if uids != nil {
            if requireComma {
                postJson.append(",")
            } else {
                requireComma = true
            }
            appendInt64Array(str: &postJson, array: uids!, withKey: "uids")
        }
        
        if gids != nil {
            if requireComma {
                postJson.append(",")
            } else {
                requireComma = true
            }
            appendInt64Array(str: &postJson, array: gids!, withKey: "gids")
        }
        
        if rids != nil {
            if requireComma {
                postJson.append(",")
            } else {
                requireComma = true
            }
            appendInt64Array(str: &postJson, array: rids!, withKey: "rids")
        }
        
        postJson.append("}")
        
        let url = URL(string:"http://" + IMDemoConfig.IMDemoServerEndpoint + "/service/lookup")!
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        request.httpBody = postJson.data(using: .utf8)    // postJson.percentEncoded()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                    errorAction("连接错误: \(error!.localizedDescription)")
                return
            }

            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                if response != nil {
                    errorAction("Error! Response: \(response!)")
                } else {
                    errorAction("Error! Response code: \(httpStatus.statusCode)")
                }
                return
            }

            // let responseString = String(data: data, encoding: .utf8)
            
            do {
                let json = try JSONDecoder().decode(LookupResponse.self, from: data)
                completedAction(json)
            } catch {
                do {
                    let json = try JSONDecoder().decode(FpnnErrorResponse.self, from: data)
                    errorAction(json.ex)
                } catch {
                    errorAction("Error during JSON serialization: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
}
