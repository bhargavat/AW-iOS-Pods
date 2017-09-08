//
//  FetchConfigurationProfileOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWError
import AWServices

class ConfigurationProfilesSetupOperation: SDKSetupAsyncOperation {
    
    static var configurationFetchTimestamp = TimeInterval(0)
    static var fetchedProfiles:[AWSDK.ConfigurationProfileType] = []
    
    let configurationFetchQueue = DispatchQueue(label: "com.air-watch.configuration-fetch-queue")
    override func startOperation() {
        precondition(self.dataStore.enrollmentInformation != nil, "Missing Enrollment Information")

        let profileTypes = self.sdkController.requestingProfiles
        let profilesToDownload = profileTypes
            .map { AWSDK.ConfigurationProfileType.fromString($0) }
            .filter { $0 != AWSDK.ConfigurationProfileType.unknown }

        
        guard profilesToDownload.count > 0 else {
            log(error: "No Known profile types to fetch. Marking Operation as failed!")
            markOperationFailed()
            return
        }

        configurationFetchQueue.sync {
            self.fetchProfiles(profilesToFetch: profilesToDownload)
        }
    }
    
    private func fetchProfiles(profilesToFetch: [AWSDK.ConfigurationProfileType]) {
        let profiles = self.dataStore.profiles
        let downloadedAllProfiles = (ConfigurationProfilesSetupOperation.fetchedProfiles == profilesToFetch)
        let downloadedWithInLast4hours = Date().timeIntervalSince1970 - ConfigurationProfilesSetupOperation.configurationFetchTimestamp < 14400
        
        let availableProfiles = profiles.map { return $0.profileType }
        let missingProfiles = profilesToFetch.filter { !availableProfiles.contains($0) }
        
        if downloadedAllProfiles &&
            downloadedWithInLast4hours &&
            missingProfiles.count == 0 {
            log(info: "Already fetched required configuration settings in last 4 hours. Will not be fetching any more.")
            DispatchQueue.main.async {
                log(info: "Sending SDKController delegate callback about profile availability.")
                self.sdkController.delegate?.controllerDidReceive?(profiles: profiles)
            }
            self.markOperationComplete()
            return
        }
        
        guard let deviceServices = self.dataStore.deviceServices else {
            log(error: "could not fetch profiles, missing Enrollment Information")
            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.enrollmentInformationSetup)
            self.markOperationFailed()
            return
        }

        var shouldCompleteOperation = true
        let profileFetchOperations = profilesToFetch.map { ConfigurationProfileFetchOperation(profile: $0, operation: self) }
        var previousOperation: ConfigurationProfileFetchOperation?  = nil
        for operation in profileFetchOperations {
            if let dependency = previousOperation {
                operation.addDependency(dependency)
            }
            previousOperation = operation
        }

        NetworkConnectivityStatusManager.canConnectTo(host: deviceServices.config.airWatchServerURL) { [weak self] (canConnect, connectionError) in
            guard shouldCompleteOperation else {
                log(info: "No need to repor the network status check as the actual operation is complete")
                return
            }
            guard let weakSelf = self else {
                log(error: "error completing the profile fetch operation, Operation deallocated before reporting operation result")
                return
            }

            guard canConnect else {
                log(info: "could not connect to host to fetch Profiles: \(String(describing: connectionError?.localizedDescription))")
                shouldCompleteOperation = false
                weakSelf.completeOperation()
                return
            }
        }
        SDKOperationQueue.workerQueue.addOperations(profileFetchOperations, waitUntilFinished: true)
        profileFetchOperations.forEach { (operation) in
            if operation.operationCompletedSuccessfully {
                log(info: "Fetched profile of type: \(operation.fetchingProfileType.StringValue).")
                ConfigurationProfilesSetupOperation.fetchedProfiles.append(operation.fetchingProfileType)
            } else {
                log(error: "Failed to fetch profile of type: \(operation.fetchingProfileType).")
            }
        }
        ConfigurationProfilesSetupOperation.configurationFetchTimestamp = Date().timeIntervalSince1970
        ConfigurationProfilesSetupOperation.fetchedProfiles = profilesToFetch
        if shouldCompleteOperation {
            self.completeOperation()
        }
    }
    
    fileprivate func completeOperation() {
        let profiles = self.dataStore.profiles
        log(info: "There are \(profiles.count) profiles saved to store.")
        guard profiles.count > 0 else {
            log(error: "No profiles available from store. Can not move forward. Failing \(type(of: self))")
            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.emptyProfiles)
            self.markOperationFailed()
            return
        }
        DispatchQueue.main.async {
            log(info: "Sending SDKController delegate callback about profile availability.")
            self.sdkController.delegate?.controllerDidReceive?(profiles: profiles)
        }
        self.markOperationComplete()
    }
}

