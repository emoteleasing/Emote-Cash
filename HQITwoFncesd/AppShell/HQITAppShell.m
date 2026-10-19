

#import "HQITAppShell.h"
#import "HQITMainTabBarController.h"
#import "HQITLoginViewController.h"
#import "HQITBaseNavigationController.h"
#import "HQITSessionManager.h"
#import "HQITHomeSessionState.h"
#import "HQITStorageKeys.h"
#import "HQITAppStartupManager.h"

NSNotificationName const HQITHomeShouldRefreshNotification = @"HQITHomeShouldRefreshNotification";

@interface HQITAppShell ()
@property (nonatomic, assign) BOOL isPresentingLogin;
@end

@implementation HQITAppShell

+ (instancetype)shared {
    static HQITAppShell *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITAppShell alloc] init];
    });
    return instance;
}

- (HQITBaseNavigationController *)makeLoginNavigationController {
    HQITLoginViewController *login = [[HQITLoginViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    login.onLoginSuccess = ^{
        [weakSelf completeLogin];
    };
    HQITBaseNavigationController *nav = [[HQITBaseNavigationController alloc] initWithRootViewController:login];
    nav.navigationBarHidden = YES;
    return nav;
}

- (BOOL)isLoginAsRoot {
    UIViewController *root = self.window.rootViewController;
    if (![root isKindOfClass:[UINavigationController class]]) return NO;
    UIViewController *first = ((UINavigationController *)root).viewControllers.firstObject;
    return [first isKindOfClass:[HQITLoginViewController class]];
}

- (void)installRootInWindow:(UIWindow *)window {
    self.window = window;
    if ([HQITSessionManager shared].isLoggedIn) {
        [self installHomeRoot];
    } else {
        [self installLoginRoot];
    }
    [window makeKeyAndVisible];
}

- (void)installHomeRoot {
    if (!self.window) return;
    self.isPresentingLogin = NO;
    HQITMainTabBarController *tab = [[HQITMainTabBarController alloc] init];
    self.window.rootViewController = tab;
}

- (void)installLoginRoot {
    if (!self.window) return;
    self.isPresentingLogin = YES;
    self.window.rootViewController = [self makeLoginNavigationController];
}

- (UIViewController *)topMostViewController {
    UIViewController *root = self.window.rootViewController;
    if (!root) {
        root = UIApplication.sharedApplication.windows.firstObject.rootViewController;
    }
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    if ([root isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)root).selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            return ((UINavigationController *)selected).visibleViewController ?: selected;
        }
        return selected ?: root;
    }
    if ([root isKindOfClass:[UINavigationController class]]) {
        return ((UINavigationController *)root).visibleViewController ?: root;
    }
    return root;
}

- (void)showLogin {
    if ([HQITSessionManager shared].isLoggedIn) return;
    if ([self isLoginAsRoot]) return;
    if (!self.window) return;

    UIViewController *root = self.window.rootViewController;
    if (root.presentedViewController) {
        __weak typeof(self) weakSelf = self;
        [root dismissViewControllerAnimated:NO completion:^{
            [weakSelf installLoginRoot];
        }];
        return;
    }
    [self installLoginRoot];
}

- (void)completeLogin {
    // Fresh login: allow dialog chain again this session
    [HQITHomeSessionState resetForLogout];
    __weak typeof(self) weakSelf = self;
    // Refresh app/config and overwrite cache before home pipeline reads it.
    [[HQITAppStartupManager shared] refreshAppConfigThen:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self hqit_enterHomeAfterLogin];
    }];
}

- (void)hqit_enterHomeAfterLogin {
    void (^finish)(void) = ^{
        self.isPresentingLogin = NO;
        [self installHomeRoot];
        [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
    };

    UIViewController *root = self.window.rootViewController;
    if ([root isKindOfClass:[UITabBarController class]] && root.presentedViewController) {
        [root dismissViewControllerAnimated:YES completion:finish];
        return;
    }
    UIViewController *top = [self topMostViewController];
    if (top.presentingViewController && ![self isLoginAsRoot]) {
        [top.presentingViewController dismissViewControllerAnimated:YES completion:finish];
        return;
    }
    finish();
}

- (void)returnToGuestHomeThenShowLogin {
    [[HQITSessionManager shared] clearSession];
    [HQITHomeSessionState resetForLogout];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud removeObjectForKey:HQITStorageKeyUserName];
    [ud removeObjectForKey:HQITStorageKeyUserMobile];
    [ud removeObjectForKey:HQITStorageKeyUserStatus];
    [ud synchronize];
    self.isPresentingLogin = NO;

    UIViewController *root = self.window.rootViewController;
    void (^goLogin)(void) = ^{
        [self installLoginRoot];
    };
    if (root.presentedViewController) {
        [root dismissViewControllerAnimated:YES completion:goLogin];
    } else {
        goLogin();
    }
}

@end
