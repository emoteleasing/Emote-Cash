

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITAutoOrderFinishedBlock)(BOOL success);

@interface HQITAutoOrderCoordinator : NSObject

+ (BOOL)isRunning;

+ (void)startWithHostViewController:(UIViewController *)hostVC
                         onFinished:(nullable HQITAutoOrderFinishedBlock)onFinished;

@end

NS_ASSUME_NONNULL_END
