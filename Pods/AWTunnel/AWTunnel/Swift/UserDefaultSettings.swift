//
//  UserDefaultSettings.swift
//  Garnet
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

/// A singleton wrapper around NSUserDefaults for ease in mocking and setting up
/// specific values for testing.
///
/// This also tightens up and secures the type specific getters to ensure that
/// the optional nature of nil values will be adhered to.

class UserDefaultSettings {
    // TODO: A constants class that will have all of the user defaults that we expect/want to see defined in one place?

    // TODO: Setup the defaults for user defaults.

    // MARK: - Public Methods
    /**
     Singleton accessor
     */
    static let sharedInstance = UserDefaultSettings()

    // MARK: Clearer
    /**
    Clear any value for key

    - Parameter key: to remove value for
    */
    func clearValue(_ key:String) {
        currentUserDefaults.removeObject(forKey: key)
    }

    /**
     Clear all known unsecure key
     */
    func clearAllKnownUnsecureItems() {
        for key in UnsecureItemType.allUnsecureItemTypeKeys {
            clearValue(key)
        }
    }

    // MARK: Getters
    /**
        Retrieve a non-null Bool

        - Parameter key: to retrieve from the standard user defaults
     */
    func boolForKey(_ key:String) -> Bool? {
        if let objectToReturn = objectForKey(key) {
            return (objectToReturn as? Bool)
        }
        return nil
    }

    /**
     Retrieve a non-null Double

     - Parameter key: to retrieve from the standard user defaults
     */
    func doubleForKey(_ key:String) -> Double? {
        if let objectToReturn = objectForKey(key) {
            return (objectToReturn as? Double)
        }
        return nil
    }

    /**
     Retrieve a non-null Float

     - Parameter key: to retrieve from the standard user defaults
     */
    func floatForKey(_ key:String) -> Float? {
        if let objectToReturn = objectForKey(key) {
            return (objectToReturn as? Float)
        }
        return nil
    }

    /**
     Retrieve a non-null Int

     - Parameter key: to retrieve from the standard user defaults
     */
    func integerForKey(_ key:String) -> Int? {
        if let objectToReturn = objectForKey(key) {
            return (objectToReturn as? Int)
        }
        return nil
    }

    /**
     Retrieve a possibly null AnyObject

     - Parameter key: to retrieve from the standard user defaults
     */
    func objectForKey(_ key:String) -> AnyObject? {
        return currentUserDefaults.object(forKey: key) as AnyObject?
    }

    /**
     Retrieve a non-null String

     - Parameter key: to retrieve from the standard user defaults
     */
    func stringForKey(_ key:String) -> String? {
        if let objectToReturn = objectForKey(key) {
            return (objectToReturn as? String)
        }
        return nil
    }

    /**
     Retrieve a non-null NSURL

     - Parameter key: to retrieve from the standard user defaults
     */
    func urlForKey(_ key:String) -> URL? {
        return (currentUserDefaults.url(forKey: key))
    }

    // MARK: Setter
    /**
     Set a non-null value
    
     - Parameter value: a non-null object to save as appropriate for the settingType
     - Parameter key: to save/retrieve this value with
     - Parameter settingType: the type of object that we're saving (defaults to Object)
    
     Returns success or failure to save
     */
    func setValue(_ value: Any,
                  forKey key:String,
                  withType settingType:SettingType = SettingType.object) -> Bool {
        switch settingType {
        case .bool:
            if (value is Bool) {
                currentUserDefaults.set(value as! Bool, forKey: key)
            } else {
                return false
            }
        case .double:
            if (value is Double) {
                currentUserDefaults.set(value as! Double, forKey: key)
            } else {
                return false
            }
        case .float:
            if (value is Float) {
                currentUserDefaults.set(value as! Float, forKey: key)
            } else {
                return false
            }
        case .integer:
            if (value is Int) {
                currentUserDefaults.set(value as! Int, forKey: key)
            } else {
                return false
            }
        case .nsDictionary:
            // UDS does not support this type
            return false
        case .url:
            if (value is URL) {
                currentUserDefaults.set((value as! URL), forKey: key)
            } else {
                return false
            }
        case .string:
            if !(value is String) {
                return false
            }
            // Explicitly fall through, as Strings are saved as objects
            fallthrough
        case .object:
            currentUserDefaults.set(value, forKey: key)
        }
        return currentUserDefaults.synchronize()
    }

    /**
     Helper method
     - Parameter: value to save
     - Parameter: key to use
     */
    func set(_ value: StorageType, forKey key:String) -> Bool {
        switch value {
        case .stBool(let object):
            return setValue(object, forKey: key, withType: SettingType.bool)
            
        case .stDouble(let object):
            return setValue(object, forKey: key, withType: SettingType.double)
            
        case .stFloat(let object):
            return setValue(object, forKey: key, withType: SettingType.float)
            
        case .stInt(let object):
            return setValue(object, forKey: key, withType: SettingType.integer)
            
        case .stString(let object):
            return setValue(object, forKey: key, withType: SettingType.string)
        
        case .sturl(let object):
            return setValue(object, forKey: key, withType: SettingType.url)
        
        case .stObject(let object):
            return setValue(object, forKey: key, withType: SettingType.object)
        default:
            // All other types are not supported
            return false
        }
    }

    // MARK: - Private
    // MARK: Properties
    /**
    Compute this value, so that it will always be current
    */
    fileprivate var currentUserDefaults : UserDefaults {
        get {
            return UserDefaults.standard
        }
    }

    // MARK: Methods
    /**
    Lock down the initializer
    */
    fileprivate init() {
        // To ensure that this cannot be  called accidentally
    }

}
