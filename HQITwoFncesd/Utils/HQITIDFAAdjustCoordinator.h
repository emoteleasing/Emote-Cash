

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITIDFAAdjustCoordinator : NSObject

+ (instancetype)shared;

/// Call from didFinishLaunching: listen for network, begin IDFA/ATT + Adjust on first reachability.
- (void)startIDFAAdjustFlow;

/// Call from applicationDidBecomeActive / sceneDidBecomeActive to resume ATT prompt if needed.
- (void)onApplicationDidBecomeActive;

/// After app/config ready: initialize Adjust if token available and flow allows.
- (void)initializeAdjustIfNeeded;

@end

NS_ASSUME_NONNULL_END
