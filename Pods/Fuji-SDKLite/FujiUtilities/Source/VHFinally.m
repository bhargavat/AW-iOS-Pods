//
//  VHFinally.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHFinally.h"

@interface VHFinally ()

/** The block to call, finally */
@property (nonatomic, copy) dispatch_block_t block;

@end

/**
 * \brief A "scope guard" helper that calls a block when it is released, typically at scope exit.
 *
 * ARC guaranttees that objects referenced only locally will be released at scope exit. This enables
 * code patterns similar to C++ RAII or Python's with keyword.
 *
 * VHFinally executes a block at scope exit time. This can be a convenient way to manage cleanup when a
 * function has multiple return sites. For example:
 *
 * - (void)foo
 * {
 *    MyFile *file = [MyFile file:...];
 *    __unused id closeFile = [VHFinally newFinally:^{ [file close]; }];
 *
 *    ... use file ...
 *    return; // <-- [file close] is sent as we exit the scope
 * }
 *
 * __unused silences compiler warnings about unused variables.
 */
@implementation VHFinally

/**
 * \brief Create a new VHFinally object with the given block (if any)
 *
 * Note it is important that this method name begin with "new" otherwise the returned object is placed
 * in an autorelease pool.
 *
 * \param block the block to call or nil
 *
 * \return the new VHFinally instance
 */
+ (VHFinally *)newFinally:(dispatch_block_t)block
{
   return [[VHFinally alloc] initWithBlock:block];
}

/**
 * \brief Create a new VHFinally object with the given block and also call the block now
 *
 * This factory function can be useful when you want to call a function at the beginning and end of a scope.
 *
 * Note it is important that this method name begin with "new" otherwise the returned object is placed
 * in an autorelease pool.
 *
 * \param block the non-nil block to call
 *
 * \return the new VHFinally instance
 */
+ (VHFinally *)newFinallyAndNow:(dispatch_block_t)block
{
   block();
   return [[VHFinally alloc] initWithBlock:block];
}

/**
 * \brief Remove (disable) the block
 */
- (void)reset
{
   self.block = nil;
}

/**
 * \brief Set or replace the block
 *
 * \param block the new block to call, or nil
 */
- (void)set:(dispatch_block_t)block
{
   self.block = block;
}

/**
 * \brief Test if the current block is non-nil
 *
 * \return YES if the current block is non-nil, NO otherwise
 */
- (BOOL)isSet
{
   return self.block != nil;
}

#pragma mark - Private implementation

/**
 * \brief Constructor
 *
 * \param block the block to call, or nil
 */
- (VHFinally *)initWithBlock:(dispatch_block_t)block
{
   if (self = [super init]) {
      self.block = block;
   }
   return self;
}

/**
 * \brief Destructor, call the block if any
 */
- (void)dealloc
{
   if (_block != nil) {
      _block();
      _block = nil;
   }
}

@end
