//
//  Fuji.h
//
//  Common Objective-C exception, assertion and logging macros.
//
//  Copyright (c) 2012-2013 VMware, Inc. All rights reserved.
//
//

#import <objc/runtime.h>
#import "TargetConditionals.h"

/**
 * App Name
 */
#define kFujiAppName @"Fuji"

// Only use NSLogger on iOS
//TODO:CHECK #if TARGET_OS_IPHONE
//#import "utilities/LoggerClient.h"
//#endif

/**
 * Assertions are used to express invariants in the code for purposes of documentation and providing sanity checks on
 * debug builds, assisting developers. They may be removed in release builds and should not be relied upon as either a
 * runtime check for error/exception conditions or even for their side-effects, since they may be implemented as macros
 * and compiled out.
 *
 * @param _expr predicate to assert.
 */
#if defined(ASSERT)
#undef ASSERT
#endif
#define ASSERT(_expr) NSAssert((_expr), @"%s", #_expr)

/**
 * Fatal exception causes.
 */
typedef enum {
   /**
    * A security violation has been observed, possible attempt to compromise workspace
    */
   FUJI_FATAL_SECURITY,

   /**
    * An inconsistent filesystem exists, need to wipe Fuij/wrapped apps
    */
   FUJI_FATAL_FILESYSTEM,

   /**
    * An inconsistent keychain exists, need to wipe Fuji/wrapped apps
    */
   FUJI_FATAL_KEYCHAIN,

   /**
    * Memory allocation failed
    */
   FUJI_FATAL_MEMORY,

   /**
    * Unrecoverable network error
    */
   FUJI_FATAL_NETWORK,

   /**
    * Invalid internal state due to a static coding bug or memory corruption
    */
   FUJI_FATAL_INVALID_STATE,

   /**
    * Code path not yet implemented, though implementation is possible
    */
   FUJI_FATAL_NOT_IMPLEMENTED,

} Fuji_FatalCause;

/**
 * Validate arguements to FATAL_IF() macro
 *
 * @param cause enum decribing reason for abort
 */
static inline void
ValidateFatalIfArgs(Fuji_FatalCause cause)
{
   (void)cause;
}

/**
 * Runtime exceptions, leading to a graceful termination of the app.
 *
 * Runtime exceptions will be caught at the top-level with an appropriate UX, recovery is not possible.
 *
 * @param _expr predicate to trigger runtime assertion.
 * @param _cause Fuji_FatalCause value indicating to top-level the reason for termination.
*/
#define FATAL_IF(_expr, _cause) \
   do { \
      if (_expr) { \
         ValidateFatalIfArgs(_cause); \
         LOG_ERROR(@#_cause); \
         @throw [NSException exceptionWithName:@#_cause reason:@#_expr userInfo:nil]; \
      } \
   } while (0)

#define FATAL(_cause) FATAL_IF(YES, _cause)

/**
 * Code that is not implemented.
 *
 * @param _expr prdicate to trigger NOT_IMPLEMENTED behavior.
 */
#define NOT_IMPLEMENTED_IF(_expr) FATAL_IF(_expr, FUJI_FATAL_NOT_IMPLEMENTED)

#define NOT_IMPLEMENTED() //NOT_IMPLEMENTED_IF(YES)

/**
 * Log verbosity levels.
 */
typedef enum {
   /** Error messages */
   FUJI_LOG_ERROR,

   /** Warning messages */
   FUJI_LOG_WARN,

   /** Normal release build messages */
   FUJI_LOG_INFO,

   /** Debug build messages */
   FUJI_LOG_DEBUG,

   /** Only enabled with verbose logging */
   FUJI_LOG_VERBOSE,

} Fuji_LogLevel;

// Use NSLogger on iOS
#if TARGET_OS_IPHONE
#define LOG_NOFLUSH(_level, ...) /*\
   LogMessageF(NULL, __LINE__, __PRETTY_FUNCTION__, NULL, _level, __VA_ARGS__)*/

#define LOG(_level,...) \
do { \
   NSLog(@"<%d> %@", _level, [NSString stringWithFormat:__VA_ARGS__]); \
} while (0)

// Use NSLog on OSX
#else
#define LOG_NOFLUSH(_level, ...) \
   NSLog(@"<%d> %@", _level, [NSString stringWithFormat:__VA_ARGS__])

#define LOG(...) LOG_NOFLUSH(__VA_ARGS__)
#endif

#define LOG_ERROR(...)             LOG(FUJI_LOG_ERROR, ##__VA_ARGS__)
#define LOG_WARNING(...)           LOG(FUJI_LOG_WARN, ##__VA_ARGS__)
#ifndef LOG_INFO
#define LOG_INFO(...)              LOG(FUJI_LOG_INFO, ##__VA_ARGS__)
#endif
#define LOG_VERBOSE_NOFLUSH(...)   LOG_NOFLUSH(FUJI_LOG_VERBOSE, ##__VA_ARGS__)
#ifdef DEBUG
#ifndef LOG_DEBUG
#define LOG_DEBUG(...)             LOG(FUJI_LOG_DEBUG, ##__VA_ARGS__)
#endif
#else
#ifndef LOG_DEBUG
#define LOG_DEBUG(...)             (void)0
#endif
#endif
