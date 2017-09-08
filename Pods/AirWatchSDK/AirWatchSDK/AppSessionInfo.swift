//
//  SessionInfo.swift
//  AWStorage
//
//  Created by Anuj Panwar on 1/11/17.
//  Copyright © 2017 VMware, Inc. All rights reserved.
//

import Foundation
import AWStorage


struct AppSessionInfo {

    let authetnicatedTimestamp: TimeInterval
    let validityPeriod: TimeInterval
    let sessionKey: Data
    
    init(authetnicatedTimestamp: TimeInterval, sessionKey: Data, validityPeriod: TimeInterval) {
        self.authetnicatedTimestamp = authetnicatedTimestamp
        self.validityPeriod = validityPeriod
        self.sessionKey = sessionKey
    }

    func isSessionValid() -> Bool {
        let validUntil = self.authetnicatedTimestamp + self.validityPeriod
        return Date().timeIntervalSince1970 < validUntil
    }

}

extension AppSessionInfo: DataRepresentable {

    enum Key: String {
        case authenticationTimeStamp    = "lastAuthenticationTimeStamp"
        case validityPeriod             = "period"
        case sessionKey                 = "sessionkey"
    }


    func toData() -> Data? {

        var dictionary: [String: AnyObject] = [:]
        dictionary[AppSessionInfo.Key.authenticationTimeStamp.rawValue] = Date(timeIntervalSince1970: self.authetnicatedTimestamp) as AnyObject
        dictionary[AppSessionInfo.Key.sessionKey.rawValue] = sessionKey as AnyObject
        dictionary[AppSessionInfo.Key.validityPeriod.rawValue] = NSNumber(value: Double(self.validityPeriod)) as AnyObject
        return (dictionary as NSDictionary).toData()
    }


    static func fromData(_ data: Data?) -> AppSessionInfo? {
        guard
            let dictionary = NSDictionary.fromData(data),
            let map  = dictionary as? [String: AnyObject]
        else {
            return nil
        }

        guard
            let authenticationTimeStamp = map[AppSessionInfo.Key.authenticationTimeStamp.rawValue] as? Date,
            let sessoinKey = map[AppSessionInfo.Key.sessionKey.rawValue] as? Data,
            let validityPeriod = map[AppSessionInfo.Key.validityPeriod.rawValue] as? NSNumber else {
                return nil
        }

        let info = AppSessionInfo(authetnicatedTimestamp: authenticationTimeStamp.timeIntervalSince1970, sessionKey: sessoinKey, validityPeriod: Double(validityPeriod))
        return info
    }

}


struct GlobalSessionTableEntry: DataRepresentable {

    enum MapKey: String {
        case PublicKey               = "publicKey"
        case EncryptedSessionData    = "encryptedSessionInfo"
        
    }
    
    let publicKey: SecKey
    let appSession: Data?

    init(publicKey: SecKey, encrypedSession: Data?) {
        self.publicKey = publicKey
        self.appSession = encrypedSession
    }
    

    func toData() -> Data? {
        var dictionary: [String: AnyObject] = [:]
       
        if let publicKeyData = Data.publicKeyData(publicKey) {
            dictionary[GlobalSessionTableEntry.MapKey.PublicKey.rawValue] = publicKeyData as AnyObject
        }
       
        if let encSessionInfo = self.appSession {
            dictionary[GlobalSessionTableEntry.MapKey.EncryptedSessionData.rawValue] = encSessionInfo as AnyObject
        }

        return (dictionary as NSDictionary).toData()
    }
    
    static func fromData(_ data: Data?) -> GlobalSessionTableEntry? {

        guard
            let dictionary = NSDictionary.fromData(data),
            let map  = dictionary as? [String: AnyObject]
        else {
            return nil
        }

        guard
            let publicKeyData = map[GlobalSessionTableEntry.MapKey.PublicKey.rawValue] as? Data,
            let publicKey = Data.secKeyRefFromPublicKeyData(publicKeyData)
            else {
            log(error: "Missing public key from global table entry")
            return nil
        }

        let encSessionInfo = map[GlobalSessionTableEntry.MapKey.EncryptedSessionData.rawValue] as? Data
        let sessionKeyStruct = GlobalSessionTableEntry(publicKey: publicKey, encrypedSession: encSessionInfo)
        return sessionKeyStruct
    }
    
}
