//
//  AWDocumentInteractionController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import QuickLook

import AWCrypto
import AWLocalization
import AWServices

final private class AWQLPreviewController: QLPreviewController, QLPreviewControllerDataSource {
    class PreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        init(previewItemURL: URL?) {
            self.previewItemURL = previewItemURL
            super.init()
        }
    }

    let url: PreviewItem

    init(with url: URL) {
        self.url = PreviewItem(previewItemURL: url)
        self._navigationItem = UINavigationItem(title: url.lastPathComponent)
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    // For an iPod Touch or an iPhone, the share button will be shown on the bottom tool bar
    // This will prevent the share button to be shown
    override var toolbarItems: [UIBarButtonItem]? {
        get { return nil }
        set {}
    }

    // For an iPad, the share button will be shown on the top navgation bar
    // This will prevent the share button to be shown
    private var _navigationItem: UINavigationItem
    override var navigationItem: UINavigationItem {
        get {
            _navigationItem.rightBarButtonItem = nil
            return _navigationItem
        }
        set {
            _navigationItem = newValue
            _navigationItem.rightBarButtonItem = nil
        }
    }

    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.url
    }
}

final public class AWDocumentInteractionController: UIDocumentInteractionController {
    
    fileprivate let fileURL: URL
    fileprivate let isFileEncrypted: Bool
    fileprivate let realInstance: UIDocumentInteractionController
    fileprivate let alertMessage: String
    fileprivate let qlPreviewViewController: AWQLPreviewController

    public var allowedApps: [String]

    public init(url: URL, encrypted: Bool = false) {
        self.fileURL = url
        self.isFileEncrypted = encrypted
        self.realInstance = UIDocumentInteractionController(url: self.fileURL)
        self.alertMessage = AWSDKLocalization.getLocalizationString("AccessAlertMessage")
        self.qlPreviewViewController = AWQLPreviewController(with: self.fileURL)
        self.allowedApps = []
        super.init()

        self.realInstance.delegate = self
    }

    fileprivate var decryptedFileURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileURL.lastPathComponent)
    }

    fileprivate var emptyFileURL: URL {
        return self.fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(self.alertMessage)
            .appendingPathComponent(fileURL.lastPathComponent)
    }
}

// MARK: Static Variables and Functions
extension AWDocumentInteractionController {
    fileprivate static var appRestrictionEnabled: Bool {
        guard let restrictionPayload = AWController.sharedInstance.context.SDKProfile?.restrictionsPayload else {
            return false
        }
        return restrictionPayload.enableDataLossPrevention && restrictionPayload.restrictDocumentToApps
    }

    public static func interactionController(with url: URL, encrypted: Bool = false) -> AWDocumentInteractionController {
        return AWDocumentInteractionController(url: url, encrypted: encrypted)
    }
}

// MARK: Instance Properties Bridging
extension AWDocumentInteractionController {
    override public var url: URL? {
        get {
            return self.realInstance.url
        }
        set {
            self.realInstance.url = newValue
        }
    }

    override public var uti: String? {
        get {
            return self.realInstance.uti
        }
        set {
            self.realInstance.uti = newValue
        }
    }

    override public var name: String? {
        get {
            return self.realInstance.name
        }
        set {
            self.realInstance.name = newValue
        }
    }

    override public var icons: [UIImage] {
        get {
            return self.realInstance.icons
        }
    }

    override public var annotation: Any? {
        get {
            return self.realInstance.annotation
        }
        set {
            self.realInstance.annotation = newValue
        }
    }

    override public var gestureRecognizers: [UIGestureRecognizer] {
        get {
            return self.realInstance.gestureRecognizers
        }
    }
}

// MARK: Instance Functions Bridging
extension AWDocumentInteractionController {
    fileprivate func provideFakeFileURLIfRequired() -> () {
        if AWDocumentInteractionController.appRestrictionEnabled {
            let emptyFilePathURL = self.emptyFileURL
            if FileManager.default.fileExists(atPath: emptyFilePathURL.path) == false {
                try? FileManager.default.createDirectory(at: emptyFilePathURL, withIntermediateDirectories: true, attributes: nil)
            }
            self.realInstance.url = emptyFilePathURL
        }
    }

    open override func presentOptionsMenu(from rect: CGRect, in view: UIView, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOptionsMenu(from: rect, in: view, animated: animated)
    }

    open override func presentOptionsMenu(from item: UIBarButtonItem, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOptionsMenu(from: item, animated: animated)
    }

    open override func presentPreview(animated: Bool) -> Bool {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return false
        }

        let navVC: UINavigationController
        if rootViewController is UINavigationController {
            navVC = rootViewController as! UINavigationController
        } else {
            navVC = UINavigationController(rootViewController: rootViewController)
        }

        navVC.pushViewController(qlPreviewViewController, animated: true)

        return true
    }

    open override func presentOpenInMenu(from rect: CGRect, in view: UIView, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOpenInMenu(from: rect, in: view, animated: animated)
    }

    open override func presentOpenInMenu(from item: UIBarButtonItem, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOpenInMenu(from: item, animated: animated)
    }

    open override func dismissPreview(animated: Bool) {
        self.realInstance.dismissPreview(animated: animated)
    }

    open override func dismissMenu(animated: Bool) {
        self.realInstance.dismissMenu(animated: animated)
    }
}

// MARK: Delegate Functions Bridging
extension AWDocumentInteractionController: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        guard let documentInteractionControllerViewControllerForPreview = self.delegate?.documentInteractionControllerViewControllerForPreview else {
            log(debug: "The delegate does not implement the function documentInteractionControllerViewControllerForPreview(_:) ")
            if let uiViewController = self.delegate as? UIViewController {
                return uiViewController
            } else {
                return UIViewController()
            }
        }
        return documentInteractionControllerViewControllerForPreview(self.realInstance)
    }

    public func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        guard let documentInteractionControllerRectForPreview = self.delegate?.documentInteractionControllerRectForPreview else {
            log(debug: "The delegate does not implement the function documentInteractionControllerRectForPreview(_:) ")
            return CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
        return documentInteractionControllerRectForPreview(self.realInstance)
    }

    public func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        guard let documentInteractionControllerViewForPreview = self.delegate?.documentInteractionControllerViewForPreview else {
            log(debug: "The delegate does not implement the function documentInteractionControllerViewForPreview(_:) ")
            return nil
        }
        return documentInteractionControllerViewForPreview(self.realInstance)
    }

    public func documentInteractionControllerWillBeginPreview(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerWillBeginPreview = self.delegate?.documentInteractionControllerWillBeginPreview else {
            log(debug: "The delegate does not implement the function documentInteractionControllerWillBeginPreview(_:) ")
            return
        }
        documentInteractionControllerWillBeginPreview(self.realInstance)
    }

    public func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerDidEndPreview = self.delegate?.documentInteractionControllerDidEndPreview else {
            log(debug: "The delegate does not implement the function documentInteractionControllerDidEndPreview(_:) ")
            return
        }
        documentInteractionControllerDidEndPreview(self.realInstance)
    }

    public func documentInteractionControllerWillPresentOptionsMenu(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerWillPresentOptionsMenu = self.delegate?.documentInteractionControllerWillPresentOptionsMenu else {
            log(debug: "The delegate does not implement the function documentInteractionControllerWillPresentOptionsMenu(_:) ")
            return
        }
        documentInteractionControllerWillPresentOptionsMenu(self.realInstance)
    }

    public func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerDidDismissOptionsMenu = self.delegate?.documentInteractionControllerDidDismissOptionsMenu else {
            log(debug: "The delegate does not implement the function documentInteractionControllerDidDismissOptionsMenu(_:) ")
            return
        }
        documentInteractionControllerDidDismissOptionsMenu(self.realInstance)
    }

    public func documentInteractionControllerWillPresentOpenInMenu(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerWillPresentOpenInMenu = self.delegate?.documentInteractionControllerWillPresentOpenInMenu else {
            log(debug: "The delegate does not implement the function documentInteractionControllerWillPresentOpenInMenu(_:) ")
            return
        }

        guard self.uti != nil else {
            log(debug: "The UTI cannot be nil if you want to prsent the Open In Menu")
            return
        }

        documentInteractionControllerWillPresentOpenInMenu(self.realInstance)
    }

    public func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        guard let documentInteractionControllerDidDismissOpenInMenu = self.delegate?.documentInteractionControllerDidDismissOpenInMenu else {
            log(debug: "The delegate does not implement the function documentInteractionControllerDidDismissOpenInMenu(_:) ")
            return
        }
        documentInteractionControllerDidDismissOpenInMenu(self.realInstance)
    }

    public func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {

        guard self.isAppAllowed(with: application) else {
            self.documentInteractionController(controller, didEndSendingToApplication: application)

            let alertController = UIAlertController(title: AWSDKLocalizedString("WarningMessageTitle"), message: self.alertMessage, preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: AWSDKLocalizedString("Ok"), style: .cancel, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
            return
        }

        guard let documentInteractionControllerWillBeginSendingToApplication = self.delegate?.documentInteractionController(_: willBeginSendingToApplication:) else {
            log(debug: "The delegate does not implement the function documentInteractionController(_: willBeginSendingToApplication:) ")
            return
        }

        guard self.isFileEncrypted else {
            documentInteractionControllerWillBeginSendingToApplication(self.realInstance, application)
            return
        }

        let destinationFileURL = self.decryptedFileURL

        guard let appKey = AWController.clientInstance().context.applicationKey else {
            log(error: "Unable to decrypt th file for the key (in this case we use application Key) is nil")
            return
        }

        guard var fileCryptor = FileCryptor(source: self.fileURL.path, destination: destinationFileURL.path, key: appKey) else {
            log(error: "Unable to set the file cryptor")
            return
        }

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        fileCryptor.decrypt { (success, error) in
            guard success, error == nil else {
                log(error: "Failed to decrypt the encrypted file at path: \(self.fileURL) with error: \(String(describing: error))")
                dispatchGroup.leave()
                return
            }
            self.realInstance.url = destinationFileURL
            dispatchGroup.leave()
        }
        
        dispatchGroup.wait()
        documentInteractionControllerWillBeginSendingToApplication(controller, application)
    }

    public func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        guard let documentInteractionControllerDidEndSendingToApplication = self.delegate?.documentInteractionController(_: didEndSendingToApplication:) else {
            log(debug: "The delegate does not implement the function documentInteractionController(_:, didEndSendingToApplication:String?) ")
            return
        }
        documentInteractionControllerDidEndSendingToApplication(self.realInstance, application)
        self.clearTemporaryFiles()
    }

}

// MARK: Helper Functions
extension AWDocumentInteractionController {
    fileprivate func isAppAllowed(with appBundleID: String?) -> Bool {
        guard AWDocumentInteractionController.appRestrictionEnabled else {
            self.realInstance.url = self.fileURL
            return true
        }

        guard !self.allowedApps.isEmpty else {
            log(debug: "no app is allowed")
            return false
        }

        guard let appBundleID = appBundleID else {
            log(debug: "appBundleID is nil")
            return false
        }

        let match = self.allowedApps.first {
            // Here we check if the app bundle id has a prefix that match one of the items in the allowed apps list
            // We do this to include not only the app but also the app extension 
            // The app bundle id usually comes as 
            // com.orgnazation.appName
            // The app extension id usually comes as
            // com.orgnazation.appName.extensionName
            // So if an app extension has a prefix that matches one of the app id inside the allowed apps list, then its extension is whitelisted as well
            appBundleID.lowercased().hasPrefix($0.lowercased())
        }

        guard match != nil else {
            log(debug: "appBundleID is not inside the allowed list")
            return false
        }
        
        self.realInstance.url = self.fileURL
        return true
    }

    fileprivate func clearTemporaryFiles() -> () {
        guard self.isFileEncrypted else {
            return
        }

        guard FileManager.default.fileExists(atPath: self.decryptedFileURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: self.decryptedFileURL)
        } catch let err {
            log(error: "Failed to delete the decrypted file at \(decryptedFileURL) with error: \(err)")
        }
    }
}
