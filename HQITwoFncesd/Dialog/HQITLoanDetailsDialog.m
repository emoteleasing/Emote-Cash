

#import "HQITLoanDetailsDialog.h"
#import "HQITLoanApplyViewModel.h"
#import "HQITFontHelper.h"
#import "HQITHUDHelper.h"
#import <Masonry/Masonry.h>

@interface HQITLoanDetailsDialog ()
@property (nonatomic, copy, nullable) void (^onCancelBlock)(void);
@end

@implementation HQITLoanDetailsDialog

- (void)configureWithRows:(NSArray<HQITLoanApplyDetailRow *> *)rows
                 onCancel:(void (^)(void))onCancel {
    self.onCancelBlock = onCancel;
    self.allowBackgroundDismiss = NO;

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;

    UIColor *labelColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1];
    UIColor *valueColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];
    UIColor *lineColor = [UIColor colorWithRed:0xEE/255.0 green:0xEE/255.0 blue:0xEE/255.0 alpha:1];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.alignment = UIStackViewAlignmentFill;
    [card addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(8);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
    }];

    for (NSInteger i = 0; i < (NSInteger)rows.count; i++) {
        HQITLoanApplyDetailRow *row = rows[i];
        UIView *rowView = [self rowViewFor:row labelColor:labelColor valueColor:valueColor];
        [stack addArrangedSubview:rowView];
        [rowView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(44);
        }];
        if (i < (NSInteger)rows.count - 1) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = lineColor;
            [stack addArrangedSubview:line];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(1.0 / UIScreen.mainScreen.scale);
            }];
        }
    }

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.clipsToBounds = YES;
    cancel.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat w = MAX(bg.size.width, 1), h = MAX(bg.size.height, 1);
        [cancel setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45)
                                                      resizingMode:UIImageResizingModeStretch]
                          forState:UIControlStateNormal];
    } else {
        cancel.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    }
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancel.titleLabel.font = [HQITFontHelper boldFontOfSize:16];
    [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancel];
    [cancel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(stack.mas_bottom).offset(20);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card).offset(-20);
    }];
}

- (UIView *)rowViewFor:(HQITLoanApplyDetailRow *)row
            labelColor:(UIColor *)labelColor
            valueColor:(UIColor *)valueColor {
    UIView *wrap = [[UIView alloc] init];

    UILabel *title = [[UILabel alloc] init];
    title.text = row.title;
    title.font = [HQITFontHelper regularFontOfSize:13];
    title.textColor = labelColor;
    [wrap addSubview:title];

    UIButton *info = nil;
    if (row.infoKey.length) {
        info = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *img = [[UIImage systemImageNamed:@"questionmark.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [info setImage:img forState:UIControlStateNormal];
        info.tintColor = labelColor;
        info.accessibilityIdentifier = row.infoKey;
        [info addTarget:self action:@selector(onInfo:) forControlEvents:UIControlEventTouchUpInside];
        [wrap addSubview:info];
    }

    UILabel *value = [[UILabel alloc] init];
    value.text = row.value;
    value.font = row.emphasized ? [HQITFontHelper boldFontOfSize:13] : [HQITFontHelper boldFontOfSize:13];
    value.textColor = valueColor;
    value.textAlignment = NSTextAlignmentRight;
    [wrap addSubview:value];

    [title mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(wrap);
        make.centerY.equalTo(wrap);
    }];
    if (info) {
        [info mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(title.mas_right).offset(4);
            make.centerY.equalTo(title);
            make.width.height.mas_equalTo(14);
        }];
    }
    [value mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(wrap);
        make.centerY.equalTo(wrap);
        make.left.greaterThanOrEqualTo(info ? info.mas_right : title.mas_right).offset(8);
    }];
    return wrap;
}

- (void)onInfo:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    NSString *msg = nil;
    if ([key isEqualToString:@"received"]) {
        msg = @"The actual amount you receive is calculated by deducting the service fee from the loan amount.";
    } else if ([key isEqualToString:@"fee"]) {
        msg = @"Service fee covers the administrative costs of processing your loan application.";
    } else if ([key isEqualToString:@"interest"]) {
        msg = @"Interest is the cost of borrowing money, calculated based on the loan amount and term.";
    }
    if (msg.length) [HQITHUDHelper showToast:msg];
}

- (void)onCancelTapped {
    void (^block)(void) = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

@end
