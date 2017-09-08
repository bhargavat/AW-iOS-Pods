//
//  AWController+OpenURL.swift
//  AirWatchSDK
//
//  Created by Anuj Panwar on 4/5/17.
//  Copyright © 2017 VMWare, Inc. All rights reserved.
//

import Foundation
import AWOpenURLClient
import AWHelpers
import AWLocalization
import AWError

extension AWError.SDK {
    public enum OpenURLRequestFailed: AWErrorType {
        case FailedToFetchEnvironmentDetailsFromAirWatchApplication
        case CallBackSchemeNotAssigned
        case AirWatchApplicationSchemeNotWhitelisted
        case AirWatchApplicationNotInstalled
        case InternalError
    }
}

extension AWController {
    
    var isExpectingOpenURLResponse: Bool {
        return OpenURLHandler.currentRequest != nil
    }
    
    var canHandleOpenURLRequest: Bool {
        return OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed == false
    }
    
    //Environment Information Request
    func fetchEnvironmentInformationForThirdPartyApplication() -> (Bool, AWErrorType?) {
        guard self.canHandleOpenURLRequest else {
            log(error: "cannot process request, has already attempted once and failed")
            return (false,  AWError.SDK.OpenURLRequestFailed.FailedToFetchEnvironmentDetailsFromAirWatchApplication)
        }
        
        guard self.isExpectingOpenURLResponse == false else {
            log(error: "cannot handle, already handling: \(String(describing: OpenURLHandler.currentRequest))")
            return (false,  AWError.SDK.OpenURLRequestFailed.InternalError)
        }
        let anchorHelper = AirWatchAnchor(context:self.context)
        
        guard anchorHelper.isAirWatchAnchorSchemeWhitelisted else {
            log(error: "cannot process request, airwatch application scheme not whitelisted")
            return (false,  AWError.SDK.OpenURLRequestFailed.AirWatchApplicationSchemeNotWhitelisted)
        }
        
        let appScheme = self.callbackScheme
        guard appScheme.characters.count > 0 else {
            log(error: "error creating a OpenURL request, no callback scheme assigned")
            return (false,  AWError.SDK.OpenURLRequestFailed.CallBackSchemeNotAssigned)
        }
        
        var requestURL :URL? = nil
        if let anchorScheme = anchorHelper.workspaceOneScheme {
            requestURL = OpenURLHandler.createOpenURLRequestForEnvironmentInformation(anchorScheme: anchorScheme, appScheme: appScheme)
            openURL(requestURL: requestURL, requestType: .EnvironmentInformation)
            return (true, nil)
        }
        
        if let anchorScheme = anchorHelper.agentScheme ?? anchorHelper.workspaceScheme {
            log(info: "creating request for anchorScheme: \(anchorScheme)")
            requestURL = OpenURLHandler.createRegisterApplicationRequest(anchorScheme: anchorScheme, appScheme: appScheme)
            openURL(requestURL: requestURL, requestType: .RegisterApplication)
            return (true, nil)
        }
        log(error: "no anchor scheme found to fetch Environment Information")
        
        return (false,  AWError.SDK.OpenURLRequestFailed.AirWatchApplicationNotInstalled)
    }
    
    //handle response from anchor app
    func handleResponse(url: URL, fromApplication: String?) -> Bool {
        guard let response = OpenURLHandler.canHandleResponse(responseUrl: url) else {
            log(info: "no a known response type")
            return false
        }
        
        //invalidate
        log(info: "Received expected response from anchor. Invalidating openurl response alarm")
        self.invalidateOpenURLResponseDelayAlarm()
        
        log(info: "Response type recieved is: \(response.rawValue)")
        switch response {
        case .EnvironmentInformation:
            
            let (response, error) = OpenURLHandler.createEnvironmentInformation(responseURL: url)
            guard let successfullResponse = response else {
                if let openURLError = error as? OpenURLError {
                    let receivedError = openURLError.errorDescription
                    log(error: "ErrorResponse received from anchor app:\(String(describing: receivedError))")
                }
                OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed = true
                log(error: "failed to receive correct OpenURLResponse")
                break
            }
            //save
            let enrollmentInfo = self.createEnrollmentInformation(serverURL: successfullResponse.serverURL, organizationGroup: successfullResponse.orgGroup, deviceID: successfullResponse.airwatchID)
            self.context.enrollmentInformation = enrollmentInfo
            OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed = false
            break
            
        case .RegisterApplication:
            
            let (response, error) = OpenURLHandler.createResponseForRegisterApplication(responseURL: url)
            guard let successfullResponse = response else {
                if let openURLError = error as? OpenURLError {
                    let receivedError = openURLError.errorDescription
                    log(error: "ErrorResponse received from anchor app:\(String(describing: receivedError))")
                }
                OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed = true
                log(error: "failed to receive correct OpenURLResponse")
                break
            }
            //save
            let enrollmentInfo = self.createEnrollmentInformation(serverURL: successfullResponse.serverURL, organizationGroup: successfullResponse.orgGroup, deviceID: successfullResponse.airwatchID)
            self.context.enrollmentInformation = enrollmentInfo
            OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed = false
            break
        }
        
        //start SDK after handling URL
        OpenURLHandler.currentRequest = nil
        self.start()
        return true
    }
    
    fileprivate func createEnrollmentInformation( serverURL: String, organizationGroup: String?, deviceID: String) -> EnrollmentInformation {
        let enrollmentInfo = EnrollmentInformation()
        enrollmentInfo.deviceIdentifier = deviceID
        enrollmentInfo.hostname = serverURL
        enrollmentInfo.organizationGroup = organizationGroup
        return enrollmentInfo
    }
    
    fileprivate func openURL(requestURL: URL?, requestType :RequestType) {
        guard let url = requestURL,
            UIApplication.shared.canOpenURL(url)
            else {
                log(error: "cannot open url:\(String(describing: requestURL))")
                return
        }
        OpenURLHandler.currentRequest = requestType
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    //clear OpenURLHandler states
    func resetOpenURLClient() {
        OpenURLHandler.currentRequest = nil
        OpenURLHandler.hasBeenRequestedOnceforThisLaunchAndFailed = false
    }
    
    func setUpOpenURLResponseAlarm() {
        if self.openURLResponseDelayAlarm == nil {
            self.openURLResponseDelayAlarm =
                Timer.scheduledTimer(timeInterval: 5.0, target: self,
                                     selector: #selector(self.showRetryAlertForOpenURLRequest),
                                     userInfo: nil, repeats: false)
        }
    }
    
    func invalidateOpenURLResponseDelayAlarm() {
        self.openURLResponseDelayAlarm?.invalidate()
        self.openURLResponseDelayAlarm = nil
    }
    
    func showRetryAlertForOpenURLRequest() {
        let controller = self

        let retryAction = UIAlertAction(title: AWSDKLocalizedString("Continue"), style: .default) { (_) -> Void in
            controller.invalidateOpenURLResponseDelayAlarm()
            controller.resetOpenURLClient()
            controller.start()
        }
         _ = KeyWindowAlert(title: AWSDKLocalizedString("Notice"), message:
             AWSDKLocalizedString("RetryToFetchConfigurationInformation"),
                            actions: [retryAction]).show()
    }

}

extension OpenURLHandler {
    static var currentRequest: RequestType? = nil
    static var hasBeenRequestedOnceforThisLaunchAndFailed = false
}
