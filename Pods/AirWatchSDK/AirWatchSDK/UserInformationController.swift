//
//  UserInfoController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWError

@objc
public final class UserInformationController: NSObject {

    public static let sharedInstance = UserInformationController()
    private override init() {}

    /**
     @brief Retrieve the user information. 
     
     @return If calling this API directly without initializing the SDK and not reaching the delegate call for initial check done then an error will occur
     */
    public func retrieveUserInfo(completionHandler: @escaping (_ userInfo: UserInformation?,_ error: NSError?) -> Void) -> Void {

        if let deviceServices = AWController.sharedInstance.context.deviceServices {
            deviceServices.fetchEnrolledUserInformation { (enrolledUserInfo, error) in
                completionHandler(enrolledUserInfo?.userInformation, error)
            }
        }
        else {
            completionHandler(nil, AWError.SDK.General.moduleNotInitialized.error)
        }
    }
}

internal extension EnrolledUserInformation {
    var userInformation: UserInformation {
        return UserInformation(username: self.userName, userIdentifier: self.userIdentifier, firstName: self.firstName, lastName: self.lastName, email: self.email, domain: self.domain, groupID: self.groupID)
    }
}
