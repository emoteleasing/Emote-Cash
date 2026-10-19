

#import "SceneDelegate.h"
#import "HQITAppStartupManager.h"
#import "HQITIDFAAdjustCoordinator.h"
#import "HQITAppShell.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    [[HQITAppShell shared] installRootInWindow:self.window];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[HQITAppStartupManager shared] performStartupSequence];
    });
}

- (void)sceneDidDisconnect:(UIScene *)scene {
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [[HQITIDFAAdjustCoordinator shared] onApplicationDidBecomeActive];
}

- (void)sceneWillResignActive:(UIScene *)scene {
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
}

@end
