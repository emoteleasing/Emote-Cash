
#import "HQITPlaceholderViewController.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>

@interface HQITPlaceholderViewController ()
@property (nonatomic, copy) NSString *pageTitle;
@end

@implementation HQITPlaceholderViewController

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _pageTitle = [title copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.hqit_hidesTabBarWhenPushed = NO;
    self.view.backgroundColor = [UIColor colorWithRed:0xF7/255.0 green:0xF8/255.0 blue:0xFA/255.0 alpha:1];
    UILabel *label = [[UILabel alloc] init];
    label.text = self.pageTitle;
    label.font = [HQITFontHelper boldFontOfSize:22];
    label.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
}

@end
