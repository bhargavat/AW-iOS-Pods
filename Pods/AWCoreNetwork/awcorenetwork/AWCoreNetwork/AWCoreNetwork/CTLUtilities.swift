//
//  CTLUtilities.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


open class CTLUtilities {
    
    open class func URLWithString(_ urlString: String?, queryParameters: [String:String]?) -> URL?
    {
        guard let urlString = urlString, urlString.characters.count > 0 else {
            return nil
        }
        
        guard let queryParameters = queryParameters, queryParameters.count > 0 else {
            return URL(string: urlString)
        }
        
        // Constructing URL paramters is not always a good idea. I'm hesitant to change the logic as
        // We are sorting them and adding them to the url. If the order is important NSURLComponents is not
        // an options. Let's revisit this with full crew.
        
        let paramStr = queryParameters.sorted { return $0.0 < $1.0}.map {
            return $0.0.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + "=" +
                $0.1.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            }.joined(separator: "&")
        
        if let _ = urlString.range(of: "?") {
            return URL(string: urlString + "&" + paramStr)
        } else {
            return URL(string: urlString + "?" + paramStr)
        }
        
    }
}
