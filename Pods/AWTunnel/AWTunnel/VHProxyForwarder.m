//
//  VHProxyForwarder.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyForwarder.h"
#import "VHProxyUtils.h"

#import "Fuji.h"
#import "NSStreamUtils.h"
#import "VHDispatchRunLoopQueuing.h"
#import "NSURLRequest+HTTPMessage.h"
#import "AWProxy.h"

#include <netinet/in.h>
#include <netinet/tcp.h>

#define FPS_BUFF_SIZE 4096

static const CFSocketNativeHandle INVALID_HANDLE = -1;

/**
 * \brief Extract the underlying handle from a CFReadStream
 *
 * \param stream The stream
 * \return The underlying handle or INVALID_HANDLE on failure
 */
static CFSocketNativeHandle
GetNativeReadHandle(CFReadStreamRef stream)
{
   CFDataRef data = (CFDataRef)CFReadStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
   if (data == NULL) {
      return INVALID_HANDLE;
   }
   FATAL_IF(CFDataGetLength(data) != sizeof (CFSocketNativeHandle), FUJI_FATAL_INVALID_STATE);
   CFSocketNativeHandle handle = *(CFSocketNativeHandle *)CFDataGetBytePtr(data);
   CFRelease(data);
   return handle;
}

/**
 * \brief Extract the underlying handle from a CFWriteStream
 *
 * \param stream The stream
 * \return The underlying handle or INVALID_HANDLE on failure
 */
static CFSocketNativeHandle
GetNativeWriteHandle(CFWriteStreamRef stream)
{
   CFDataRef data = (CFDataRef)CFWriteStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
   if (data == NULL) {
      return INVALID_HANDLE;
   }
   FATAL_IF(CFDataGetLength(data) != sizeof (CFSocketNativeHandle), FUJI_FATAL_INVALID_STATE);
   CFSocketNativeHandle handle = *(CFSocketNativeHandle *)CFDataGetBytePtr(data);
   CFRelease(data);
   return handle;
}

@interface VHProxyForwarder () {
   // members accessed on the data forwarding path are Ivars to avoid Obj-C dispatches
   uint8_t *_readBuf;
   uint8_t *_readBufEnd;
   NSMutableData *_readBufBacking;
   NSInputStream *_input;
   NSOutputStream *_output;
    
@private
    CFHTTPMessageRef                    _HTTPRequest;
}
@property (nonatomic, retain) NSString *label;
@property (nonatomic, retain) id<VHDispatchRunLoopQueuing> queue;
@property (nonatomic, copy) dispatch_block_t completion;
@property (nonatomic, strong) AWMutableURLRequest *req;
@property (nonatomic) AWRequestSignerType signatureType;


@end

/**
 * \brief Forwards data from an input stream to an output stream
 *
 * \note This initial implementation favors simplicity over performance.
 * See @knownjira{FUJI-1966} for a discussion of future performance tuning.
 */
@implementation VHProxyForwarder

- (VHProxyForwarder *)initWithInput:(NSInputStream *)input
                             output:(NSOutputStream *)output
                              label:(NSString *)label
                              queue:(id<VHDispatchRunLoopQueuing>)queue
                               signatureType:(AWRequestSignerType)signatureType
{
   if (self = [super init]) {
      PROXY_TRACE(@"%@", self);
      _readBuf = NULL;
      _readBufBacking = NULL;
      _input = input;
      _input.delegate = self;
      _output = output;
      _output.delegate = self;
      self.label = label;
      self.queue = queue;
       self.signatureType = signatureType;
   }
   return self;
}

/**
 * \brief Destroy a completed/closed forwarder
 */
- (void)dealloc
{
   PROXY_TRACE(@"%@", self);
   ASSERT(_completion == nil);
   ASSERT(_input == nil);
   ASSERT(_output == nil);
   //[_readBufBacking release];
   _readBufBacking = nil;
   //[_label release];
   _label = nil;
   //[_queue release];
   _queue = nil;
    _readBuf = nil;
    _readBufEnd = nil;
    if(_HTTPRequest) {
        CFRelease(_HTTPRequest);
    }
   //[super dealloc];
}

/**
 * \brief Schedule the streams and start forwarding data
 *
 * \param completion Called when data forwarding has stopped and the streams have been closed. Called on
 *        the forwarder's queue / run loop.
 */
- (void)startWithCompletion:(dispatch_block_t)completion
{
   ASSERT(completion != nil);
   [self.queue enqueue:
    ^{
       ASSERT(self.completion == nil);
       self.completion = completion;
       // keep this object in memory until complete. Balanced by release in -complete.
       //[self retain];

       [_input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
       [_output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
       if (_input.streamStatus == NSStreamStatusNotOpen) {
          [_input open];
       }
       if (_output.streamStatus == NSStreamStatusNotOpen) {
          [_output open];
       }
    }];
}

/**
 * \brief Close streams and call the completion callback as necessary
 */
- (void)cancel
{
   [self.queue enqueue:
    ^{
       [self complete];
    }];
}

#pragma mark - Private implementation

/**
 * \brief Write buffered data to the output stream
 *
 * Clear the buffer if all data can be written.
 *
 * \return YES if some data was written (progress was made)
 *         NO if no data was written
 */
- (BOOL)write
{
   if (_readBuf != NULL &&
       _output.hasSpaceAvailable &&
       _readBufEnd != _readBuf /* read EOF case */) {
    
       if(self.signatureType) {
           
           _HTTPRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault,true);
           
           CFHTTPMessageAppendBytes(_HTTPRequest, _readBuf, (_readBufEnd - _readBuf));
           
           NSString * originalSerializedString = [NSString stringWithUTF8String:(const char *)_readBuf];
           NSArray *originalChunks = [originalSerializedString componentsSeparatedByString: @"\r\n"];
       
           NSString *requestMethod = (NSString *)CFBridgingRelease(CFHTTPMessageCopyRequestMethod(_HTTPRequest));
           if (requestMethod &&
               ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame ||
               [requestMethod caseInsensitiveCompare:@"GET"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"POST"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"PUT"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"DELETE"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"OPTIONS"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"HEAD"] == NSOrderedSame||
                [requestMethod caseInsensitiveCompare:@"PATCH"] == NSOrderedSame)) {
                   
                   CFURLRef cfURL = CFHTTPMessageCopyRequestURL(_HTTPRequest);
                   if (self.signatureType == AWRequestSignerTypeMAG) {
                       NSString *scheme =  (NSString *)CFBridgingRelease(CFURLCopyScheme(cfURL));
                       NSString *host = (NSString *)CFBridgingRelease(CFURLCopyNetLocation(cfURL));
           
                       if ([requestMethod caseInsensitiveCompare:@"CONNECT"] == NSOrderedSame)
                       {
                           host = scheme;
                           scheme = @"https";
                       }
           
                       NSString *urlWithSchemeString = [NSString stringWithFormat:@"%@://%@", scheme, host];
           
                       NSURL *url = [[NSURL alloc] initWithString:urlWithSchemeString];
                       NSData *body = (NSData *)CFBridgingRelease(CFHTTPMessageCopyBody(_HTTPRequest));
           
                       AWMutableURLRequest *req = [[AWMutableURLRequest alloc] initWithURL:url];
                       [req setHTTPMethod:requestMethod];
                       [req setHTTPBody:body];
                       
                    
                       req = [[AWRequestSigner sharedInstance] MAGSignedRequestWithPort:nil andRequest:req error:NULL];
                       NSString *proxyAuth = [[req allHTTPHeaderFields] valueForKey:@"Proxy-Authorization"];
                       NSString *date = [[req allHTTPHeaderFields] valueForKey:@"Date"];
                        
                   
                       CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Proxy-Authorization", (__bridge CFStringRef)proxyAuth);
                       CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Date", (__bridge CFStringRef)date);
                       CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"DNT", (__bridge CFStringRef)@"1");
                       CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Accept", (__bridge CFStringRef)@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
                       CFHTTPMessageSetHeaderFieldValue(_HTTPRequest, (__bridge CFStringRef)@"Accept-Charset", (__bridge CFStringRef)@"utf-8,ISO-8859-1;q=0.7,*;q=0.3");

                       
                   } else if (self.signatureType == AWRequestSignerTypeBASIC) {
                       CFHTTPMessageAddAuthentication(_HTTPRequest, NULL, (__bridge CFStringRef)[[AWProxy sharedInstance] username], (__bridge CFStringRef)[[AWProxy sharedInstance] password], kCFHTTPAuthenticationSchemeBasic, YES);
                   }
                   
                   //free up cfURL
                   CFRelease(cfURL);
                   CFDataRef serialized = CFHTTPMessageCopySerializedMessage(_HTTPRequest);
           
                   // Replace first line with original line from sender.
                   // CFHTTPMessageCopySerializedMessage serializes the message for
                   // non proxy mode.
                   NSString * serializedString = [[NSString alloc] initWithBytes:(const char *)[(__bridge_transfer NSMutableData *) serialized bytes] length:(CFDataGetLength(serialized)) encoding:NSUTF8StringEncoding];
                   NSMutableArray *chunks = [[serializedString componentsSeparatedByString: @"\r\n"] mutableCopy];
                   if(chunks && originalChunks) {
                       chunks[0] = originalChunks[0];
                       serializedString = [[chunks valueForKey:@"description"] componentsJoinedByString:@"\r\n"];
                   }
                   _readBuf = (unsigned char *)[[serializedString dataUsingEncoding:NSUTF8StringEncoding] bytes];
                   _readBufEnd = _readBuf + [serializedString length];
           }
       }
       //NSString * string __unused = [[NSString alloc] initWithBytes:(const char *)_readBuf length:(_readBufEnd - _readBuf) encoding:NSUTF8StringEncoding];
       //if(string) NSLog(@"\n%@ \n********", string);
      NSInteger written = [_output write:_readBuf
                               maxLength:_readBufEnd - _readBuf];
      if (written > 0) {
         _readBuf += written;
         if (_readBuf == _readBufEnd) {
             if(self.signatureType) {
                 CFRelease(_HTTPRequest);
                 _HTTPRequest = nil;
             }
            _readBuf = NULL;
         }
         return YES;
      }
   }
   return NO;
}

/**
 * \brief Read data from the input stream
 *
 * \return YES if some data was read (progress was made)
 *         NO if no data was read
 */
- (BOOL)read
{
   if (_readBuf == NULL && _input.hasBytesAvailable) {
      // try the embedded buffer first
      NSUInteger length = 0;
      if ([_input getBuffer:&_readBuf
                     length:&length]) {
         if (length == 0) {
            // EOF case?
            _readBuf = NULL;
            return NO;
         }
         _readBufEnd = _readBuf + length;
         return YES;
      }
      // otherwise use our internal buffer backing
      if (_readBufBacking == nil) {
         _readBufBacking = [[NSMutableData alloc]initWithCapacity:FPS_BUFF_SIZE];
         _readBufBacking.length = FPS_BUFF_SIZE;
      }
      NSInteger read = [_input read:_readBufBacking.mutableBytes
                          maxLength:_readBufBacking.length];
      if (read > 0) {
         _readBuf = _readBufBacking.mutableBytes;
         _readBufEnd = _readBuf + read;
          //NSString * string __unused = [[NSString alloc] initWithBytes:(const char *)_readBuf length:(_readBufEnd - _readBuf) encoding:NSUTF8StringEncoding];
          //if(string) NSLog(@"\n%@ \n***^ was %d *****", string, read);
         return YES;
      }
   }
   return NO;
}

/**
 * \brief If we have reached a terminal condition complete forwarding
 */
- (void)tryComplete
{
   if (_readBuf == NULL && _input.streamStatus == NSStreamStatusAtEnd) {
      // no more data to deliver
      [self complete];
      return;
   }
   if (_output.streamStatus == NSStreamStatusError) {
      PROXY_TRACE(@"%@: output.streamError: %@", self.label, _output.streamError);
      // nothing more we can do
      [self complete];
      return;
   }
   if (_readBuf == NULL && _input.streamStatus == NSStreamStatusError) {
      PROXY_TRACE(@"%@: input.streamError: %@", self.label, _input.streamError);

      /*
       * \todo @knownjira{FUJI-1627} proxy errors by calling close() without shutdown(). That should generate
       * a RST. We may need to detach from the CF stream to do this?
       */

      [self complete];
      return;
   }
}

/**
 * \brief stop forwarding and call our completion block
 */
- (void)complete
{
   if (self.completion != nil) {
      PROXY_TRACE(@"%@", self);
      [_input close];
      //[_input release];
      _input = nil;
      [_output close];
      //[_output release];
      _output = nil;
      self.completion();
      self.completion = nil;
      // balanced by retain in startWithCompletion
      //[self release];
   }
}

#pragma mark - NSStreamDelegate

/**
 * \brief Implement NSStreamDelegate
 *
 * Greedily write and read data until we can nolonger make progress.
 *
 * \todo @knownjira{FUJI-1966} fairness - after some number of iterations re-queue to the run loop
 */
- (void)stream:(NSStream*)stream
   handleEvent:(NSStreamEvent)eventCode
{
   PROXY_TRACE(@"%@(%p): event:%@", self.label, stream, NSStreamEventDescription(eventCode));
   PROXY_TRACE(@"input.streamStatus:%@ output.streamStatus:%@ readBuf:%p len:%d",
             NSStreamStatusDescription(_input.streamStatus),
             NSStreamStatusDescription(_output.streamStatus),
             _readBuf,
             (int)(_readBuf ? _readBufEnd - _readBuf : 0));
   if (eventCode == NSStreamEventOpenCompleted) {
      if ([stream isKindOfClass:[NSInputStream class]]) {
         CFReadStreamRef readStream = (__bridge CFReadStreamRef)(NSInputStream *)stream;
         CFSocketNativeHandle remoteSocket = GetNativeReadHandle(readStream);
         if (setsockopt(remoteSocket, IPPROTO_TCP, TCP_NODELAY, &(int){ 1 }, sizeof(int)) != 0) {
            LOG_WARNING(@"unable to set TCP_NODELAY");
         }
      } else if ([stream isKindOfClass:[NSOutputStream class]]) {
         CFSocketNativeHandle remoteSocket = GetNativeWriteHandle((__bridge CFWriteStreamRef)(NSOutputStream *)stream);
         if (setsockopt(remoteSocket, IPPROTO_TCP, TCP_NODELAY, &(int){ 1 }, sizeof(int)) != 0) {
            LOG_WARNING(@"unable to set TCP_NODELAY");
         }
      }
   }
   BOOL wrote;
   BOOL read;
   do {
      wrote = [self write];
      read = [self read];
   } while (wrote || read);
   [self tryComplete];
}

@end
