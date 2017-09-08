# AWOpenSSL


## Introduction
AWOpenSSL is a dynamic framework that provides missing Crypto, Identity and Security  functions from iOS Common Crypto

## Background
Initial goal to have this as seperate framework is to limit the openssl integration to one repo and updates to openssl can be applied to top level application or SDKs that are being distributed without upgrading all components. 

We would like to limit the usage of Open SSL through an Objective-C Interface(as Swift framework is little messy to integrate with openssl). When native(Common Crypto) functionality is available we will slowly sunset openssl and replace with Common Crypto functions.

## Requirements

* **iOS8.0** and Above
* Targeted as Application, Framework or Static Library

## Usage
AWOpenSSL is distrubuted as a vendored framework through **Cocoapods**. You can integrate AWOpenSSL with **both Applications, Frameworks** written in **Objective-C** as well as **Swift**

Since AWOpenSSL is a dynamic library(Framework) you need to make sure the Framework will be copied into final product in case of application, embedded into Test bundle for Frameworks.

Here is a Small Example of how can you do this.

~~~ruby
	source 'ssh://git@stash.air-watch.com:7999/icpd/specs.git'
	source 'https://github.com/CocoaPods/Specs.git'
	
	platform :ios, '8.0'
	inhibit_all_warnings!
	use_frameworks!
	
	def framework_dependencies
	 ...
   	 pod 'AWOpenSSL'
	 ...   	 
	end
	
	def framework_tests_specific_dependencies
   	 pod 'Kiwi'
   	 pod 'Quick'
	 ...
	end

	target "<target app or framework>" do
	 framework_dependencies
	end

	target "<target app or framework tests>" do
	 framework_dependencies
	 framework_tests_specific_dependencies
	end
~~~



## Functionality
At this momenr AWOpenSSL provided following capabilities

* X509 Certificates
 	* Create with custom attrbitues
 	* Verify Certificate with Root Certificate
 	* Sign Certififcate with Root Certificate
* PKCS7 Encryption
  	* Encrypt payload with Certificate
 	* Decrypt Data with Certificate, password for private key
 	* Sign payload with Certificate
 	* Verify Payload signature with Certiciate, Password

* p12 Data Import
	* validate PKCS12 with the given password
	* Parse PKCS12 and extract certificate data
	* Extract private key from p12 file with password
    * Create a p12 certificate from a der formatted cert and pem formatted private key


## Create New Versions of AWOpenSSL
Creating a new Version of AWOpenSSL when there are changes have an addional step from creating a new version of Cocoapods.

When all changes have been made and tested, and ready to create a new version of Cocoapod, the process looks like this.

* Make sure all required public headers are properly added into **Headers: Public** Secion.
* Add the public headers into Bridging Header (**AWOpenSSL.h**).
* Update Framework version(**version-number**) (increase just build, minor or major) if required.
* Use the same version number in **AWOpenSSL.podspec**.
* Run Unit Tests one last time before the update.
* Use Carthage to build framework: 
	* `$ carthage build --no-skip-current`
	* `$ carthage archive AWOpenSSL`
	* Move latest built framework from **Carthage/Build/iOS/AWOpenSSL.framework** to **Release-Framework**.  
* Ensure that the new framework has been generated in **Release-Framework**.
* Commit changes to git.
* Create the **Tag** with version-number.
* Push changes and Tag to remote.
* push pod spec to Air Watch Specs repo.

~~~
	$ pod repo push <air-watch-specs> AWOpenSSL.podspec --verbose
~~~
