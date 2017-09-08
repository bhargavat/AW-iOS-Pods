//
//  QRViewController.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWLocalization
import AVFoundation
import UIKit

enum QRScannerType {
    case ServerDetails
    case TokenCode
}

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var details: ServerDetails?
    var tokenCode: String?
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet weak var backButton: UIButton?
    @IBOutlet weak var flashButton: UIButton?
    @IBOutlet weak var cameraContainerView: UIView?
    var captureDevice : AVCaptureDevice? = nil
    var scannerType: QRScannerType = .ServerDetails
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSubviews()
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted) in
            if granted {
                log(debug: "User has given application access to the camera")
            } else {
                log(debug: "User choose not to give application access to the camera; returning to previous view controller")
                DispatchQueue.main.async {
                    self.backButtonPressed(UIButton())
                }
            }
        })
    }
    
    //MARK:- IBActions
    
    @IBAction open func backButtonPressed(_ sender: UIButton) {
        _ = navigationController?.popViewController(animated: true)
        switch scannerType {
        case .ServerDetails:
            self.performSegue(withIdentifier: "qrToServerDetails", sender: self)
        case .TokenCode:
            self.performSegue(withIdentifier: "qrToAuthenticationToken", sender: self)
        }
    }
    
    @IBAction func flashButtonTapped(_ sender: UIButton) {
        if let _ = try? captureDevice?.lockForConfiguration() {
            defer {
                captureDevice?.unlockForConfiguration()
            }
            let bundle = Bundle(for: object_getClass(self))
            if (captureDevice?.flashMode == .on) {
                sender.setBackgroundImage(UIImage(named: "NoFlash", in: bundle, compatibleWith:nil), for: .normal)
                captureDevice?.flashMode = .off
            }
            else if(captureDevice?.flashMode == .off) {
                sender.setBackgroundImage(UIImage(named: "Flash", in: bundle, compatibleWith:nil), for: .normal)
                captureDevice?.flashMode = .on
            }
        }
    }
    
    //MARK: Helper Methods
    func configureSubviews() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        addCameraLayer()
        addFlashButtonIfNeeded()
        
    }
    func addFlashButtonIfNeeded() {
        //The button displays the state of flash (i,e Initial State - No Flash)
        flashButton?.isHidden =  !((captureDevice?.hasFlash) ?? false)
    }
    func addCameraLayer() {
        // Get capture device for video
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            // Set up capture input, session and output
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input as AVCaptureInput)
            
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
            
            // Set up video preview layer
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            if videoPreviewLayer != nil {
                cameraContainerView?.layer.addSublayer(videoPreviewLayer!)
            }
            // Start video capture
            captureSession?.startRunning()
        } catch let error as NSError {
            // Handle error of not being able to access the camera?
            let alert = UIAlertController(title: AWSDKLocalization.getLocalizationString("ErrorTitle"), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AWSDKLocalization.getLocalizationString("Dismiss"), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    // MARK: Implementation for AVCaptureMetadataOutputObjectsDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        // If metadataObjects is nil or empty, just return early
        if metadataObjects == nil || metadataObjects.count == 0 {
            return
        }
        
        // PROTOCOL FOR PURPOSES OF UNIT TEST
        if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObjectProtocol {
            if metadataObj.type == AVMetadataObjectTypeQRCode {
                // If QR code, try to read the query
                
                if let qrString = metadataObj.stringValue{
                    switch scannerType {
                    case .ServerDetails:
                        captureServerUrlDetailsFromQR(qrString: qrString)
                    case .TokenCode:
                        captureTokenCodeFromQR(qrString: qrString)
                    }
                    
                }
                
            }
        }
        
    }
    
    func captureServerUrlDetailsFromQR(qrString: String) {
        if let queryItems = URLComponents(string: qrString)?.queryItems {
            if let serverURL = serverURLFromQueryItems(queryItems), let groupID = groupIDFromQueryItems(queryItems) {
                // Successfully extracted server details
                captureSession?.stopRunning()
                details = ServerDetails(serverURL: serverURL, groupID: groupID)
                
                self.performSegue(withIdentifier: "qrToServerDetails", sender: self)
            }
            // Currently silently fails if unable to successfully extract server details
        }
    }
    
    func captureTokenCodeFromQR(qrString: String) {
        tokenCode = qrString
        self.performSegue(withIdentifier: "qrToAuthenticationToken", sender: self)
    }
    
    
    // Helper Methods
    func serverURLFromQueryItems(_ queryItemsOpt: [URLQueryItem]?) -> String? {
        var serverURL: String? = nil
        if let queryItems = queryItemsOpt {
            for queryItem in queryItems {
                if queryItem.name.caseInsensitiveCompare("serverurl") == .orderedSame {
                    serverURL = queryItem.value
                }
            }
        }
        return serverURL
    }
    
    func groupIDFromQueryItems(_ queryItemsOpt: [URLQueryItem]?) -> String? {
        var groupID: String? = nil
        if let queryItems = queryItemsOpt {
            for queryItem in queryItems {
                if queryItem.name.caseInsensitiveCompare("gid") == .orderedSame {
                    groupID = queryItem.value
                }
            }
        }
        return groupID
    }
}

// MARK: Support for unit testing
protocol AVMetadataMachineReadableCodeObjectProtocol {
    var corners: [Any]! {get}
    var stringValue: String! {get}
    var type: String! {get}
}

extension AVMetadataMachineReadableCodeObject:  AVMetadataMachineReadableCodeObjectProtocol {
    
}
