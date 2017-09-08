//
//  MigrationProcess_0_to_1.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWStorage

struct DataMigartionFrom_0_to_1: MigrationDatasource {
    // Only necessary for retrieval of 5.x.x data from sqlite. Data was wrapped using NSKeyedUnarchiver.
    func getLocalStoreData(forKey key: String, completion: ((_ object: AnyObject?)-> Void) ) {
        let data: Data? = localStore(name: "Settings").get(key)
        if let data = data {
            let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
            // If we cannot or have already done this step in a previous attempt to migrate data, this decode object step will return nil
            if let decodedData = unarchiver.decodeObject(forKey: "data") as AnyObject? {
                completion(decodedData)
            }
        } else {
            completion(nil)
        }
    }
}

// Migration from pre 17.1 is considered data store 0
class SDKDataMigrationFrom_0_1: MigrationOperation, MigrationProtocol, MigrationDatasource {
    var applicationDataStore: ApplicationDataStore
    var migrationDatasource: DataMigartionFrom_0_to_1
    
    init(applicationDataStore: ApplicationDataStore, datasource: DataMigartionFrom_0_to_1 = DataMigartionFrom_0_to_1() ) {
        self.applicationDataStore = applicationDataStore
        self.migrationDatasource = datasource
    }
    
    func canMigrate() -> Bool {
        // if the SDK is pre 17.1, then applicationDataStore.datastoreVersion will return 0
        if applicationDataStore.datastoreVersion == 0 {
            return true
        }
        
        return false
    }
    
    override func start() {
        if canMigrate() == false{
            markOperationComplete()
            return
        }
        self.performMigration()
    }
    
    func performMigration() {
        // BEGINNING OF MIGRATION
        log(info: "Will begin migration from pre 17.1 AWSDK")
        
        //set ApplicationPreviouslyLaunched to true if updgrading from pre 17.1 SDK
        migrationDatasource.getLocalStoreData(forKey: "AWLauchedOnce") { (object: AnyObject?) in
            let value = object as? Bool
            if value == true {
                _ = applicationDataStore.applicationPreviouslyLaunched
            }
        }
        
        // Get the enrollment status from keychain and then modify the application's enrollmentInformation with the apps enrollmentStatus
        let enrollmentInformation = applicationDataStore.enrollmentInformation
        // AWSDKEnrollmentStatus
        migrationDatasource.getLocalStoreData(forKey: "AWSDKEnrollmentStatus") { (object: AnyObject?) in
            if let value = object as? NSInteger, let enrollmentStatus = AWSDK.EnrollmentStatus(rawValue: value) {
                log(info: "Migration of AWSDKEnrollmentStatus is necessary")
                enrollmentInformation?.lastKnownEnrollmentStatus = enrollmentStatus
                applicationDataStore.enrollmentInformation = enrollmentInformation
            } else {
                log(info: "Migration not needed or could not be done for AWSDKEnrollmentStatus")
            }
        }
        
        // AWSDKCachedSDKProfile
        // Profile from sqlite must be taken out from NSKeyedArchiver and saved back into the sqlite database as an object
        migrationDatasource.getLocalStoreData(forKey: "AWSDKCachedSDKProfile") { (object: AnyObject?) in
            if let data = object as? [String: Any] {
                log(info: "Migration of AWSDKCachedSDKProfile is necessary")
                let profile = Profile(info: data)
                _ = applicationDataStore.saveProfile(profile)
            } else {
                log(info: "Migration not needed or could not be done for AWSDKCachedSDKProfile")
            }
        }
        
        // AWSSOStatus
        // If SSO is defined in keychain because of an app being 17.1+, take that value and ignore the app's sqlite SSO status
        let ssoStatusInKeychain: Bool? = migrationDatasource.keychain.fetch(KeyValueStoreItemQueryProvider.nonSharedItem.SingleSignOnEnabled)
        if ssoStatusInKeychain != nil, let ssoStatus = ssoStatusInKeychain {
            log(info: "Migration found value for SSO in keychain and that will take precidence")
            log(verbose: "Since SSO is in keychain, we will ignore the app's sqlite value")
            applicationDataStore.setContext(shared: ssoStatus)
            
            // SDKAccessControlSetupOperation uses this value to determine if resetCurrentKey should be called.
            // If newDataStoreMode is Shared and lastDataStoreMode is NonShared, then resetCurrentKey is called
            applicationDataStore.lastDataStoreSetupMode = ssoStatus
        } else {
            migrationDatasource.getLocalStoreData(forKey: "AWSSOStatus") { (object: AnyObject?) in
                let value = object as? NSInteger
                // In the previous version of the SDK there was an enum with 0 (unknown), 1 (enrolled), 2 (disabled)
                if value == 1 {
                    log(info: "Migration of AWSSOStatus is necessary")
                    applicationDataStore.setContext(shared: true)
                    // SDKAccessControlSetupOperation uses this value to determine if resetCurrentKey should be called.
                    // If newDataStoreMode is Shared and lastDataStoreMode is NonShared, then resetCurrentKey is called
                    applicationDataStore.lastDataStoreSetupMode = true
                }
            }
        }
        
        guard let url = applicationDataStore.enrollmentInformation?.hostname,
              let deviceID = applicationDataStore.enrollmentInformation?.deviceIdentifier else {
            log(error: "Missing data for migration")
                log(error: "Hostname is currently \(String(describing:applicationDataStore.enrollmentInformation?.hostname)) and will fail migration of secure channel migration if nil")
            log(error: "Device identifier returned \(String(describing: applicationDataStore.enrollmentInformation?.deviceIdentifier)) and will fail migration of secure channel migration if nil")
            markOperationComplete()
            return
        }
        
        guard let host = URL(string: url)?.host else {
            log(error: "Failed to finish migration. Secure Channel url could not resolve the host.")
            markOperationComplete()
            return
        }
        
        let legacySecureChannel = Pre17LegacySecureChannelStorage()
        // Migrate the current SecureChannel private/public/server certificate for the given hostname
        let configurationManager = SDKSecureChannelConfigurationManager(url: host,
                                                                        deviceIdentifier: deviceID)
        let secureChannelManagerMigration = SecureChannelConfigurationManagerMigration(deviceID: deviceID, hostname: host)
        if
            let rawPublicData = legacySecureChannel.publicKey(hostname: host),
            let rawPrivateData = legacySecureChannel.privateKey(hostname: host),
            let rawServerData = legacySecureChannel.serverCertificate(hostname: host) {
            
            var urlStringForSecureChannelEndpoint: String? = nil
            // get the secure channel url endpoint from the plist so to limit the amount of calls to resolve the secure channel endpoint
            migrationDatasource.getLocalStoreData(forKey: "AWSecureChannelDetails") { (object: AnyObject?) in
                let dictionary = object as? [String:AnyObject]
                if let secureChannelEndpoint = dictionary?[host] as? String {
                    urlStringForSecureChannelEndpoint = secureChannelEndpoint
                }
            }
            secureChannelManagerMigration.migrate(publicData: rawPublicData,
                                                  privateData: rawPrivateData,
                                                  serverData: rawServerData,
                                                  secureChannelEndpointURL: urlStringForSecureChannelEndpoint,
                                                  configurationManager: configurationManager)
        }
        

        
        // Set the SDKVersion in sqlite to 1
        _ = applicationDataStore.datastoreVersion = 1
        
        log(info: "Migration from pre version 1 data has completed.")
        
        markOperationComplete()
    }
}
