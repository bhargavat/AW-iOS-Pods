# AWError




---- 


## Overview
**AWError** is a module that mainly focuses on providing a easy-to-use, simple-to-extend and neatly organized error messaging system. Each error comes out of this module will have a self-explanatory structure that requires no extra comment for the purpose of further explanation.

## Installation
It is recommended to deploy **AWError** via **CocoaPods**.  The following is the steps to install:

- Add following codes to the top of your *Podfile*:

	```
	source 'ssh://git@stash.air-watch.com:7999/icpd/specs.git 
	source 'https://github.com/CocoaPods/Specs.git'
	```

- Add following code to your *Podfile* dependency section:

	```
	pod 'AWError'
	```

- Run following command in your terminal under your project folder where the *Podfile* is located and you should be good to go:
	
	```
	pod install
	```




---- 


## How to use
The main purpose of creating this module is that we found, during the development of the new SDK Lite, the errors are created carelessly and randomly. This brings a lot of problems. 

To give an example, we know that errors in SDK Lite are all created using a `enum` type, this makes perfect sense because the `enum` type are the most suitable data type here. However, each `enum` type they create for their errors are given names that do not follow the same pattern. For example, they do not share a same prefix, so when it comes to use, you do not know if there is already an error created for your situation and the auto-completion of Xcode can not help you because you do not know what to start typing with. The consequence is not good, because you probably will create some errors that already existed with a different name, or a bunch of errors that are completely different from existing ones but share a same error category name.

With the new **AWError** module, when you want to throw an error, you do not need to know what the specific error category should this one fall in, you just need to first `import AWError` and then type `AWError.` and start choosing the domain you want this error to be in. Like following gif shows:
  
![](demo.gif)

All errors in module **AWError** conform to *protocol* **AWErrorType**, which comes with 13 computed properties:

- `_code`: This one comes automatically with *protocol* **ErrorType** to which **AWErrorType** conforms to. It indicates the natural index of the `enum` cases. For example, if it is the first case of the `enum`, then its `_code` value will be *0*; if it is the second, then its `_code` value will be *1*, etc.

- `code`: By default it will return the value of `_code`. It is mainly for the purpose of being overridden, if a specific error code is required.

- `domainPrefix`: By default its value is “*com.vmware.airwatch*”. It servers as a component as the property `domain`

- `domainSuffix`: By default its value is “*ErrorDomain*”. It servers as a component as the property `domain`

- `domainIdentifier`: This one will capture the `debugPrint()` result of current variable and converts it to a string. It servers as a component as the property `domain`.

- `domain`: This one is composed with `domainPrefix`, `domainSuffix`, and `domainIdentifier`. Its format follows this pattern: `domainPrefix. domainIdentifier.domainSuffix.`

- `_domain`: This one comes automatically with *protocol* **ErrorType** to which **AWErrorType** conforms to.

- `errorDescription`: The more detailed description of current error. It is mainly for the purpose of being overridden, if it is not, it will return the case name by default.

- `localizableInfo`: The extra information of this error that can or needs to be localized. It is mainly for the purpose of being overridden. If it does not have a valid value, it will return `nil`. By default, it will be added to the *Dictionary* `_userInfo` with *Key* `NSLocalizedDescriptionKey`, if it is not `nil`.

- `_userInfo`: If `localizableInfo` **is not** `nil`, then this property will be a `Dictionary<String: String>` that contains only one entry which comes with *Key* `NSLocalizedDescriptionKey` and *Value* of `localizableInfo`. But if `localizableInfo` **is** `nil`, it will return `nil` as well.

- `userInfo`: By default, it will return property `_userInfo`. It is mainly for the purpose of being overridden, if you wish to add more information to the `userInfo` dictionary. Here is how to customize your own `userInfo`:

	```
	// First, you declare a variable that 
	// is empty, if _userInfo is nil
	// or equal to _userInfo, if _userInfo is not nil
	var userInfoDict: AWErrorInfoDict = _userInfo ?? [:]
	
	// Second, you add as many your customized key-value pairs as you want
	userInfoDict["Test1Key"] = Test1ValueProperty
	userInfoDict["Test2Key"] = Test1ValueProperty
	
	// Finally, you
	// return nil, if userInfoDict is empty
	// return userInfoDict if it is not empty
	return userInfoDict.isEmpty ? nil : userInfoDict
	
	
	
	// The whole process will be look like:
	var userInfo: AWErrorInfoDict? {
	      var userInfoDict: AWErrorInfoDict = _userInfo ?? [:]
	
	      userInfoDict["Test1Key"] = Test1ValueProperty
	      userInfoDict["Test2Key"] = Test1ValueProperty
	        
	      return userInfoDict.isEmpty ? nil : userInfoDict
	}
	```

- `error`: This is a `NSError` object. It is initialized with domain of property `domain`, code of property `code`, and userInfo of property  `userInfo`. When you want to use an `AWError` as `NSError`, this property will come handy. In the old way we deal with errors, we cast the `enum` case directly to `NSError`, this is doable, but it will loss all associated value except for `code` and `domain`, which means the `userInfo` will be lost for sure. So when you need a `NSError`, remember to use this property. For example, when you want to get a `NSError` version of `AWError.SDK.AssetManagement.DeviceNotEnrolled`: 

	**DO NOT USE FOLLOWING CODE**:

	```
	let err = AWError.SDK.AssetManagement.DeviceNotEnrolled as NSError

	```
	
	**PLEASE USE FOLLOWING CODE INSTEAD**:

	```
	let err = AWError.SDK.AssetManagement.DeviceNotEnrolled.error
	```

- `stackTrace`: It contains the stack trace at the point when the error was thrown, which will help developer to debug the deeper reason of the error.




---- 


## How to extend




---- 


### How to extend SDK errors
If you want to add an error in current SDK, here is the steps you need to take:

- First, add an `extension` of `AWError.SDK`
- Second, add your errors as an `enum` type into this `extension` and make sure this `enum` conforms to *protocol* `AWSDKErrorType`
- Finally, add your error cases inside this `enum`, and you are good to go. Here is an example.

	```
	// Now we are trying to add an error type called DemoTest
	public extension AWError.SDK {
	    enum DemoTest: AWSDKErrorType {
	        case Failed
		case Unknown
	    }
	}
	
	// Test
	// Following will return 0
	AWError.SDK.DemoTest.Failed.code 
	
	// Following will return com.vmware.airwatch.SDK.DemoTest.ErrorDomain
	AWError.SDK.DemoTest.Failed.domain
	```




---- 


### How to extend AWError at app level
- First, add a protocol that conform to `AWErrorType` for your own application to use.
- Second, add an`extension` of `AWError`
- Third, add your app level as an **empty** `enum` type into this `extension` and make sure this `enum` conforms to your own protocol
- Finally, start extending it by following the similar way introduced on * How to extend SDK errors*

	```
	// Now we are trying to add an app level extension for DemoApp
	public protocol AWDemoAppErrorType: AWErrorType {
	
	}
	
	public extension AWError {
	    enum DemoApp: AWDemoAppErrorType {
	
	    }
	}
	```
	