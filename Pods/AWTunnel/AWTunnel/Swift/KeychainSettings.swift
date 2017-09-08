//
//  KeychainSettings.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWError


/// This file is copied from Garnet

// MARK: Internal Keychain Methods Results

/**
Keychain Result Types
- Success - Success with optional Generic result
- Failure - Failure results are associated with an NSError value
*/
enum KeychainResults<T> {
    case success(T?)
    case failure(NSError)

    /// Helper dynamic variable to roll the success into a Bool that can be if-tested
    var isSuccess: Bool {
        switch self {
        case .failure(_):
            return false
        default:
            return true
        }
    }

    /// Access the error for Failure, nil otherwise
    func resultError() -> NSError? {
        switch self {
        case .failure(let errorToReturn):
            return errorToReturn
        default:
            return nil
        }
    }

    /// Access the string for Success, nil otherwise
    func resultString() -> String? {
        switch self {
        case .success(let valueToReturn):
            return valueToReturn as? String
        default:
            return nil
        }
    }

    // Access the data for Success, nil otherwise
    func resultData() -> Data? {
        switch self {
        case .success(let valueToReturn):
            return valueToReturn as? Data
        default:
            return nil
        }
    }

    func resultDictionary() -> NSDictionary? {
        switch self {
        case .success(let valueToReturn):
            return valueToReturn as? NSDictionary
        default:
            return nil
        }
    }

    // Helper function to pull out the
    func value() -> T? {
        switch self {
        case .success(let valueToReturn):
            return valueToReturn
        default:
            return nil
        }
    }
}

/// A singleton wrapper around low level keychain calls such as SecItemAdd,
/// SecItemCopyMatching, SecItemDelete, and SecItemUpdate. For this project
/// we assume that all keychain items will require a pincode.

class KeychainSettings {
    // --------------- PUBLIC ---------------
    // MARK: - Public Section

    /// Definition of dictionary type used in querying, setting, or retrieving
    /// data from the keychain
    typealias AttributeDictionary = [String:AnyObject]

    // MARK: Public Properties
    // MARK: sharedInstance
    /**
    Singleton accessor
    */
    static let sharedInstance = KeychainSettings(OthersShouldNotCallDirectly: true)!

    // MARK: Public Methods
    /**
     Import the Jade keychain values into Garnet
     */
    func importJadeKeychainValues() -> KeychainResults<String> {
        var didFail = false
        var lastError: NSError?

        // All known keychain items
        let allKnownKeychainItems = [SecureItemType.clientID, .clientSecret, .tempDeviceUUID,
            .oAuthAccessToken, .oAuthRefreshToken]

        for keychainItem in allKnownKeychainItems {
            let accountNameJade = keychainItem.accountName(false)
            let serviceNameJade = keychainItem.serviceName(false)
            let accountNameGarnet = keychainItem.accountName()
            let serviceNameGarnet = keychainItem.serviceName()
            let jadeGetResult: LowlevelKeychainResults = self.dataForQuery(accountNameJade, service: serviceNameJade)
            if  jadeGetResult.isSuccess() {
                let garnetSetResult = self.setDataForQuery(jadeGetResult.resultData()!,
                    account: accountNameGarnet,
                    service: serviceNameGarnet,
                    accessibleValue: self.accessibleValueForKnownItem(keychainItem))
                if (garnetSetResult.isSuccess() == false) {
                        didFail = true
                        lastError = garnetSetResult.resultError()!
                }

                // Let's clear the jade keychain item once we imported them
                clearAllDataForQuery(accountNameJade, service: serviceNameJade)
            }
        }

        if (didFail) {
            return KeychainResults.failure(lastError!)
        }

        return KeychainResults.success(nil)
    }

    /**
     Clear keychain data for a known SecureItemType.

     - Parameters:
        - itemType: to clear
     */
    func clearValue(_ itemType: SecureItemType) -> KeychainResults<String> {
        let clearStatus = clearAllDataForQuery(itemType.accountName(),
            service: itemType.serviceName())
        if (clearStatus.isSuccess() == false) {
            return KeychainResults.failure(clearStatus.resultError()!)
        }
        return KeychainResults.success(nil)
    }

    /**
     Clear all keychain data for all known Secure Items managed by Garnet and shared with productivity apps

     - Returns: the result from the keycahin modification
     */
    func clearSharedKnownSecureItems() -> KeychainResults<String> {
        var isFailure = false
        var lastFailure: NSError?

        for key in SecureItemType.allSharedTypes {
            let clearStatus = clearAllDataForQuery(key.accountName(), service: key.serviceName())
            if (clearStatus.isSuccess() == false) {
                log(error: "Unable to clear data for account (\(key.accountName()) for service (\(key.serviceName()))) : <\(clearStatus.resultError())>")
                isFailure = true
                lastFailure = clearStatus.resultError()!
            }
        }

        if (isFailure) {
            return KeychainResults.failure(lastFailure!)
        } else {
            return KeychainResults.success(nil)
        }
    }

    /**
     Clear safe to overwrite keychain data for all known Secure Items managed by Garnet and shared with productivity apps

     The current exception from total clear is shared Device UDID

     - Returns: the result from the keycahin modification
     */
    func safelyClearSharedKnownSecureItems() -> KeychainResults<String> {
        var isFailure = false
        var lastFailure: NSError?

        for key in SecureItemType.safeToOverwriteSharedTypes {
            let serviceName = key.serviceName()
            let clearStatus = clearAllDataForQuery(nil, service: serviceName)
            if (clearStatus.isSuccess() == false) {
                log(error: "Unable to clear data for account (\(serviceName)) : <\(clearStatus.resultError())>")
                isFailure = true
                lastFailure = clearStatus.resultError()!
            }
        }

        if (isFailure) {
            return KeychainResults.failure(lastFailure!)
        } else {
            return KeychainResults.success(nil)
        }
    }

    /**
     Clear all keychain data for all known Secure Items managed by Garnet and not shared with productivity apps

     - Returns: the result from the keycahin modification
     */
    func clearNonsharedKnownSecureItems() -> KeychainResults<String> {
        var isFailure = false
        var lastFailure: NSError?
        for accountName in SecureItemType.garnetAccountNames {
            let clearStatus = clearAllDataForQuery(accountName, service: nil)
            if (clearStatus.isSuccess() == false) {
                log(error: "Unable to clear data for account (\(accountName)) : <\(clearStatus.resultError())>")
                isFailure = true
                lastFailure = clearStatus.resultError()!
            }
        }

        if (isFailure) {
            return KeychainResults.failure(lastFailure!)
        } else {
            return KeychainResults.success(nil)
        }
    }

    /**
     Set the data for a known SecureItemType

     parameter data: to save
     parameter itemType: to save
     */
    func setData(_ data: Data, itemType: SecureItemType) -> KeychainResults<String> {
        let setStatus = setDataForQuery(data,
                                        account: itemType.accountName(),
                                        service: itemType.serviceName(),
                                        accessibleValue: self.accessibleValueForKnownItem(itemType))
        
        if (setStatus.isSuccess() == false) {
            return KeychainResults.failure(setStatus.resultError()!)
        }
        return KeychainResults.success(nil)
    }

    /**
     Set the dictionary for a known SecureItemType by serializing NSDictionary as an NSData object

     parameter dict: to save
     parameter itemType: to save
     */
    func setDictionary(_ dict: NSDictionary, itemType: SecureItemType) -> KeychainResults<NSDictionary> {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict,
                format: .xml,
                options: 0)
            let setStatus = setDataForQuery(data,
                account: itemType.accountName(),
                service: itemType.serviceName(),
                accessibleValue: self.accessibleValueForKnownItem(itemType))
            if (setStatus.isSuccess() == false) {
                return KeychainResults.failure(setStatus.resultError()!)
            }
            return KeychainResults.success(nil)
        } catch let error as NSError {
            log(error: "Unable to save HMAC dictionary to the keychain due to serialization error: \(error)")
            return KeychainResults.failure(error)
        }
    }

    /**
     Set the value for a known SecureItemType

     parameter value: to save
     parameter itemType: to save
     */
    func setValue(_ value: String, itemType: SecureItemType) -> KeychainResults<String> {
        let encodedData = value.data(using: String.Encoding.utf8)
        if (encodedData == nil) {
            log(error: "Failed to set value on keychain due to encoding failure.")
            return KeychainResults.failure(AWError.SDK.Tunnel.Storage.keychainError.error)
        }
        return setData(encodedData!, itemType: itemType)
    }

    /**
     Data for known SecureItemType

     parameter itemType: to retrieve
     */
    func data(_ itemType: SecureItemType) -> KeychainResults<Data> {
        let getStatus = dataForQuery(itemType.accountName(),
            service: itemType.serviceName())
        if (getStatus.isSuccess() == false) {
            return KeychainResults.failure(getStatus.resultError()!)
        }
        return KeychainResults.success(getStatus.resultData()!)
    }

    /**
     NSDictionary for known SecureItemType

     parameter itemType: to retrieve
     */
    func dictionary(_ itemType: SecureItemType) -> KeychainResults<NSDictionary> {
        let getStatus = dataForQuery(itemType.accountName(),
            service: itemType.serviceName())
        if (getStatus.isSuccess() == false) {
            return KeychainResults.failure(getStatus.resultError()!)
        }
        let data = getStatus.resultData()!
        do {
            let dict = try PropertyListSerialization.propertyList(from: data,
                options: PropertyListSerialization.MutabilityOptions(),
                format: nil) as? NSDictionary
            return KeychainResults.success(dict)
        } catch let error as NSError {
            log(error: "Unable to retrieve HMAC key from keychain due to serialization error: \(error)")
            return KeychainResults.failure(error)
        }
    }

    /**
     Value for known SecureItemType

     parameter itemType: to retrieve
     */
    func value(_ itemType: SecureItemType) -> KeychainResults<String> {
        let getStatus = data(itemType)

        if (getStatus.isSuccess == false) {
            return KeychainResults<String>.failure(getStatus.resultError()!)
        }

        if let dataToDecode = getStatus.resultData() {
            if let decodedString = String.init(data: dataToDecode,
                encoding: String.Encoding.utf8) {
                    return KeychainResults.success(decodedString)
            } else {
                log(error: "Unable to retrieve item from keychain: failed to decode the data into a String")
            }
        } else {
            log(error: "Unable to retrieve item from keychain: No data was passed upstream -- THIS SHOULDN'T HAPPEN")
        }

        return KeychainResults.failure(AWError.SDK.Tunnel.Storage.keychainError.error)
    }

    // --------------- INTERNAL ---------------
    // MARK: - Internal Section
    /**
    Lock down the initializer
    */
    internal init?(OthersShouldNotCallDirectly shouldNotCall: Bool = false) {
        // To ensure that this cannot be called accidentally by another class
        if (shouldNotCall == true) {
            // Initialize
        } else {
            // Fail
            return nil
        }
    }

    // MARK: Overriding Helper Methods for Testing
    /**
    Overloadable Helper Method to create a query attributes dictionary for use
    with the keychain wrappers

    - parameter accountToQuery: optional String for the account
    - parameter serviceToQuery: optional String for the service
    */
    internal dynamic func keychainQueryDictionary(_ accountToQuery: String?,
        serviceToQuery: String?) -> AttributeDictionary {
            var queryAttributes = AttributeDictionary()
            queryAttributes[SecClass] = SecClassGenericPassword as AnyObject?
            if (accountToQuery?.isEmpty == false) {
                queryAttributes[SecAttrAccount] = accountToQuery as AnyObject?
            }
            if (serviceToQuery?.isEmpty == false) {
                queryAttributes[SecAttrService] = serviceToQuery as AnyObject?
            }
            return queryAttributes
    }

    /**
     Overloadable Helper Method to define whether or not we should be requiring
     pincode status
     */
    internal func shouldRequirePincode() -> Bool {
        if (AWSecurityWrapper.isSimulator()) {
            log(error: "This is running on the simulator and therefore, unable " +
                "to require a pincode")
            return false
        }
        return true
    }

    // --------------- PRIVATE ---------------
    // MARK: - Private Section
    // MARK: Private Enums
    // MARK: Lowlevel Keychain Results
    fileprivate enum LowlevelKeychainResults {
        case success
        case successWithAttributes(AttributeDictionary)
        case successWithData(Data)
        case failure(NSError)

        /// Helper method to roll the successes into a Bool
        func isSuccess() -> Bool {
            switch self {
            case .failure(_):
                return false
            default:
                return true
            }
        }

        // Access attributes for SuccessWithAttributes, nil otherwise
        func resultAttributes() -> AttributeDictionary? {
            switch self {
            case .successWithAttributes(let attributesToReturn):
                return attributesToReturn
            default:
                return nil
            }
        }

        // Access data for SuccessWithData, nil otherwise
        func resultData() -> Data? {
            switch self {
            case .successWithData(let dataToReturn):
                return dataToReturn
            default:
                return nil
            }
        }

        // Access error for Failure, nil otherwise
        func resultError() -> NSError? {
            switch self {
            case .failure(let errorToReturn):
                return errorToReturn
            default:
                return nil
            }
        }
    }

    // MARK: KeychainOSTATResults
    // Because of the nature of the OSStatus, they're not literals, and thus we
    // cannot use them as case literals, so we need to parse the OSSTATUS into
    // the enums. Rather than being able to do: resultSuccess = errSecSuccess
    // for enum <name> : OSSTATUS
    /**
    Keychain result types
    - resultSuccess
    - resultUnimplemented
    - resultParam
    - resultAllocate
    - resultNotAvailable
    - resultAuthFailed
    - resultDuplicateItem
    - resultItemNotFound
    - resultInteractionNotAllowed
    - resultDecode
    - resultUnknown (keychainstatus) - our catch all enum
    */
    fileprivate enum KeychainOSTATResults {
        /// Define the cases
        case resultSuccess,
        resultUnimplemented,
        resultParam,
        resultAllocate,
        resultNotAvailable,
        resultAuthFailed,
        resultDuplicateItem,
        resultItemNotFound,
        resultInteractionNotAllowed,
        resultDecode,
        resultUnknown (keychainStatus: OSStatus)

        /**
         Convert the OSStatus from the keychain methods into the enum
         */
        static func parseKeychainStatus(_ keychainStatus: OSStatus) -> KeychainOSTATResults {
            switch keychainStatus {
            case errSecSuccess:
                return resultSuccess
            case errSecUnimplemented:
                return resultUnimplemented
            case errSecParam:
                return resultParam
            case errSecAllocate:
                return resultAllocate
            case errSecNotAvailable:
                return resultNotAvailable
            case errSecAuthFailed:
                return resultAuthFailed
            case errSecDuplicateItem:
                return resultDuplicateItem
            case errSecItemNotFound:
                return resultItemNotFound
            case errSecInteractionNotAllowed:
                return resultInteractionNotAllowed
            case errSecDecode:
                return resultDecode
            default:
                return resultUnknown(keychainStatus: keychainStatus)
            }
        }

        /**
         Generate a printable string from the different types of the enum
         */
        func debugStatus() -> String {
            switch self {
            case .resultSuccess:
                return "Success"
            case .resultUnimplemented:
                return "Function or operation not implemented"
            case .resultParam:
                return "One or more parameters passed to the function were not valid"
            case .resultAllocate:
                return "Failed to allocate memory"
            case .resultNotAvailable:
                return "No trust results are available"
            case .resultAuthFailed:
                return "Authorization/Authentication failed"
            case .resultDuplicateItem:
                return "Item already exists"
            case .resultItemNotFound:
                return "Item not found"
            case .resultInteractionNotAllowed:
                return "Interaction with the security server is not allowed"
            case .resultDecode:
                return "Unable to decode the provided data"
            case .resultUnknown(let keychainStatusValue):
                return "Unknown status code (\(keychainStatusValue))"
            }
        }
    }

    // MARK: Private Properties
    // Convert some of the keychain keys and values into String values
    fileprivate let SecAttrAccessContro = String(kSecAttrAccessControl)
    fileprivate let SecAttrAccessible = String(kSecAttrAccessible)
    fileprivate let SecAttrAccessibleAfterFirstUnlock = String(kSecAttrAccessibleAfterFirstUnlock)
    fileprivate let SecAttrAccessibleAlways = String(kSecAttrAccessibleAlways)
    fileprivate let SecAttrAccessibleAlwaysThisDeviceOnly = String(kSecAttrAccessibleAlwaysThisDeviceOnly)
    fileprivate let SecAttrAccessibleWhenPasscodeSetThisDeviceOnly = String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
    fileprivate let SecAttrAccessibleWhenUnlocked = String(kSecAttrAccessibleWhenUnlocked)
    fileprivate let SecAttrAccessibleWhenUnlockedThisDeviceOnly = String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    fileprivate let SecAttrAccount = String(kSecAttrAccount)
    fileprivate let SecAttrCreationDate = String(kSecAttrCreationDate)
    fileprivate let SecAttrGeneric = String(kSecAttrGeneric)
    fileprivate let SecAttributeValueTrue = Bool(kCFBooleanTrue)
    fileprivate let SecAttrModificationDate = String(kSecAttrModificationDate)
    fileprivate let SecAttrService = String(kSecAttrService)
    fileprivate let SecClass = String(kSecClass)
    fileprivate let SecClassGenericPassword = String(kSecClassGenericPassword)
    fileprivate let SecMatchLimit = String(kSecMatchLimit)
    fileprivate let SecMatchLimitOne = String(kSecMatchLimitOne)
    fileprivate let SecReturnAttributes = String(kSecReturnAttributes)
    fileprivate let SecReturnData = String(kSecReturnData)
    fileprivate let SecValueData = String(kSecValueData)

    // MARK: Private Methods

    // MARK: Helper Methods

    /// Helper method to return accessible values for known secure item types
    fileprivate func accessibleValueForKnownItem(_ itemType: SecureItemType) -> String {
        // Per https://confluence.eng.vmware.com/pages/viewpage.action?pageId=144705700
        // (Keychain required information), we need different accessible
        // levels for the different keychain items.
        switch (itemType) {
        case .awAgentUDID:
            return SecAttrAccessibleAlwaysThisDeviceOnly
            
        case .awhmac:
            return SecAttrAccessibleAfterFirstUnlock
            
        case .awServerURL:
            return SecAttrAccessibleAfterFirstUnlock
            
        case .awGroupID:
            return SecAttrAccessibleAfterFirstUnlock
            
        case .proxyMAGCertificate:
            return SecAttrAccessibleAlwaysThisDeviceOnly
            
        case .f5SessionKey:
            return SecAttrAccessibleAlwaysThisDeviceOnly
            
        default:
            return SecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }

    /**
    Helper method to handle error keychain status codes

    - parameter keychainStatus: to parse
    */
    fileprivate func osstatusToError(_ keychainStatus: OSStatus) -> NSError {
        let keychainResultStatus: KeychainOSTATResults = KeychainOSTATResults.parseKeychainStatus(keychainStatus)
        let errorToReturn: NSError

        if (keychainStatus == errSecAuthFailed) {
            log(error: "Keychain authorization failure encountered: \(keychainResultStatus.debugStatus())")
            errorToReturn = AWError.SDK.Tunnel.Storage.keychainAuthError.error
        } else {
            if (keychainStatus != errSecNotAvailable) {
                log(error: "Keychain failure encountered: \(keychainResultStatus.debugStatus())")
            }
            errorToReturn = AWError.SDK.Tunnel.Storage.keychainError.error
        }

        return errorToReturn
    }

    // MARK: Keychain Wrappers
    /**
    Add the attributes to the keychain

    - parameter attributes: to save
    */
    fileprivate func keychainAdd(_ attributes: AttributeDictionary) -> LowlevelKeychainResults {
        let status = SecItemAdd(attributes as CFDictionary, nil)

        if (status == errSecSuccess) {
            return LowlevelKeychainResults.success
        }

        return LowlevelKeychainResults.failure(osstatusToError(status))
    }

    /**
     Copy the attributes from the keychain

     - parameter attributeQuery: to use to query the keychain store
     */
    fileprivate func keychainCopy(_ attributeQuery: AttributeDictionary) -> LowlevelKeychainResults {
        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(attributeQuery as CFDictionary, UnsafeMutablePointer($0))
        }

        if (status == errSecSuccess) {
            return LowlevelKeychainResults.successWithAttributes(result as! AttributeDictionary)
        }

        return LowlevelKeychainResults.failure(osstatusToError(status))
    }

    /**
     Delete records from the keychain that meet our query requirements

     - parameter attributeQuery: to search for and delete
     */
    fileprivate func keychainDelete(_ attributeQuery: AttributeDictionary) -> LowlevelKeychainResults {
        let status = SecItemDelete(attributeQuery as CFDictionary)

        if (status == errSecSuccess) {
            return LowlevelKeychainResults.success
        }

        return LowlevelKeychainResults.failure(osstatusToError(status))
    }

    /**
     Updates the attributes in the keychain

     - parameter attributeQuery: to search for
     - parameter attributesToSave: to save
     */
    fileprivate func keychainUpdate(_ attributeQuery: AttributeDictionary,
        attributesToSave: AttributeDictionary) -> LowlevelKeychainResults {
            let status = SecItemUpdate(attributeQuery as CFDictionary, attributesToSave as CFDictionary)

            if (status == errSecSuccess) {
                return LowlevelKeychainResults.success
            }

            return LowlevelKeychainResults.failure(osstatusToError(status))
    }

    // MARK: Higher level data wrappers

    /**
    Clears all keychain data for account and/or service

    parameter account: optional account to clear the data for
    parameter service: optional service to clear the data for
    */
    @discardableResult
    fileprivate func clearAllDataForQuery(_ account: String?, service: String?) -> LowlevelKeychainResults {
        let attributesToQuery = keychainQueryDictionary(account,
            serviceToQuery: service)

        return keychainDelete(attributesToQuery)
    }

    /**
     retrieve keychain data for account and service

     parameter account: to retrieve data for
     parameter service: to retrieve data for
     */
    @discardableResult
    fileprivate func dataForQuery(_ account: String, service: String) -> LowlevelKeychainResults {
        var attributesToQuery = keychainQueryDictionary(account, serviceToQuery: service)

        // Refine the query
        attributesToQuery[SecMatchLimit] = SecMatchLimitOne as AnyObject?
        attributesToQuery[SecReturnAttributes] = SecAttributeValueTrue as AnyObject?
        attributesToQuery[SecReturnData] = SecAttributeValueTrue as AnyObject?

        let queryResults = keychainCopy(attributesToQuery)

        if (queryResults.isSuccess()) {
            if let attributesReturned = queryResults.resultAttributes() {
                if let objectReturned = attributesReturned[SecValueData] {
                    if (objectReturned is Data) {
                        let dataReturned: Data = objectReturned as! Data
                        if (dataReturned.count == 0) {
                            log(error: "Data is missing from returned data " +
                                "(\(dataReturned)[\(dataReturned.count)]) in " +
                                "attributes (\(attributesReturned)) this " +
                                "should never happen")
                        } else {
                            // Success
                            return LowlevelKeychainResults.successWithData(dataReturned)
                        }
                    } else {
                        log(error: "Keychain Error: Object returned isn't an NSData object " +
                            "(\(objectReturned)) in attributes " +
                            "(\(attributesReturned)) this should never happen")
                    }
                } else {
                    log(error: "Keychain Error: No data returned in attributes " +
                        "(\(attributesReturned)) this should never happen")
                }
            } else {
               log(error: "Keychain Error: No attributes returned for query " +
                    "<\(attributesToQuery)>, this should never happen")
            }
            return LowlevelKeychainResults.failure(AWError.SDK.Tunnel.Storage.keychainError.error)

        } // end of success

        // Failures just return
        return queryResults
    }

    /**
     set keychain data for account and service

     parameter dataToSave: non-null data
     parameter account: to retrieve data for
     parameter service: to retrieve data for
     parameter accessibleValue: to use when storing data for this key
     */
    @discardableResult    
    fileprivate func setDataForQuery(_ dataToSave: Data!,
                                    account: String,
                                    service: String,
                            accessibleValue: String) -> LowlevelKeychainResults {
        if (dataToSave == nil || dataToSave.count == 0) {
            log(error: "Keychain Error: failed to save data to keychain due to nil or empty data object")
            return LowlevelKeychainResults.failure(AWError.SDK.Tunnel.Storage.keychainError.error)
        }

        var attributesToQuery = keychainQueryDictionary(account, serviceToQuery: service)

        // Refine the query
        attributesToQuery[SecMatchLimit] = SecMatchLimitOne as AnyObject?
        attributesToQuery[SecReturnAttributes] = SecAttributeValueTrue as AnyObject?
        attributesToQuery[SecReturnData] = SecAttributeValueTrue as AnyObject?

        let keychainStatusFromCopy = keychainCopy(attributesToQuery)

        // Our internal functions
        /// Tweak the query attributes and save them
        func addToKeychainWrapper(_ attributes: AttributeDictionary) -> LowlevelKeychainResults {
            var attributesToSave: AttributeDictionary = attributes
            // Refine the query
            attributesToSave.removeValue(forKey: SecMatchLimit)
            attributesToSave.removeValue(forKey: SecReturnAttributes)
            attributesToSave.removeValue(forKey: SecReturnData)

            attributesToSave[SecValueData] = dataToSave as AnyObject?
            attributesToSave[SecAttrCreationDate] = Date() as AnyObject?
            if (shouldRequirePincode()) {
                attributesToSave[SecAttrAccessible] = accessibleValue as AnyObject?
            } else {
                log(error: "Not requiring a pincode -- SHOULD NOT HAPPEN IN PRODUCTION")
            }

            return keychainAdd(attributesToSave)
        }

        /// Tweak the query attributes and update them
        func updateToKeychainWrapper(_ attributes: AttributeDictionary) -> LowlevelKeychainResults {
            var attributesToSave: AttributeDictionary = attributes
            // Refine the query
            attributesToSave.removeValue(forKey: SecMatchLimit)
            attributesToSave.removeValue(forKey: SecReturnAttributes)
            attributesToSave.removeValue(forKey: SecReturnData)

            // Create a second dictionary
            var attributesToUpdate: AttributeDictionary = AttributeDictionary()
            // Populate it
            for (key, value) in attributesToSave {
                attributesToUpdate[key] = value
            }

            // We don't need the class in the update dictionary, as the keychain
            // already knows what it is.
            attributesToUpdate.removeValue(forKey: SecClass)

            attributesToUpdate[SecValueData] = dataToSave as AnyObject?
            attributesToUpdate[SecAttrModificationDate] = Date() as AnyObject?

            return keychainUpdate(attributesToSave, attributesToSave: attributesToUpdate)
        }

        if (keychainStatusFromCopy.isSuccess() == false) {
            // It's not there, save it
            return addToKeychainWrapper(attributesToQuery)
        } else if let attributesReturned = keychainStatusFromCopy.resultAttributes() {
            let presentData = attributesReturned[SecValueData] as! Data

            if (presentData == dataToSave) {
                // It's the same thing
                return LowlevelKeychainResults.success
            }

            // It's different, update it
            return updateToKeychainWrapper(attributesToQuery)
        }

        // When all else fails, return the keychainStatus
        return keychainStatusFromCopy
    }

}
