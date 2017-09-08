//
//  StorageRequirements.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import CocoaLumberjack
import Foundation

/// This file is copied from Garnet.

/// HMAC Dictionary Keys to be stored in the keychain (see https://confluence.eng.vmware.com/pages/viewpage.action?pageId=144705700 for full details)
struct Const {
    struct HMACDict {
        static let Key = "AWHMACKey"
        static let AuthenticationGroup = "AWHMACAuthenticationGroup"
    }
}

// MARK: Known Secure ItemType
// MARK: Keychain ItemTypes for storage/retrieval

/**
Known Item Types for Keychain Storage/Retrieval
- AWServerURL
- AWAgentUDID
- AWHMAC -- this is the NSData of an NSDictionary with the keys from Const.HMACDict
- ClientID
- ClientSecret
- TempDeviceUUID
- OAuthAccessToken
- OAuthRefreshToken
*/
enum SecureItemType {
    case awServerURL
    case awAgentUDID
    case awhmac
    case awGroupID
    case clientID
    case clientSecret
    case tempDeviceUUID
    case oAuthAccessToken
    case oAuthRefreshToken
    case proxyMAGCertificate
    case f5SessionKey

    /**
     Computed property to return the appropriate account string for the keychain item

         https://confluence.eng.vmware.com/pages/viewpage.action?pageId=144705700

     - Returns:
        - the account name used for the keystore storage query
    */
    internal func accountName(_ isGarnet : Bool = true) -> String {
        switch self {
        case .awAgentUDID:
            return "com.air-watch.ios.application"
        case .awhmac:
            return "com.aw.common.hmac.account"
        case .awServerURL:
            return "AWApplicationServerURLAccount"
        case .awGroupID:
            return "kAWApplicationGroupIDAccount"
        case .proxyMAGCertificate:
            return "com.vmware.air-watch.tunnel.magcert"
        case .f5SessionKey:
            return "com.vmware.air-watch.tunnel.f5"
        default:
            return self.garnetPrefix(isGarnet) + "com.AW.GB.account"
        }
    }

    /**
     Computed property to return the appropriate service string for the keychain item
     
         https://confluence.eng.vmware.com/pages/viewpage.action?pageId=144705700

     - Returns:
        - the account name used for the keystore storage query
    */
    internal func serviceName(_ isGarnet : Bool = true) -> String {
        switch self {
        case .awServerURL:
            return "AWApplicationServerURLService"
        case .awAgentUDID:
            return "com.air-watch.ios.applicationUDID"
        case .awhmac:
            return "com.aw.common.hmac.service"
        case .awGroupID:
            return "kAWApplicationGroupIDService"
        case .clientID:
            return self.garnetPrefix(isGarnet) + "com.GB.client.id.service"
        case .clientSecret:
            return self.garnetPrefix(isGarnet) + "com.GB.client.secret.service"
        case .tempDeviceUUID:
            return self.garnetPrefix(isGarnet) + "com.GB.UUID.service"
        case .oAuthAccessToken:
            return self.garnetPrefix(isGarnet) + "com.GB.access.token.service"
        case .oAuthRefreshToken:
            return self.garnetPrefix(isGarnet) + "com.GB.refresh.token.service"
        case .f5SessionKey:
            fallthrough
        case .proxyMAGCertificate:
            return "com.vmware.air-watch.tunnelservice"
        }
    }

    /**
     Computed property to return all of the known accounts for Garnet
     */
    internal static var garnetAccountNames : [String] {
        return [SecureItemType.clientID.accountName()]
    }

    /**
     Computed property to return all of the known accounts for the shared keychain group of Airwatch apps
     */
    internal static var airwatchAccountNames : [String] {
        return [SecureItemType.awAgentUDID.accountName(),
            SecureItemType.awhmac.accountName()]
    }

    internal static var allSharedTypes:[SecureItemType] = [awAgentUDID, awhmac, awServerURL, awGroupID]
    internal static var safeToOverwriteSharedTypes:[SecureItemType] = [awhmac, awServerURL, awGroupID]

    /// Constant for converting back/forth between Garnet/Jade
    fileprivate func garnetPrefix(_ isGarnet : Bool) -> String {
        if (isGarnet) {
            return "com.air-watch.GB.Garnet-"
        }
        return ""
    }
}

// MARK: SettingType
// MARK: -  Retrieval Enums
/**
Setting Types for retrieving
- Bool - Boolean values
- Double - Double values
- Float - Float values
- Integer - Integer values
- NSDictionary - Dictionary that will be serialized into NSData using NSPropertyListSerialization
- Object - AnyObject? values
- String - String values
- URL - NSURL? values
*/
public enum SettingType {
    case bool, double, float, integer, nsDictionary, object, string, url
}

// MARK: StorageType
/**
Storage Type to store/retrieve strongly typed objects
- STBool - Boolean value
- STDictionary - NSDictoinary value
- STDouble - Double value
- STFloat - Float value
- STInt - Integer value
- STString - String value
- STURL - NSURL value
- STObject - catch all AnyObject values
*/

public enum StorageType {
    case stBool (Bool)
    case stDictionary (NSDictionary)
    case stDouble (Double)
    case stFloat (Float)
    case stInt (Int)
    case stString (String)
    case stData (Data)
    case sturl (URL)
    case stObject (AnyObject)

    /**
     init methods for the specific options
     */
    init(_ object : Bool) {
        self = .stBool(object)
    }

    init (_ object : NSDictionary) {
        self = .stDictionary(object)
    }
    
    init(_ object : Double) {
        self = .stDouble(object)
    }

    init (_ object : Float) {
        self = .stFloat(object)
    }

    init (_ object : Int) {
        self = .stInt(object)
    }

    init (_ object : String) {
        self = .stString(object)
    }

    init (_ object : Data) {
        self = .stData(object)
    }
    
    init (_ object : URL) {
        self = .sturl(object)
    }

    init (_ object : AnyObject) {
        self = .stObject(object)
    }

    /**
     Generic helper method to retrieve the associated value
     */
    func value<T>() -> T? {
        switch self {
        case .stBool(let object):
            return object as? T
        
        case .stDictionary(let object):
            return object as? T
        
        case .stDouble(let object):
            return object as? T
        
        case .stFloat(let object):
            return object as? T
        
        case .stInt(let object):
            return object as? T

        case .stData(let object):
            return object as? T
            
        case .stString(let object):
            return object as? T
        
        case .sturl(let object):
            return object as? T
        
        case .stObject(let object):
            return object as? T
        }
    }
}

// MARK: Class Extensions for StorageType
extension Bool {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension NSDictionary {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension Double {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension Float {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension Int {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension String {
    var storageType : StorageType {
        return StorageType(self)
    }
}

extension URL {
    var storageType : StorageType {
        return StorageType(self)
    }
}

// We cannot extend AnyObject

// MARK: StorageResult
/**
Storage Result for any storage operation
- Success - with an optional StorageType
- Failure - with an NSError
*/
public enum StorageResult {
    case success(StorageType?)
    case failure(NSError)

    /**
     Computed variable to raise the error for failure cases
     */
    var error : NSError? {
        switch self {
        case .success(_):
            return nil
        case .failure(let error):
            return error
        }
    }

    /**
     Computed variable to define whether the results are successful or not
     */
    var isSuccess : Bool {
        switch self {
        case .failure(_):
            return false
        default:
            return true
        }
    }

    /**
     Generic Helper method to retrieve the associated values on Success
     */
    func value<T>() -> T? {
        switch self {
        case .success(let stEnum):
            if (stEnum != nil) {
                return stEnum!.value() as T?
            }
            return nil
        default:
            return nil
        }
    }

}

/// SettingsStore accessor

/*
 Usage:

    let settings = Settings.store()

    var result : StorageResult
    result = settings.set(UnsecureItemType.UserEmailKey, value: "stored")
    result = settings.get(UnsecureItemType.UserEmailKey, valueType: .String)
    if let resultString : String = result.value() {
        debugPrint("resultString (\(resultString))")
    }
    result = settings.set("key", value: "updated")
    result = settings.clear("key")

    // Or
    result = settings.set(SecureItemTypes.OAuthAccessToken,
            value: "stored")
    result = settings.get(SecureItemTypes.OAuthAccessToken,
            valueType: .String)
    if let resultString : String = result.value() {
        debugPrint("resultString (\(resultString))")
    }
    result = settings.set(SecureItemTypes.OAuthAccessToken,
            value: "updated")
    result = settings.clear(SecureItemTypes.OAuthAccessToken)

 */

// MARK: Known Unsecure ItemType
// MARK: UserDefaultSettings ItemTypes for storage/retrieval

/**
Known Item Types for UserDefaultSettings
- ACE (App Configuration for Enterprise) Key
- First Run Key
- Greenbox URL Key
- Last Time Entered Background Key
- Rage Shake Setting determined by Settings bundle
- System Cancelled Key
- User Email Key
*/
enum UnsecureItemType : String {
    case AceKey = "com.apple.configuration.managed"
    case FirstRunKey = "com.GB.hasFirstRunCompleted"
    
    // GreenboxURLKey and LastTimeEnteredBackgroundKey are taken directly from v1.0 (Jade). These values
    // must match to seamlessly upgrade from Jade to Garnet
    case GreenboxURLKey = "GreenBoxServerURL"
    case LastTimeEnteredBackgroundKey = "timeStampOfLastUseOfApp"
    
    case RageShakeKey = "toggleRageShake"
    case SystemCancelledKey = "systemCancelledUnlockScreen"
    case UserEmailKey = "kSettingsKeyUserEmail"

    /// Computed property to deliver the key value for the enums
    internal var key : String {
        return "\(self.rawValue)"
    }

    /// Computed property to deliver a list of all keys
    internal static var allUnsecureItemTypeKeys : [String] {
        return [UnsecureItemType.AceKey.key,
            UnsecureItemType.FirstRunKey.key,
            UnsecureItemType.GreenboxURLKey.key,
            UnsecureItemType.LastTimeEnteredBackgroundKey.key,
            UnsecureItemType.SystemCancelledKey.key,
            UnsecureItemType.UserEmailKey.key]
    }
}

/// SettingsStore Access Container
struct Settings {
    static let store = SettingsImpl.sharedInstance
}

// MARK: SettingsStore protocol
/// Functionality required for any SettingsStore object
public protocol SettingsStore {
    /**
     Clear all known keys except the shared keychain values. This
     effectively executes a logout.
     - Returns: Result of the storage operation
     */
    @discardableResult
    func clearAll() -> StorageResult

    /**
     Clear secure keys other then the shared keychain items.
     - Returns: Result of the storage operation
     */
    @discardableResult
    func clearSecureKeys() -> StorageResult

    /**
     Clear all unsecure keys
     - Returns: Result of the storage operation
     */
    @discardableResult
    func clearAllUnsecureKeys() -> StorageResult
    
    /**
     Clear shared keys, except for UDID
     - Returns: Result of the storage operation
     */
    @discardableResult
    func clearSafeSharedKeys() -> StorageResult

    /**
     Clear all keys without prejudice.
     
     - Return: Success or Failure indicating the status of the wipe.
     */
    @discardableResult
    func wipeDevice() -> StorageResult

    /**
     Generic Helper Method to clear the value for a key
     - Parameter key: to clear
     */
    @discardableResult
    func clear<K>(_ key : K) -> StorageResult where K : Hashable
    
    /**
     Generic Helper Method to get the value for a key
     - Parameter key: to get
     - Parameter valueType: type of value to get or fail at
     */
    @discardableResult
    func get<K>(_ key : K, valueType: SettingType) -> StorageResult where K : Hashable
    
    /**
     Generic Helper Method to set/update the value for a key
     - Parameter key: to set
     - Parameter value: to set
     */
    @discardableResult
    func set<K,V>(_ key: K, value: V) -> StorageResult where K : Hashable, V : Any
}
