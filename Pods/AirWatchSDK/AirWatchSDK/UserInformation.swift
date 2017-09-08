//
//  UserInformation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWStorage
import AWServices

extension CoderKeys {
    class UserInformation {
        static let username = "Username"
        static let userIdentifier = "userIdentifier"
        static let firstname = "firstname"
        static let lastname = "lastname"
        static let email = "email"
        static let domain = "domain"
        static let groupID = "groupCode"
    }
}

@objc(AWUserInformation)
public final class UserInformation: NSObject {
    public let userName: String
    public let userIdentifier: String
    public let firstName: String
    public let lastName: String
    public let email: String
    public let domain: String
    public let groupID: String

    init(username: String, userIdentifier: String, firstName: String, lastName: String, email: String, domain: String, groupID: String) {
        self.userName = username
        self.userIdentifier = userIdentifier
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.domain = domain
        self.groupID = groupID
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let rhs: UserInformation = object as? UserInformation else { return false }
        let result = (self.userName == rhs.userName && self.userIdentifier == rhs.userIdentifier &&
            self.firstName == rhs.firstName && self.lastName == rhs.lastName &&
            self.email == rhs.email && self.domain == rhs.domain && self.groupID == rhs.groupID)
        
        return result
    }
}

extension EnrolledUserInformation {
    var _UserInformation: UserInformation  {
        return UserInformation(username: self.userName, userIdentifier: self.userIdentifier, firstName: self.firstName, lastName: self.lastName, email: self.email, domain: self.domain, groupID: self.groupID)
    }

}

extension UserInformation: DataRepresentable {

    public func toData() -> Data? {
        var dict: [String: String] = [:]
        dict[CoderKeys.UserInformation.username] = self.userName
        dict[CoderKeys.UserInformation.userIdentifier] = self.userIdentifier
        dict[CoderKeys.UserInformation.firstname] = self.firstName
        dict[CoderKeys.UserInformation.lastname] = self.lastName
        dict[CoderKeys.UserInformation.email] = self.email
        dict[CoderKeys.UserInformation.domain] = self.domain
        dict[CoderKeys.UserInformation.groupID] = self.groupID
        guard let data = try? dict.propertyListDataFromDictionary() else {
            log(error: "Can not convert Userinformation to data")
            return nil
        }
        return data

    }

    public static func fromData(_ data: Data?) -> UserInformation? {
        guard let dictionaryData =  data else {
            log(info: "Empty user information")
            return nil
        }


        guard
            let dictionary = try? NSDictionary.dictionaryFromPlistData(dictionaryData),
            let userInfoDict = dictionary as? [String: String]
        else {
            log(error: "Can not convert provided user information to data")
            return nil
        }
        guard
            let username = userInfoDict[CoderKeys.UserInformation.username],
            let userIdentifier = userInfoDict[CoderKeys.UserInformation.userIdentifier],
            let firstname = userInfoDict[CoderKeys.UserInformation.firstname],
            let lastname = userInfoDict[CoderKeys.UserInformation.lastname],
            let email = userInfoDict[CoderKeys.UserInformation.email],
            let domain = userInfoDict[CoderKeys.UserInformation.domain],
            let groupID = userInfoDict[CoderKeys.UserInformation.groupID]
        else {
            log(error: "Missing or incomplete data while deserializing from data")
            return nil
        }

        return UserInformation(username: username, userIdentifier: userIdentifier, firstName: firstname, lastName: lastname, email: email, domain:  domain, groupID: groupID)
    }

}
