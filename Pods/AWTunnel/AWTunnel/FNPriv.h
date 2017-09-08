//
//  FNPriv.h
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#ifndef _FN_PRIV_H_
#define _FN_PRIV_H_

#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <assert.h>


/*
 * Utilities:
 * - CFLog(): present in iOS, but CFLogUtilities.h not in the SDK.
 * - FNHalt: forcibly stop the application; in the debugger, when applicable.
 */
#define CFLog(args...) \
do { \
CFStringRef _string = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, args); \
CFShow(_string); \
CFRelease(_string); \
} while(0)

#if defined(__arm__)
#define FNHalt() \
do { asm __volatile__("bkpt 0xCF"); kill(getpid(), 9); } while (0)
#else // x86
#define FNHalt() \
do { asm __volatile__("int3"); kill(getpid(), 9); } while (0)
#endif


/*
 * Make sure we use C, not Objective-C, ASSERTs.
 */

//#define ASSERT_DEBUG 1

#if defined(ASSERT_LOG)
#undef ASSERT_LOG
#endif
#if defined(ASSERT_DEBUG)
#define ASSERT_LOG(cond)                                \
if (!(cond)) {                                       \
CFLog(CFSTR("ASSERT in %s.%s:%d on (%s)"),               \
__FILE__, __FUNCTION__, __LINE__, #cond); \
}
#else
#define ASSERT_LOG(cond)
#endif


#if defined(ASSERT)
#undef ASSERT
#endif
#define ASSERT(cond)   \
do {                \
ASSERT_LOG(cond) \
assert((cond));  \
} while(0)



#define FN_TRACE_ON 1

#if defined(FN_TRACE_ON)
#define FN_TRACE()                               \
do {                                          \
CFLog(CFSTR("FN_TRACE at %s.%s:%d"),  \
__FILE__, __FUNCTION__, __LINE__); \
} while (0)
#else
#define FN_TRACE()
#endif


#if !defined(NELEM)
#define NELEM(a) (sizeof (a) / sizeof (a)[0])
#endif


/**
 * Tests whether the argument is NULL or an empty CFString.
 * @param string string to test.
 * @return 0 if test is negative, != 0 otherwise.
 */

static inline int
IsCFStringEmpty(CFStringRef string)
{
    return ((string == NULL) || (CFStringGetLength(string) == 0));
}


/**
 * Releases CF value argument, if not NULL.
 * @param val CFType value to release.
 */

static inline void
ReleaseIfNotNULL(CFTypeRef val)
{
    if (val) {
        CFRelease(val);
        val = nil;
    }
}


/*
 * Basic double-linked list functionality.
 */

typedef struct FNList {
    struct FNList *prev;
    struct FNList *next;
} FNList;

typedef int (*FNListCBType)(FNList *arg, void *cbData);


/**
 * Initializes a list element.
 * @param[in,out] elem the element to initialize.
 */

static inline void
FNListInit(FNList *elem)
{
    ASSERT(elem);
    elem->prev = elem->next = elem;
}


/**
 * Tests if given argument is an empty list.
 * @param elem the element to test.
 */

static inline int
FNListIsEmpty(FNList *elem)
{
    ASSERT(elem);
    return ((elem->prev == elem) && (elem->next == elem));
}


/**
 * Appends a list element after a known list position. It is illegal to
 *   append an element to itself.
 * @param[in,out] position list element after which new element is appended.
 * @param[in,out] elem the element to append.
 */

static inline void
FNListAppend(FNList *position,
             FNList *elem)
{
    ASSERT(position && elem && (position != elem));
    elem->next = position->next;
    elem->prev = position;
    position->next->prev = elem;
    position->next = elem;
}


/**
 * Removes a list element.
 * @param[in,out] elem the element to remove.
 * @return next element if list was not empty, 'elem' otherwise.
 */

static inline  FNList *
FNListRemove(FNList *elem)
{
    FNList *res;
    
    if (!FNListIsEmpty(elem)) {
        elem->next->prev = elem->prev;
        elem->prev->next = elem->next;
        res = elem->next;
    } else {
        res = elem;
    }
    
    return res;
}


/**
 * Deallocates a list by removing and calling the callback on all its elements.
 *    Note; No argument may be NULL.
 * @param elem list to deallocate.
 * @param cb deallocator callback function.
 * @param cbData callback function data.
 */

static inline void
FNListDeallocate(FNList *elem,
                 FNListCBType cb,
                 void *cbData)
{
    FNList *tmp;
    
    ASSERT(elem && cb);
    for (tmp = elem; (elem = FNListRemove(tmp)) != tmp; tmp = elem) {
        (void)cb(tmp, cbData);
    }
    cb(tmp, cbData);
}


/**
 * Applies a callback function over a list; the iteration may be stopped by
 *    the callback returning a non-zero value.
 *    Note; No argument may be NULL.
 * @param elem list to iterate over.
 * @param cb callback function.
 * @param cbData callback function data.
 * @return value returned by the callback on its last run.
 */

static inline int
FNListApply(FNList *elem,
            FNListCBType cb,
            void *cbData)
{
    int rc;
    FNList *tmp;
    
    ASSERT(elem && cb);
    for (tmp = elem; tmp->next != elem; tmp = tmp->next) {
        rc = cb(tmp, cbData);
        if (rc) {
            return rc;
        }
    }
    return cb(tmp, cbData);
}


/**
 * Apply callback for FNStringArrayLog
 * @param value array element value. Assumed to be CFString.
 * @param label the label cast to void *
 */
static inline void
FNStringArrayLogFunc(const void *value,
                     void *label)
{
    CFLog(CFSTR("%s %@"), (const char *)label, (CFStringRef)value);
}


/**
 * Simplistic utility to log a CFArray of CFStrings
 * @param label A label for each log line/item
 * @param array NULL or an array whose elements are all CFStrings.
 */
static inline void
FNStringArrayLog(const char *label,
                 CFArrayRef array)
{
    if (array == NULL) {
        CFLog(CFSTR("%s <NULL>"), label);
    } else {
        CFArrayApplyFunction(array, CFRangeMake(0, CFArrayGetCount(array)),
                             &FNStringArrayLogFunc, (void *)label);
    }
}

#endif // _FN_PRIV_H_

