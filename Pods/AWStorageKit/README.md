# AWStorage

## Overview

AWStorage is a module to set/get data from shared keychain, non-shared keychain and database. User can set/get anyObject, AWStorage will archive it to NSData before saving, and unarchive before return it to user.

## Installation

AWStorage is avaliable for [CocoaPods](http://cocoapods.org), To install:

* add the following to the top of your Podfile
```
source 'ssh://git@stash.air-watch.com:7999/icpd/specs.git'
source 'https://github.com/CocoaPods/Specs.git'
```
* add `pod 'AWStorageKit'` for your target

## Public APIs

1. **setSharedValue(key: String, value: AnyObject) throws**
Save value for key to shared Keychain.

2. **getSharedValue(key: String) throws -> AnyObject?**
get value for key from shared Keychain.

3. **setSecureLocalValue(key: String, value: AnyObject) throws**
Save value for key to non-shared Keychain.

4. **getSecureLocalValue(key: String) throws -> AnyObject?**
Get value for key from non-shared Keychain.

5. **setLocalValue(key: String, value: AnyObject ) throws**
Save value for key to database.

6. **getLocalValue(key: String) throws -> AnyObject?**
Get value for key from database.

## License

AWStorage is available under the VMware Copyright. See the LICENSE file for more info.
