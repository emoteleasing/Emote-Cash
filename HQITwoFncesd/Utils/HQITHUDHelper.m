

#import "HQITHUDHelper.h"
#import <MBProgressHUD/MBProgressHUD.h>

@implementation HQITHUDHelper

+ (UIView *)keyView {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        if (!window) window = ws.windows.firstObject;
        if (window) break;
    }
    return window ?: UIApplication.sharedApplication.windows.firstObject;
}

+ (void)hqit_runOnMainSync:(dispatch_block_t)block {
    if (!block) return;
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (NSArray<UIView *> *)hqit_candidateHostsIncluding:(UIView *)view {
    NSMutableArray<UIView *> *hosts = [NSMutableArray array];
    void (^add)(UIView *) = ^(UIView *v) {
        if (v && ![hosts containsObject:v]) [hosts addObject:v];
    };
    add(view);
    add([self keyView]);
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            add(w);
        }
    }
    return hosts;
}

+ (void)hqit_hideLoadingHUDsInView:(UIView *)target animated:(BOOL)animated {
    if (!target) return;
    for (UIView *sub in [target.subviews copy]) {
        if (![sub isKindOfClass:[MBProgressHUD class]]) continue;
        MBProgressHUD *hud = (MBProgressHUD *)sub;
        if (hud.mode == MBProgressHUDModeIndeterminate) {
            [hud hideAnimated:animated];
        }
    }
}

+ (void)hqit_hideLoadingHUDsEverywhereAnimated:(BOOL)animated preferredView:(UIView *)view {
    for (UIView *host in [self hqit_candidateHostsIncluding:view]) {
        [self hqit_hideLoadingHUDsInView:host animated:animated];
    }
}

+ (void)showLoading {
    [self showLoadingInView:nil];
}

+ (void)showLoadingInView:(UIView *)view {
    [self showLoadingWithMessage:nil inView:view];
}

+ (void)showLoadingWithMessage:(NSString *)message {
    [self showLoadingWithMessage:message inView:nil];
}

+ (void)showLoadingWithMessage:(NSString *)message inView:(UIView *)view {
    UIView *target = view ?: [self keyView];
    if (!target) return;
    [self hqit_runOnMainSync:^{
        [self hqit_hideLoadingHUDsInView:target animated:NO];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:target animated:YES];
        hud.mode = MBProgressHUDModeIndeterminate;
        hud.removeFromSuperViewOnHide = YES;
        if (message.length > 0) {
            hud.label.text = message;
            hud.label.numberOfLines = 0;
        }
    }];
}

+ (void)hideLoading {
    [self hideLoadingInView:nil];
}

+ (void)hideLoadingInView:(UIView *)view {
    [self hqit_runOnMainSync:^{
        [self hqit_hideLoadingHUDsEverywhereAnimated:YES preferredView:view];
    }];
}

+ (void)showToast:(NSString *)message {
    [self showToast:message inView:nil];
}

+ (void)showToast:(NSString *)message inView:(UIView *)view {
    if (message.length == 0) return;
    UIView *target = view ?: [self keyView];
    if (!target) return;
    [self hqit_runOnMainSync:^{
        [self hqit_hideLoadingHUDsEverywhereAnimated:NO preferredView:target];
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:target animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.label.text = message;
        hud.label.numberOfLines = 0;
        hud.offset = CGPointMake(0, 0);
        hud.removeFromSuperViewOnHide = YES;
        hud.userInteractionEnabled = NO;
        [hud hideAnimated:YES afterDelay:2.0];
    }];
}

@end
