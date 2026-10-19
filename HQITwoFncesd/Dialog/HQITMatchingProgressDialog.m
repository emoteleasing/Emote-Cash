

#import "HQITMatchingProgressDialog.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>

@implementation HQITMatchingProgressDialog

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.allowBackgroundDismiss = NO;
        self.cardView.backgroundColor = [UIColor clearColor];
        self.cardView.layer.cornerRadius = 0;
        self.cardView.clipsToBounds = NO;
        [self buildContent];
    }
    return self;
}

- (void)buildContent {
    UILabel *body = [[UILabel alloc] init];
    body.numberOfLines = 0;
    body.textAlignment = NSTextAlignmentCenter;
    body.font = [HQITFontHelper regularFontOfSize:14];
    body.textColor = [UIColor whiteColor];
    body.text = @"We are reviewing your profile to provide more suitable products. Priority matching in progress, estimated time: 10 seconds...";
    [self.cardView addSubview:body];

    UILabel *title = [[UILabel alloc] init];
    title.numberOfLines = 1;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [HQITFontHelper boldFontOfSize:16];
    title.textColor = [UIColor whiteColor];
    title.text = @"Matching in progress";
    [self.cardView addSubview:title];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipeitime_icon"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [self.cardView addSubview:icon];

    [body mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.cardView);
        make.left.equalTo(self.cardView).offset(8);
        make.right.equalTo(self.cardView).offset(-8);
    }];
    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(body.mas_bottom).offset(20);
        make.left.right.equalTo(body);
    }];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(title.mas_bottom).offset(28);
        make.centerX.equalTo(self.cardView);
        make.width.height.mas_equalTo(88);
        make.bottom.equalTo(self.cardView);
    }];
}

@end
