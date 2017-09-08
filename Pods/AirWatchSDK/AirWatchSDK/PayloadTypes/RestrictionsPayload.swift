//
//  RestrictionsPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/**
 * @brief		Access control payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the access control group of an SDK profile.
 * @version     6.0
 */
@objc(AWRestrictionsPayload)
public class RestrictionsPayload: ProfilePayload {

    /** A boolean indicating if Copy and Cut actions are allowed. */
    public fileprivate (set) var preventCopyPaste: Bool = false

    /** A boolean indicating if Copy and Cut actions are allowed. */
    @available(*, deprecated: 6.0, message: "preventCopyAndCut is deprecated, use preventCopyPaste instead")
    public fileprivate (set) var preventCopyAndCut: Bool {
        get {
            return preventCopyPaste
        }
        set {
            preventCopyPaste = newValue
        }
    }

    /** A boolean indicating whether to only allow open document in allowed list of app */
    public fileprivate (set) var restrictDocumentToApps: Bool = false

    /** A list of Apps that're allowed to open documents */
    public fileprivate (set) var allowedApplications: [String] = []
    
    /** A boolean indicating if printing is allowed. */
    public fileprivate (set) var printingEnabled: Bool = false

    /** A boolean indicating if data loss prevention is enabled. */
    public fileprivate (set) var enableDataLossPrevention: Bool = false

    /** A boolean indicating if watermark should be displayed on content that has watermark. */
    public fileprivate (set) var enableWatermark: Bool = false

    /** The string that indicate the watermark overlay on the content. */
    public fileprivate (set) var watermarkOverlay: String?

    public fileprivate (set) var enableMailComposing: Bool = false
    public fileprivate (set) var enableLocationReporting: Bool = false
    public fileprivate (set) var enableDataBackup: Bool = false
    public fileprivate (set) var enableCameraAccess: Bool = false

    /// For constructing this payload in UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])
    }

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        
        guard dictionary[RestrictionsPayloadConstants.kPayloadType] as? String == RestrictionsPayloadConstants.kRestrictionsPayloadType else {
            log(error: "Failed to get restriction payload")
            return
        }
        
        self.restrictDocumentToApps ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictDocumentsToApps)
        
        // a blank application list still ends up with count of 1
        if let apps = dictionary[RestrictionsPayloadConstants.kAllowedApplications] as? [String] {
            self.allowedApplications = apps.filter { $0 != "" }
        }
        
        
        if let allowCopyPaste = dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsPreventCopyAndCutKey) {///comes down as prevent copy paste so reverse it
            self.preventCopyPaste = !allowCopyPaste
        }
        
        
        self.printingEnabled ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnablePrinting)
        self.enableDataLossPrevention ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableDataLossPrevention)
        self.enableWatermark ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableWatermark)
        
        if self.enableWatermark {
            self.watermarkOverlay = dictionary[RestrictionsPayloadConstants.kRestrictionsWatermarkOverlay] as? String
        }
        
        self.enableMailComposing ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableEmailComposing)
        self.enableLocationReporting ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableLocationReporting)
        self.enableCameraAccess ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableCameraAccess)
        self.enableDataBackup ??= dictionary.bool(for: RestrictionsPayloadConstants.kRestrictionsEnableDataBackUp)
        
        log(debug: "RestrictionsPayload Created")
    }

    override public class func payloadType() -> String {
        return RestrictionsPayloadConstants.kRestrictionsPayloadType
    }
}
