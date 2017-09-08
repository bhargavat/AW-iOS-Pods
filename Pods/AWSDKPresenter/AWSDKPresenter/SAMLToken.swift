//
//  BridgeSafariAndWebViewDelegate.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWHelpers
import AWError
import AWLocalization
import WebKit

public enum AWSafariControllerAvailabilityStatus {
    case available
    case unavailable
}

let kSAMLURLSchemeQuery = "SAMLAuthentication"

public protocol SAMLTokenDelegate {
    /**
     This function will be called in different situations...
     * There is a token with error is nil
     * The user clicks the Close button, token and error is nil
     */
    func didReceive(token: String?, error: NSError?)
}

public class SAMLToken: NSObject {
    /** 
     Should be set by SDKPresenter's pushSAML function
     */
    public var samlDelegate: SAMLTokenDelegate?
    internal var token: String?
    
    public static func getSAMLTokenFromURL(_ url: URL) -> String? {
        guard url.host?.caseInsensitiveCompare(kSAMLURLSchemeQuery) == ComparisonResult.orderedSame,
        let components = url.query?.components(separatedBy: "&") else {
            return nil
        }

        for component in components {
            let pairs = component.components(separatedBy: "=")
            // pairs should be token keyword and token value
            if let firstItem = pairs.first, firstItem == "token", let lastItem = pairs.last {
                return lastItem
            }
        }
        return nil
    }
}

class SAMLViewController: BaseViewController, WKNavigationDelegate {
    var webView: WKWebView = WKWebView()
    var url: URL?
    var samlDelegate: SAMLTokenDelegate?
    var allowCancel = false
    var callbackScheme: String?
    
    @IBOutlet var navigationBarText: UINavigationItem?
    @IBOutlet var viewToBeWebView: UIView?
    @IBOutlet weak var closeButton: UIBarButtonItem?
    
    override func loadView() {
        super.loadView()
        // Clear any possible cache. At the moment without these lines is not causing an issue, but as a preventative measure for the future we should clear cache.
        resetCache()
        createWebView()
    }
    
    override func viewDidLoad() {
        setupWebView()
        closeButton?.isEnabled = allowCancel
    }
    @IBAction func close(_ sender: UIBarButtonItem) {
        dismiss()
        samlDelegate?.didReceive(token: nil, error: nil)
    }
    // If the server responds with no token, then
    func tryAgain() {
        resetCache()
        createWebView()
        setupWebView()
    }
    func createWebView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.frame = self.view.frame
        webView.sizeToFit()
        viewToBeWebView?.addSubview(webView)
    }
    func setupWebView() {
        guard let url = url else {
            log(error:"Cannot create SAML view controller with properties not set")
            log(debug: "URL: \(String(describing: self.url))")
            log(debug: "SAMLDelegate: \(String(describing: self.samlDelegate))")
            return
        }
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = false
        closeButton?.isEnabled = allowCancel
    }
    
    func resetCache(_ completion: (()->Void)? = nil) {
        let set: Set = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        WKWebsiteDataStore.default().removeData(ofTypes: set, modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {
            completion?()
        })
    }
    
    func dismiss() {
        resetCache()
        if self.navigationController?.topViewController == self {
            _ = self.navigationController?.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme == callbackScheme {
            let token = SAMLToken.getSAMLTokenFromURL(url)
            if token != nil {
                samlDelegate?.didReceive(token: token, error: nil)
                self.dismiss(animated: true, completion: nil)
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
            } else {
                decisionHandler(WKNavigationActionPolicy.cancel)
                closeButton?.isEnabled = allowCancel
                let alert = KeyWindowAlert(title: nil, message: AWSDKLocalizedString("PleaseContactYourAdminstrator"))
                let tryAgainAction = UIAlertAction(title: AWSDKLocalizedString("TryAgain"),
                                                   style: UIAlertActionStyle.default, handler: { [weak self] (alertAction) in
                    self?.tryAgain()
                })
                let dismissAction = UIAlertAction(title: AWSDKLocalizedString("OK"),
                                                  style: UIAlertActionStyle.default, handler: { [weak self] (alertAction) in
                    self?.dismiss()
                })
                if allowCancel {
                    alert.actions = [tryAgainAction, dismissAction]
                } else {
                    alert.actions = [tryAgainAction]
                }
                _ = alert.show()
            }
            return
        }
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        closeButton?.isEnabled = false
        
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        closeButton?.isEnabled = allowCancel
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        closeButton?.isEnabled = allowCancel
    }
}

