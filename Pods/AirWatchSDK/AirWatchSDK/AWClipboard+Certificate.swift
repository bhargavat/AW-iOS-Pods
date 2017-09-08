//
//  AWClipboard+Certificate.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

let certPasteboardType = "com.airwatch.certificate"

internal extension AWClipboard {

    func writeToMainPasteboardWithCertData(_ certData: Data) {
        guard let pasteboard = UIPasteboard.awgeneral() else {
            log(error: "UIPasteboard.awgeneral() returns nil")
            log(verbose: "Could not complete setting Cert Data to pasteboard")
            return
        }
        
        // Add Data
        pasteboard.setData(certData, forPasteboardType: certPasteboardType)
        log(verbose: "Completed setting Cert Data to pasteboard \(pasteboard)")
    }

    func readCertDataFromMainPasteboard() -> Data {
        guard let pasteboard = UIPasteboard.awgeneral() else {
            log(error: "UIPasteboard.awgeneral() returns nil")
            return Data()
        }
        
        if let certDataEncrypted = pasteboard.data(forPasteboardType: certPasteboardType) {
            return certDataEncrypted
        } else {
            log(warning: "No Cert Data found")
            log(verbose: "Pasteboard \(pasteboard), did not have cert data.")
            return Data()
        }
    }

    func clearCertData() {
        guard let pasteboard = UIPasteboard.awgeneral() else {
            log(error: "UIPasteboard.awgeneral() returns nil")
            log(error: "Could not completly clear Cert Data from pasteboard")
            return
        }
        
        let emptyData = Data()
        let emptyDict: [String: Any] = Dictionary()
        
        pasteboard.setData(emptyData, forPasteboardType: certPasteboardType)
        pasteboard.setValue(emptyDict, forPasteboardType: certPasteboardType)
        pasteboard.setValue("", forPasteboardType: certPasteboardType)
        
        log(verbose: "Completed clearing Cert Data from pasteboard \(pasteboard)")
    }
}
