//
//  NSStreamUtils.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "NSStreamUtils.h"

#import "Fuji.h"

/**
 * \brief provide a loggable description of a stream status
 *
 * \param status a valid stream status enum value
 * \return a loggable name of the enum value
 */
NSString *
NSStreamStatusDescription(NSStreamStatus status)
{
   switch (status) {
      case NSStreamStatusNotOpen: return @"NotOpen";
      case NSStreamStatusOpening: return @"Opening";
      case NSStreamStatusOpen: return @"Open";
      case NSStreamStatusReading: return @"Reading";
      case NSStreamStatusWriting: return @"Writing";
      case NSStreamStatusAtEnd: return @"AtEnd";
      case NSStreamStatusClosed: return @"Closed";
      case NSStreamStatusError: return @"Error";
   }
   LOG_ERROR(@"unknown stream status:%X", status);
   FATAL(FUJI_FATAL_INVALID_STATE);
}

/**
 * \brief provide a loggable description of a stream event
 *
 * \param event a valid stream event enum value
 * \return a loggable name of the enum value
 */
NSString *
NSStreamEventDescription(NSStreamEvent event)
{
   switch (event) {
      case NSStreamEventNone: return @"None";
      case NSStreamEventOpenCompleted: return @"OpenCompleted";
      case NSStreamEventHasBytesAvailable: return @"BytesAvailable";
      case NSStreamEventHasSpaceAvailable: return @"SpaceAvailable";
      case NSStreamEventErrorOccurred: return @"ErrorOccurred";
      case NSStreamEventEndEncountered: return @"EndEncountered";
   }
   LOG_ERROR(@"unknown stream event:%X", event);
   FATAL(FUJI_FATAL_INVALID_STATE);
}

