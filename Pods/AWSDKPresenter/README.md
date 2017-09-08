
# AWSDKPresenter
### Summary

Branding, view controllers, storyboards, and images necessary for the SDK.

---

## Table of Contents
- [Introduction](#introduction)
	* [Terminology](#terminology)
    * [Setup](#setup)
- [How to use](#how-to-use)
	* [AWBrandingManager](#awbrandingmanager)

---

## Introduction
### Terminology
* AWBrandingManager - Retrieve colors and images which apps and frameworks can use.
* SDKPresenter - class is a simple API to push or display the desired view controller(s) using a window system.

### Setup
It is necessary to configure your app to use certain features. 
* To use QR scanner, add to your app's Info.plist the string entry 'Privacy - Camera Usage Description' with a description of how it will be used. Not including the key to the plist will disable the feature. The actual key for the Info.plist is 'NSCameraUsageDescription' in case you wanted to programatically change it using localization.

---

## How to use
### AWBrandingManager
All branding images and colors can be retrieved using the AWBrandingManager. This class will return console, plist, and/or default images and colors. AWBrandingManager is set up when the SDK receives a profile and values are set based off of those values in the payload to be later retrieved by apps and frameworks.

AWBrandingManager will pull its data from a few locations. If using the AWBrandingManager with the SDK, when a profile is downloaded then the SDK will insert into the local AWBrandingManager sqlite file with images and the colors from Console. If there is no branding payload from Console or when the SDK has not downloaded any profile, then AWBrandingManager functions will attempt to pull branding information from what is inside the plist. If the plist is not defined, then the default Airwatch color and images are returned.

When the SDK downloads a profile, the SDK will call a few methods to setup the sqlite branding values. When branding is enabled and colors are set, the SDK will call the **saveConsoleColor(color:key:)** to save the UIColor with the specified AWColorKey.
```
public enum AWColorKey: String {
	case ToolbarColor = "Toolbar"
	case ToolbarTextColor = "ToolbarText"
	case PrimaryColor = "PrimaryHighlight"
	case PrimaryTextColor = "PrimaryText"
	case SecondaryColor = "SecondaryHighlight"
	case SecondaryTextColor = "SecondaryText"
}
```
**Note**:  PrimaryColor serves two purposes for color, the primary color and background color.

The default saving or retrieving is done using sqlite. The object  ***managerStorage***  implements the default behavior of using sqlite because ***managerStorage*** conforms to the protocol ***AWBrandingManagerStorage***.

The SDK also attempts to download the CompanyLogo and BackgroundImage. It is necessary to set the NSURLs for ***urlForCompanyLogo*** and ***urlForBackgroundImage*** so that when the downloadAssetsAndNotifyBrandingUpdated(completionHandler:) is called the images will fetch asynchronously the images. The object ***managerProperties*** conforms to the protocol ***AWBrandingManagerStorage***.

Things to ***Note***

* All of the keys below are expected to be present in the app's bundle in the file named "skin.plist"
* All the keys representing colors are expected to be a dictionary with values for keys "red", "blue", "green" and "alpha"
* The images are displayed as Aspect Fit. Apps should set the appropriate sized images in order to completely obscure the UI with that image. If images are of smaller size than the device's resolution, then the remaining portion of the background  color will be displayed.
* Since SDK ignores the PrimaryText field and always uses white color instead of it, apps should not set background color as white color OR background image as any whitish image. Doing so will not make the text being entered in the SDK login UI appear clearly to the user.

---
### Plist Branding
These are the keys that are necessary to setup the plist for local branding without console.

Key | Description
--- | ---
PrimaryHighlight | This represents the primary background color. This color is set as background color of all SDK UI.
SecondaryHighlight | This represents the secondary background color. This color could be used by apps as background color for smaller UI controls. For example, an application can use this color to set the navigation bar item's background color. This color is not being used in SDK.
PrimaryText	| This represents the primary text color. This color could be used as text color for UILabel, UITextField, UITextView, etc. For SDK UI, this value is ignored and the input fields text color is always white.
SecondaryText | This represents the secondary text color. For example - In a table view showing list of emails, this can represent the text color of the email body preview whereas the PrimaryText can represent the email title. This color is not being used in SDK.
PrimaryiPad	| This represents the background image name for non-retina iPad devices. When this is set, the image will super impose the background color.
PrimaryiPad2X | This represents the background image name for retina iPad devices. When this is set, the image will super impose the background color.
PrimaryiPhone | This represents the background image name for non-retina iPhone devices. When this is set, the image will super impose the background color.
PrimaryiPhone5 | This represents the background image name specific for iPhone 5 devices. When this is set, the image will super impose the background color.
PrimaryiPhone2X | This represents the background image name for retina iPhone devices. When this is set, the image will super impose the background color.
SecondaryiPad | This represents the company logo image for non-retina iPad devices. This image appears above the input fields in the SDK login UI.
SecondaryiPad2X	| This represents the company logo image for retina iPad devices. This image appears above the input fields in the SDK login UI.
SecondaryiPhone | This represents the company logo image for non-retina iPhone devices. This image appears above the input fields in the SDK login UI.
SecondaryiPhone2X | This represents the company logo image for retina iPhone devices. This image appears above the input fields in the SDK login UI.
UsePrimaryImage | This represents if Primary Image (background image) should be displayed in the app. Apps can toggle this value to enable/disable the display of Primary Image (background image).
UseSecondaryImage | This represents if Secondary Image (Company Logo Image) should be displayed in the app. Apps can toggle this value to enable/disable the display of Secondary Image (Company Logo Image)
Toolbar | This represents the background color for top bar. If top bar has any text display, then this color should not coincide with PrimaryText (potentially SecondaryText too).
