

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITHomeSessionState : NSObject

+ (BOOL)hasShownVersionDialogThisLaunch;
+ (void)markVersionDialogShownThisLaunch;

+ (void)markPendingAutoOrderAfterKYC;
+ (BOOL)hasPendingAutoOrderAfterKYC;
+ (BOOL)consumePendingAutoOrderAfterKYC;

+ (void)resetForLogout;

@end

NS_ASSUME_NONNULL_END
