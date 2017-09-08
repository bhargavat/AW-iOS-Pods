//
//  NSData+SecureSampling.m
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import <Foundation/Foundation.h>

#import <stdlib.h>
#import <string.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>

#import <Security/Security.h>
#import <Security/SecRandom.h>
#import <Security/Security.h>
#import <Security/SecRandom.h>


@import AWHelpers;
@import AWCrypto;

#import "FjwDetectJailbreak.h"

#define SEED_SIZE 64
#define R_SIZE 4
#define TIMESTAMP_SIZE 4
#define DATACHECK_SIZE 8
static NSString *const kAWString = @"AwYCDgIGAh4DAgYCDgIGAhcGAh4CBgIOFwIeAgYCDgIEAxMDFQ8DBxUHFwcLHxcPAgMOBQYHHgMKEwEVFx8BBRsRBA8DBwEDAQwOAwcfHR8DAwYBAw0DEgkREgULDA8bCgscGwQCCQwEAwEGHQcRFx4fBBgeCRESGRkBFwQWDBc=";

/**
 Must allocate the length of path plus one character for the character '\0' for the output parameter. Neither parameter must be NULL
 */
static inline void AW_manipulatePathValue(const char * path, char* output, size_t outputLength) __attribute__ ((always_inline));
static inline void AW_manipulatePathValue(const char * path, char* output, size_t outputLength)
{
    if (output == NULL || path == NULL || outputLength < strlen(path)) {
        return;
    }
#if TARGET_IPHONE_SIMULATOR
    memcpy(output, path, outputLength);
    return;
#else
    size_t length = strlen(path);
    output[length] = '\0';
    
    for (int index = 0; index < length; index++) {
        const unsigned char x = 0x95;
        char character = path[index];
        
        output[index] = character ^ x;
    }
#endif
}

static inline BOOL AW_doesProhibitedPathExist(const char * path) __attribute__((always_inline));
static inline BOOL AW_doesProhibitedPathExist(const char * path)
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    BOOL result = NO;
    
    struct stat s;
    int status;
    status = stat(path, &s);
    if (status != -1) {
        result = YES;
    }
    
    return result;
}

static inline BOOL AW_isMobileSubstrateInstalled() __attribute__((always_inline));
static inline BOOL AW_isMobileSubstrateInstalled()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL result = NO;
    
    /* Plain Text Values
     * const char *subStrate = "/MobileSubstrate.dylib";
     * const char *mobileSubPath = "Library/MobileSubstrate/MobileSubstrate.dylib";
     * const char *con1 = "Library/MobileSubstrate/DynamicLibraries/xCon.dylib";
     */
    const char *sub1 = "\xba\xd8\xfa\xf7\xfc\xf9\xf0\xc6\xe0\xf7\xe6\xe1\xe7\xf4\xe1\xf0\xbb\xf1\xec\xf9\xfc\xf7";
    size_t outputLengthForSUB1 = strlen(sub1)+1;
    char sub1Output[outputLengthForSUB1];
    AW_manipulatePathValue(sub1, sub1Output, outputLengthForSUB1);
    
    const char *sub2 = "\xd9\xfc\xf7\xe7\xf4\xe7\xec\xba\xd8\xfa\xf7\xfc\xf9\xf0\xc6\xe0\xf7\xe6\xe1\xe7\xf4\xe1\xf0\xba\xd8\xfa\xf7\xfc\xf9\xf0\xc6\xe0\xf7\xe6\xe1\xe7\xf4\xe1\xf0\xbb\xf1\xec\xf9\xfc\xf7";
    size_t outputLengthForSUB2 = strlen(sub2)+1;
    char sub2Output[outputLengthForSUB2];
    AW_manipulatePathValue(sub2, sub2Output, outputLengthForSUB2);
    
    const char *con1 = "\xd9\xfc\xf7\xe7\xf4\xe7\xec\xba\xd8\xfa\xf7\xfc\xf9\xf0\xc6\xe0\xf7\xe6\xe1\xe7\xf4\xe1\xf0\xba\xd1\xec\xfb\xf4\xf8\xfc\xf6\xd9\xfc\xf7\xe7\xf4\xe7\xfc\xf0\xe6\xba\xed\xd6\xfa\xfb\xbb\xf1\xec\xf9\xfc\xf7";
    size_t outputLengthForCON1 = strlen(con1)+1;
    char con1Output[outputLengthForCON1];
    AW_manipulatePathValue(con1, con1Output, outputLengthForCON1);
    
    //Check for existence of MobileSubstrate lib at path
    BOOL p1 = AW_doesProhibitedPathExist(sub1Output);
    if (p1) {
        result = YES;
    }
    
    if (!result) {
        void * h1 = dlopen(sub2Output, RTLD_LAZY);
        void * h2 = dlopen(con1Output, RTLD_LAZY);
        BOOL op1 = (h1) ? YES : NO;
        BOOL op2 = (h2) ? YES : NO;
        if (op1 || op2) {
            result = YES;
        }
    }
    
    if (!result) {
        BOOL pre1 = dlopen_preflight(sub2Output);
        BOOL pre2 = dlopen_preflight(con1Output);
        if (pre1 || pre2) {
            result = YES;
        }
    }
    
    if (!result) {
        //Check dylib names.
        u_int32_t count = _dyld_image_count();
        for (u_int32_t i = 0; i < count; i++) {
            const char * name = _dyld_get_image_name(i);
            char * libName = strrchr(name, '/');
            
            //name matches mobilesubstrate
            if (strcmp(libName, sub1Output) == 0) {
                result = YES;
                break;
            }
            
            //check for duplicate dylib names made by spoofers
            for (u_int32_t j = i + 1; j < count; j++) {
                const char *b = _dyld_get_image_name(j);
                if (strcmp(name, b) == 0) {
                    result = YES;
                    break;
                }
            }
            if (result) {
                break;
            }
        }
    }
    
    return result;
}

static inline BOOL AW_fstabModificationDetected() __attribute__((always_inline));
static inline BOOL AW_fstabModificationDetected()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    //const char * f = "/etc/fstab";
    const char * f = "\xba\xf0\xe1\xf6\xba\xf3\xe6\xe1\xf4\xf7";
    size_t outputLengthForF = strlen(f)+1;
    char fOutput[outputLengthForF];
    AW_manipulatePathValue(f, fOutput, outputLengthForF);
    
    BOOL result = NO;
    
    /*
     * NOTE! iOS 7, at least as of current beta,
     * does not let us stat the fstab file. That
     * is why we are checking return code.
     */
    
    struct stat s;
    int res = stat(fOutput, &s);
    if ((s.st_size < 70 || s.st_size > 300) && res == 0) {
        result = YES;
    }
    
    return result;
#endif
}

static inline BOOL AW_isRootApplicationsDirectorySymbolicallyLinked() __attribute__((always_inline));
static inline BOOL AW_isRootApplicationsDirectorySymbolicallyLinked()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL result = NO;
    
    //const char * a = "/Applications";
    const char * a = "\xba\xd4\xe5\xe5\xf9\xfc\xf6\xf4\xe1\xfc\xfa\xfb\xe6";
    size_t outputLengthForA = strlen(a)+1;
    char aOutput[outputLengthForA];
    AW_manipulatePathValue(a, aOutput, outputLengthForA);
    
    struct stat s;
    lstat(aOutput, &s);
    BOOL s1 = (s.st_mode & S_IFLNK);
    
    //Probably suspect if the folder is larger than a terabyte
    BOOL s2 = (s.st_size > 1099511627776);
    //Link number equal to or greater than int max
    BOOL s7 = (s.st_nlink >= UINT16_MAX);
    
    if (s1 || s2 || s7) {
        result = YES;
    }
    
    return result;
}

static inline BOOL AW_isCydiaInstalled() __attribute__((always_inline));
static inline BOOL AW_isCydiaInstalled ()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    BOOL result = NO;
    
   	//const char * cp = "/Applications/Cydia.app";
    const char * cp = "\xba\xd4\xe5\xe5\xf9\xfc\xf6\xf4\xe1\xfc\xfa\xfb\xe6\xba\xd6\xec\xf1\xfc\xf4\xbb\xf4\xe5\xe5";
    size_t outputLengthForCP = strlen(cp)+1;
    char cpOutput[outputLengthForCP];
    AW_manipulatePathValue(cp, cpOutput, outputLengthForCP);
    
    //const char * lip = "/var/lib/cydia";
   	const char * lip = "\xba\xe3\xf4\xe7\xba\xf9\xfc\xf7\xba\xf6\xec\xf1\xfc\xf4";
    size_t outputLengthForlip = strlen(lip)+1;
    char lipOutput[outputLengthForlip];
    AW_manipulatePathValue(lip, lipOutput, outputLengthForlip);
    
    //const char * lop = "/var/tmp/cydia.log";
    const char * lop = "\xba\xe3\xf4\xe7\xba\xe1\xf8\xe5\xba\xf6\xec\xf1\xfc\xf4\xbb\xf9\xfa\xf2";
    size_t outputLengthForlop = strlen(lop)+1;
    char lopOutput[outputLengthForlop];
    AW_manipulatePathValue(lop, lopOutput, outputLengthForlop);
    
   	BOOL c1 = AW_doesProhibitedPathExist(cpOutput);
   	BOOL c2 = AW_doesProhibitedPathExist(lipOutput);
   	BOOL c3 = AW_doesProhibitedPathExist(lopOutput);
    
   	result = (c1 || c2 || c3);
    
#if DEBUG && DD_NLOG_LEVEL > 4 
    //Move into if debug
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:cpOutput], (c1) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:lipOutput], (c2) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:lopOutput], (c3) ? @"YES" : @"NO");
#endif
    
    return result;
}

static inline BOOL AW_doesAPTDirectoryExists() __attribute__((always_inline));
static inline BOOL AW_doesAPTDirectoryExists ()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL result = NO;
    
    //const char * ap = "/etc/apt/";
    const char * ap = "\xba\xf0\xe1\xf6\xba\xf4\xe5\xe1\xba";
    size_t outputLengthForAP = strlen(ap)+1;
    char apOutput[outputLengthForAP];
    AW_manipulatePathValue(ap, apOutput, outputLengthForAP);
    
    //const char * alp = "/var/lib/apt";
    const char * alp = "\xba\xe3\xf4\xe7\xba\xf9\xfc\xf7\xba\xf4\xe5\xe1";
    size_t outputLengthForALP = strlen(alp)+1;
    char alpOutput[outputLengthForALP];
    AW_manipulatePathValue(alp, alpOutput, outputLengthForALP);
    
    //const char * acp = "/var/cache/apt";
    const char * acp = "\xba\xe3\xf4\xe7\xba\xf6\xf4\xf6\xfd\xf0\xba\xf4\xe5\xe1";
    size_t outputLengthForACP = strlen(acp)+1;
    char acpOutput[outputLengthForACP];
    AW_manipulatePathValue(acp, acpOutput, outputLengthForACP);
    
    BOOL a1 = AW_doesProhibitedPathExist(apOutput);
    BOOL a2 = AW_doesProhibitedPathExist(alpOutput);
    BOOL a3 = AW_doesProhibitedPathExist(acpOutput);
    
    result = (a1 || a2 || a3);
    
#if DEBUG && DD_NSLOG_LEVEL > 4
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:apOutput], (a1) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:alpOutput], (a2) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:acpOutput], (a3) ? @"YES" : @"NO");
#endif
    
    return result;
}

static inline BOOL AW_canWriteRootPath() __attribute__((always_inline));
static inline BOOL AW_canWriteRootPath ()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL canWrite = NO;
    const char * f = "\xba\xe3\xf4\xe7\xba\xf8\xfa\xf7\xfc\xf9\xf0\xba\xe1\xf0\xf8\xe5\xbb\xe1\xed\xe1";
    //const char * f = "/var/mobile/temp.txt";
    size_t outputLengthForF = strlen(f)+1;
    char fOutput[outputLengthForF];
    AW_manipulatePathValue(f, fOutput, outputLengthForF);
    
    FILE *file = fopen(fOutput, "wb+");
    int status;
    if (file) {
        status = fprintf(file, "We simplify enterprise mobility\n");
        if (status >= 0) {
            canWrite = YES;
        }
        fclose(file);
    }
    
    return canWrite;
}

static inline BOOL AW_canFork() __attribute__((always_inline));
static inline BOOL AW_canFork ()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL canFork = NO;
    
    int result = fork();
    if (!result)
        exit(0);
    if (result >= 0) {
        canFork = YES;
    }
    
    return canFork;
}

static inline BOOL AW_doesSupplementarySystemCheckFail() __attribute__((always_inline));
static inline BOOL AW_doesSupplementarySystemCheckFail()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    BOOL result = NO;
    
    //const char * sysLogPath = "/var/log/syslog";
    const char * sl = "\xba\xe3\xf4\xe7\xba\xf9\xfa\xf2\xba\xe6\xec\xe6\xf9\xfa\xf2";
    size_t outputLengthForSL = strlen(sl)+1;
    char slOutput[outputLengthForSL];
    AW_manipulatePathValue(sl, slOutput, outputLengthForSL);
    
    //const char * bashPath = "/bin/bash";
    const char * ba = "\xba\xf7\xfc\xfb\xba\xf7\xf4\xe6\xfd";
    size_t outputLengthForBA = strlen(ba)+1;
    char baOutput[outputLengthForBA];
    AW_manipulatePathValue(ba, baOutput, outputLengthForBA);
    
    //const char * shPath = "/bin/sh";
    const char * sh = "\xba\xf7\xfc\xfb\xba\xe6\xfd";
    size_t outputLengthForSH = strlen(sh)+1;
    char shOutput[outputLengthForSH];
    AW_manipulatePathValue(sh, shOutput, outputLengthForSH);
    
    BOOL s1 = AW_doesProhibitedPathExist(slOutput);
    BOOL s2 = AW_doesProhibitedPathExist(baOutput);
    BOOL s3 = AW_doesProhibitedPathExist(shOutput);
    
#if DEBUG && DD_NSLOG_LEVEL > 4
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:slOutput], (s1) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:baOutput], (s2) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:shOutput], (s3) ? @"YES" : @"NO");
#endif
    
    result = (s1 || s2 || s3);
    if (DJ_CheckSystem()) {
        return result;
    }

    return NO;
}

static inline BOOL AW_isOpenSSHInstalled() __attribute__((always_inline));
static inline BOOL AW_isOpenSSHInstalled()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL result = NO;
    
    //const char *sshPath = "/usr/sbin/sshd";
    const char *sp = "\xba\xe0\xe6\xe7\xba\xe6\xf7\xfc\xfb\xba\xe6\xe6\xfd\xf1";
    size_t outputLengthForSP = strlen(sp)+1;
    char spOutput[outputLengthForSP];
    AW_manipulatePathValue(sp, spOutput, outputLengthForSP);
    
    //const char *sshKeysign = "/usr/libexec/ssh-keysign";
    const char *sk = "\xba\xe0\xe6\xe7\xba\xf9\xfc\xf7\xf0\xed\xf0\xf6\xba\xe6\xe6\xfd\xb8\xfe\xf0\xec\xe6\xfc\xf2\xfb";
    size_t outputLengthForSK = strlen(sk)+1;
    char skOutput[outputLengthForSK];
    AW_manipulatePathValue(sk, skOutput, outputLengthForSK);
    
    //const char *sshConfig = "/etc/ssh/sshd_config";
    const char *sc = "\xba\xf0\xe1\xf6\xba\xe6\xe6\xfd\xba\xe6\xe6\xfd\xf1\xca\xf6\xfa\xfb\xf3\xfc\xf2";
    size_t outputLengthForSC = strlen(sc)+1;
    char scOutput[outputLengthForSC];
    AW_manipulatePathValue(sc, scOutput, outputLengthForSC);
    
    BOOL s1 = AW_doesProhibitedPathExist(spOutput);
    BOOL s2 = AW_doesProhibitedPathExist(skOutput);
    BOOL s3 = AW_doesProhibitedPathExist(scOutput);
    
#if DEBUG && DD_NSLOG_LEVEL > 4
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:spOutput], (s1) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:skOutput], (s2) ? @"YES" : @"NO");
    log(info: @"Path: %@ Exists: %@", [NSString stringWithUTF8String:scOutput], (s3) ? @"YES" : @"NO");
#endif
    
    result = (s1 || s2 || s3);
    
    return result;
}

static inline BOOL AW_isCompromised() __attribute__((always_inline));
static inline BOOL AW_isCompromised()
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#endif
    
    BOOL isCompromised = NO;
    
    BOOL cydiaExists = AW_isCydiaInstalled();
   	BOOL aptExists = AW_doesAPTDirectoryExists();
    BOOL canWrite = AW_canWriteRootPath();
    BOOL canFork = AW_canFork();
    BOOL fstabModified = AW_fstabModificationDetected();
    BOOL isAppDirSymLink = AW_isRootApplicationsDirectorySymbolicallyLinked();
    BOOL isMobileSubstateInstalled = AW_isMobileSubstrateInstalled();
    BOOL isOpenSSHInstalled = AW_isOpenSSHInstalled();
    BOOL doesSupplementarySystemCheckFail = AW_doesSupplementarySystemCheckFail();
    
    if (cydiaExists || aptExists ||
        canWrite || canFork ||
        fstabModified || isAppDirSymLink ||
        isMobileSubstateInstalled ||
        doesSupplementarySystemCheckFail || isOpenSSHInstalled || DJ_IsJailBroken())
    {
        isCompromised = YES;
    }
    
#if DEBUG && DD_NSLOG_LEVEL > 4
    log(info: @"Cydia Insalled: %@", (cydiaExists) ? @"YES" : @"NO");
    log(info: @"apt Exists: %@", (aptExists) ? @"YES" : @"NO");
    log(info: @"Can Write Root Path: %@", (canWrite) ? @"YES" : @"NO");
    log(info: @"Can Fork: %@", (canFork) ? @"YES" : @"NO");
    log(info: @"fstab Size Failed: %@", (fstabModified) ? @"YES" : @"NO");
    log(info: @"App Dir is Symbolically Linked: %@", (isAppDirSymLink) ? @"YES" : @"NO");
    log(info: @"Mobile Substrate Insalled: %@", (isMobileSubstateInstalled) ? @"YES" : @"NO");
    log(info: @"Bin Dir Contains Jailbroken Items: %@", (doesSupplementarySystemCheckFail) ? @"YES" : @"NO");
    log(info: @"OpenSSH Installed: %@", (isOpenSSHInstalled) ? @"YES" : @"NO");
    
    log(info: @"Is Device Compromised: %@", (isCompromised) ? @"YES" : @"NO");
#endif
    
    return isCompromised;
}

//
static BOOL  AW_isPrime(unsigned int number) __attribute__((always_inline));
static BOOL  AW_isPrime(unsigned int number)
{
    if (number <= 1) return NO; // zero and one are not prime
    unsigned int i;
    for (i=2; i*i<=number; i++) {
        if (number % i == 0) return NO;
    }
    return YES;
}
static int  AW_prime(int st,int end) __attribute__((always_inline));
static int  AW_prime(int st,int end)
{
    int start = 0;
    
    for (start = st; start < end; start++)
    {
        if (AW_isPrime(start))
            return start;
    }
    return start;
}

static int  AW_composite(int st,int end) __attribute__((always_inline));
static int  AW_composite(int st,int end)
{
    int start = 0;
    
    for (start = st+1; start < end; start++)
    {
        if (!AW_isPrime(start))
            return start;
    }
    return start;
}

static int  AW_rand(int st,int end) __attribute__((always_inline));
static int  AW_rand(int st,int end)
{
    int r = rand()%(end - st) + st;
    return r;
}
static inline void AW_transform(uint8_t *b,int pos) __attribute__((always_inline));
static inline void AW_transform(uint8_t *b,int pos)
{
    uint8_t *po =(uint8_t*)[[NSData AW_base64DecodedData:kAWString] bytes];
    memset(b,0x0,DATACHECK_SIZE);
    uint8_t pr = pos +1;
    
    *(b+0) = (*(po+(pos*DATACHECK_SIZE+0)) ^ pr);
    *(b+1) = (*(po+(pos*DATACHECK_SIZE+1)) ^ *(b+0));
    *(b+2) = (*(po+(pos*DATACHECK_SIZE+2)) ^ *(b+1));
    *(b+3) = (*(po+(pos*DATACHECK_SIZE+3)) ^ *(b+2));
    *(b+4) = (*(po+(pos*DATACHECK_SIZE+4)) ^ *(b+3));
    *(b+5) = (*(po+(pos*DATACHECK_SIZE+5)) ^ *(b+4));
    *(b+6) = (*(po+(pos*DATACHECK_SIZE+6)) ^ *(b+5));
    *(b+7) = (*(po+(pos*DATACHECK_SIZE+7)) ^ *(b+6));
    
}
static NSString * AW_byte() __attribute__((always_inline));
NSString * AW_byte(const uint8_t deviceseed[32])
{
    
    uint8_t msg[72];
    uint head[R_SIZE];
    
    memset(msg,  0x0, sizeof(uint8_t)*72);
    memset(head, 0x0, sizeof(uint)*R_SIZE);
    
    char *seed = "\xad\xa7\xf4\xa5\xac\xa5\xf1\xf1\xa2\xad\xf1\xa3\xa1\xa4\xac\xf6\xa7\xf3\xa3\xa6\xf0\xa1\xa1\xa7\xad\xa4\xa7\xf6\xf1\xa1\xa4\xa2\xf7\xf7\xa4\xa2\xf6\xad\xa4\xa5\xf0\xac\xa6\xf0\xf1\xf4\xf4\xf7\xa7\xa7\xac\xa6\xf6\xa7\xf7\xf1\xa2\xf1\xf4\xa6\xa4\xa4\xf4\xac";
    
    uint32_t time = [[NSDate aw_gmtDate] timeIntervalSince1970];
    
    srand(time);
    NSData *random = [[NSData alloc] initWithRandomBytesLength:72];
    
    memcpy(msg,[random bytes], 72); // Random
    
    NSData *random1 = [[NSData alloc] initWithRandomBytesLength:R_SIZE];
    memcpy(head, [random1 bytes], R_SIZE);
    
    uint8_t version = 1;
    
    uint8_t value = 0;
    // Fill random
    
    
    memcpy(msg+28,deviceseed,32);
    
    memcpy(msg+60, &time, TIMESTAMP_SIZE);
    
    uint8_t b[DATACHECK_SIZE];
    memset(b,0x0,DATACHECK_SIZE);
    
    int pos = 0;
    //----------------------- OPCODE----------------------------------
    uint8_t idx = 0;
    srand(time);
    
    int count = time %10;
    while (count>0)
    {
        count--;
        idx = AW_rand(0, 15);
    }
    idx = AW_rand(0, 15);
    
    uint8_t opcode = 0;
    opcode = (idx & 0x1F);
    opcode = (opcode << 3);
    memcpy(msg+26, &opcode, 1);
    //----------------------- OPCODE----------------------------------
    
    //----------------------- Get Position Array----------------------
    uint8_t p=2,c=1,previous_p,previous_c;
    p = AW_rand(0, 128);
    previous_p = p;
    previous_c = c;
    AW_transform(b, idx);
    
    //----------------------- Start----------------------
    //_______________________________________________________________________________________________________________
   	
    BOOL c1 = AW_isCydiaInstalled();
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = c;
    }
    else{
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        value = p;
        previous_p = p;
    }
    
    // 2.
    //_______________________________________________________________________________________________________________
    c=previous_c;
    p = previous_p;
    pos ++;
    
    //_______________________________________________________________________________________________________________
    
    c1 = AW_doesAPTDirectoryExists();
    
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
        
    }
    else{
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    
    c=previous_c;
    p = previous_p;
    pos ++;
    // 3
    //_______________________________________________________________________________________________________________
    
    c1 = AW_canWriteRootPath();
    
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
        
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    
    c=previous_c;
    p = previous_p;
    pos ++;
    
    // 4
    //_______________________________________________________________________________________________________________
    
    c1 = AW_canFork();
    
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value =  value ^ c;
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    c=previous_c;
    p = previous_p;
    pos ++;
    
    // 5
    //_______________________________________________________________________________________________________________
    
    c1 = AW_fstabModificationDetected();
    BOOL c11 = DJ_IsJailBroken();
    if (c1 || c11)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    
    c=previous_c;
    p = previous_p;
    pos ++;
    
    // 6
    //_______________________________________________________________________________________________________________
    c1 = AW_isRootApplicationsDirectorySymbolicallyLinked();
    
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    
    c=previous_c;
    p = previous_p;
    pos ++;
    //_______________________________________________________________________________________________________________
    
    c1 = AW_isMobileSubstrateInstalled();
    if (c1)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    c=previous_c;
    p = previous_p;
    pos ++;
    
    // 7
    //_______________________________________________________________________________________________________________
    
    c1 = AW_isOpenSSHInstalled();
    c11 = DJ_IsJailBroken();
    BOOL c3 = AW_doesSupplementarySystemCheckFail();
    if (c1 || c3 || c11)
    {
        srand(c);
        c = AW_composite(c, 255);// change composite
        msg[b[pos]] = ((c << pos) | (c >> (sizeof(uint8_t)*8 - pos)));
        previous_c = c;
        value = value ^ c;
    } else
    {
        p = AW_prime(p+1, 255);
        msg[b[pos]] = ((p << pos) | (p >> (sizeof(uint8_t)*8 - pos)));
        previous_p = p;
        value = value ^ p;
    }
    c=previous_c;
    p = previous_p;
    pos ++;
    
    // /bin/sh/pwd
    const char * pathAsHexValue = "\xba\xf7\xfc\xfb\xba\xe6\xfd\xba\xe5\xe2\xf1";
    size_t outputLengthForAsHexValue = strlen(pathAsHexValue)+1;
    char p1_Output[outputLengthForAsHexValue];
    AW_manipulatePathValue(pathAsHexValue, p1_Output, outputLengthForAsHexValue);
    
    BOOL c2 = AW_doesProhibitedPathExist(p1_Output);
    if (c2)
    {
        
    }
    // /bin/sh/ps
    pathAsHexValue = "\xba\xf7\xfc\xfb\xba\xe6\xfd\xba\xe5\xe6";
    outputLengthForAsHexValue = strlen(pathAsHexValue)+1;
    char p2_Output[outputLengthForAsHexValue];
    AW_manipulatePathValue(pathAsHexValue, p2_Output, outputLengthForAsHexValue);
    c2 = AW_doesProhibitedPathExist(p2_Output);
    if (c2)
    {
        
    }
    ///var/mobile/cyd.txt
    pathAsHexValue = "\xba\xe3\xf4\xe7\xba\xf8\xfa\xf7\xfc\xf9\xf0\xba\xf6\xec\xf1\xbb\xe1\xed\xe1";
    outputLengthForAsHexValue = strlen(pathAsHexValue)+1;
    char p3_Output[outputLengthForAsHexValue];
    AW_manipulatePathValue(pathAsHexValue, p3_Output, outputLengthForAsHexValue);
    c2 = AW_doesProhibitedPathExist(p3_Output);
    if (c2)
    {
        
    }
    // /Library/MobileSubstrate/DynamicLibraries/cyd.dylib
    pathAsHexValue = "\xba\xd9\xfc\xf7\xe7\xf4\xe7\xec\xba\xd8\xfa\xf7\xfc\xf9\xf0\xc6\xe0\xf7\xe6\xe1\xe7\xf4\xe1\xf0\xba\xd1\xec\xfb\xf4\xf8\xfc\xf6\xd9\xfc\xf7\xe7\xf4\xe7\xfc\xf0\xe6\xba\xf6\xec\xf1\xbb\xf1\xec\xf9\xfc\xf7";
    outputLengthForAsHexValue = strlen(pathAsHexValue)+1;
    char p4_Output[outputLengthForAsHexValue];
    AW_manipulatePathValue(pathAsHexValue, p4_Output, outputLengthForAsHexValue);
    c2 = AW_doesProhibitedPathExist(p4_Output);
    if (c2)
    {
        
    }
    
    //_______________________________________________________________________________________________________________
    
    //----------------------- END----------------------
    
    memcpy(msg+25,&value,1);
    size_t outputLengthForSeed = strlen(seed)+1;
    char preshared[outputLengthForSeed];
    AW_manipulatePathValue(seed, preshared, outputLengthForSeed);
    uint8_t presharedLength = SEED_SIZE + R_SIZE;
    uint8_t seedValue[SEED_SIZE+R_SIZE];
    memcpy(seedValue, preshared, SEED_SIZE);
    memcpy(seedValue+SEED_SIZE, head, R_SIZE);
    
    unsigned char md[CC_SHA512_DIGEST_LENGTH];
    unsigned char *result = CC_SHA512(seedValue, presharedLength, md);
    for (int i=0;i<64;i++)
    {
        msg[i] = msg[i] ^ result[i];
    }
    
    
    NSMutableData *finalData = [NSMutableData data];
    [finalData appendBytes:&version length:1];
    [finalData appendBytes:head length:R_SIZE];
    [finalData appendBytes:msg length:64];
    
    return [finalData base64EncodedStringWithOptions:0];
}


#pragma mark public/global function

NSString* awBytesFromData(NSData *data)
{
    NSMutableData *mutableData = [NSMutableData dataWithLength:32];
    NSRange range = {0, MIN(32, [data length])};

    [mutableData replaceBytesInRange:range
                           withBytes:[data bytes]];

    return AW_byte([mutableData bytes]);
}

BOOL awIsCompromised()
{
    return AW_isCompromised();
}
