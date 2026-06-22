/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#if !TARGET_OS_OSX // [macOS] iOS-only RedBox 2.0 / extracted controller (#56640); fork uses inline macOS RCTRedBoxController

#import <React/RCTUIKit.h> // [macOS]

/**
 * Parses ANSI escape sequences in text and produces an NSAttributedString
 * with the corresponding foreground/background colors applied.
 *
 * Uses the Afterglow color theme (matching LogBox's AnsiHighlight.js).
 */
@interface RCTRedBox2AnsiParser : NSObject

+ (NSAttributedString *)attributedStringFromAnsiText:(NSString *)text
                                            baseFont:(UIFont *)font
                                           baseColor:(UIColor *)color;

@end

#endif // !TARGET_OS_OSX [macOS]
