//
//  AuthenticationPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//
import Foundation

/**
 * @brief		Authentication payload that is contained in an 'AWProfile'.
 * @details     A profile payload that represents the authentication group of an SDK profile.
 * @version     6.0
 */
@objc(AWAuthenticationPayload)
public class AuthenticationPayload: ProfilePayload {

    //MARK: - Class Variables

    // The authentication type being used.
    public fileprivate (set)  var authenticationMethod: AWSDK.AuthenticationMethod = .none

    /**
     The minimum length of a passcode.
     **This only applies to passcodes**
     */
    public fileprivate (set) var minimumPasscodeLength: Int = 0

    /**
     The minimum complex characters a passcode must contain.
     **This only applies to passcodes.**
     */
    public fileprivate (set) var minimumComplexCharacters: Int = 0

    /**
     The maximum amount of days before a passcode expires and a new one must be set.
     A Value <= 0 is interpreted as no maximum passcode age
     */
    public fileprivate (set) var maximumPasscodeAge: Int = 0

    /**
     The amount of passcodes that must be unique before reusing one is allowed.
     **This only applies to passcodes.**
     */
    @available(*, deprecated: 6.0, message: "Use minimumUniquePasscodesBeforeReuse")
    public fileprivate (set) var passcodeHistory: Int {
        get {
            return self.minimumUniquePasscodesBeforeReuse
        }
        set {
            self.minimumUniquePasscodesBeforeReuse = newValue
        }
    }

    /**
     The amount of passcodes that must be unique before reusing one is allowed.
     **This only applies to passcodes.**
     */
    public fileprivate (set) var minimumUniquePasscodesBeforeReuse: Int = 0
    
    /**
     Amount of time the application can be unlocked without prompting for the passcode.
     **This applies to username / password & passcodes**
     */
    @available(*, deprecated: 6.0, message: "Use passcodeTimeout instead")
    public fileprivate (set) var gracePeriod: TimeInterval {
        get {
            return TimeInterval(self.passcodeTimeout)
        }
        set {
            self.passcodeTimeout = Int(newValue)
        }
    }

    /**
     Number of failed authentication attempts allowed before actions should be executed.
     **This applies to username / password & passcode.**
     */
    public fileprivate (set) var maximumFailedAttempts: Int = Int.max

    /**
     The idle time (in minute) before application will auto lock
     */
    @available(*, deprecated: 6.0, message: "Use passcodeTimeout instead")
    public fileprivate (set) var autoLockMinute: Int {
        get {
            return self.passcodeTimeout
        }
        set {
            self.passcodeTimeout = newValue
        }
    }

    /**
     Determine if device passcode level should be required.
     **This start being implemented in 6.4 to replace authenticationMethod = 1 (passcode)**
     */
    public fileprivate (set) var requirePasscode: Bool = false

    /**
     A boolean indicating if Single Sign-On is enabled.
     */
    public fileprivate (set) var enableSingleSignOn: Bool = false
    
    /**
     The assigned PasscodeMode to be used.
     */
    fileprivate var _passcodeMode: AWSDK.PasscodeMode = .off
    public fileprivate (set) var passcodeMode: AWSDK.PasscodeMode {
        get {
            switch authenticationMethod {
            case .none:
                return .off
            default:
                return _passcodeMode
            }
        }
        set {
            _passcodeMode = newValue
        }
    }
    
    /**
     A boolean indicating if simple passcodes are allowed to be used.
     */
    public fileprivate (set) var allowSimple: Bool = false
    
    /**
     Amount of time the application can be unlocked without prompting for the passcode.
     */
    public fileprivate (set) var passcodeTimeout: Int = Int.max
    public fileprivate (set) var policyId: String?

    @available(*, deprecated: 6.0, message: "all payloads are now V2")
    public fileprivate (set) var isV2: Bool = true

    /**
     A boolean indicating if Integrated Authentication is enabled.
     */
    public fileprivate (set) var enableIntegratedAuthentication: Bool = false   /**< A boolean indicating if Integrated Authentication is enabled. */

    /**
     An array of allowedSites.
     */
    public fileprivate (set) var allowedSites: [String] = []

    @available(*, deprecated: 6.0, message: "use toDictionary() instead")
    public var payloadDictionary: [String: AnyObject] {
        return super.toDictionary() as [String: AnyObject]
    }

    /**
     The assigned Biometric Method to be used.
     */
    fileprivate var _biometricMethod: AWSDK.BiometricMethod = .none
    public fileprivate (set) var biometricMethod: AWSDK.BiometricMethod {
        get {
            switch authenticationMethod {
            case .none:
                return .none
            default:
                return _biometricMethod
            }
        }
        set {
            _biometricMethod = newValue
        }
    }

    /// For constructing this payload in Objective-C UT. It should not be called for elsewhere
    convenience init() {
        self.init(dictionary: [:])        
    }

    //MARK: - Lifecycle
    public override init(dictionary: [String : Any]) {
        self.allowedSites = []
        super.init(dictionary: dictionary)

        let isAuthenticationPayload: Bool = dictionary["PayloadType"] as? String == AuthenticationPayloadConstants.kAuthenticationPayloadType
        let isAuthenticationPasscodeModeValid: Bool = dictionary[AuthenticationPayloadConstants.kAuthenticationPasscodeMode] != nil

        guard (isAuthenticationPayload || isAuthenticationPasscodeModeValid) else {
            return
        }

        if let authenticationTypeValue = dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationTypeKey) {
            self.authenticationMethod = AWSDK.AuthenticationMethod(rawValue: authenticationTypeValue) ?? authenticationMethod
        }

        if let passcodeModeValue = dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationPasscodeMode) {
            self.passcodeMode = AWSDK.PasscodeMode(rawValue:passcodeModeValue) ?? passcodeMode
        }

        self.requirePasscode = (self.passcodeMode != AWSDK.PasscodeMode.off) //if passcodeModeOff, dont require passcode

        self.allowSimple                       ??= dictionary.bool(for: AuthenticationPayloadConstants.kAuthenticationAllowSimple)
        self.minimumPasscodeLength             ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationMinimumPasscodeLenth)
        self.minimumComplexCharacters          ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationMinimumComplexChars)
        self.maximumPasscodeAge                ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationMaximumPasscodeAge)
        self.minimumUniquePasscodesBeforeReuse ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationMinimumUniquePasscodesBeforeReuse)
        self.maximumFailedAttempts             ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationMaximumFailedAttempts)
        self.policyId                            = dictionary[AuthenticationPayloadConstants.kAuthenticationPolicyId] as? String
        self.passcodeTimeout                   ??= dictionary.int(for: AuthenticationPayloadConstants.kAuthenticationPasscodeTimeout)

        self.enableSingleSignOn                ??= dictionary.bool(for: AuthenticationPayloadConstants.kAuthenticationSingleSignOnEnabled)
        self.enableIntegratedAuthentication    ??= dictionary.bool(for: AuthenticationPayloadConstants.kIntegratedAuthenticationEnabled)

        //Authentication timeout 0 should be interpreted as an infinite timeout
        //If an authentication timeout is set to 0, the SDK should not automatically timeout
        if self.passcodeTimeout <= 0 {
            self.passcodeTimeout = Int.max
        }
        if self.maximumFailedAttempts <= 0 {
            self.maximumFailedAttempts = Int.max
        }
        // a blank domain list still ends up with an empty value
        if let sites = dictionary[AuthenticationPayloadConstants.kIntegratedAutheAllowedSitesKey] as? [String] {
            self.allowedSites = sites.filter { $0 != "" }
        }

        if let bioMetricMethodIntValue: Int = dictionary.int(for: AuthenticationPayloadConstants.kBiometricModeKey) {
            self.biometricMethod = AWSDK.BiometricMethod(rawValue: bioMetricMethodIntValue) ?? biometricMethod
        }
    }

    override public class func payloadType() -> String {
        return AuthenticationPayloadConstants.kAuthenticationPayloadType
    }
}
