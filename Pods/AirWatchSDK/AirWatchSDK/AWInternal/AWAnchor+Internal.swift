//
//  AWUtlity+Internal.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers

internal let WorkspaceSchemeKey = "AWSDKWorkSpaceScheme"
internal let AgentSchemeKey = "AWSDKAgentScheme"

@objc
public class AWAnchor: NSObject {
    
    static let anchor = AirWatchAnchor(context: AWController.sharedInstance.context)

    static internal var customWorkspaceScheme: String? {
        guard let dictionary = SDKDefaultSettings.sharedSettings.plistDictionary else { return nil }
        return dictionary.object(forKey: WorkspaceSchemeKey) as? String
    }

    static internal var customAgentScheme: String? {
        guard let dictionary = SDKDefaultSettings.sharedSettings.plistDictionary else { return nil }
        return dictionary.object(forKey: AgentSchemeKey) as? String
    }

    @objc
    public static func canUseAnchor() -> Bool {
        return anchor.anchorScheme != nil
    }

    @objc
    public static func canUseAgent() -> Bool {
        return anchor.agentScheme != nil
    }
    
    public static func canUseWorkspace() -> Bool {
        return anchor.workspaceScheme != nil
    }
    
    static internal var isCurrentApplicationAirWatchApplication: Bool {
        return anchor.isAnchorApplication || anchor.isNonAnchorAirWatchApplication
    }
    
    static internal var commonAuthenticationGroup: String? {
        
        if let commonAuthGroupFromCommonIdentity =
            anchor.context.commonIdentity?.authorization?.authorizationGroup {
            return commonAuthGroupFromCommonIdentity
        }
        
        if let commonAuthGroup = anchor.context.commonAuthenticationGroup {
            return commonAuthGroup
        }
        
        guard AWAnchor.isCurrentApplicationAirWatchApplication == false else {
            return "com.air-watch.agent"
        }
        
        log(info: "no common authGroup found stored, generating one")
        guard let bundleID = Bundle.main.bundleIdentifier,
        let appIdentifierPrefix = anchor.appIdentifierPrefix
        else {
            log(error: "error generating appIdentifier prefix")
            return nil
        }
        let commonAuthenticationGrp = "\(appIdentifierPrefix).\(bundleID)"
        return commonAuthenticationGrp
    }
}
