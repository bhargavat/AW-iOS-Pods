//
//  AWTunnelService.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWHelpers
import Foundation


/**
    This class would be the bridge between Swift SDK and Objective C classes.

    Note that all public functions here are not thread or re-entrant safe. So please avoid calling them
    within multithreaded context.
 */

enum AWTunnelServiceNotifications : String {
    case MAGCertCleared = "AWTunnelMAGCertCleared"
    
    func getNotifcation() -> Notification? {
        switch self {
        case .MAGCertCleared:
            return Notification.init(name:Notification.Name.init(self.rawValue))
        default:
            return nil
        }
    }
    
    
}

public typealias ProxySetupCompletion = (_ success: Bool, _ error: NSError?) -> Void
public typealias TunnelWipeStorageCompletion = (_ magCertClearError: NSError?,  _ F5KeyClearError: NSError?) -> Void

@objc
open class AWTunnelService: NSObject {
    open static let sharedInstance = AWTunnelService()

    private var deviceServices: DeviceServices? = nil

    private var setupCompletion: ProxySetupCompletion? = nil

    static let sem : DispatchSemaphore = DispatchSemaphore.init(value: 0);
    static let setupQ : DispatchQueue = DispatchQueue.init(label: "AWTunnel.setup-queue")
    static let serialQueue : DispatchQueue = DispatchQueue.init(label: "AWTunnel.serial.Queue")
    private var _proxySetupDone: Bool = false
    private var proxySetupDone : Bool {
        get {
            var returnVal : Bool = false
            AWTunnelService.serialQueue.sync {
                returnVal = self._proxySetupDone
            }
            return returnVal
        }
        
        set {
            AWTunnelService.serialQueue.sync {
                self._proxySetupDone = newValue
            }
        }
    }
    
    private var proxy : AWProxy
    private var signer : AWRequestSigner
    fileprivate var proxyPayload : ProxyPayload?
    fileprivate var certPayload : CertificatePayload?


    override init() {
        proxy = AWProxy.sharedInstance()
        signer = AWRequestSigner.sharedInstance()
        super.init()
        
        if let notification = AWTunnelServiceNotifications.MAGCertCleared.getNotifcation() {
            NotificationCenter.default.addObserver(self, selector: #selector(MAGCertCleared), name: notification.name, object: nil)
        }
        
        
    }
    
    /**
     Initialize core classes
     */
    open func boot(deviceServices: DeviceServices) {
        
        self.deviceServices = deviceServices
        let proxyCertService = AWProxyCertService(deviceServices: deviceServices)
        proxy.proxyCertService = proxyCertService
        signer.proxyCertService = proxyCertService
    }

    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func MAGCertCleared() {
        self.proxySetupDone = false
    }

    
    
    open func configureSSO(username: String, password: String) {
        let proxy = AWProxy.sharedInstance()
        proxy.username = username
        proxy.password = password
    }

    open func startProxy(proxyPayload: ProxyPayload?, certificatePayload certPayload:CertificatePayload?, forceRestart: Bool,completion: @escaping ProxySetupCompletion) {
        
        log(info: "Enqueue tunnel setup operation")
        AWTunnelService.setupQ.async {
            
            log(info: "begin tunnel setup")
            self.certPayload = certPayload
            
            if forceRestart {
                self.proxySetupDone = false
            }
            
            self.startProxyWithProxyProfile(proxyPayload) { success,err in
                
                completion(success,err)
                AWTunnelService.sem.signal()
                
                log(info: "tunnel setup end")
            }
            
            AWTunnelService.sem.wait()
            log(info: "tunnel setup operation compelete")
        }

    }
    
    
    private func startProxyWithProxyProfile(_ proxyPayload: ProxyPayload?, completion: @escaping ProxySetupCompletion) {
        
        guard
            let payload  = proxyPayload,
            let proxyHost = payload.hostName
            else {
                log(error: "Incomplete poxy information")
                completion(false,nil)
                return
        }
        
        
        var shouldSetupProxy = true;
        
        if self.proxySetupDone {
            
            let httpsPort = payload.httpsPort
            let httpPort = payload.httpPort
            
            if self.proxy.isEnabled,
                let host = self.proxy.host, host == payload.hostName &&
                self.proxy.httpsPort == httpsPort &&
                self.proxy.httpPort == httpPort {
                shouldSetupProxy = false;
                log(info: "Proxy already running for \(proxyHost):[\(httpsPort)/\(httpPort)]")
            }

        }
        
        if shouldSetupProxy {
            self.setupCompletion = completion
            startProxy(payload)
        }
            
        else {
            completion(true,nil)
        }
        
    }

    open func stopProxy(willWipeStorage wipe: Bool) {

        log(info: "Stopping proxy")
        
        if (wipe) {
            wipeStorage()
        }
        
        self.proxy.stop()
        proxySetupDone = false
    }

    open func wipeStorage( completionHandler:TunnelWipeStorageCompletion? = nil) {

        /** put in queue to avoid deleting certs when setup is in progress **/
 
        AWTunnelService.setupQ.async {

            let magCertClearError = AWProxyCertService.clearMAGCert()
            let result = Settings.store.clear(SecureItemType.f5SessionKey)
            
            completionHandler?(magCertClearError as NSError?,result.error)
        }

    }

    open var deviceServicesURL: URL? {
        return self.deviceServices?.config != nil ? URL(string: (self.deviceServices?.config.airWatchServerURL)!) : nil
    }

    open var deviceUDID: String? {
        return self.deviceServices?.config.deviceId
    }

    open var bundleID: String? {
        return self.deviceServices?.config.bundleId
    }

    open var F5SessionKey: String? {
        get {
            let valueResult: StorageResult = Settings.store.get(SecureItemType.f5SessionKey, valueType: SettingType.string)
            if valueResult.isSuccess {
                return valueResult.value()! as String
            }
            return nil
        }

        set (key) {
            guard Settings.store.set(SecureItemType.f5SessionKey,
                                       value: key).isSuccess else {
                                        log(error: "cannot store the value for 'F5 session key' to the keychain")
                                        return
            }
        }
    }

    @objc

    fileprivate func startProxy(_ object: ProxyPayload) {
        
        log(info: "Setting up proxy")
        self.proxyPayload = object
        let proxyHandler = AWProxyHandler.sharedInstance()
        proxyHandler?.delegate = self as (AWProxyDelegate & AWProxySetupDelegate)
        proxyHandler?.setupProxy(proxyPayload) { (success, error) in
            if success {
                log(debug: "Tunnel Proxy is successfully started")
            } else {
                log(error: "Tunnel Proxy setup error: \(error?.localizedDescription)")
            }
            
            self.proxySetupDone = success
            self.setupCompletion?(success, error as? NSError)
        }
        
    }
}

public extension UIDevice {
    
    var WiFiMACAddress: String? {
        return  UIDevice.current.aw_networkAdapters()
                .filter{ $0 is AWNetworkAdapter}
                .map{ $0 as! AWNetworkAdapter }
                .filter{ $0.name == "en0" }
                .first?.macAddress?
                .replacingOccurrences(of: ":", with: "")
    }
}

extension AWTunnelService: AWProxySetupDelegate {
    
    //MARK: AWProxySetupDelegate
    public func certificateData() -> Data? {
        guard
            let payload = self.certPayload,
            let certData = payload.certificateData
            else {
                return nil
        }
        
        return certData
    }
    
    public func certificatePassword() -> String? {
        guard
            let payload = self.certPayload,
            let certPasswd = payload.certificatePassword
            else {
                return nil
        }
        
        return certPasswd
    }
}

extension AWTunnelService: AWProxyDelegate {
    //MARK: AWProxyDelegate
    public func proxyConnectionFailed(_ reason: AWProxyFailureReason) {
        log(error: "Proxy setup failed. Reason: \(reason.rawValue)")
        #if sdk_mixpanel_data_collection_enabled
            SDKMixpanelDataCollectionService.sharedInstance?.update(userSetting: SDKSettings.proxyEnabled(false))
        #endif
        //TODO: handle proxy connection failure
    }
}
