//
//  SupportInfoController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWError
import Foundation


@objc(AWConsoleSupportInformation)
public protocol ConsoleSupportInformation {
    var email: String? { get }
    var telephoneNumber: String? { get }
    var errorMessage: String? { get }
}


internal class SDKConsoleSupportInformation: NSObject, ConsoleSupportInformation {
    public var email: String?
    public var telephoneNumber: String?
    public var errorMessage: String?

    init(email: String?, telephoneNumber: String?, errorMessage: String?) {
        self.email = email
        self.telephoneNumber = telephoneNumber
        self.errorMessage = errorMessage
    }
}

extension SupportInformation {
    internal var _consoleSupportInformation: ConsoleSupportInformation {
        return SDKConsoleSupportInformation(email: self.email, telephoneNumber: self.telephoneNumber, errorMessage: self.errorMessage)
    }
}

@objc
public final class SupportInformationController: NSObject {
    
    public static let sharedInstance = SupportInformationController()
    private override init() {}
    
    /**
     Retrieve the support information for email and telephone that's configured on console
     
     @return AWError.SDK.General.moduleNotInitialized If calling this API directly without initializing the SDK and not reaching the delegate call for initial check done then an error will occur
     @return AWError.SDK.CoreNetwork.CTL.createRequestFailure(error.localizedDescription) - network related failure
     @return AWError.SDK.General.jsonDeserializationFailed - could not unwrap the response data which is supposed to be JSON
     @return AWError.SDK.General.configurationValuesUnavailable.error - An Error was returned on the server. Check the error message for a possible message
     @return SupportInformation If an object is returned, check that there is no error message and use the data accordingly. 
     */
    public func retrieveSupportInfo(completion: @escaping (ConsoleSupportInformation?, Error?) -> Void ) -> Void {
        guard let deviceServices = AWController.sharedInstance.context.deviceServices else {
            completion(nil, AWError.SDK.General.moduleNotInitialized)
            return
        }

        deviceServices.fetchSupportInformation { (supportInformation, error) in
            completion(supportInformation?._consoleSupportInformation, error)
        }
    }
}
