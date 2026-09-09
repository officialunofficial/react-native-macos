/**
 * Copyright (c) Microsoft Corporation.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// [macOS]
#if TARGET_OS_OSX

#import "RCTPlatformDisplayLink.h"

#import <CoreVideo/CVDisplayLink.h>
#import <CoreVideo/CVHostTime.h>

#import <os/lock.h>

@interface RCTPlatformDisplayLink ()

@property (nonatomic, strong) NSRunLoop *runLoop;

@end

@implementation RCTPlatformDisplayLink
{
  CVDisplayLinkRef _displayLink;
  SEL _selector;
  __weak id _target;
  NSRunLoop *_runLoop;
  NSMutableArray<NSRunLoopMode> *_modes;
  os_unfair_lock _lock; // OS_UNFAIR_LOCK_INIT == 0
  BOOL _paused;
  // Host times of the last vsync callback, guarded by _lock. Zero until the first frame.
  uint64_t _frameHostTime;
  uint64_t _targetHostTime;
}

+ (RCTPlatformDisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel
{
  RCTPlatformDisplayLink *displayLink = [self.class new];
  displayLink->_target = target;
  displayLink->_selector = sel;
  return displayLink;
}

static NSTimeInterval RCTPlatformDisplayLinkSeconds(uint64_t hostTime)
{
  return (NSTimeInterval)hostTime / (NSTimeInterval)CVGetHostClockFrequency();
}

static CVReturn RCTPlatformDisplayLinkCallBack(__unused CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, __unused CVOptionFlags flagsIn, __unused CVOptionFlags* flagsOut, void* displayLinkContext)
{
  @autoreleasepool {
    RCTPlatformDisplayLink *rctDisplayLink = (__bridge RCTPlatformDisplayLink*)displayLinkContext;

    // Lock and check for invalidation prior to calling out to the runloop
    os_unfair_lock_lock(&rctDisplayLink->_lock);
    uint64_t nowHostTime = (now->flags & kCVTimeStampHostTimeValid) ? now->hostTime : CVGetCurrentHostTime();
    rctDisplayLink->_frameHostTime = nowHostTime;
    rctDisplayLink->_targetHostTime = (outputTime->flags & kCVTimeStampHostTimeValid) ? outputTime->hostTime : nowHostTime;
    if (rctDisplayLink->_runLoop != nil) {
      CFRunLoopRef cfRunLoop = [rctDisplayLink->_runLoop getCFRunLoop];
      CFRunLoopPerformBlock(cfRunLoop, (__bridge CFArrayRef)rctDisplayLink->_modes, ^{
        @autoreleasepool {
          [rctDisplayLink tick];
        }
      });
      CFRunLoopWakeUp(cfRunLoop);
    }
    os_unfair_lock_unlock(&rctDisplayLink->_lock);
  }
  return kCVReturnSuccess;
}

- (void)dealloc
{
  if (_displayLink != NULL) {
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
    _displayLink = NULL;
  }
}

- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode
{
  os_unfair_lock_lock(&_lock);
  _runLoop = runloop;

  if (_displayLink != NULL) {
    [_modes addObject:mode];
    os_unfair_lock_unlock(&_lock);
    return;
  }

  _modes = @[mode].mutableCopy;
  os_unfair_lock_unlock(&_lock);
  CVReturn ret = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
  if (ret != kCVReturnSuccess) {
    ret = CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &_displayLink);
  }
  NSCAssert(ret == kCVReturnSuccess, @"Cannot create display link");
  CVDisplayLinkSetOutputCallback(_displayLink, &RCTPlatformDisplayLinkCallBack, (__bridge void *)(self));
  if (!_paused) {
    CVDisplayLinkStart(_displayLink);
  }
}

- (void)removeFromRunLoop:(__unused NSRunLoop *)runloop forMode:(NSRunLoopMode)mode
{
  [_modes removeObject:mode];
  if (_modes.count == 0) {
    [self invalidate];
  }
}

- (void)invalidate
{
  if (_runLoop != nil) {
    os_unfair_lock_lock(&_lock);
    _runLoop = nil;
    _modes = nil;
    os_unfair_lock_unlock(&_lock);

    // CVDisplayLinkStop attempts to acquire a mutex possibly held during the callback's invocation.
    // Stop the display link outside of the lock to avoid deadlocking here.
    if (_displayLink != NULL) {
      CVDisplayLinkStop(_displayLink);
    }
  }
}

- (void)setPaused:(BOOL)paused
{
  _paused = paused;
  if (_displayLink == NULL) {
    return;
  }
  if (paused) {
    CVDisplayLinkStop(_displayLink);
  } else {
    CVDisplayLinkStart(_displayLink);
  }
}

- (BOOL)isPaused
{
  return _displayLink != NULL ? !CVDisplayLinkIsRunning(_displayLink) : _paused;
}

// Like CADisplayLink, these report the last vsync, so they stay valid while
// paused. CVDisplayLinkGetCurrentTime returns zero on a stopped link.
- (NSTimeInterval)timestamp
{
  os_unfair_lock_lock(&_lock);
  uint64_t hostTime = _frameHostTime;
  os_unfair_lock_unlock(&_lock);
  return RCTPlatformDisplayLinkSeconds(hostTime != 0 ? hostTime : CVGetCurrentHostTime());
}

- (NSTimeInterval)targetTimestamp
{
  os_unfair_lock_lock(&_lock);
  uint64_t hostTime = _targetHostTime;
  os_unfair_lock_unlock(&_lock);
  return hostTime != 0 ? RCTPlatformDisplayLinkSeconds(hostTime) : self.timestamp + self.duration;
}

- (NSTimeInterval)duration
{
  NSTimeInterval duration = 1.0 / 60.0;
  if (_displayLink == NULL) {
    return duration;
  }
  const CVTime time = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
  if (!(time.flags & kCVTimeIsIndefinite) && time.timeValue > 0) {
    duration = (NSTimeInterval)time.timeValue / (NSTimeInterval)time.timeScale;
  }
  return duration;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (void)tick
{
  if (_selector && [_target respondsToSelector:_selector]) {
    [_target performSelector:_selector withObject:self];
  }
}
#pragma clang diagnostic pop

@end
#endif