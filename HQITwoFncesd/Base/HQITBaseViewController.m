

#import "HQITBaseViewController.h"

@implementation HQITBaseViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _hqit_hidesTabBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    if (self.hqit_hidesTabBarWhenPushed) {
        self.hidesBottomBarWhenPushed = YES;
    }
    [self hqit_setupBackButtonIfNeeded];
}

- (BOOL)hqit_shouldPopBack {
    return YES;
}

- (void)hqit_setupBackButtonIfNeeded {
    if (self.navigationController.viewControllers.count <= 1) {
        return;
    }
    UIImage *icon = [UIImage imageNamed:@"back_icon"];
    if (!icon) {
        icon = [UIImage systemImageNamed:@"chevron.left"];
    }
    icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:icon
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(hqit_onBackTapped)];
    self.navigationItem.leftBarButtonItem = back;
}

- (void)hqit_onBackTapped {
    if (![self hqit_shouldPopBack]) {
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end
