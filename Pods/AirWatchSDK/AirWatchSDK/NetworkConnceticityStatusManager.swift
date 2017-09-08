//
//  OfflineAccessManager.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWHelpers
import AWNetwork
import AWLocalization
import AWStorage
import Alamofire
import AWError

extension AWError.SDK {
    internal enum ConnectivityTest: AWErrorType {
        case invalidURL
        case connectionTimedOut
        case notConnectedToInternet
        case urlError
        case unknown
    }
}

internal final class NetworkConnectivityStatusManager {
    internal static let sharedInstance = NetworkConnectivityStatusManager()
    internal private(set) var currentNetworkReachabilityStatus: NetworkReachabilityStatus? = nil
    internal var networkAccessSettings: NetworkAccessPayload? = nil
    internal var offlineAccessSettings: OfflineAccessPayload? = nil
    internal var reachabilityCheckHostname: String? = nil
    
    internal var networkActivtyStatusUpdateHandler: ((_ status: AWSDK.NetworkActivityStatus) -> Void)? = nil
    internal var offlineAccessBlockHandler: ((_ shouldBlock: Bool) -> Void)? = nil
    
    internal var whitelistedSSIDs: [String] = ["*"] //By default allow all SSIDs to connect
    internal var allowCellularConnection = AWSDK.AllowCellularNetworkAccess.always
    internal let localStorage = AWSettingsDatabase.getDatastore("Settings")
    internal var offlineTimer: Timer? = nil
    internal var reachability = Reachability.forInternetConnection
    
    deinit {
        self.stop()
    }
    
    internal static func canConnectTo(host: String, completion: @escaping (_ result: Bool, _ error: Error?) -> Void) {
        let sampleDeviceIdentifier = "abcdef1234567890abcdef1234567890abcdef12"
        let statusEndpoint = "\(host)/deviceservices/awmdmsdk/v1/platform/2/uid/\(sampleDeviceIdentifier)/status"
        guard let requestURL = URL(string: statusEndpoint) else {
            completion(false, AWError.SDK.ConnectivityTest.invalidURL)
            return
        }
        let request = NSMutableURLRequest(url: requestURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15.0
        let session = URLSession.shared
        
        session.dataTask(with: request as URLRequest, completionHandler: {(data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                log(info: "httpResponse.statusCode for Ping: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                    return
                }
            }
            var connectivityError = AWError.SDK.ConnectivityTest.urlError
            guard let returnedError = error as? URLError else {
                log(error: "recieved unknown error: \(String(describing: error?.localizedDescription)) for connectivity test")
                completion(false, AWError.SDK.ConnectivityTest.unknown)
                return
            }
            
            switch returnedError.code {
            case .timedOut:
                connectivityError = AWError.SDK.ConnectivityTest.connectionTimedOut
                fallthrough
            case .notConnectedToInternet:
                connectivityError = AWError.SDK.ConnectivityTest.notConnectedToInternet
                break
            default:
                log(error: "recieved error: \(String(describing: returnedError.localizedDescription)) for connectivity test")
                break
            }
            completion(false, connectivityError)
        }).resume()

    }

    private func applyReachabilitySettings() {
        if let hostname = self.reachabilityCheckHostname {
            self.reachability = Reachability(hostname: hostname)
        } else {
            self.reachability = Reachability.forInternetConnection
        }
        self.start()
    }
    
    private func applyOfflineSettings(){
        guard
            let offlineSettings = self.offlineAccessSettings
        else {
            self.lastSeenOffline = nil
            self.maximumSecondsAllowedOffline = nil
            self.offlineTimer?.invalidate()
            self.offlineTimer = nil;
            log(info: "Not monitoring Offline⟷Online Activity")
            return
        }
        self.maximumSecondsAllowedOffline = offlineSettings.maximumSecondsAllowedOffline
        log(info: "Max allowed seconds offline is \(offlineSettings.maximumSecondsAllowedOffline)")
    }

    private func applyNetworkAccessSettings() {
        guard
            let networkSettings = self.networkAccessSettings,
            networkSettings.allowWifiConnection  == .filter
            else {
                self.whitelistedSSIDs = ["*"]
                self.allowCellularConnection = self.networkAccessSettings?.allowCellularConnection ?? .always
                log(info: "Allowing to connect using any WiFi or cellular network (including Data Connections on Roaming as well)")
                return
        }
        self.whitelistedSSIDs = networkSettings.allowedSSIDs.filter{ $0 != ""}
        self.allowCellularConnection = networkSettings.allowCellularConnection
        log(info: "Whitelisted SSIDs: \(self.whitelistedSSIDs)")
        log(info: "Allow Cellular Connection: \(self.allowCellularConnection.rawValue)")
    }
    
    @objc
    internal func handleNetworkStatusUpdate(_ notification: Notification) {
        self.evaluateDeviceConnectivityPolicy()
        self.evaluateDeviceNetworkAccessPolicy()
    }
    
    private func evaluateDeviceConnectivityPolicy() {
        
        self.currentNetworkReachabilityStatus = self.reachability?.currentReachabilityStatus
        let isDeviceOnline = (self.reachability?.currentReachabilityStatus != .notReachable)
        let shouldAllowOfflineAccess = self.offlineAccessSettings?.enableOfflineAccess ?? true
        log(debug: "Network is reachable:\(isDeviceOnline), Offline Access Allowed: \(shouldAllowOfflineAccess)");
        let allowDeviceAccess = { [weak self] in
            if let timer = self?.offlineTimer {
                log(debug: "Offline Blocking Timer invalidated. Time left Until: \(timer.fireDate). Current Time: \(Date())")
                timer.invalidate()
                self?.offlineTimer = nil;
                
            }
            log(debug: "Resetting Last see offline timestamp!")
            self?.lastSeenOffline = nil
            
            log(debug: "Asking the handler to stop blocking the user from using the app!")
            self?.offlineAccessBlockHandler?(false)
        }
        
        let handleOfflineAccess = {[weak self] in
            //Record last seen offline
            let offlineStartedTimestamp = self?.lastSeenOffline ?? Date().timeIntervalSince1970
            if self?.lastSeenOffline == nil {
                self?.lastSeenOffline = offlineStartedTimestamp
                log(debug: "Setting Last Seen Offline: \(String(describing: self?.lastSeenOffline))")
            }
            
            //Check if we should restrict offline access.
            guard shouldAllowOfflineAccess else {
                self?.offlineAccessBlockHandler?(true)
                return
            }
            
            guard let maximumSecondsAllowedOffline = self?.maximumSecondsAllowedOffline else {
                log(error: "Last Seen Offline: \(String(describing: self?.lastSeenOffline)) MaximumSecondsAllowedOffline: \(String(describing: self?.maximumSecondsAllowedOffline)), Can not Block Offline Access.")
                allowDeviceAccess()
                return
            }

            /**
             When the user's networks becomes offline when networkChanged is called, then that timestamp is saved in local storage when offline occured. This saved timestamp is then added to the maximum seconds allowed seconds to be offline and is compared with the current timestamp.
             If the current timestamp is greater than the timestamp saved when offline occured plus the maximum allowed seconds, then we return true because the user has been offline for more time than is allowed.
             If the user has never been offline or set, and the maximum seconds allowed is not set, then false is returned
             */

            guard maximumSecondsAllowedOffline != 0 else {
                self?.offlineAccessBlockHandler?(false)
                return
            }

            let totalTimeOffline = (Date().timeIntervalSince1970 - offlineStartedTimestamp)
            let remainingTimeOffline = maximumSecondsAllowedOffline - totalTimeOffline
            let shouldBlockOfflineAccess = (remainingTimeOffline <= 0)
            log(info: "Should Block Offline Access?: \(shouldBlockOfflineAccess)")
            if shouldBlockOfflineAccess {
                self?.offlineAccessBlockHandler?(true)
                return
            }
            self?.startCountingTimerToBlockOfflineAccess(for: remainingTimeOffline)
            self?.offlineAccessBlockHandler?(false)
        }
        
        if isDeviceOnline {
            allowDeviceAccess()
            return
        }
        
        self.doubleCheckConsoleReachability { (isConnected) in
            if isConnected{
                allowDeviceAccess()
            } else {
                handleOfflineAccess()
            }
        }
    }
    
    @objc
    fileprivate func maximumAllowedOfflineTimeReached() {
        self.offlineTimer?.invalidate()
        log(warning: "Reached the maximumSecondsAllowedOffline for Offline Policy Manager")
        log(warning: "Will take action since the user has been ofline too long")
        log(warning: "Will call maxTimeAllowedOfflineReached")
        self.offlineAccessBlockHandler?(true)
    }
    
    private func startCountingTimerToBlockOfflineAccess(for timeInterval: TimeInterval) -> Void {
        log(info: "Network Connectivity is no longer available. Will block app usage after: \(timeInterval)")
        self.offlineTimer?.invalidate()
        if timeInterval <= 0 {
            self.maximumAllowedOfflineTimeReached()
            return
        }
        
        self.offlineTimer = Timer.scheduledTimer(timeInterval: timeInterval,
                                                 target: self,
                                                 selector: #selector(self.maximumAllowedOfflineTimeReached),
                                                 userInfo: nil,
                                                 repeats: false)
        log(warning: "Starting count down Timer.")
        log(warning: "Offline Access will be blocked on/at: \(Date(timeIntervalSinceNow: timeInterval))")
    }
    
    private func evaluateDeviceNetworkAccessPolicy() {
        let isDeviceOnline = (self.currentNetworkReachabilityStatus != .notReachable)
        guard isDeviceOnline else {
            return
        }


        self.reachability?.evaluateConnectedNetworkActivityStatus(allowedSSIDS: self.whitelistedSSIDs,
                                                                  cellularAccess: AllowCellularNetworkAccess(rawValue: self.allowCellularConnection.rawValue) ?? .always) { [weak self] (networkActivityStatus, error) in
            self?.networkActivtyStatusUpdateHandler?(error != nil ? .unknown : AWSDK.NetworkActivityStatus(rawValue: networkActivityStatus.rawValue) ?? .unknown)
        }
    }
    
    internal func refresh() {
        log(info: "Starting enforcer for NetworkAccess and OfflineAccess Payloads")
        self.applyOfflineSettings()
        self.applyNetworkAccessSettings()
        self.applyReachabilitySettings()
        self.evaluateDeviceConnectivityPolicy()
        self.evaluateDeviceNetworkAccessPolicy()
    }

    private func start() {
        log(debug: "Network Status Manager: Start")
        self.reachability?.startReachabilityMonitoring()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusUpdate), name: NSNotification.Name.AWReachabilityDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusUpdate), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    private func stop() {
        log(debug: "Network Status Manager: Stop")
        self.reachability?.stopReachabilityMonitoring()
        NotificationCenter.default.removeObserver(self)
        self.offlineTimer?.invalidate()
    }
    
    private func doubleCheckConsoleReachability(completion:@escaping (_ connected: Bool)->()) {
        guard let reachbilityHost = self.reachabilityCheckHostname else {
            completion(false)
            return
        }
        
        Alamofire.request(reachbilityHost).responseData { (response) in
            guard let error = response.result.error as? URLError else {
                completion(true)
                return
            }
            
            switch error.code {
            case .internationalRoamingOff: fallthrough
            case .callIsActive: fallthrough
            case .dataNotAllowed: fallthrough
            case .notConnectedToInternet:
                completion(false)
            
            default:
                completion(true)
            }
            
        }                  
    }

    internal func checkReachabilityNetworkActivityStatus(compeltion:@escaping (_ status: AWSDK.NetworkActivityStatus) -> Void) {
        self.reachability?.evaluateConnectedNetworkActivityStatus(allowedSSIDS: self.whitelistedSSIDs,
                                                                  cellularAccess: AllowCellularNetworkAccess(rawValue: self.allowCellularConnection.rawValue) ?? .always)
        {(networkActivityStatus, error) in
            compeltion(error != nil ? .unknown : AWSDK.NetworkActivityStatus(rawValue: networkActivityStatus.rawValue) ?? .unknown)
        }
    }
}

private let OfflinePolicyTime: String = "OfflinePolicyTime"
private let MaximumSecondsAllowed = "MaximumSecondsAllowed"

fileprivate extension NetworkConnectivityStatusManager {
    fileprivate var reachabilityNetworkStatus: NetworkReachabilityStatus? {
        return reachability?.currentReachabilityStatus
    }
    
    fileprivate  var lastSeenOffline: TimeInterval? {
        get {
            guard let offlineTimestamp: Double = self.localStorage.get(OfflinePolicyTime) else {
                log(error: "Could not get OfflinePolicyTime")
                return nil;
            }
            return offlineTimestamp
        }
        set {
            if !self.localStorage.set(OfflinePolicyTime, value: newValue) {
                log(error: "Could not save OfflinePolicyTime")
            }
        }
    }
    /**
     Set the max amount of time that is allowed to be offline. If the application is forcefully shutdown, maximumSecondsAllowedOffline will pull from the local storage the value saved.
     */
    fileprivate var maximumSecondsAllowedOffline: TimeInterval? {
        get {
            guard let maxSecondsAllowedOffline: Double = localStorage.get(MaximumSecondsAllowed) else {
                log(error: "Could not get from local storage \(MaximumSecondsAllowed)")
                return nil
            }
            return maxSecondsAllowedOffline
        }set {
            log(info: "Setting Maximum Allowed Time for Offline Policy Manager with time in seconds \(String(describing: newValue))")
            if !self.localStorage.set(MaximumSecondsAllowed, value: newValue) {
                log(error: "Could not save into local storage \(MaximumSecondsAllowed)")
            }
        }
    }
    
}
