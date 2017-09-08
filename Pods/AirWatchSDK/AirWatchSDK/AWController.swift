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
import AWPresentation
import AWLocalization
import AWServices
import AWError
import AWOpenURLClient

@objc
public final class AWController: NSObject {
    /** Error to keep track to report to the application and block from allowing application usage */
    internal var sdkSetupOperationError: AWSDKError.Setup? = nil
    internal static let sharedInstance = AWController()
    internal var presenter: SDKQueuePresenter = MainQueueSDKPresenter()
    internal var context: SDKContext = ApplicationDataStore()
    internal var authHandler: URLChallengeController  /// Used by extension AWController+AuthenticationHelper
    internal var commandHandlers: [CommandHandler] = []
    internal var applicationEventsMonitoringOptions: ApplicationEventsMonitoringOptions = .none
    internal var openURLResponseDelayAlarm: Timer? = nil
    /**
     Returns current AirWatch SDK Version.
     */
    public let AWSDKVersion: String = "17.6"

    public static func clientInstance() -> AWController { return sharedInstance }

    /**
     Delegate to receieve events such as recieved profiles, locked, initialCheckDone etc.
     - Note:
        Since AWController is a singleton, setting this delegate will reset previously set delegate.
     -
     */
    public weak var delegate: AWControllerDelegate? = nil

    /**
     Delegate to receieve events regarding command processor.
     If your application supports commands delivered by the console, you can listen to events such
     as started loading commands, failed and finished loading commands.
     - Note:
     Since AWController is a singleton, setting this delegate will reset previously set command management delegate.
     -
     */
    public weak var commandManagementDelegate: ControllerCommandManagementDelegate? = nil

    /**
     Callback scheme for the application to be used to flip to Anchor Applications and back from it.
     */
    public var callbackScheme: String  = ""

    /**
     APNS Token to pass to console for push noticiations regarding profiles, etc.
     */
    public var APNSToken: String {
        get {
            return self.context.latestAPNSToken ?? ""
        }
        set {
            self.context.latestAPNSToken = newValue
            SDKBeaconTransmitter.sharedTransmitter.sendBeacon(updatedAPNSToken: newValue, completion: nil)
        }
    }

    public internal(set) var requestingProfiles: [String]  = [AWSDK.ConfigurationProfileType.sdk.StringValue]

    public override init() {
        authHandler = URLChallengeController(context: context)
        super.init()
        #if sdk_mixpanel_data_collection_enabled
            SDKMixpanelDataCollectionService.configureDataCollection(shouldCollectData: true)
        #endif
        self.monitorApplicationEvents()
        
    }

    public func start() {
        
        EnrollmentInformationVerificationOperation.lastknownEnrollmentStatus = .unknown
        ConfigurationProfilesSetupOperation.configurationFetchTimestamp = TimeInterval(0)
        ConfigurationProfilesSetupOperation.fetchedProfiles = []
#if sdk_mixpanel_data_collection_enabled
        SDKMixpanelDataCollectionService.sharedInstance?.time(event: SDKLifeCycleEvent.Start)
#endif
        self.applicationEventsMonitoringOptions = .sdkSetupInProgressOptions
        self.refreshSDK()
    }
    
    public func sync() {
        self.refreshSDK()
    }

    public func refreshSDK() {
        self.sdkSetupOperationError = nil
        self.presenter.reset()
        SDKOperationQueue.reset()

        let setupOperation = SDKSetupOperation(sdkController: self, presenter: self.presenter, dataStore: self.context)
        DispatchQueue.background.async {
            SDKOperationQueue.sharedQueue.addOperation(setupOperation)
        }
    }

    public func handleOpenURL(_ url: URL?, fromApplication: String?) -> Bool {
        //check if we can handle
        
        guard let receievedURL = url else {
            log(info: "no url receieved, cannot handle")
            return false
        }

        return self.handleResponse(url: receievedURL, fromApplication: fromApplication)
        
    }
}

internal extension AWController {

    internal func updateDelegateBasicCheckDone() {
        var sdkInitialized = false
        
        switch (self.sdkSetupOperationError, self.sdkSetupOperationError?.shouldBlockApplicationFromMovingForward) {
            
        case (nil, _):
            sdkInitialized = true
            log(info: "🏁🏁🏁 SDK Initialized without any errors  🏁🏁🏁")
            self.applicationEventsMonitoringOptions = .sdkSetupCompleteOptions
            self.startObservingHMACChanges()
            
        case (_, false?):
            sdkInitialized = true
            log(info: "🏁🏁🏁 SDK Initialized without any blocking errors  🏁🏁🏁")
            self.applicationEventsMonitoringOptions = .sdkSetupCompleteOptions
            self.startObservingHMACChanges()
            
        default:
            sdkInitialized = false
            log(error: "❌❌❌ SDK Initialization failed with error: \(String(describing: self.sdkSetupOperationError)) ❌❌❌")
            self.applicationEventsMonitoringOptions = .sdkSetupFailedOptions
        }

        #if sdk_mixpanel_data_collection_enabled
            SDKMixpanelDataCollectionService.sharedInstance?.track(event: SDKLifeCycleEvent.initialization(sdkInitialized, self.sdkSetupOperationError?.errorDescription))
        #endif

        self.presenter.dismissNonBlockingViewControllers()
        DispatchQueue.main.async {
            self.delegate?.controllerDidFinishInitialCheck(error: self.sdkSetupOperationError?.error)
        }
        log(warning: "Sent controllerDidFinishInitialCheck(error: \(String(describing: self.sdkSetupOperationError?.errorDescription)))")
    }

    internal func updateDelegateThoroughCheckDone() {
        self.presenter.dismissNonBlockingViewControllers()
        DispatchQueue.main.async {
            self.delegate?.controllerDidCompleteVerificationWithServer?(success: self.sdkSetupOperationError == nil, error: self.sdkSetupOperationError?.error)
        }
    }

    /**
     @brief Decides if the error is worth saving for later use when updateDelegateBasicCheckDone() or updateDelegateThoroughCheckDone() is called
     @description When an error is passed into this function, the function will store the variable in sdkSetupOperationError if it is an error worth saving to later pass to the function initialCheckDone with error.

     @return Is this error worth stoping the setup? If the error is severe then true will be returned and the task should not continue.
     */
    internal func setupEncounteredFailure(error: AWSDKError.Setup) {
        self.sdkSetupOperationError = error
    }
}
