

#import "AppDelegate.h"
#import "HQITIDFAAdjustCoordinator.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [IQKeyboardManager sharedManager].enable = YES;
    [IQKeyboardManager sharedManager].shouldResignOnTouchOutside = YES;
    [[HQITIDFAAdjustCoordinator shared] startIDFAAdjustFlow];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[HQITIDFAAdjustCoordinator shared] onApplicationDidBecomeActive];
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
}

@end
