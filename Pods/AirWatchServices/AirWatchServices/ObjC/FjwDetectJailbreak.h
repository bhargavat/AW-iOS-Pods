//
//  FjwDetectJailbreak.h
//
//  Copyright (c) 2013,2014,2015 VMware, Inc. All rights reserved.
//

#ifndef fuji_DetectJailbreak_h
#define fuji_DetectJailbreak_h

#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/param.h>
#import <sys/ucred.h>
#import <sys/mount.h>
#import <sys/mman.h>

#if DEBUG && DD_NSLOG_LEVEL > 4
#define DEBUG_PERROR(s) perror(s)

#ifdef AWLogDebug
#define LOG_DEBUG(fmt,...) log(debug: fmt,##__VA_ARGS__)
#else
#define LOG_DEBUG(fmt,...) NSLog(fmt,##__VA_ARGS__)
#endif

#else
#define DEBUG_PERROR(s) do { } while (0)
#define LOG_DEBUG(fmt,...) (void)0
#endif

#define PT_DENY_ATTACH  31

// copied from xnu/bsd/sys/codesign.h

#define CS_VALID     0x0001
#define CS_HARD      0x0100
#define CS_KILL      0x0200

#define CS_OPS_STATUS   0

/* copied from acct.h */
#define ASU 0x02     /* used super-user permissions */

/**
 * Call ptrace via the syscall such that it is not simply interceptable.
 */
static inline int
inline_ptrace(int request, pid_t pid, caddr_t addr, int data)
{
#if defined(__arm64__)
    register uint32_t armr0 asm ("w0") = (uint32_t)request;
    register uint32_t armr1 asm ("w1") = (uint32_t)pid;
    register uint64_t armr2 asm ("x2") = (uint64_t)addr;
    register uint32_t armr3 asm ("w3") = (uint32_t)data;

    asm volatile ("mov   x16, #26\n\t" \
                  "svc   #128\n\t" \
                  "cset  %w1, cs"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2), "r" (armr3)
                  : "x4", "x5", "x6", "x7", "x16", "x17", "memory", "cc");

    if (!armr1) {
        return armr0;
    } else {
#ifdef DEBUG
        errno = armr0;
#endif
        return -1;
    }
#elif defined(__arm__)
    register unsigned int armr0 asm ("r0") = (unsigned int)request;
    register unsigned int armr1 asm ("r1") = (unsigned int)pid;
    register unsigned int armr2 asm ("r2") = (unsigned int)addr;
    register unsigned int armr3 asm ("r3") = (unsigned int)data;

    asm volatile ("mov   r12, #26 \n\t" \
                  "svc   #128 \n\t" \
                  "ite   cc \n\t" \
                  "movcc %1, #0 \n\t" \
                  "movcs %1, #1"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2), "r" (armr3)
                  : "r12", "memory");

    if (!armr1) {
        return armr0;
    } else {
#ifdef DEBUG
        errno = armr0;
#endif
        return -1;
    }
#else
    return -1;
#endif
}

/**
 * Call getfsstat via the syscall such that it is not simply interceptable.
 */
static inline int
inline_getfsstat(struct statfs *buf, int bufsize, int flags)
{
#if defined(__arm64__)
    register uint64_t armr0 asm ("x0") = (uint64_t)buf;
    register uint32_t armr1 asm ("w1") = (uint32_t)bufsize;
    register uint32_t armr2 asm ("w2") = (uint32_t)flags;

    asm volatile ("mov   w16, #347\n\t" \
                  "svc   #128\n\t" \
                  "cset  %w1, cs"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2)
                  : "x3", "x4", "x5", "x6", "x7", "x16", "x17", "memory", "cc");

    if (!armr1) {
        return (int)armr0;
    } else {
#ifdef DEBUG
        errno = (int)armr0;
#endif
        return -1;
    }
#elif defined(__arm__)
    register unsigned int armr0 asm ("r0") = (unsigned int)buf;
    register unsigned int armr1 asm ("r1") = (unsigned int)bufsize;
    register unsigned int armr2 asm ("r2") = (unsigned int)flags;

    asm volatile ("mov   r12, #256 \n\t" \
                  "orr   r12, r12, #91 \n\t" \
                  "svc   #128 \n\t" \
                  "ite   cc \n\t" \
                  "movcc %1, #0 \n\t" \
                  "movcs %1, #1"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2)
                  : "r3", "r12", "memory");

    if (!armr1) {
        return armr0;
    } else {
#ifdef DEBUG
        errno = armr0;
#endif
        return -1;
    }
#else
    return -1;
#endif
}

/**
 * Call csops via the syscall such that it is not simply interceptable
 */
static inline int
inline_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize)
{
#if defined(__arm64__)
    register uint32_t armr0 asm ("w0") = (uint32_t)pid;
    register uint32_t armr1 asm ("w1") = (uint32_t)ops;
    register uint64_t armr2 asm ("x2") = (uint64_t)useraddr;
    register uint64_t armr3 asm ("x3") = (uint64_t)usersize;

    asm volatile ("mov   x16, #169\n\t" \
                  "svc   #128\n\t" \
                  "cset  %w1, cs"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2), "r" (armr3)
                  : "x4", "x5", "x6", "x7", "x16", "x17", "memory", "cc");
    if (!armr1) {
        return armr0;
    } else {
#ifdef DEBUG
        errno = armr0;
#endif
        return -1;
    }
#elif defined(__arm__)
    register unsigned int armr0 asm ("r0") = (unsigned int)pid;
    register unsigned int armr1 asm ("r1") = (unsigned int)ops;
    register unsigned int armr2 asm ("r2") = (unsigned int)useraddr;
    register unsigned int armr3 asm ("r3") = (unsigned int)usersize;

    asm volatile ("mov   r12, #169 \n\t" \
                  "svc   #128 \n\t" \
                  "ite   cc \n\t" \
                  "movcc %1, #0 \n\t" \
                  "movcs %1, #1"
                  : "+r" (armr0), "+r" (armr1)
                  : "r" (armr2), "r" (armr3)
                  : "r12", "memory");
    if (!armr1) {
        return armr0;
    } else {
#ifdef DEBUG
        errno = armr0;
#endif
        return -1;
    }
#else
    return -1;
#endif
}

/**
 * Call getpid via the syscall such that it is not simply interceptable
 */
static inline int
inline_getpid(void)
{
#if defined(__arm64__)
    register uint32_t armw0 asm ("w0");

    asm volatile ("mov  w16, #20\n\t" \
                  "svc  #128\n\t"
                  : "=r" (armw0)
                  :
                  : "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x16", "x17", "memory", "cc");

    return armw0;
#elif defined(__arm__)
    register unsigned int armr0 asm ("r0") = 0;

    asm volatile ("mov   r12, #20 \n\t" \
                  "svc   128 \n\t" \
                  : "+r" (armr0)
                  :
                  : "r1", "r2", "r3", "r12", "memory");

    return armr0;
#else
    return -1;
#endif
}

/**
 * Log a statfs structure for debugging.
 *
 * \param fs statsfs reference.
 */
static inline void
LogStatFS(const struct statfs *fs)
{
    LOG_DEBUG(@"checkMounts() %s on %s %s (%x)%s%s%s\n",
              fs->f_mntfromname,
              fs->f_mntonname,
              fs->f_fstypename,
              fs->f_flags,
              (fs->f_flags & MNT_RDONLY) ? " r" : " w",
              (fs->f_flags & MNT_NOSUID) ? " nosuid" : "",
              (fs->f_flags & MNT_NODEV) ? " nodev" : "");
}

/**
 * Sanity check the current filesystem state for signs of a jailbroken system.
 *
 * iOS 5.1.1 JailBroken:
 *    /dev/disk0s1s1 on / (hfs, local, journaled, noatime)
 *    devfs on /dev (devfs, local, nobrowse)
 *    /dev/disk0s1s2 on /private/var (hfs, local, journaled, noatime, protect)
 *
 * \return Is the filesystem free from jailbreak symptoms?
 */
static inline Boolean
DJ_CheckMounts(void)
{
    int numFilesystems = inline_getfsstat(NULL, 0, 0);

    if (numFilesystems == -1) {
        DEBUG_PERROR("DJ_CheckMounts: getfsstat() 0");
        return false;
    }

    if (numFilesystems > 64) {
        LOG_DEBUG(@"checkMounts() too many filesystems");
        return false;
    }
    
    struct statfs filesystems[numFilesystems];
    int rc = inline_getfsstat(filesystems, (int)sizeof(filesystems), MNT_NOWAIT);

    if (rc == -1) {
        DEBUG_PERROR("DJ_CheckMounts(): getfsstat() sizeof(filesystems)");
        return false;
    }

    Boolean foundDevFS = false;
    Boolean rootOnHFS = false;
    Boolean rootOnAPFS = false;

    for (int i = 0; i < rc; i++) {
        struct statfs *fs = &(filesystems[i]);

        /*
         * All filesystems must enforce permissions.
         */
        if ((fs->f_flags & MNT_IGNORE_OWNERSHIP) == MNT_IGNORE_OWNERSHIP) {
            LOG_DEBUG(@"Ownership ignored");
            return false;
        }

        if (strcmp(fs->f_fstypename, "devfs") == 0) {
            /*
             * devfs on /dev devfs (4101000) w
             *
             * There should only be one devfs on /dev.
             */
            if (foundDevFS ||
                strcmp(fs->f_mntonname, "/dev") != 0) {
                return false;
            }

            foundDevFS = true;
        } else if (strcmp(fs->f_fstypename, "hfs") == 0) {
            if (strcmp(fs->f_mntonname, "/") == 0) {
                /*
                 * /dev/disk0s1s1 on / hfs (1480d000) w
                 *
                 * Must be read only.
                 */
                if ((fs->f_flags & MNT_RDONLY) != MNT_RDONLY) {
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnAPFS) {
                    return false;
                }
                rootOnHFS = true;
            } else if (strcmp(fs->f_mntonname, "/private/var") == 0) {
                /*
                 * /dev/disk0s1s2 on /private/var hfs (14809080) w
                 *
                 * must be nodev, nosuid.
                 */
                if ((fs->f_flags & (MNT_NODEV | MNT_NOSUID)) !=
                    (MNT_NODEV | MNT_NOSUID)) {
                    LOG_DEBUG(@"Invalid flags %x", fs->f_flags);
                    LogStatFS(fs);
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnAPFS) {
                    return false;
                }
                rootOnHFS = true;
            } else if (strcmp(fs->f_mntonname, "/private/var/wireless/baseband_data") == 0) {
                /*
                 * /dev/disk0s1s3 on /private/var/wireless/baseband_data hfs (14809018) w nosuid nodev
                 *
                 * must be nodev, nosuid.
                 */
                if ((fs->f_flags & (MNT_NODEV | MNT_NOSUID)) !=
                    (MNT_NODEV | MNT_NOSUID)) {
                    LOG_DEBUG(@"Invalid flags %x", fs->f_flags);
                    LogStatFS(fs);
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnAPFS) {
                    return false;
                }
                rootOnHFS = true;
            } else if (strcmp(fs->f_mntonname, "/Developer") == 0) {
                /*
                 * /dev/disk1 on /Developer hfs (4009001) r
                 *
                 * Must be MNT_RDONLY.
                 */
                if ((fs->f_flags & MNT_RDONLY) != MNT_RDONLY) {
                    return false;
                }
            } else {
                LOG_DEBUG(@"Unexpected mount");
                LogStatFS(fs);
                return false;
            }
        } else if (strcmp(fs->f_fstypename, "routefs") == 0) {
            if (strcmp(fs->f_mntonname, "/private/var/mobile") == 0) {
                /*
                 * route on /private/var/mobile routefs (101000) w
                 *
                 *  Flags MNT_LOCAL, MNT_DONTBROWSE not relevent for security.
                 */
            } else {
                LOG_DEBUG(@"Unexpected mount");
                LogStatFS(fs);
                return false;
            }
        } else if (strcmp(fs->f_fstypename,"apfs") == 0) {
            if (strcmp(fs->f_mntonname, "/") == 0) {
                /*
                 * /dev/disk0s1s1 on / apfs (14805009) r nosuid
                 *
                 *  Flags Must be MNT_RDONLY MNT_NOSUID.
                 */
                if ((fs->f_flags & (MNT_RDONLY | MNT_NOSUID)) != (MNT_RDONLY | MNT_NOSUID)) {
                    LOG_DEBUG(@"Invalid flags %x", fs->f_flags);
                    LogStatFS(fs);
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnHFS) {
                    return false;
                }
                rootOnAPFS = true;
            } else if (strcmp(fs->f_mntonname, "/private/var") == 0) {
                /*
                 * /dev/disk0s1s2 on /private/var apfs (14801098) w nosuid nodev
                 *
                 *  Flags Must be MNT_NODEV MNT_NOSUID.
                 */
                if ((fs->f_flags & (MNT_NODEV | MNT_NOSUID)) != (MNT_NODEV | MNT_NOSUID)) {
                    LOG_DEBUG(@"Invalid flags %x", fs->f_flags);
                    LogStatFS(fs);
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnHFS) {
                    return false;
                }
                rootOnAPFS = true;
            } else if (strcmp(fs->f_mntonname, "/private/var/wireless/baseband_data") == 0) {
                /*
                 * /dev/disk0s1s3 on /private/var/wireless/baseband_data apfs (14801018) w nosuid nodev
                 *
                 *  Flags Must be MNT_NODEV MNT_NOSUID.
                 */
                if ((fs->f_flags & (MNT_NODEV | MNT_NOSUID)) != (MNT_NODEV | MNT_NOSUID)) {
                    LOG_DEBUG(@"Invalid flags %x", fs->f_flags);
                    LogStatFS(fs);
                    return false;
                }
                /* all root filesystems should be the same type */
                if (rootOnHFS) {
                    return false;
                }
                rootOnAPFS = true;
            } else {
                LOG_DEBUG(@"Unexpected mount");
                LogStatFS(fs);
                return false;
            }
        } else {
            LOG_DEBUG(@"Unhandled filesystem type");
            LogStatFS(fs);
            return false;
        }
    }

    LOG_DEBUG(@"OK");

    return true;
}

/**
 * The sysctl variable security.mac.proc_enforce controls whether MAC policies
 * are enforced on process operations such as fork(), setpriority(), kill() and
 * wait(). This is patched in some jailbreaks.
 *
 * \return Is security.mac.proc_enforce set?
 */
static inline Boolean
DJ_CheckProcEnforce(void)
{
    int procEnforce[3];
    size_t len = sizeof(procEnforce);

    /*
     * Should use direct constants from iOS headers and inline syscall - @knownjira{FUJI-2095}.
     */
    int rc = sysctlbyname("security.mac.proc_enforce", &procEnforce, &len, NULL, 0);

    if (rc < 0) {
        DEBUG_PERROR("sysctl(\"security.mac.proc_enforce\",...)");
      return errno == EPERM;    // iOS 10b2 sandbox blocks access to sysctl();
    }

    LOG_DEBUG(@"security.mac.proc_enforce = %d\n", procEnforce[0]);

    return procEnforce[0] == 1;
}


/**
 * The sysctl variable security.mac.vnode_enforce controls??? whether MAC policies
 * are enforced on process operations such as fork(), setpriority(), kill() and
 * wait(). This is patched in some jailbreaks but is normally set back to 1 as soon as possible
 * so it is very unlikely that this check will ever fail.
 *
 * \return Is security.mac.vnode_enforce set?
 */
static inline Boolean
DJ_CheckVnodeEnforce(void)
{
    int vnodeEnforce[3];
    size_t len = sizeof(vnodeEnforce);

    /*
     * Should use direct constants from iOS headers and inline syscall - @knownjira{FUJI-2095}.
     */
    int rc = sysctlbyname("security.mac.vnode_enforce", &vnodeEnforce, &len, NULL, 0);

    if (rc < 0) {
        DEBUG_PERROR("sysctl(\"security.mac.vnode_enforce\",...)");
      return errno == EPERM;    // iOS 10b2 sandbox blocks access to sysctl();
    }

    LOG_DEBUG(@"security.mac.vnode_enforce = %d\n", vnodeEnforce[0]);

    return vnodeEnforce[0] == 1;
}

typedef uint32_t CC_LONG;
extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);

/**
 * \brief Check process environment variables
 *
 * The very common MobileSubstrate libraries used on Jailbroken devices use a number
 * of enviroment variables that should never otherwise be used. Also the debuggers also
 * add environment variables that are never used in production.
 *
 * The implementation is first done using simple string comparisions to prove the algorithm
 * followed by a hash based implementation to make it harder to observe what is being looked
 * for.
 *
 * \return No suspicious environemnt variables set?
 */
static inline Boolean
DJ_CheckEnvironment(void)
{
    /*
     * Number of suspicious variables presetn in the environment.
     */
    int value = 0;
    
    /*
     * These environment variables are set while debugging or by common jailbreaks.
     *
     * static const char *badEnvironments[] = {
     *    "DYLD_INSERT_LIBRARIES=",     // Set by MobileSubstrate for code injection
     *    "_MSSafeMode=",               // Set by MobileSubstrate to disable code injection
     *    "NSUnbufferedIO=",            // Set by debuggers
     *    "CFLOG_FORCE_STDERR=",        // Set by debuggers
     *    NULL
     * };
     *
     * SHA256 sums of the above strings to obfuscate what we are looking for.
     */
    static const unsigned char badHashes[4][32] = {
#ifndef DEBUG
#ifndef AWALLOWDEBUG
        { 0xbc, 0xde, 0x13, 0x96, 0x71, 0x0b, 0xdc, 0xd9, 0x1f, 0x9b, 0xaf, 0xcc, 0x11, 0x38, 0x35, 0x66, 0x91, 0x5e, 0x15, 0x8e, 0x80, 0xea, 0xdb, 0x99, 0x73, 0x6b, 0x93, 0xbb, 0xe3, 0x72, 0x99, 0x01 },
#endif
#endif
        { 0xfd, 0x00, 0xe3, 0xc3, 0xad, 0x36, 0x77, 0x11, 0xe9, 0xb8, 0x7d, 0x22, 0x1a, 0x39, 0x6b, 0x85, 0x2d, 0xab, 0x86, 0xa0, 0x60, 0x0a, 0xc2, 0xae, 0x1d, 0xa2, 0x96, 0x73, 0xa0, 0x84, 0x96, 0x7e },
#ifndef DEBUG
#ifndef AWALLOWDEBUG
        { 0x86, 0xc2, 0xda, 0x81, 0xd5, 0xc9, 0x3b, 0x30, 0x3d, 0xdb, 0x7e, 0x48, 0x21, 0xd7, 0xf5, 0x59, 0xc9, 0xcf, 0x36, 0x12, 0x1c, 0x05, 0x82, 0x22, 0xfa, 0x85, 0xce, 0x18, 0x0a, 0x3b, 0xe4, 0xe0 },
        { 0xf2, 0x78, 0x12, 0xc1, 0x90, 0x14, 0x45, 0xba, 0x13, 0x0e, 0xe5, 0xc2, 0xf6, 0x22, 0x21, 0x99, 0x5f, 0xd2, 0x7d, 0x66, 0xcf, 0xd0, 0xa9, 0xfc, 0x90, 0x50, 0x2d, 0x6a, 0x43, 0x11, 0xb4, 0x95 },
#endif
#endif
    };
    
    // Scan the current enviroment
    extern char **environ;
    
    for (int i = 0; environ[i]; i++) {
        // calculate md5
        unsigned char sha256Result[32];
        const char *currentEnvironmentVariable = environ[i];
        
        // j doubles as both the index and the length of the string
        size_t j = 0;
        // Search for the '=' sign and return the position at which it was found. End loop once we reach the '\0' character.
        while(currentEnvironmentVariable[j] != '\0' && currentEnvironmentVariable[j] != '=') {
            j++;
        }
        
        CC_SHA256(environ[i], (CC_LONG)j, sha256Result);
        
        for (int j = 0; j < (sizeof(badHashes)/sizeof(badHashes[0])); j++) {
            if (memcmp(sha256Result, badHashes[j], sizeof(sha256Result)) == 0) {
                // Suspicous environment variable present
                value++;
            }
        }
    }
    
    return value == 0;
}

/*
 * Check to see that all environment variables have equals signs
 * 
 * If by any chance a developer has changed the environment variable by not following basic posix standard, does not include an '=' sign for environment variables, then someone has tampered with the OS's environment variable.
 *
 * \return Are all environemnt variables properly set correctly?
 */
static inline Boolean
DJ_CheckEnvironmentVariablesProperlyFormatted(void) {
    extern char **environ;
    
    // Assume all environ variables are malformed unless a '=' sign is found
    BOOL environmentVariableIsMalformed = true;
    for (int i = 0; environ[i]; i++) {
        const char *currentEnvironmentVariable = environ[i];
        
        // Search for the '=' sign and end loop once we reach the '\0' character
        int j=0;
        while (currentEnvironmentVariable[j] != '\0') {
            if (currentEnvironmentVariable[j] == '=') {
                environmentVariableIsMalformed = false;
                break;
            }
            j++;
        }
        // If the '=' is not found then this variable will remain unchanged (true) and we can return that a environment variable is not formatted properly
        if (environmentVariableIsMalformed) {
            return false;
        }
    }
    return true;
}

/*
 * Query the current code signing enforcement status.
 *
 * Note that code signing is not enforced when running in the iOS Simulator or
 * when running under the debugger.
 *
 * \return Code signing enforced?
 */
static inline Boolean
DJ_CheckCsops(void)
{
    uint32_t csflags = 0;
    int rc = inline_csops(0, CS_OPS_STATUS, &csflags, sizeof(csflags));

    if (rc != 0) {
        DEBUG_PERROR("csops");
        return false;
    }

    LOG_DEBUG(@"csops flags %x", csflags);

    /*
     * Code signing is disabled when running under the debug to support
     * breakpoints.
     */
#ifdef AWALLOWDEBUG
    return true;
#endif
#ifdef DEBUG
    return true;
#else
    return (csflags & (CS_HARD | CS_KILL | CS_VALID)) == (CS_HARD | CS_KILL | CS_VALID);
#endif
}

/**
 * Check for evidence that we're being debugged - super-user permissions,
 * ptrace.
 *
 * \return Not being debugged?
 */
static inline Boolean
DJ_CheckDebugPerms(void)
{
#ifdef AWALLOWDEBUG
    return true;
#endif
    int rc;
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, inline_getpid()};
    struct kinfo_proc kp;

    memset(&kp, 0x00, sizeof(kp));

    /*
     * Get the current process information structure.
     *
     * Should inline syscall - @knownjira{FUJI-2095}.
     */
    size_t len = sizeof(kp);
    rc = sysctl(mib, 4, &kp, &len, NULL, 0);

    if (rc < 0) {
        DEBUG_PERROR("sysctl(CTL_KERN, KERN_PROC,...)");
        return false;
    }

#ifndef DEBUG
#if 0
    /*
     * ASU check seems to always fail, even on release/non-debugged/non-rooted builds - commenting out for now.
     *
     * @knownjira{FUJI-2223}
     */
    if (kp.kp_proc.p_acflag & ASU) {
        LOG_DEBUG(@"Something used super-user permissions! - are we being debugged? %d %d %x", getpid(), inline_getpid(), kp.kp_proc.p_acflag);
        return false;
    }
#endif

    /*
     * check for evidence that we are being debugged?
     */
    if (kp.kp_proc.p_oppid || kp.kp_proc.p_flag & P_TRACED) {
        LOG_DEBUG(@"Are we being ptraced?");
        return false;
    }
#endif

    return true;
}

/*
 * If command is a NULL pointer, system() will return non-zero if the command
 * interpreter sh(1) is available, and zero if it is not.
 *
 * \return sh absent?
 */
static inline Boolean
DJ_CheckSystem(void)
{
    static int (*fnPtrSystem)(const char *path) = NULL;
    if (fnPtrSystem == NULL) {
        fnPtrSystem = dlsym(RTLD_SELF, "system");
    }

    if (fnPtrSystem != NULL) {
        return fnPtrSystem(NULL) == 0;
    }

    return true;
}

/**
 * This both disables debuggers from attaching and disconnects any
 * currently attached ones.
 */
static inline void
DisablePtrace(void)
{
    int rc = inline_ptrace(PT_DENY_ATTACH, 0, NULL, 0);

    if (rc) {
        DEBUG_PERROR("ptrace");

        if (errno == ENOTSUP) {
            LOG_DEBUG(@"Debugger already attached!");
        }

        abort();
    }
}

/**
 * Is a device jailbroken?
 *
 * Some security theatre we perform, apply some heuristic to detect "common"
 * jailbreaks.
 *
 * \return Is the device jailbroken?
 */
static inline Boolean
DJ_IsJailBroken(void)
{
    /*
     * Can only perform jailbreak detection on an actual device.
     */
#if defined(__arm64__) || defined(__arm__)
    Boolean jailbroken =
    !(
      DJ_CheckMounts() &&
      DJ_CheckVnodeEnforce() &&
      DJ_CheckProcEnforce() &&
      DJ_CheckEnvironmentVariablesProperlyFormatted() &&
      DJ_CheckEnvironment() &&
      DJ_CheckCsops() &&
      DJ_CheckDebugPerms() &&
      DJ_CheckSystem());
#else
    Boolean jailbroken = false;
#endif

    if (jailbroken) {
        LOG_DEBUG(@"JAILBROKEN!!!");
        DisablePtrace();
    }

    return jailbroken;
}

#endif
