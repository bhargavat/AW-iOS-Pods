//
//  AWController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc(AWSDKDelegate)
public protocol AWControllerDelegate: class {

    @objc(initialCheckDoneWithError:)
    func controllerDidFinishInitialCheck(error: NSError?)

    @objc(completedVerificationWithServer:error:)
    optional func controllerDidCompleteVerificationWithServer(success: Bool, error: NSError?)

    @objc(receivedProfiles:)
    optional func controllerDidReceive(profiles: [Profile])

    @objc(didReceiveEnrollmentStatus:)
    optional func controllerDidReceive(enrollmentStatus: AWSDK.EnrollmentStatus)

    @objc(userChanged)
    optional func controllerDidDetectUserChange()

    @objc(wipe)
    optional func controllerDidWipeCurrentUserData()

    @objc(willLock)
    optional func controllerWillPromptForPasscode()

    @objc(lock)
    optional func controllerDidLockDataAccess()

    @objc(unlock)
    optional func controllerDidUnlockDataAccess()


    @objc(stopNetworkActivity:)
    optional func applicationShouldStopNetworkActivity(reason: AWSDK.NetworkActivityStatus)

    @objc(resumeNetworkActivity)
    optional func applicationCanResumeNetworkActivity()

}
