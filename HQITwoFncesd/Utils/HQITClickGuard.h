

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITClickGuard : NSObject

+ (void)lockControl:(UIControl *)control;
+ (void)unlockControl:(UIControl *)control;
+ (BOOL)tryLockControl:(UIControl *)control;

@end

NS_ASSUME_NONNULL_END
