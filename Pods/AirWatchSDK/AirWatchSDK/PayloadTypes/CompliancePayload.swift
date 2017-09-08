//
//  CompliancePayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 * @brief		Compliance payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the compliance group of an SDK profile.
 * @version     6.0
 */
@objc(AWCompliancePayload)
public class CompliancePayload: ProfilePayload {
    public static let kComplianceStatusKey: String = "com.airwatch.compliance.compromisedPolicy"

    /** A boolean indicating if compromised (jailbroken) devices should be prevented. */
    public fileprivate (set) var preventCompromisedDevices: Bool = false

    /** A boolean indicating if device restorations should be prevented. */
    public fileprivate (set) var preventRestoringBackupDevices: Bool = false

    /** An array of actions to be performed if the device is compromised. */
    public fileprivate (set) var preventCompromisedDevicesActions: NSArray = []

    /** A boolean indicating if compromised (jailbroken) devices should be prevented. */
    public fileprivate (set) var enableCompromisedProtection: Bool = false

    /** A string for the id of the compromised policy. */
    public fileprivate (set) var compromisedPolicyID: String?

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        
        guard dictionary["PayloadType"] as? String == CompliancePayloadConstants.kCompliancePayloadType else {
            log(error: "Failed to get Compliance Payload")
            return
        }
        self.preventCompromisedDevices ??= dictionary.bool(for: CompliancePayloadConstants.kComplianceCompromisedProtectionKey)
        self.enableCompromisedProtection = self.preventCompromisedDevices
        self.compromisedPolicyID = dictionary[CompliancePayloadConstants.kCompliancePolicyID] as? String
    }

    override public class func payloadType() -> String {
        return CompliancePayloadConstants.kCompliancePayloadType
    }
}
