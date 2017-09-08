//
//  AirWatchAnchor.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWStorage

let AppIdentifierPrefixForAirWatchApps = "Z7N7QHVWT2."

let WorkspaceBrokerSchemeV2 = "AWSSOBroker2"
let AgentSchemeV2 = "airwatch"
let WorkspaceOneOpenURLScheme = "awws1enroll"


final class AirWatchAnchor {
    
    var context: SDKContext
    init(context: SDKContext) {
        self.context = context
    }

    var canUseSharedData: Bool {
        if (self.isSharedDataAvailable || self.isSharedKeyChainSetup) {
            log(debug: "Shared Keychain from Agent is available.")
            return true
        }
        log(error: "Agent Did not setup Shared Keychain.")
        return false
    }

     var isSharedDataAvailable: Bool {
        return self.context.sharedDataAvailable
    }

     var isSharedKeyChainSetup: Bool {
        get {
            return self.context.sharedKeychainSetup
        }
        set {
            self.context.sharedKeychainSetup = newValue
        }
    }

     var anchorScheme: String? {
        get {

            if let schemeSetByAgent =  self.context.currentAnchorScheme {
                return schemeSetByAgent
            }

            if let resolvedScheme =  self.agentScheme ?? self.workspaceScheme {
                self.context.currentAnchorScheme = resolvedScheme
                return resolvedScheme
            }

            return nil
        }
        set {
            self.context.currentAnchorScheme = newValue
        }
    }



    var workspaceScheme: String? {
        guard SDKApplication.isExtension == false else { return nil }
        let containerScheme = AWAnchor.customWorkspaceScheme ?? WorkspaceBrokerSchemeV2

        if let containerURLScheme = URL(string: "\(containerScheme):") {
            if UIApplication.shared.canOpenURL(containerURLScheme) {
                return containerScheme
            }
        }
        return nil
    }

    var agentScheme: String? {
        guard SDKApplication.isExtension == false else { return nil }
        let agentScheme = AWAnchor.customAgentScheme ?? AgentSchemeV2
        if let agentURLScheme = URL(string: "\(agentScheme):") {
            if UIApplication.shared.canOpenURL(agentURLScheme) {
                return agentScheme
            }
        }
        return nil
    }
    
    var workspaceOneScheme: String? {
        if let workspace1URLScheme = URL(string: "\(WorkspaceOneOpenURLScheme):") {
            if UIApplication.shared.canOpenURL(workspace1URLScheme) {
                return WorkspaceOneOpenURLScheme
            }
            return nil
        }
        return nil
    }
    
    var isAnchorApplication: Bool {
        guard SDKApplication.isExtension == false else { return false }
        let airWatchAnchorApps: Set<String> = ["com.air-watch.agent",
                                               "com.air-watch.appcenter",
                                               "com.air-watch.awworkspace"]
        if let bundleId = Bundle.main.bundleIdentifier?.lowercased(),
            airWatchAnchorApps.contains(bundleId) {
            return true
        }
        return false
    }
    
    var isNonAnchorAirWatchApplication: Bool {
        
        //AirWatch apps need to add an entry with the specified key
        if let appIdentifierPrefix = Bundle.main.infoDictionary?["AWAppIdentifierPrefix"] as? String {
            return appIdentifierPrefix.lowercased() == AppIdentifierPrefixForAirWatchApps.lowercased()
        }
        log(debug:"AppIdentifier prefix entry is NOT present in info.plist")
        //try one last time
        if let appIdentifierPrefixString = self.appIdentifierPrefix {
            let appIdentifierPrefix = "\(appIdentifierPrefixString)."
            return appIdentifierPrefix.lowercased() == AppIdentifierPrefixForAirWatchApps.lowercased()
        }
        log(error: "error retrieving appidentifierPrefix to determine if it is an airwatch app")
        return false
    }
    
    var appIdentifierPrefix: String? {
        let keychainStore = AWKeychain()
        let account = "testAccount"
        let service = "testService"
        guard let dummyData = "dummyData".data(using: .utf8),
        keychainStore.set(account, key:  service, value: dummyData) else {
            log(error: "Error adding entry")
            return nil
        }
        var retrieveQuery = [ String(kSecClass) : kSecClassGenericPassword,
                              String(kSecAttrAccount) : account as AnyObject,
                              String(kSecAttrService) : service as AnyObject ]
        
        retrieveQuery[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        retrieveQuery[String(kSecReturnAttributes)] = true as AnyObject
        
        var data: AnyObject?
        let result: OSStatus = SecItemCopyMatching(retrieveQuery as CFDictionary, &data)
        if result != noErr { log(error: "AWKeychain retrieveQuery error code: \(result)") }
        _ = keychainStore.set(account, key: service, value: nil)
        
        guard let returnedDict = data as? Dictionary<String,AnyObject>
            else {
                return nil
        }
        guard let accessGrp = returnedDict[String(kSecAttrAccessGroup)] as? String else {
            log(error: "error: cannot retrive access grp")
            return nil
        }
        let accessGrpComponents = accessGrp.components(separatedBy: ".")
        guard accessGrpComponents.count > 1 else {
            log(error: "error: accessgrp does not have two components, weird 😳")
            return nil
        }
        return accessGrpComponents.first
    }
    
    var isAirWatchAnchorSchemeWhitelisted: Bool {
        if let whitelistedSchemes: [String] = Bundle.main.infoDictionary?["LSApplicationQueriesSchemes"]
            as? [String] {
            let lowercasedWhitelistedSchemes = Set(whitelistedSchemes.map { $0.lowercased()})
            let AirWatchAnchorSchemes: Set<String> = [WorkspaceOneOpenURLScheme.lowercased(),
                                                      AgentSchemeV2.lowercased(),
                                                      WorkspaceBrokerSchemeV2.lowercased()]
            return AirWatchAnchorSchemes.intersection(lowercasedWhitelistedSchemes).isEmpty == false
        }
        return false
    }

}
