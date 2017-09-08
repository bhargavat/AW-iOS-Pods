//
//  AWResource.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit

open class AWResource {
    internal static let resourceBundle = Bundle.init(for: object_getClass(AWResource.self))
    
    open static func getImage( _ name : String ) -> UIImage? {
        let myimage = UIImage.init(named: name, in: resourceBundle, compatibleWith: nil)
        return myimage
    }
}
