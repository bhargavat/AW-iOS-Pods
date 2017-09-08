# AirwatchSDK
---
### Summary
This guide describes how to install the SDK quickly onto your machine with description of how to use the SDK.

The AirwatchSDK is a collection of different pods to form one framework. You can see the list of pods the SDK uses and each pod has limited dependencies upon each other.

<br/>

## Table of Contents
---
- [Installation](#installation)
  * [Terminology](#installation-terminology)
  * [Setup](#installation-setup)
  * [Advanced Topics](#installation-advanced-topics)
- [Using the SDK](#using-the-sdk)
  * [Summary](#using-the-sdk-summary)
- [Pods](#pods)
- [Diagrams](#diagrams)
  * [Startup](#diagrams-startup)
  * [Refresh](#diagrams-refresh)

<br />

## Installation <a name="installation"></a>
---
### Terminology <a name="installation-terminology"></a>

* **CocoaPods** - CocoaPods is a software that facilitates the installation of framework/libraries into an existing Xcode project. The developer of a project ( a pod) will preconfigure a podspec. You as the developer must specify which pod(s) to install into your project. Any dependencies for a pod(s) are handled by CocoaPods.
* **pod** - The frameworks/libraries which is preconfigured so that a project that uses it does not need to change build settings.
* **Podfile** - This is a file with a list of the pods and the location where to find the pods you will want to add to your project. This is the file you create to specify which framework/libraries to include to your project.
* **~.podspec** - The ~ is a placeholder for the name of the pod. The podspec file type is specific to when you want to create a pod for other projects. This file specifies how to configures the Build Settings of an app/framework.
* **Spec Sheet** - This is a git repository where all the pod specs are stored. This is used to help CocoaPods find a specific pod and/or version of a pod. The format of a spec sheet is there is a Spec folder, and inside it contains folders with the names of the pods. When a pod folder is selected, you will see folders of the versions which were committed. There is a single ~.podspec file inside each of the version folders.


<br />

### Setup <a name="installation-setup"></a>
---
First CocoaPods must be installed via terminal. Within OS X select spotlight and type in Terminal. When the application is launched, type the command  

```
sudo gem install cocoapods
```

You will be prompted for your password of your machine to install.
**Note**: Even though there is no indication whether the password is being entered, don't worry it is.

The simplest way to add the SDK pod to a project is to create a Podfile and put that Podfile in the same path as your project's xcodeproj file. The file must have the same capitalization. Add these lines to your Podfile...

```
source 'ssh://git@stash.air-watch.com:7999/icpd/specs.git'
source 'https://github.com/CocoaPods/Specs.git'
pod 'AirWatchSDK'
```
The final step would be to issue the terminal command `pod install` in the directory which the Podfile is located. This command will download all the dependent pods into a Pods folder and configure the Build Settings for your project's xcodeproj file and create a workspace file.

The newly created workspace file is what you will use from now on when compiling your project. After `pod install` compiling the xcodeproj without using the workspace will not work.

That's it, now when you open the workspace, you will see your project and the Pods project inside the workspace. To use the SDK in your code do `@import AirWatchSDK` for ObjC in the file your are coding or for the swift equivalent `import AirWatchSDK`.

If by any chance you do not want to use a pod(s) and wish to remove CocoaPods from your xcodeproj, issue the command `pod deintegrate`.


<br/>

### Advanced Topics <a name="installation-advanced-topics"></a>
---

**Specifying a Version**

You can also specify in the Podfile a specific version to pull down, or you could use a local repository.

For a further discussion on specifying a version in a Podfile check out http://guides.cocoapods.org/using/the-podfile.html. This approach of just specifying a version allows someone to quickly and easily swap out version of the SDK and start developing within their project.


**Local SDK**

There is a more advance way to setup the SDK and that is by referencing the SDK project locally. To reference the SDK locally download the project from https://stash.air-watch.com/projects/ISDKL/repos/airwatchsdk/browse and checkout the latest development branch using git or SourcesTree. Once you have pulled the latest development you will see that there are SDK files and a SampleApps folder which you can use to test the SDK against (at this moment only the Roomfinder apps work). Roomfinder is written in both Swift and ObjectiveC and the apps reference the local SDK.

By referencing the SDK locally you will have more freedom to develop and test your app or framework against the SDK. If you check the Podfile of the sample apps you will see `pod 'AirWatchSDK', :path => '../../'`.

By referencing the SDK locally you have the ability to modify the SDK's code to later create a branch for the creation of a PR. Accessing the SDK locally allows you to change the branch which you are currently using to a different one for testing purposes so that you do not have to wait for a release.

The final step is to navigate to the desired Podfile within the project of choice (SDK, Roomfinder Objc/Swift) and issue the command `pod install` to download all the dependent pods for that project. This will download the pod(s) into a Pods folder and create a workspace file which you will now need to use. You will not be able to compile the xcodeproj without using the workspace.

**Note**: If a add/remove a file to the local SDK, make sure you issue the command `pod install` on the project you are developing on (your own project or Roomfinder). This will update the sample app with the new or removed file.


<br/>

## Using the SDK <a name="using-the-sdk"></a>
---
### Summary <a name="using-the-sdk-summary"></a>
The instruction to setup your project with the SDK is in swift. To use in Objective-C the functions are named the same and can be used exactly the same.

The forward facing APIs to customers have not changed, but the private APIs are not the same.

There are different ways to setup the SDK with a project. One way to quickly setup the SDK is to add the line `import AirWatchSDK` to the App's delegate or in case of a framework in a class which will implement the AirwatchSDK protocols.

The common place to initiate the SDK in an app would be in the App's delegate file. The app delegate must implement the protocol defined in the SDK.

```
class AppDelegate: UIResponder, UIApplicationDelegate, AWSDKDelegate {
  ...
}
```


To initiate the SDK you must set the delegate, setup the call back scheme, and start the SDK.
```
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool
    {
        // Override point for customization after application launch.
        let awc = AWController.clientInstance()
        awc.delegate = self
        // Your application's scheme name
        awc.callbackScheme = "myAppName"
        awc.start()
        return true
    }
```

The class which is the delegate must implement these protocols.
```
// This function will be called once the SDK has finished its setup
func initialCheckDone(Error error: NSError?) {
    NSLog("SDK Initial Check Done!")
}

func receivedProfiles(profiles: NSArray) {

}

func lock() {
    NSLog("SDK Lock!")
}

func unlock() {
    NSLog("SDK unLock!")
}

func wipe() {
    NSLog("SDK Wipe!")
}

@objc
func stopNetworkActivity(networkActivityStatus: AWNetworkActivityStatus) {

}

func resumeNetworkActivity() {

}
```

<br />

## Pods <a name="pods"></a>
---
These are the pods which were created by Airwatch that are used within the SDK.

Name | Description
---|---
[AirwatchService](https://stash.air-watch.com/projects/ISDKL/repos/airwatchservices/browse) |	All the necessary APIs to communicate with the Console to get HMAC, authenticate, escrow passcode, un-enroll, etc.
[AWCoreNetwork](https://stash.air-watch.com/projects/ISDKL/repos/awcorenetwork/browse)	| The underlying APIs to make network calls for many of the pods. This project wraps Alamofire with an API to facilitate any changes that may occur in Alamofire.
[AWCorePlatformHelpers](https://stash.air-watch.com/projects/ISDKL/repos/awcoreplatformhelpers/browse) |	This pod has the core functionality that might be used across multiple pods. This pod consists of extension to Apple APIs, reads default plist entries like ASDKDefaults.plist to know how to configure a specific functionality, reachability, swizzling, etc.
[AWCryptoKit](https://stash.air-watch.com/projects/ISDKL/repos/awcryptokit/browse)	| Encryption and Decryption of data.
[AWDataSampler](https://stash.air-watch.com/projects/ISDKL/repos/awdatasampler/browse) |	Data sampling of GPS, analytics, memory, etc.
[AWDataUsage](https://stash.air-watch.com/projects/ISDKL/repos/awdatausage/browse) |	Intercept network calls and save the amount of bytes sent/received by the app.
[AWError](https://stash.air-watch.com/projects/ISDKL/repos/awerror/browse)	| A simple way to order all errors for the SDK.
[AWLog](https://stash.air-watch.com/projects/ISDKL/repos/awlog/browse) |	Logging similar to the legacy SDK for printing logs to console or saving to disc.
[AWOpenSSL](https://stash.air-watch.com/projects/ISDKL/repos/awopenssl/browse) |	A modified version of OpenSSL which we precompile for the SDK.
[AWStorage](https://stash.air-watch.com/projects/ISDKL/repos/awstorage/browse)	| The SDK will decide whether to save to either local or keychain storage. There is a single variable that is passed around for storage in the SDK which will have been set on startup to either use local or keychain storage. This variable implements the SDKContext protocol so that saving of data will be consistent regardless of wether local or keychain storage is used.
[AWTunnel](https://stash.air-watch.com/projects/ISDKL/repos/awtunnel/browse) |


<br/>

## Diagrams <a name="diagrams"></a>
---
### Startup <a name="diagrams-startup"></a>
Empty
### Refresh <a name="diagrams-refresh"></a>
Empty
