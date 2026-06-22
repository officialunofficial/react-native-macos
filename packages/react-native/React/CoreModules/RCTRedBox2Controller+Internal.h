/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if !TARGET_OS_OSX // [macOS] iOS-only RedBox 2.0 / extracted controller (#56640); fork uses inline macOS RCTRedBoxController

#import <React/RCTDefines.h>

#import "RCTRedBox+Internal.h"

#if RCT_DEV_MENU

typedef void (^RCTRedBox2ButtonPressHandler)(void);

@interface RCTRedBox2Controller : UIViewController <RCTRedBox2Controlling, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) id<RCTRedBoxControllerActionDelegate> actionDelegate;

- (instancetype)initWithCustomButtonTitles:(NSArray<NSString *> *)customButtonTitles
                      customButtonHandlers:(NSArray<RCTRedBox2ButtonPressHandler> *)customButtonHandlers;

- (void)showErrorMessage:(NSString *)message
               withStack:(NSArray<RCTJSStackFrame *> *)stack
                isUpdate:(BOOL)isUpdate
             errorCookie:(int)errorCookie;

/// The bundle URL used by the app, for the native HMR connection.
@property (nonatomic, strong, nullable) NSURL *bundleURL;

- (void)dismiss;
@end

#endif

#endif // !TARGET_OS_OSX [macOS]
