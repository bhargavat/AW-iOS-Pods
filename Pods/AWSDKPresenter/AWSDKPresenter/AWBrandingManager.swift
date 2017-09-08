//
//  AWBrandingManager.swift
//  AWPresentation
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import AWHelpers
import AWStorage

internal let Plist_Branding = "Branding"
internal let Plist_EnabledBranding = "EnableBranding"
internal let Plist_AppLogo_1x = "AppLogo_1x"
internal let Plist_AppLogo_2x = "AppLogo_2x"
internal let Plist_SplashLogo_1x = "SplashLogo_1x"
internal let Plist_SplashLogo_2x = "SplashLogo_2x"
internal let Plist_BackgroundImage_3_2 = "BackgroundImage_3_2"
internal let Plist_BackgroundImage_4_3 = "BackgroundImage_4_3"
internal let Plist_BackgroundImage_3_4 = "BackgroundImage_3_4"
internal let Plist_BackgroundImage_16_9 = "BackgroundImage_16_9"

public enum AWColorKey: String {
case ToolbarColor = "Toolbar"
case ToolbarTextColor = "ToolbarText"
case PrimaryColor = "PrimaryHighlight" // PrimaryColor serves two purposes for color, the primary color and background color
case PrimaryTextColor = "PrimaryText"
case SecondaryColor = "SecondaryHighlight"
case SecondaryTextColor = "SecondaryText"
}
internal let DeviceSpecificBackgroundImage = "DeviceSpecificBackgroundImage"
internal let DeviceSpecificCompanyLogo = "DeviceSpecificCompanyLogo"
internal let DeviceSpecificBackgroundColor = "DeviceSpecificBackgroundColor"

internal let StringURLForCompanyLogo = "StringURLForCompanyLogo"
internal let StringURLForBackground = "StringURLForBackground"

public protocol AWBrandingManagerProperties {

    var isConsoleBrandingEnabled: Bool { get set }

    var defaultAirwatchColor: UIColor { get }
    var defaultAirwatchCompanyLogo: UIImage? { get }

    var imageBackground: UIImage? { get }
    var imageAppLogo: UIImage? { get }
    var imageSplashLogo: UIImage? { get }

    var urlForCompanyLogo: URL? { get set }
    var urlForBackgroundImage: URL? { get set }

    var colorBackground: UIColor { get }
    var isPlistBrandingEnabled: Bool { get }

    //MARK: Branding color set by console or plist
    // When the init is called on branding manager, these values are loaded with the values saved in storage
    var primaryColor: UIColor? { get }
    var primaryTextColor: UIColor? { get }
    var secondaryColor: UIColor? { get }
    var secondaryTextColor: UIColor? { get }
    var toolbarColor: UIColor? { get }
    var toolbarTextColor: UIColor? { get }

    func downloadAssetsAndNotifyBrandingUpdated(_ completionHandler: @escaping () -> Void)
}

public protocol AWBrandingManagerStorage: AWBrandingManagerProperties {
    var brandingStore: LocalSettingsDataStore { get set }
    var sdkDefaultSettings: SDKDefaultSettings { get set }
    // Branding Dictionary relating to which images or colors to use
    var brandingDictionary: NSDictionary? { get }

    func getSavedConsoleBackgroundImage() -> UIImage?
    func getSavedConsoleCompanyLogo() -> UIImage?
    func getSavedConsoleBackgroundColor() -> UIColor?

    func getBackgroundImageFromPlist() -> UIImage?
    func getBackgroundColorFromPlist() -> UIColor?
    func getAppLogoFromPlist() -> UIImage?
    func getSplashLogoFromPlist() -> UIImage?
    func getPlistColorForKey(_ key: AWColorKey) -> UIColor?

    mutating func setConsoleBackgroundImage(_ data: Data?) -> Bool
    mutating func setConsoleCompanyLogo(_ data: Data?) -> Bool
    mutating func setConsoleBackgroundColor(_ data: UIColor) -> Bool
}

extension UIColor: DataRepresentable {
    public func toData() -> Data? {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }

    public static func fromData(_ data: Data?) -> Self? {
        guard let colorData = data else { return nil}
        if let color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? UIColor {
            return self.init(cgColor: color.cgColor)
        }
        return nil
    }
}
extension AWBrandingManagerStorage {

    //MARK: Console Settings
     public func getSavedConsoleBackgroundImage() -> UIImage? {
        if let data = retrieveFromDocumentDir(fileName: DeviceSpecificBackgroundImage) {
            let image = UIImage(data: data)
            return image
        }
        return nil
    }
    public func getSavedConsoleCompanyLogo() -> UIImage? {
        if let data = retrieveFromDocumentDir(fileName: DeviceSpecificCompanyLogo) {
            let image = UIImage(data: data)
            return image
        }
        return nil
    }
    public func getSavedConsoleBackgroundColor() -> UIColor? {
        return brandingStore.get(DeviceSpecificBackgroundColor)
    }

    fileprivate func retrieveFromDocumentDir(fileName: String) -> Data? {
        guard
            var userApplicationSupportPathWithFileName  = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        else {
            log(error: "Could not get documents directory for user")
            return nil
        }
        
        userApplicationSupportPathWithFileName.appendPathComponent(fileName)
        return try? Data(contentsOf: userApplicationSupportPathWithFileName)
    }

    //MARK: Plist settings
   public func getBackgroundImageFromPlist() -> UIImage? {
        var pathForBackgoundImage: String?

        switch (UIDevice.current.aspectRatio()) {
        case .device_3_2:
            pathForBackgoundImage = brandingDictionary?[Plist_BackgroundImage_3_2] as? String
        case AspectRatio.device_4_3:
            pathForBackgoundImage = brandingDictionary?[Plist_BackgroundImage_4_3] as? String
        case AspectRatio.device_16_9:
            pathForBackgoundImage = brandingDictionary?[Plist_BackgroundImage_16_9] as? String
        default:
            pathForBackgoundImage = nil
        }

        var returnImageBackground: UIImage? = nil
        if pathForBackgoundImage != nil {
            let imagePath = sdkDefaultSettings.plistBundle?.path(forResource: pathForBackgoundImage!, ofType: nil)
            if imagePath != nil {
                returnImageBackground = UIImage(contentsOfFile: imagePath!)
            }
        }

        return returnImageBackground
    }

    public func getBackgroundColorFromPlist() -> UIColor? {
        let color = getPlistColorForKey(AWColorKey.PrimaryColor)
        return color
    }
    
    public func getAppLogoFromPlist() -> UIImage? {
        var pathForAppLogo: String? = nil
        // Non-Retina screens
        if UIScreen.main.scale == 1 {
            pathForAppLogo = brandingDictionary?[Plist_AppLogo_1x] as? String
        } else {
            pathForAppLogo = brandingDictionary?[Plist_AppLogo_2x] as? String
        }
        var returnImageAppLogo: UIImage? = nil
        if let path = pathForAppLogo {
                returnImageAppLogo = UIImage(named: path)
        }
        return returnImageAppLogo
    }
 
    public func getSplashLogoFromPlist() -> UIImage? {
        var pathForSplashLogo: String? = nil
        // Non-Retina screens
        if UIScreen.main.scale == 1 {
            pathForSplashLogo = brandingDictionary?[Plist_SplashLogo_1x] as? String
        } else {
            pathForSplashLogo = brandingDictionary?[Plist_SplashLogo_2x] as? String
        }
        var returnImageSplashLogo: UIImage? = nil
        if let path = pathForSplashLogo {
            returnImageSplashLogo = UIImage(named: path)
        }
        return returnImageSplashLogo
    }
    
    public func getPlistColorForKey(_ key: AWColorKey) -> UIColor? {
        // First we need to unwrap attempt to unwrap the Colors dictionary and then access the color type we are looking for
        // After unwrapping Colors, you will be given something similar to "Toolbar":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"]
        // Then upon unwrapping that all we're left with is ["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"] in the colorDictionary
        
        //The branding dictionary is value of key branding from the AWSDKDefaultSettings.plist, so read values directly
        guard let colorForKey = brandingDictionary?["Colors"] as? NSDictionary else {
            return nil
        }
        guard let colorDictionary = colorForKey[key.rawValue] as? NSDictionary else {
            return nil
        }
        
        let redStr = colorDictionary["Red"] as? NSNumber
        let blueStr = colorDictionary["Blue"] as? NSNumber
        let greenStr = colorDictionary["Green"] as? NSNumber
        let alphaStr = colorDictionary["Alpha"] as? NSNumber

        guard let r = redStr, let g = greenStr, let b = blueStr, let a = alphaStr else {
            return nil
        }
        
        return UIColor(red: CGFloat(r.doubleValue/255.0),
                       green: CGFloat(g.doubleValue/255.0),
                       blue: CGFloat(b.doubleValue/255.0),
                       alpha: CGFloat(a.doubleValue/255.0))
    }

    //MARK:Save console settins to db and file cache
    public mutating func setConsoleBackgroundImage(_ data: Data?) -> Bool {
        return saveToDocumentDir(fileName: DeviceSpecificBackgroundImage, data: data)
    }
    public mutating func setConsoleCompanyLogo(_ data: Data?) -> Bool {
        return saveToDocumentDir(fileName: DeviceSpecificCompanyLogo, data: data)
    }
    public mutating func setConsoleBackgroundColor(_ color: UIColor) -> Bool {
        return self.brandingStore.set(DeviceSpecificBackgroundColor, value: color)
    }

    internal mutating func saveToDocumentDir(fileName: String, data: Data?) -> Bool {
        let fileManager = FileManager.default
        guard
            var usersDocumentPathWithFileName = fileManager.urls(for: .documentDirectory, in: .userDomainMask).last
        else {
            log(error: "Could not save data (\(String(describing: data))) with key(\(fileName)) because user application support path was not resolved")
            return false
        }
        usersDocumentPathWithFileName.appendPathComponent(fileName)
        
        let fullFilePath = usersDocumentPathWithFileName.path
        let fileCreated = fileManager.createFile(atPath: fullFilePath, contents: data, attributes: nil)
        log(debug: "Did create file at path \(fullFilePath), \(fileCreated ? "yes": "no")")
        
        return fileCreated
    }

    /**
     @return If no plist exists then return false
     @return If plist exists and there exists an entry called EnableBranding under the key Branding then return that value, else return true if plist exists
     */
    public var isPlistBrandingEnabled: Bool {
        get {
            guard let sdkDefaultsBranding = brandingDictionary else { return false }
            
            // If the branding dictionary exists but the EnableBranding key does not, then return true because we assume they want it enabled
            guard let sdkDefaultsPlistEntryValue = sdkDefaultsBranding[Plist_EnabledBranding] as? Bool else {
                return true
            }
            return sdkDefaultsPlistEntryValue
        }
    }
    
    /**
     When console specific branding has been downloaded, then this flag should be set to true
     */
    public var isConsoleBrandingEnabled: Bool {
        get {
            guard let boolValue: Bool = self.brandingStore.get("ConsoleBrandingEnabled") else {
                return false
            }
            return boolValue
        } set {
            _ = self.brandingStore.set("ConsoleBrandingEnabled", value: newValue)
        }
    }
}

/**
 AWBrandingManager
 When the object is initialized, certain variables which are saved in storage will be loaded
 */
@objc open class AWBrandingManager: NSObject, AWBrandingManagerStorage {
    
    open var brandingStore: LocalSettingsDataStore
    open static let sharedInstance = AWBrandingManager()
    open var storeName: String = Bundle(for: object_getClass(AWResource.self)).bundleIdentifier!
    open var managerProperties: AWBrandingManagerProperties?
    open var managerStorage: AWBrandingManagerStorage?
    open static let AWNotificationBrandingDidUpdate = "AWNotificationBrandingDidUpdate"

    //MARK: Protocol variables
    open var sdkDefaultSettings = SDKDefaultSettings.sharedSettings

    // Format of what should be in the AWSDKDefaultSettings.plist
    // This variable is initialized in init() by the AWSDKDefaultSettings object by returning a dictionary after the Branding part of the dictionary has been removed so that we don't have to constantly unwrap the "Branding" part of the dictionary.
//    ["Branding": [
//      "EnableBranding":"YES",
//      "CompanyLogo1x": "image1.png",
//      "CompanyLogo2x": "image2.png",
//      "BackgroundImage_3_2":"bg1.png",
//      "BackgroundImage_4_3":"bg2.png",
//      "BackgroundImage_3_4":"bg3.png",
//      "BackgroundImage_16_9":"bg4.png",
//      "Colors" : [
//          "Toolbar":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"],
//          "ToolbarText":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"],
//          "Secondary":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"],
//          "SecondaryText":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"],
//          "Primary":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"],
//          "PrimaryText":["Red":"0.25","Green":"0.5","Blue":".75","Alpha":"1"]
//       ]
//    ]]
    
    // values set when the branding manager is initialized
    // the variable isConsoleBrandingEnabled is also set initially when the object is created
    open var brandingDictionary: NSDictionary?
    open var defaultAirwatchColor: UIColor
    open var defaultAirwatchCompanyLogo: UIImage?
    open var colorForDisabled = UIColor.gray
    open var colorBackground: UIColor {
        get {
            guard let color = getConsoleColor(AWColorKey.PrimaryColor) else {
                return defaultAirwatchColor
            }
            return color
        }
    }
    open var imageBackground: UIImage? {
        get {
            var image: UIImage?
            // always need to check if isConsoleBrandingEnabled and if not check if plist branding is enabled, else return nil
            if (isConsoleBrandingEnabled) {
                image = getSavedConsoleBackgroundImage()
            }
            if (image == nil && isPlistBrandingEnabled) {
                image = getBackgroundImageFromPlist()
            }
            return image
        }
    }
    open var imageAppLogo: UIImage? {
        get {
            var image: UIImage?
            // always need to check if isConsoleBrandingEnabled and if not check if plist branding is enabled, else load default airwatch logo
            if (isConsoleBrandingEnabled) {
                image = getSavedConsoleCompanyLogo()
            }
            if (image == nil && isPlistBrandingEnabled) {
                image = getAppLogoFromPlist()
            }
            if (image == nil) {
                image = defaultAirwatchCompanyLogo
            }
            
            return image
        }
    }
    
    open var imageSplashLogo: UIImage? {
        get {
            var image: UIImage?
            if (image == nil && isPlistBrandingEnabled) {
                image = getSplashLogoFromPlist()
            }
            if (image == nil) {
                image = defaultAirwatchCompanyLogo
            }
            
            return image
        }
    }

    open var primaryColor: UIColor? {
        var color: UIColor?
        if isConsoleBrandingEnabled {
            color = getConsoleColor(AWColorKey.PrimaryColor)
        }
        if color == nil && isPlistBrandingEnabled {
            color = getPlistColorForKey(AWColorKey.PrimaryColor)
        }
        if color == nil {
            color = defaultAirwatchColor
        }
        return color
    }
    open var primaryTextColor: UIColor? {
        get {
            var color: UIColor?
            if isConsoleBrandingEnabled {
                color = getConsoleColor(AWColorKey.PrimaryTextColor)
            }
            if (color == nil) {
                color = getPlistColorForKey(AWColorKey.PrimaryTextColor)
            }
            return color
        }
    }
    open var secondaryColor: UIColor? {
        get {
            var color: UIColor?
            if isConsoleBrandingEnabled {
                color = getConsoleColor(AWColorKey.SecondaryColor)
            }
            if (color == nil) {
                color = getPlistColorForKey(AWColorKey.SecondaryColor)
            }
            return color
        }
    }
    open var secondaryTextColor: UIColor? {
        get {
            var color: UIColor?
            if isConsoleBrandingEnabled {
                color = getConsoleColor(AWColorKey.SecondaryTextColor)
            }
            if (color == nil) {
                color = getPlistColorForKey(AWColorKey.SecondaryTextColor)
            }
            return color
        }
    }
    open var toolbarColor: UIColor? {
        get {
            var color: UIColor?
            if isConsoleBrandingEnabled {
                color = getConsoleColor(AWColorKey.ToolbarColor)
            }
            if color == nil {
                color = getPlistColorForKey(AWColorKey.ToolbarColor)
            }
            return color
        }
    }
    open var toolbarTextColor: UIColor? {
        get {
            var color: UIColor?
            if isConsoleBrandingEnabled {
                color = getConsoleColor(AWColorKey.ToolbarTextColor)
            }
            if color == nil {
                color = getPlistColorForKey(AWColorKey.ToolbarTextColor)
            }
            return color
        }
    }

    // variables which are not set when branding manager is initialized
    open var urlForCompanyLogo: URL?
    open var urlForBackgroundImage: URL?
    fileprivate var brandingDatabase: SQLiteDatabase
    internal override init() {
        brandingDatabase = SQLiteDatabase(sqliteFilePath: SQLiteDatabase.documentsLocalSettingsFilepath("AWBranding.sqlite"))
        brandingStore = brandingDatabase.getDatastore("Branding")
        defaultAirwatchColor = UIColor(red: 0, green: 161/255, blue: 225/255, alpha: 1.0)
        defaultAirwatchCompanyLogo = AWResource.getImage("VMware_AirWatch_gray_white_bg")

        // Check if branding is enabled
        brandingDictionary = sdkDefaultSettings.brandingDictionary()

        super.init()
        managerStorage = self
        managerProperties = self
    }
    open func wipeData() {
        // DO NOT WIPE brandingDictionary. If a device is running and has a plist, we need to continue to use it. This wipe function should only be for console related database values. 
        _ = brandingStore.clear()
        NotificationCenter.default.post(name: Notification.Name(rawValue: AWBrandingManager.AWNotificationBrandingDidUpdate), object: nil)
    }
    
    /**
     Get the saved color which is/was in the last payload for the specific key
     */
    open func getConsoleColor(_ key: AWColorKey) -> UIColor? {
        guard let color: UIColor = self.brandingStore.get(key.rawValue) else {
            log(error: "Could not get console color for key \(key)")
            return nil
        }
        log(verbose: "Found console color \(color) for key \(key)")
        return color
    }

    /**
     Save the the color and based off of the key
     */
    open func saveConsoleColor(_ color: UIColor?, key: AWColorKey) -> Bool {
        if self.brandingStore.set(key.rawValue, value: color) {
            log(verbose: "Saved console color \(String(describing:color)) for key \(key)")
            return true
        }
        log(error: "Could not save console color for key \(key) and color \(String(describing:color))")
        return false
    }

    /**
     Download the assets set in urlForBackgroundImage and urlForCompanyLogo asynchronously. After the images have been downloaded, the notification AWNotificationBrandingDidUpdate will be posted if consoleBrandingEnabled is true
     */
    open func downloadAssetsAndNotifyBrandingUpdated(_ completionHandler: @escaping () -> Void) {

        DispatchQueue(label: "Download Branding...", attributes: []).async {
            [weak self] in

            let brandingManager = AWBrandingManager.sharedInstance
            let urlForBackgroundImage = brandingManager.urlForBackgroundImage
            let urlForCompanyLogo = brandingManager.urlForCompanyLogo

            if let URLToDownloadBackgroundImage = urlForBackgroundImage,
                let dataDownloadedForBackgroundImageFromURL = try? Data(contentsOf: URLToDownloadBackgroundImage) {
                _ = self?.managerStorage?.setConsoleBackgroundImage(dataDownloadedForBackgroundImageFromURL)
            } else {
                _ = self?.managerStorage?.setConsoleBackgroundImage(nil)
            }

            if let URLToDownloadCompanyLogo = urlForCompanyLogo,
                let dataDownloadedForCompanyLogoFromURL = try? Data(contentsOf: URLToDownloadCompanyLogo) {
                _ = self?.managerStorage?.setConsoleCompanyLogo(dataDownloadedForCompanyLogoFromURL)
            } else {
                _ = self?.managerStorage?.setConsoleCompanyLogo(nil)
            }
            
            // call delgate so that it can update UI
            NotificationCenter.default.post(name: Notification.Name(rawValue: AWBrandingManager.AWNotificationBrandingDidUpdate), object: nil)
            
            completionHandler()
        }
    }
}
