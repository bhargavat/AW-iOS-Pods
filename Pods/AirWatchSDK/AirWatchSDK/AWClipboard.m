//
//  AWPasteboard.m
//  Clipboard
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#import "AWClipboard.h"
#import "UIPasteboard+Swizzle.m"
@import MobileCoreServices;

@interface AWClipboard()
@property (nonatomic) BOOL isActive;
@end

@implementation AWClipboard

@synthesize preventCopyPaste;
@synthesize isAirWatchClipboardEnabled;

#pragma mark - Initializations

+ (id)sharedInstance {
    static AWClipboard *sharedAWClipboard = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAWClipboard = [[self alloc] init];
    });
    return sharedAWClipboard;
}

- (id)init {
    if (self) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationDidBecomeActiveNotification object:nil];        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePasteboardChanges:) name:UIPasteboardChangedNotification object:nil];
        preventCopyPaste = false;
        isAirWatchClipboardEnabled = [[SDKDefaultSettings sharedSettings] isAirWatchClipboardEnabled];
        if (isAirWatchClipboardEnabled) {
            AWLogInfo(@"Setting up AWClipboard");
            if (!_isActive) {
                [UIPasteboard setUpAWPasteboard];
                _isActive = YES;
            }

        }
    }
    return self;
}

#pragma mark - Memory management

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public methods

+(BOOL) supportsAction:(SEL) action withSender:(id) sender {
    
    // We return default behavior for all public edit menu items.
    if (action == @selector(cut:) ||
        action == @selector(copy:) ||
        action == @selector(paste:) ||
        action == @selector(delete:) ||
        action == @selector(select:) ||
        action == @selector(selectAll:) ||
        action == @selector(toggleBoldface:) ||
        action == @selector(toggleItalics:) ||
        action == @selector(toggleUnderline:) ||
        action == @selector(makeTextWritingDirectionLeftToRight:) ||
        action == @selector(makeTextWritingDirectionRightToLeft:)) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Private methods

- (void) synchronize {
    if (isAirWatchClipboardEnabled && preventCopyPaste) {
        UIPasteboard *generalPasteboard = [UIPasteboard awgeneralPasteboard];
        UIPasteboard *privatePasteboard = [UIPasteboard awprivatePasteboard];
        
        NSString *generalPasteboardString = generalPasteboard.string;
        
        // Check if there is some string to be copied from general pasteboard.
        if (generalPasteboardString.length > 0) {
            
            NSString *privatePasteboardString = privatePasteboard.string;
            if (privatePasteboardString.length == 0 || [generalPasteboardString isEqualToString:privatePasteboardString] == NO) {
                
                // Finally, transfer from general pasteboard to private pasteboard as they are not equal.
                [privatePasteboard setString:generalPasteboardString];
            }
        }
        
        // Check if there is some image to be copied from general pasteboard.
        UIImage *generalPasteboardImage = generalPasteboard.image;
        if (generalPasteboardImage) {
            
            UIImage *privatePasteboardImage = privatePasteboard.image;
            
            NSData *generalPasteboardImageData = UIImagePNGRepresentation(generalPasteboardImage);
            NSData *privatePasteboardImageData = UIImagePNGRepresentation(privatePasteboardImage);
            if (privatePasteboardImage == nil || [generalPasteboardImageData isEqualToData:privatePasteboardImageData] == NO) {
                
                // Finally, transfer from general pasteboard to private pasteboard as they are not equal.
                [privatePasteboard setImage:generalPasteboardImage];
            }
        }
    }
}

- (void) handlePasteboardChanges:(NSNotification *) notification {
    if (isAirWatchClipboardEnabled && preventCopyPaste) {
        
        UIPasteboard *generalPasteboard = [UIPasteboard awgeneralPasteboard];
        UIPasteboard *privatePasteboard = [UIPasteboard awprivatePasteboard];
        
        if (notification.object == privatePasteboard) {
            
            // Clear general pasteboard string.
            NSString *privatePasteboardString = privatePasteboard.string;
            if (privatePasteboardString.length > 0) {
                NSString *generalPasteboardString = generalPasteboard.string;
                if (generalPasteboardString.length == 0 || [privatePasteboardString isEqualToString:generalPasteboardString] == NO) {
                    [generalPasteboard setString:@""];
                }
            }
            
            // Clear general pasteboard image.
            UIImage *privatePasteboardImage = privatePasteboard.image;
            if (privatePasteboardImage) {
                UIImage *generalPasteboardImage = generalPasteboard.image;
                
                NSData *generalPasteboardImageData = UIImagePNGRepresentation(generalPasteboardImage);
                NSData *privatePasteboardImageData = UIImagePNGRepresentation(privatePasteboardImage);
                
                if (!generalPasteboardImage || [privatePasteboardImageData isEqualToData:generalPasteboardImageData] == NO) {
                    [generalPasteboard removeItemForPasteboardType:kUTTypeImage];
                }
            }
        }
    }
}

@end
