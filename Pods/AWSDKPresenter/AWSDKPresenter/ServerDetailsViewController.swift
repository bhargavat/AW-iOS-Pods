//
//  ServerDetailsViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import AWLocalization
import Foundation
import UIKit

open class ServerDetailsViewController: BaseViewController {

    open weak var serverDelegate: ServerDetailsViewControllerDelegate?

    @IBOutlet open weak var serverURLTextField: SDKUITextField?
    @IBOutlet open weak var serverGroupIDTextField: SDKUITextField?
    @IBOutlet open weak var cancelButton: UIButton?
    @IBOutlet open weak var nextButton: UIButton?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    @IBOutlet weak var scanForQRCodeButton: UIButton?
    
    open var serverURL: String?
    open var serverGroupID: String?
    open var canUseCameraToScanQRCode: Bool = false
    internal var serverURLHasChanged: Bool = false
    internal var serverGroupIDHasChanged: Bool = false

    override open func viewDidLoad() {
        super.viewDidLoad()
        _ = serverURLTextField?.becomeFirstResponder()
        self.cancelButton?.isHidden = false
        self.cancelButton?.isEnabled = true
        self.cancelButton?.alpha = AWColor.enabledAlphaValue

        self.nextButton?.isEnabled = false
        self.nextButton?.isHidden = true
        
        self.serverURLTextField?.delegate = self
        self.serverURLTextField?.autocorrectionType = UITextAutocorrectionType.no
        self.serverGroupIDTextField?.delegate = self
        self.serverGroupIDTextField?.autocorrectionType = UITextAutocorrectionType.no
        if ((self.serverURL?.contains(" ")) != true) {
            self.serverURLTextField?.text = serverURL
        } else {
            self.serverURLTextField?.text = nil
        }
        self.serverGroupIDTextField?.text = serverGroupID
        
        if let serverURLTextCount = self.serverURLTextField?.text?.characters.count, serverURLTextCount > 0,
            let serverGroupIDTextCount = self.serverGroupIDTextField?.text?.characters.count, serverGroupIDTextCount > 0 {
        }
        
        
        // If this key is not found in the app's Info.plist on an iPhone, the iPhone will crash. So if the key/value pair isn't found, disable button to access the camera.
        let reasonForCameraUsage = Bundle.main.infoDictionary?["NSCameraUsageDescription"]
        self.canUseCameraToScanQRCode = !(reasonForCameraUsage == nil)
        if self.canUseCameraToScanQRCode == false {
            self.scanForQRCodeButton?.isEnabled = false
            self.scanForQRCodeButton?.isHidden = true
        }
        
        self.enableUIElementsForUserInput()
        
        self.serverURLTextField?.addTarget(self, action: #selector(areTextFieldsValid), for: UIControlEvents.editingChanged)
        self.serverGroupIDTextField?.addTarget(self, action: #selector(areTextFieldsValid), for: UIControlEvents.editingChanged)
    }
    
    @IBAction open func nextButtonPressed() {
        guard
            let serverURLString = self.serverURLTextField?.text,
            let serverGroupIDString = self.serverGroupIDTextField?.text
        else {
            log(error: "Either server URL or group id is nil")
            return
        }
        
        // This guard should never execute since if the user does not enter either of server url or group id then ok button should be disabled
        guard serverURLString != "" || serverGroupIDString != "" else {
            let msg = AWSDKLocalization.getLocalizationString("EmptyServerDetailsErrorMessage")
            let alert = KeyWindowAlert(title: nil, message: msg)
            _ = alert.show()
            return
        }
        
        self.stopObservingApplicationLifecycleNotifications()
        self.disableUIElementsWhileProcessing()
        
        // We assign these variables because if the user has entered an invalid url and then attempts to add the same URL, the URLs must be different or else the Ok button will not be grayed out.
        self.serverURL = serverURLString
        self.serverGroupID = serverGroupIDString
        
        self.activityIndicator?.startAnimating()
        self.serverDelegate?.validateServerDetails(serverURLString,
                                              organizationGroup: serverGroupIDString,
                                              completionHandler: { [weak self] (success: Bool) in
                                                DispatchQueue.main.async { [weak self] in
                                                    if success == false {
                                                        _ = self?.serverURLTextField?.becomeFirstResponder()
                                                    }
                                                    self?.startObservingApplicationLifecycleNotifications()
                                                    self?.enableUIElementsForUserInput()
                                                }
        })
    }
    
    //call to "grey out" and disable all buttons. Used while networking is happening
    override func disableUIElementsWhileProcessing() {
        self.activityIndicator?.startAnimating()
        self.nextButton?.isEnabled = false
        self.serverURLTextField?.disable()
        self.serverGroupIDTextField?.disable()
        if self.canUseCameraToScanQRCode {
            self.scanForQRCodeButton?.alpha = AWColor.disabledAlphaValue
            self.scanForQRCodeButton?.isEnabled = false
        }
        
        self.cancelButton?.isEnabled = false
        self.cancelButton?.alpha = AWColor.disabledAlphaValue
    }
    
    override func enableUIElementsForUserInput() {
        self.activityIndicator?.stopAnimating()
        _ = self.areTextFieldsValid()
        self.serverURLTextField?.enable()
        self.serverGroupIDTextField?.enable()
        if self.canUseCameraToScanQRCode {
            self.scanForQRCodeButton?.alpha = AWColor.enabledAlphaValue
            self.scanForQRCodeButton?.isEnabled = true
        }
        
        self.cancelButton?.isEnabled = true
        self.cancelButton?.alpha = AWColor.enabledAlphaValue
    }
    
    @IBAction open func cancelButtonPressed() {
        log(debug: "User did dismiss server details view controller")
        self.serverDelegate?.userDidDismissServerDetailsViewController()
    }
    
    @objc
    internal func areTextFieldsValid() -> Bool {
        guard let newServerURLString = (serverURLTextField?.text as NSString?), let newServerGroupIDString = (serverGroupIDTextField?.text as NSString?) else {
            return false
        }
        
        let areBothTextFieldsNotEmpty = newServerURLString != "" && newServerGroupIDString != ""
        
        if (areBothTextFieldsNotEmpty) {
            self.nextButton?.isEnabled = true
            self.nextButton?.isHidden = false
            return true
        } else {
            self.nextButton?.isHidden = true
            self.nextButton?.isEnabled = false
        }
        
        return false
    }
    
    //MARK:- UITextField Delegate Methods
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if self.nextButton?.isEnabled == true {
            self.nextButtonPressed()
            return true
        } else if textField == serverURLTextField {
            _ = self.serverGroupIDTextField?.becomeFirstResponder()
        } else if textField == serverGroupIDTextField {
            _ = self.serverURLTextField?.becomeFirstResponder()
        }
        
        return false
    }
}
