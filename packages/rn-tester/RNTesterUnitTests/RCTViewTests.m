/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>
#import "OCMock/OCMock.h"

#import <React/RCTAutoInsetsProtocol.h>
#import <React/RCTMockDef.h>
#import <React/RCTScrollView.h>
#import <React/RCTView.h>
#import <React/RCTViewUtils.h>

#if TARGET_OS_OSX // [macOS]
#import <AppKit/AppKit.h>
#import <React/RCTUITextField.h>
#import <React/RCTUITextView.h>
#endif // [macOS]

RCT_MOCK_REF(RCTView, RCTContentInsets);

UIEdgeInsets gContentInsets;
static UIEdgeInsets RCTContentInsetsMock(RCTUIView *view) // [macOS]
{
  return gContentInsets;
}

@interface RCTViewTests : XCTestCase
@end

@implementation RCTViewTests

#if !TARGET_OS_OSX // [macOS]
- (void)testAutoAdjustInsetsUpdateOffsetNo
{
  RCT_MOCK_SET(RCTView, RCTContentInsets, RCTContentInsetsMock);

  RCTScrollView *parentView = OCMClassMock([RCTScrollView class]);
  OCMStub([parentView contentInset]).andReturn(UIEdgeInsetsMake(1, 1, 1, 1));
  OCMStub([parentView automaticallyAdjustContentInsets]).andReturn(YES);
  RCTUIScrollView *scrollView = [[RCTUIScrollView alloc] initWithFrame:CGRectZero]; // [macOS]

  gContentInsets = UIEdgeInsetsMake(1, 2, 3, 4);
  [RCTView autoAdjustInsetsForView:parentView withScrollView:scrollView updateOffset:NO];

  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(scrollView.contentInset, UIEdgeInsetsMake(2, 3, 4, 5)));
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(scrollView.verticalScrollIndicatorInsets, UIEdgeInsetsMake(2, 3, 4, 5)));

  RCT_MOCK_RESET(RCTView, RCTContentInsets);
}
#endif // [macOS]

#if TARGET_OS_OSX // [macOS]
// Regression tests for https://github.com/microsoft/react-native-macos/issues/2955
// On macOS a multiline TextInput is backed by RCTUITextView. When the JS prop
// `enableFocusRing` is false, the view must not draw an AppKit focus ring, i.e.
// its `focusRingType` must be NSFocusRingTypeNone. Under the new architecture
// this was broken: the prop was ignored and the focus ring was always drawn.
- (void)testMultilineTextViewHidesFocusRingWhenDisabled
{
  RCTUITextView *textView = [[RCTUITextView alloc] initWithFrame:NSZeroRect];
  XCTAssertTrue(
      [textView respondsToSelector:@selector(setEnableFocusRing:)],
      @"RCTUITextView must implement setEnableFocusRing: so the prop can be honored (#2955)");

  textView.enableFocusRing = NO;
  XCTAssertEqual(
      textView.focusRingType,
      NSFocusRingTypeNone,
      @"focusRingType must be None when enableFocusRing is NO (#2955)");
}

- (void)testMultilineTextViewShowsFocusRingWhenEnabled
{
  RCTUITextView *textView = [[RCTUITextView alloc] initWithFrame:NSZeroRect];
  if (![textView respondsToSelector:@selector(setEnableFocusRing:)]) {
    XCTFail(@"RCTUITextView must implement setEnableFocusRing: (#2955)");
    return;
  }

  textView.enableFocusRing = YES;
  XCTAssertEqual(
      textView.focusRingType,
      NSFocusRingTypeDefault,
      @"focusRingType must be Default when enableFocusRing is YES (#2955)");
}

// Regression tests for https://github.com/microsoft/react-native-macos/issues/2954
// Single-line TextField is backed by RCTUITextField. With enableFocusRing=false
// the focus ring must stay hidden even after AppKit resets focusRingType on a
// later redraw/re-mount. The setter-only approach loses the setting; overriding
// the focusRingType getter (derived from enableFocusRing) makes it durable.
- (void)testSingleLineTextFieldKeepsFocusRingHiddenAfterRedraw
{
  RCTUITextField *textField = [[RCTUITextField alloc] initWithFrame:NSZeroRect];
  textField.enableFocusRing = NO;
  XCTAssertEqual(
      textField.focusRingType,
      NSFocusRingTypeNone,
      @"focusRingType must be None when enableFocusRing is NO (#2954)");

  // Simulate AppKit / an internal control re-enabling the ring on redraw.
  [textField setFocusRingType:NSFocusRingTypeExterior];
  XCTAssertEqual(
      textField.focusRingType,
      NSFocusRingTypeNone,
      @"focusRingType must remain None after a redraw tries to re-enable it (#2954)");
}

- (void)testSingleLineTextFieldShowsFocusRingWhenEnabled
{
  RCTUITextField *textField = [[RCTUITextField alloc] initWithFrame:NSZeroRect];
  textField.enableFocusRing = YES;
  XCTAssertNotEqual(
      textField.focusRingType,
      NSFocusRingTypeNone,
      @"focusRingType must not be None when enableFocusRing is YES (#2954)");
}
#endif // [macOS]

@end
