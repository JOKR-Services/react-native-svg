/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNSVGSvgViewModule.h"
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTUIManagerUtils.h>
#import "RNSVGSvgView.h"

@implementation RNSVGSvgViewModule

RCT_EXPORT_MODULE()

#ifdef RCT_NEW_ARCH_ENABLED
@synthesize viewRegistry_DEPRECATED = _viewRegistry_DEPRECATED;
#endif // RCT_NEW_ARCH_ENABLED
@synthesize bridge = _bridge;

static RCTResponseSenderBlock _logCallback = nil;
static NSMutableArray<NSString *> *_pendingMessages = nil;
static dispatch_queue_t _logQueue = nil;
static BOOL _callbackUsed = NO;

+ (void)initialize
{
  if (self == [RNSVGSvgViewModule class]) {
    _pendingMessages = [NSMutableArray array];
    _logQueue = dispatch_queue_create("com.horcrux.svg.log", DISPATCH_QUEUE_SERIAL);
  }
}

+ (void)logMessage:(NSString *)message
{
  if (!message) {
    return;
  }

  dispatch_async(_logQueue, ^{
    if (_logCallback && !_callbackUsed) {
      // Mark callback as used and call it
      _callbackUsed = YES;
      RCTResponseSenderBlock callback = _logCallback;

      dispatch_async(dispatch_get_main_queue(), ^{
        callback(@[ message ]);
      });
    } else if (_logCallback && _callbackUsed) {
      // Callback already used, queue the message
      [_pendingMessages addObject:message];
    } else {
      // No callback set yet, queue the message
      [_pendingMessages addObject:message];
    }
  });
}

- (void)toDataURL:(nonnull NSNumber *)reactTag
          options:(NSDictionary *)options
         callback:(RCTResponseSenderBlock)callback
          attempt:(int)attempt
{
#ifdef RCT_NEW_ARCH_ENABLED
  [self.viewRegistry_DEPRECATED addUIBlock:^(RCTViewRegistry *viewRegistry) {
    __kindof RNSVGPlatformView *view = [viewRegistry viewForReactTag:reactTag];
#else
  [self.bridge.uiManager
      addUIBlock:^(RCTUIManager *uiManager, __unused NSDictionary<NSNumber *, RNSVGPlatformView *> *viewRegistry) {
        __kindof RNSVGPlatformView *view = [uiManager viewForReactTag:reactTag];
#endif // RCT_NEW_ARCH_ENABLED
    NSString *b64;
    if ([view isKindOfClass:[RNSVGSvgView class]]) {
      RNSVGSvgView *svg = view;
      if (options == nil) {
        b64 = [svg getDataURLWithBounds:svg.boundingBox];
      } else {
        id width = [options objectForKey:@"width"];
        id height = [options objectForKey:@"height"];
        if (![width isKindOfClass:NSNumber.class] || ![height isKindOfClass:NSNumber.class]) {
          RCTLogError(@"Invalid width or height given to toDataURL");
          return;
        }
        NSNumber *w = width;
        NSInteger wi = (NSInteger)[w intValue];
        NSNumber *h = height;
        NSInteger hi = (NSInteger)[h intValue];

        CGRect bounds = CGRectMake(0, 0, wi, hi);
        b64 = [svg getDataURLWithBounds:bounds];
      }
    } else {
      RCTLogError(@"Invalid svg returned from registry, expecting RNSVGSvgView, got: %@", view);
      return;
    }
    if (b64) {
      callback(@[ b64 ]);
    } else if (attempt < 1) {
      [self toDataURL:reactTag options:options callback:callback attempt:(attempt + 1)];
    } else {
      callback(@[]);
    }
  }];
};

RCT_EXPORT_METHOD(toDataURL
                  : (nonnull NSNumber *)reactTag options
                  : (NSDictionary *)options callback
                  : (RCTResponseSenderBlock)callback)
{
  [self toDataURL:reactTag options:options callback:callback attempt:0];
}

RCT_EXPORT_METHOD(setLogCallback : (RCTResponseSenderBlock)callback)
{
  dispatch_async(_logQueue, ^{
    // Reset the callback state when a new callback is set
    _logCallback = callback;
    _callbackUsed = NO;

    // Process any pending messages with the new callback
    if (callback && [_pendingMessages count] > 0) {
      NSArray<NSString *> *messages = [_pendingMessages copy];
      [_pendingMessages removeAllObjects];

      // Only call the callback once with the first message
      // Subsequent messages will be queued again
      if ([messages count] > 0) {
        _callbackUsed = YES;
        NSString *firstMessage = messages[0];
        dispatch_async(dispatch_get_main_queue(), ^{
          callback(@[ firstMessage ]);
        });

        // Queue remaining messages
        if ([messages count] > 1) {
          NSArray<NSString *> *remainingMessages = [messages subarrayWithRange:NSMakeRange(1, [messages count] - 1)];
          [_pendingMessages addObjectsFromArray:remainingMessages];
        }
      }
    }
  });
}

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeSvgViewModuleSpecJSI>(params);
}
#endif

- (dispatch_queue_t)methodQueue
{
  if (self.bridge) {
    return RCTGetUIManagerQueue();
  } else {
    return dispatch_get_main_queue();
  }
}

@end
