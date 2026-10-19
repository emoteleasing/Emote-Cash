
#import "HQITMainTabBarController.h"
#import "HQITBaseNavigationController.h"
#import "HQITBaseViewController.h"
#import "HQITHomeLoanViewController.h"
#import "HQITMeViewController.h"
#import "HQITEMIInputViewController.h"
#import "HQITOrderHistoryViewController.h"
#import "HQITFontHelper.h"
#import "HQITAppShell.h"
#import "HQITSessionManager.h"

@interface HQITMainTabBarController () <UITabBarControllerDelegate>
@property (nonatomic, assign) NSUInteger lastSelectedIndex;
@end

@implementation HQITMainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.delegate = self;
    self.lastSelectedIndex = 0;
    [self configureAppearance];
    [self buildTabs];
}

- (void)configureAppearance {
    UIColor *normal = [UIColor colorWithRed:0x94/255.0 green:0xA3/255.0 blue:0xB8/255.0 alpha:1];
    UIColor *selected = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor whiteColor];
    appearance.shadowColor = [UIColor colorWithWhite:0.9 alpha:1];

    UITabBarItemAppearance *item = appearance.stackedLayoutAppearance;
    item.normal.iconColor = normal;
    item.selected.iconColor = selected;
    item.normal.titleTextAttributes = @{
        NSFontAttributeName: [HQITFontHelper regularFontOfSize:11],
        NSForegroundColorAttributeName: normal,
    };
    item.selected.titleTextAttributes = @{
        NSFontAttributeName: [HQITFontHelper boldFontOfSize:11],
        NSForegroundColorAttributeName: selected,
    };
    self.tabBar.standardAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        self.tabBar.scrollEdgeAppearance = appearance;
    }
    self.tabBar.tintColor = selected;
    self.tabBar.unselectedItemTintColor = normal;
}

- (HQITBaseNavigationController *)wrapRoot:(UIViewController *)root
                                     title:(NSString *)title
                               normalImage:(NSString *)normal
                             selectedImage:(NSString *)selected {
    if ([root isKindOfClass:[HQITBaseViewController class]]) {
        ((HQITBaseViewController *)root).hqit_hidesTabBarWhenPushed = NO;
    }
    HQITBaseNavigationController *nav = [[HQITBaseNavigationController alloc] initWithRootViewController:root];
    nav.navigationBarHidden = YES;
    UIImage *n = [[UIImage imageNamed:normal] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *s = [[UIImage imageNamed:selected] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:n selectedImage:s];
    return nav;
}

- (void)buildTabs {
    HQITHomeLoanViewController *loan = [[HQITHomeLoanViewController alloc] init];
    HQITOrderHistoryViewController *order = [[HQITOrderHistoryViewController alloc] init];
    HQITEMIInputViewController *emi = [[HQITEMIInputViewController alloc] init];
    HQITMeViewController *me = [[HQITMeViewController alloc] init];

    // Grey = unselected, red/orange = selected (asset names are inconsistent across tabs)
    self.viewControllers = @[
        [self wrapRoot:loan title:@"Loan" normalImage:@"an_loan_icon" selectedImage:@"loan_icon"],
        [self wrapRoot:order title:@"Order" normalImage:@"any_order_icon" selectedImage:@"order_icon"],
        [self wrapRoot:emi title:@"EMI" normalImage:@"pink_emi_icon" selectedImage:@"emi_icon"],
        [self wrapRoot:me title:@"Me" normalImage:@"be_me_icon" selectedImage:@"me_icon"],
    ];
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    NSUInteger index = [tabBarController.viewControllers indexOfObject:viewController];
    if (index == 0) return YES;
    if (![HQITSessionManager shared].isLoggedIn) {
        [[HQITAppShell shared] showLogin];
        return NO;
    }
    return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    NSUInteger index = tabBarController.selectedIndex;
    // §2.2.1: switching back to Loan from another tab refreshes pipeline
    if (index == 0 && self.lastSelectedIndex != 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HQITHomeShouldRefreshNotification object:nil];
    }
    self.lastSelectedIndex = index;
}

@end
