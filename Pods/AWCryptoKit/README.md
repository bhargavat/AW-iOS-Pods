
![AWCryptoKit icon](https://cdn2.iconfinder.com/data/icons/security-2-1/512/Cryptography-128.png)

# AWCryptoKit
---
### Summary
AWCryptoKit is a group of algorithms, methods and helper functions to perform common crypto operations using
**CommonCrypto** for iOS and OSX

<br/>

## Table of Contents
---
- [Introducation](#introduction)
  * [Terminology](#introduction-terminology)
    * [Hash Encryption](#introduction-hash-encryption)
      * MD5
      * SHA1
      * SHA256
      * SHA512
    * [Symmetric Key Cryptography](#introduction-terminology-symmetric-key-crypt)
      * AES128
      * AES192
      * AES256
      * DES
      * Triple-DES(3DES)
    * [Asymmetric Cryptography](#introduction-terminology-asymmetric-crypt)
      * [RSA](#introduction-terminology-asymmetric-crypt-rsa)
- [Using Module](#using-module)
  * [Hash Encryption](#using-module-hash-encryption)
  * [Symmetric Key Cryptography](#using-module-symmetric-key-crypt)
  * [Asymmetric Key Cryptography](#using-module-asymmetric-key-crypt)
    * [Generating RSA](#using-module-asymmetric-key-crypt-generating-rsa)
    * [Encryption and Decryption using RSA](#using-module-asymmetric-key-crypt-encrypt-decrypt-rsa)


<br />

## Introduction <a name="introduction"></a>

---

This collection of classes/functions simplify the encryption/decryption of data using  symmetric, asymmetric and hash (hash encrypts one way) algorithms. To find real world examples check out the  AWOpenSSL module.

<br />

### Terminology <a name="introduction-terminology"></a>

---

### Hash Encryption <a name="introduction-hash-encryption"></a>

Hash algorithms encrypt data and there is no way to reverse the output to get the original data. Normally the hashed data has a fixed size regardless of the length of the data. One thing to note is that no two data sets can ever have the same output hash value.

Those that have a Level of Safety of LOW can be manipulated to be falsified.

Encryption | Level of Safety | FIPS
---|---|---
[MD5](https://en.wikipedia.org/wiki/MD5)| LOW | Unknown
[SHA1](https://en.wikipedia.org/wiki/SHA-1) | LOW | 180-1
[SHA2-256](https://en.wikipedia.org/wiki/SHA-2) | MED | 180-2
[SHA2-512](https://en.wikipedia.org/wiki/SHA-2) | HIGH | 180-2

***Example of Hashes of the text `hello`***

Algorithm |Hash Value
---|---
MD5 | 5d41402abc4b2a76b9719d911017c592
SHA1 | aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
SHA256| 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
SHA512 | 9B71D224BD62F3785D96D46AD3EA3D73319BFBC2890CAADAE2DFF72519673CA72323C3D99BA5C11D7C7ACC6E14B8C5DA0C4663475C2E5C3ADEF46F73BCDEC043

<br />

### Symmetric Key Cryptography <a name="introduction-terminology-symmetric-key-crypt"></a>

---

Symmetric encryption requires the same string, data, etc. to encrypt and decrypt data. All AES is compliant with FIPS PUB 197.

Encryption | Level of Safety | Description
---|---|---
AES128| MED |Description
AES192 | HIGH | Description
AES256 | HIGHER | Description
DES | NONE | Description
Triple-DES | LOW | Description

<br />

## Asymmetric Cryptography <a name="introduction-terminology-asymmetric-crypt"></a>

---

Asymmetric algorithms generate two different keys (private and public), where one is used to encrypt while the other is used to decrypt. The public key may be freely distributed to clients while the private one must be guarded (not distributed). The clients may decrypt encrypted data using the public key. Data encrypted with the public key can only be decrypted with the private key which should be kept somewhere secret.

<br/>

### RSA <a name="introduction-terminology-asymmetric-crypt-rsa"></a>
---

RSA is used in this module.

<br />

## Using Module <a name="using-module"></a>

---

### Hash Encryption <a name="using-module-hash-encryption"></a>

There are two ways that data can be hashed, Digest and BufferedDigest.

**Digest**

Digest is an enum which you specify the hash to use and then you call the `digest(data:) -> NSData?` function to get the hashed outputted data.

```
let stringData = "SomeStringData".dataUsingEncoding(NSUTF8StringEncoding)
let hashedStringDataUsingSHA512 = Digest.SHA512.digest(stringData!)
```

Also AWCryptKit offers an extension to NSData which offers encryption of data by calling the extension functions.

```
let stringData = "SomeStringData".dataUsingEncoding(NSUTF8StringEncoding)
let hashedStringDataUsingSHA512: NSData? = stringData!.sha512
```

The other ways to encrypt an NSData object are md5, sha1, and sha256.

**BufferedDigest**

BufferedDigest has an initializer which takes in the algorithm type (Digest) and it is possible to use this class as a factory get the hash output.

```
let stringData = "SomeStringData".dataUsingEncoding(NSUTF8StringEncoding)
let bufferedDigest = BufferedDigest(algorithm: Digest.SHA512)
bufferedDigest.update(stringData!)
let hashedStringDataUsingSHA512: NSData? = bufferedDigest.finalize()
```

**Note:**
After running update and passing in the data to hash, you will have access to the hashed value by accessing the `context: UnsafeMutablePointer<Void>`.

<br />

### Symmetric Key Cryptography <a name="using-module-symmetric-key-crypt"></a>

---

The CipherMessage protocol must be implemented in a class to encrypt or decrypt data. The class which implements the protocol can be initialize a few ways.

The default way to initialize can be done by...
```
struct CipherObject: CipherMessage {
  var algorithm: CipherAlgorithm
  var blockMode: BlockCipherMode
  var ivSize: Int
}

let cipherObject = CipherObject.defaultMessage
let stringDataToEncrypt = "DataToEncrypt".dataUsingEncoding(NSUTF8StringEncoding)
let keyData = "SecretKey".dataUsingEncoding(NSUTF8StringEncoding)

// Encrypt and then Decrypt the data
do {
  let encryptedData: NSData? = try cipherObject.encrypt(stringDataToEncrypt!, key: keyData!)
  let decryptedData: NSData? = try CipherObject.decrypt(encryptedData!, key: keyData!)
  let decryptedString = String(data: decryptedData!, encoding: NSUTF8StringEncoding)
} catch {
  // Handle Exceptions
}
// decryptedString and "DataToEncrypt" are the same
```

Besides the `defaultMessage`, it is possible to initialize an object by using other forms.

Forms to initialize:
* Static functions
  * defaultMessage
  * AES256ECBNoIV
  * AES256CBCWithIV
  * AES256CBCNoIV
  * AES128CBCWithIV
* Initializer(s)
  * init(algorithm:blockMode:ivSize:)

<br />

## Asymmetric Key Cryptography <a name="using-module-asymmetric-key-crypt"></a>

---

### Generating RSA public/private keypair <a name="using-module-asymmetric-key-crypt-generating-rsa"></a>


Generating a RSA public/private key pair requires you to call some of the static functions within SecurityKeyPair. The three static functions are `generate(keySize:identifier:persistent:)throws -> SecurityKeyPair`, `get(identifier:)throws -> SecurityKeyPair`,  `clear(identifier:)`.

**Generating SecurityKeyPair Object**

RSA requires a number of bits for encryption, that is the first parameter. The recommendation is to use 2048 or higher. It is necessary to have an identifier so to retrieve the correct public/private key-pair at a later time. To save persistently set the value for the third parameter to true to be retrievable using the identifier.

```
let securityKeyPair = try SecurityKeyPair.generate(2048, identifier: "MyCustomCertificate", persistent: true)
```

Once the SecurityKeyPair has been created, use the RSACryptor class to encrypt, decrypt, sign, and verify data.

RSACryptor can either be initialized or the static functions can be used.

**Retrieving**

To retrieve the previously created SecurityKeyPair just pass in the identifier previously used to create the object.

```
let securityKeyPairUsingIdentifier = try SecurityKeyPair.get("MyCustomCertificate")
```

**Clearing**

Clearing the SecurityKeyPair is just one call to the  clear function with the identifier.

```
SecurityKeyPair.clear("MyCustomCertificate")
```

**Note:** Generating and Retrieving should be surrounding with do/catch, else you can do `try?`.

<br />

### Encrypt and Decrypt data using RSA <a name="using-module-asymmetric-key-crypt-encrypt-decrypt-rsa"></a>

With a SecurityKeyPair object you can now use the RSACryptor class to encrypt, decrypt, sign, and verify data.

Methods to encrypt/decrypt data or create an object to encrypt/decrypt data...
* Class/Static functions
  * encrypt(data:publicKey:padding:) -> NSData?
  * decrypt(data:privateKey:padding:) -> NSData?
* Initializer(s)
  * init(keyPair:)

```
do {
  let securityKeyPair = try SecurityKeyPair.generate(2048, identifier: "MyCustomCertificate", persistent: true)
  let rsaCryptor = try RSACryptor(keyPair: securityKeyPair)
  let encryptedData = try rsaCryptor!.encrypt(dataToEncrypt!)
  let decryptedData = try rsaCryptor!.decrypt(encryptedData)
  let decryptedString = String(data: decryptedData, encoding: NSUTF8StringEncoding)
  // decryptedString is equal to BeamMeUpScotty
} catch {
  // Must Handle exceptions
}
```

Method | Throws
---|---
encrypt(data:)  | AWError.SDK.CryptoKit.RSACryptor.MissingPublicKey
-               | AWError.SDK.CryptoKit.RSACryptor.EncryptionFailed(status)
decrypt(data:)  | AWError.SDK.CryptoKit.RSACryptor.MissingPrivateKey
-               | AWError.SDK.CryptoKit.RSACryptor.DecryptionFailed(status)
sign(data:)     | AWError.SDK.CryptoKit.RSACryptor.MissingPrivateKey
-               | AWError.SDK.CryptoKit.RSACryptor.DataSigningFailed(status)
verify(data:)   | AWError.SDK.CryptoKit.RSACryptor.MissingPublicKey
-               | AWError.SDK.CryptoKit.RSACryptor.SignatureVerificationFailed(status)
encrypt(data:publicKey:padding:)  | AWError.SDK.CryptoKit.RSACryptor.EncryptionFailed(status)
decrypt(data:publicKey:padding:)  | AWError.SDK.CryptoKit.RSACryptor.DecryptionFailed(status)
sign(data:privateKey:padding:)    | AWError.SDK.CryptoKit.RSACryptor.DataSigningFailed(status)
verify(singedData:signature:publicKey:padding:) | AWError.SDK.CryptoKit.RSACryptor.SignatureVerificationFailed(status)
