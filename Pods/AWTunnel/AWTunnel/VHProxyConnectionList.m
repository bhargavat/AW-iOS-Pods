//
//  VHProxyConnectionList.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyConnectionList.h"
#import "VHProxyConnection.h"

#import "Fuji.h"
#import "VHDispatchRunLoopQueuing.h"

@interface VHProxyConnectionList ()

/** \brief queue used to sychronize access to the list */
@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;

/** \brief the list of connections */
@property (nonatomic, retain) NSMutableArray *connections;

@end

/**
 * \brief Holds a list of connections and supports closing all connections in the list
 */
@implementation VHProxyConnectionList

/**
 * \brief initialize a new list instance
 *
 * \param queue Queue used to synchronize access to the list
 * \return the initialized list instance
 */
- (VHProxyConnectionList *)initWithQueue:(id<VHDispatchRunLoopQueuing>)queue
{
   if (self = [super init]) {
      self.queue = queue;
      self.connections = [[NSMutableArray alloc] initWithCapacity:20];
   }
   return self;
}

/**
 * \brief free the list
 */
- (void)dealloc
{
   ASSERT(_connections.count == 0);
   //[_connections release];
   _connections = nil;
   //[_queue release];
   _queue = nil;
   //[super dealloc];
}

/**
 * \brief add a connection to the list
 *
 * \param connection the connection to add
 */
- (void)add:(VHProxyConnection *)connection
{
   [self.queue enqueue:^{
      ASSERT([self.connections indexOfObject:connection] == NSNotFound);
      [self.connections addObject:connection];
   }];
}

/**
 * \brief remove a connection from the list
 *
 * \param connection the connection to remove
 */
- (void)remove:(VHProxyConnection *)connection
{
   [self.queue enqueue:^{
      ASSERT([self.connections indexOfObject:connection] != NSNotFound);
      [self.connections removeObject:connection];
   }];
}

/**
 * \brief close all connections in the list (but do not remove them)
 */
- (void)close
{
   [self.queue enqueue:^{
      [self.connections enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
         VHProxyConnection *connection = (VHProxyConnection *)obj;
         [connection close];
      }];
   }];
}

@end
