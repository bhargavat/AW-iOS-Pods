//
//  UnenrollApplicationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

class UnenrollApplicationOperation: SDKSetupAsyncOperation {
    
    override func startOperation() {
        var store = self.dataStore
        
        guard let deviceServices = store.deviceServices else {
            log(error: "Device services is nil; cannot proceed with reporting unenrollment!")
            store.shouldReportUnenrollment = false
            self.markOperationFailed()
            return
        }
        
        store.shouldReportUnenrollment = true
        log(verbose: "Trying to send unenroll message to console.")
        
        deviceServices.unenrollDevice { [weak self] (success) in
            
            guard success else {
                log(error: "SDK Failed to report unenrollment to the Server")
                self?.markOperationFailed()
                return
            }
            
            let enrollmentInfomation = store.enrollmentInformation
            enrollmentInfomation?.hostname = nil;
            enrollmentInfomation?.organizationGroup = nil;
            enrollmentInfomation?.lastKnownEnrollmentStatus = .unenrolled;
            enrollmentInfomation?.lastVerifiedDate = Date();
            store.enrollmentInformation = enrollmentInfomation
            store.shouldReportUnenrollment = false
            
            log(warning: "Cleared Environment Information as we have got successfull confirmation about unenrollment")
            log(warning: "Completed Unenrollment Application Operation successfully")
            
            self?.markOperationComplete()
        }
    }
}
