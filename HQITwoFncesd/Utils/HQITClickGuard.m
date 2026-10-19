
#import "HQITClickGuard.h"

static const NSTimeInterval kHQITClickGuardUnlockDelay = 0.8;

@implementation HQITClickGuard

+ (void)lockControl:(UIControl *)control {
    if (!control) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        control.enabled = NO;
        control.alpha = 0.6;
    });
}

+ (void)unlockControl:(UIControl *)control {
    if (!control) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        control.enabled = YES;
        control.alpha = 1.0;
    });
}

+ (BOOL)tryLockControl:(UIControl *)control {
    if (!control || !control.enabled) {
        return NO;
    }
    [self lockControl:control];
    __weak UIControl *weakControl = control;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHQITClickGuardUnlockDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self unlockControl:weakControl];
    });
    return YES;
}

@end
