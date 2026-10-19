

#import "HQITHomeSessionState.h"

@implementation HQITHomeSessionState

static BOOL sShownVersion;
static BOOL sPendingAutoOrderAfterKYC;


+ (BOOL)hasShownVersionDialogThisLaunch {
    return sShownVersion;
}

+ (void)markVersionDialogShownThisLaunch {
    sShownVersion = YES;
}

+ (void)markPendingAutoOrderAfterKYC {
    sPendingAutoOrderAfterKYC = YES;
    NSLog(@"[HQITHome] pendingAutoOrderAfterKYC=YES");
}

+ (BOOL)hasPendingAutoOrderAfterKYC {
    return sPendingAutoOrderAfterKYC;
}

+ (BOOL)consumePendingAutoOrderAfterKYC {
    BOOL v = sPendingAutoOrderAfterKYC;
    sPendingAutoOrderAfterKYC = NO;
    if (v) NSLog(@"[HQITHome] pendingAutoOrderAfterKYC consumed");
    return v;
}

+ (void)resetForLogout {
    sShownVersion = NO;
    sPendingAutoOrderAfterKYC = NO;
}

@end
