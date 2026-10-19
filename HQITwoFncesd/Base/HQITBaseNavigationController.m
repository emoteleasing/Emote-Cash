

#import "HQITBaseNavigationController.h"
#import "HQITBaseViewController.h"
#import "HQITNavigationBarStyle.h"

@implementation HQITBaseNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    self.interactivePopGestureRecognizer.delegate = self;
    [HQITNavigationBarStyle applyLoanBackgroundToNavigationBar:self.navigationBar];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (self.viewControllers.count > 0) {
        viewController.hidesBottomBarWhenPushed = YES;
    }
    [super pushViewController:viewController animated:animated];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    BOOL showTabBar = (viewController == navigationController.viewControllers.firstObject);
    [self hqit_setTabBarHidden:!showTabBar animated:animated forViewController:viewController];
}

- (void)hqit_setTabBarHidden:(BOOL)hidden
                    animated:(BOOL)animated
           forViewController:(UIViewController *)viewController {
    UITabBar *tabBar = self.tabBarController.tabBar;
    if (!tabBar) return;

    id<UIViewControllerTransitionCoordinator> coordinator = viewController.transitionCoordinator;
    if (animated && coordinator) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            tabBar.hidden = hidden;
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (context.isCancelled) {
                UIViewController *top = self.topViewController;
                tabBar.hidden = (top != self.viewControllers.firstObject);
            } else {
                tabBar.hidden = hidden;
            }
        }];
    } else {
        tabBar.hidden = hidden;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer != self.interactivePopGestureRecognizer) {
        return YES;
    }
    if (self.viewControllers.count <= 1) {
        return NO;
    }
    UIViewController *top = self.topViewController;
    if ([top isKindOfClass:[HQITBaseViewController class]]) {
        return [(HQITBaseViewController *)top hqit_shouldPopBack];
    }
    return YES;
}

@end
