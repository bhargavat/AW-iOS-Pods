//
//  AbstractSecureEnclaveStore.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLocalization

public protocol AbstractSecureEnclaveStore: AbstractKeychainDataStore, AbstractAsyncKeyValueStore {}

public extension AbstractSecureEnclaveStore {
    // If user selects cancel, then then success will be false and nil will be returned for error. If there is an error then error object will be returned with success as false. If everything was successful then error will be nil and successful will be true.
    public func get<DR: DataRepresentable>(_ group: String, key: String, withCompletionHandler completionBlock: @escaping (_ success: Bool, _ data: DR?, _ error: NSError?) -> Void) {
        guard group.characters.count != 0 else {
            //TODO: error support ??
            let returnError = NSError(domain: "error", code:0, userInfo: nil)
            completionBlock(false, nil, returnError)
            return
        }
        guard key.characters.count != 0 else {
            //TODO: error support ??
            let returnError = NSError(domain: "error", code:0, userInfo: nil)
            completionBlock(false, nil, returnError)
            return
        }
        var query = self.genericQuery(group, service: key)
        query[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        query[String(kSecReturnData)] = true as AnyObject
        query[String(kSecUseOperationPrompt)] = AWSDKLocalization.getLocalizationString("AuthenticateForAccess") as AnyObject


        DispatchQueue.global(qos: .default).async {
            var returnedData: AnyObject?
            let result = SecItemCopyMatching(query as CFDictionary, &returnedData)
            DispatchQueue.main.async {

                if result == noErr {
                    let keychainReturnedData = returnedData as? Data
                    let finalData = DR.fromData(keychainReturnedData)
                    completionBlock(true, finalData, nil)
                }
                else if (result == errSecUserCanceled) {
                    completionBlock(false, nil, nil)
                }
                else {
                    //TODO: error support ??
                    // Passing the OSStatus so that caller can act accordingly.
                    let returnError = NSError(domain: "error", code:Int(result), userInfo: nil)
                    completionBlock(false, nil, returnError)
                }

            }
        }
    }


    public mutating func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?, withCompletionHandler completionBlock: @escaping (_ success: Bool, _ error: NSError?) -> Void) -> Void {
        guard key.characters.count != 0 else {
            //TODO: error support ??
            let returnError = NSError(domain: "error", code:0, userInfo: nil)
            completionBlock(false, returnError)
            return
        }
        guard group.characters.count != 0 else {
            //TODO: error support ??
            let returnError = NSError(domain: "error", code:0, userInfo: nil)
            completionBlock(false, returnError)
            return
        }
        //data cannot be nil for secure enclave
        guard let dataValue = value?.toData() else {
            let returnError = NSError(domain: "error", code:0, userInfo: nil)
            completionBlock(false, returnError)
            return
        }

        var itemQuery = self.genericQuery(group, service: key)
        itemQuery[String(kSecUseOperationPrompt)] = AWSDKLocalization.getLocalizationString("AuthenticateForAccess") as AnyObject
        
        var copiedSelf: Self
        copiedSelf = self

        DispatchQueue.global(qos: .default).async {
            guard copiedSelf.delete(itemQuery)
            else {
                DispatchQueue.main.async {
                    completionBlock(false, nil)
                }
                return
            }
            var sacObject: SecAccessControl?
            let accessControlError: UnsafeMutablePointer<Unmanaged<CFError>?>? = nil

            sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, SecAccessControlCreateFlags.touchIDCurrentSet, accessControlError)
            
            if (sacObject == nil || accessControlError != nil) {
                //TODO: error support ??
                DispatchQueue.main.async {
                    let returnError = NSError(domain: "error", code:0, userInfo: nil)
                    completionBlock(false, returnError)
                }
                return
            } else {
                itemQuery.removeValue(forKey: String(kSecUseOperationPrompt))
                itemQuery[String(kSecUseAuthenticationUI)] = true as AnyObject
                itemQuery[String(kSecAttrAccessControl)] = sacObject
                let added: Bool = copiedSelf.add(itemQuery, data: dataValue)
                var returnError: NSError? = nil
                if(!added) {
                    //TODO: error support ??
                    returnError = NSError(domain: "error", code:0, userInfo: nil)
                }
                DispatchQueue.main.async {
                    completionBlock(added, returnError)
                }
            }
        }
        self = copiedSelf
    }

    //needed as secureEnclave does not need the kSecAttrAccessible attribute
    internal func add(_ itemQuery: [ String : AnyObject ], data: Data) -> Bool {
        var query = itemQuery
        query[String(kSecValueData)] = data as AnyObject
        query[String(kSecAttrCreationDate)] = Date() as AnyObject
        let result = SecItemAdd(query as CFDictionary, nil)
        if result != noErr { AWLogError("AWKeychain add Error Code:\(result)") }
        return (result == noErr)
    }

}
