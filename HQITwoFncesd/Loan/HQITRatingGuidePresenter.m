
#import "HQITRatingGuidePresenter.h"
#import "HQITAppConfigHelper.h"
#import "HQITCategoryText.h"
#import "HQITDialogs.h"
#import "HQITHUDHelper.h"
#import <StoreKit/StoreKit.h>

static NSString * const kHQITRatingShownKey = @"HQITRatingGuideShownOnce";

@implementation HQITRatingGuidePresenter

+ (BOOL)shouldShowForForced:(BOOL)forced userType:(NSInteger)userType {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kHQITRatingShownKey]) return NO;
    if (forced) return YES;
    NSInteger mode = [HQITAppConfigHelper feedbackGuidanceMode];
    if (mode == 0) return NO;
    if (mode == 1) return YES;
    if (mode == 2) return userType == 2;
    return NO;
}

+ (void)requestStoreReview {
    if (@available(iOS 14.0, *)) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (scene) {
            [SKStoreReviewController requestReviewInScene:scene];
        } else {
            [SKStoreReviewController requestReview];
        }
    } else {
        [SKStoreReviewController requestReview];
    }
}

+ (void)presentIfNeededForced:(BOOL)forced
                     userType:(NSInteger)userType
                       inView:(UIView *)hostView
                   completion:(void (^)(void))completion {
    void (^done)(void) = ^{
        if (completion) completion();
    };
    if (![self shouldShowForForced:forced userType:userType]) {
        done();
        return;
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHQITRatingShownKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [HQITDialogs showRatingGuideInView:hostView
                              onSubmit:^(NSInteger stars) {
        if (stars >= 4) {
            [self requestStoreReview];
            done();
        } else {
            [HQITDialogs showRatingThanksInView:hostView onConfirm:^{
                done();
            }];
        }
    } onCancel:^{
        done();
    } onEmptySubmit:^{
        NSString *msg = [HQITCategoryText textForKey:@"q9"
                                        defaultText:@"Please select a rating before clicking Confirm"];
        [HQITHUDHelper showToast:msg];
    }];
}

@end
