

#import "HQITDialogs.h"
#import "HQITMatchingProgressDialog.h"
#import "HQITCaptureProgressDialog.h"
#import "HQITLoanDetailsDialog.h"
#import "HQITLoanApplyViewModel.h"
#import "HQITFontHelper.h"
#import "HQITBuryRecorder.h"
#import <Masonry/Masonry.h>
#import <objc/runtime.h>
#import <SDWebImage/SDWebImage.h>

static UIView * HQITDialogAddFooterSeparator(UIView *card, UIView *contentAbove) {
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [UIColor colorWithRed:0xF0/255.0 green:0xF0/255.0 blue:0xF0/255.0 alpha:1];
    [card addSubview:sep];
    [sep mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(contentAbove.mas_bottom).offset(16);
        make.left.equalTo(card).offset(18);
        make.right.equalTo(card).offset(-18);
        make.height.mas_equalTo(0.5);
    }];
    return sep;
}

@implementation HQITSelectionOption
+ (instancetype)optionWithKey:(NSString *)key label:(NSString *)label {
    HQITSelectionOption *o = [[HQITSelectionOption alloc] init];
    o.key = key ?: @"";
    o.label = label ?: @"";
    return o;
}
@end

@interface HQITStandardDialog : HQITBaseDialog
- (void)configureWithTitle:(nullable NSString *)title
                      body:(NSString *)body
                      icon:(nullable UIImage *)icon
             confirmTitle:(NSString *)confirmTitle
              cancelTitle:(nullable NSString *)cancelTitle
                onConfirm:(HQITDialogActionBlock)onConfirm
                 onCancel:(HQITDialogActionBlock)onCancel;
@end

@implementation HQITStandardDialog

- (void)configureWithTitle:(NSString *)title
                      body:(NSString *)body
                      icon:(UIImage *)icon
             confirmTitle:(NSString *)confirmTitle
              cancelTitle:(NSString *)cancelTitle
                onConfirm:(HQITDialogActionBlock)onConfirm
                 onCancel:(HQITDialogActionBlock)onCancel {
    UIView *card = self.cardView;
    UIColor *bodyColor = [UIColor colorWithRed:0x94/255.0 green:0xA3/255.0 blue:0xB8/255.0 alpha:1];
    UIColor *accent = [UIColor colorWithRed:0.15 green:0.78 blue:0.72 alpha:1];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentFill;
    [card addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(20);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
    }];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"✕" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];
    [close mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(12);
        make.right.equalTo(card).offset(-12);
        make.width.height.mas_equalTo(28);
    }];

    if (icon) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [iv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(56);
        }];
        [stack addArrangedSubview:iv];
    }

    if (title.length > 0) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [HQITFontHelper boldFontOfSize:16];
        titleLabel.numberOfLines = 0;
        [stack addArrangedSubview:titleLabel];
    }

    UILabel *bodyLabel = [[UILabel alloc] init];
    bodyLabel.text = body ?: @"";
    bodyLabel.textColor = bodyColor;
    bodyLabel.font = [HQITFontHelper regularFontOfSize:14];
    bodyLabel.numberOfLines = 0;
    [stack addArrangedSubview:bodyLabel];

    UIView *sep = HQITDialogAddFooterSeparator(card, stack);

    UIStackView *btnStack = [[UIStackView alloc] init];
    btnStack.axis = UILayoutConstraintAxisVertical;
    btnStack.spacing = 12;
    btnStack.alignment = UIStackViewAlignmentFill;
    [card addSubview:btnStack];
    [btnStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(sep.mas_bottom).offset(16);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
        make.bottom.equalTo(card.mas_safeAreaLayoutGuideBottom).offset(-20);
    }];

    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeCustom];
    [confirm setTitle:confirmTitle forState:UIControlStateNormal];
    [confirm setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirm.backgroundColor = accent;
    confirm.layer.cornerRadius = 22;
    confirm.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [confirm mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(44);
    }];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [weakSelf dismissAnimated:YES];
        if (onConfirm) onConfirm();
    }] forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:confirm];

    if (cancelTitle.length > 0) {
        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        [cancel setTitle:cancelTitle forState:UIControlStateNormal];
        [cancel setTitleColor:bodyColor forState:UIControlStateNormal];
        [cancel addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            [weakSelf dismissAnimated:YES];
            if (onCancel) onCancel();
        }] forControlEvents:UIControlEventTouchUpInside];
        [btnStack addArrangedSubview:cancel];
    }

    objc_setAssociatedObject(self, @selector(onClose), onCancel, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)onClose {
    HQITDialogActionBlock cancel = objc_getAssociatedObject(self, @selector(onClose));
    [self dismissAnimated:YES];
    if (cancel) cancel();
}

@end

#pragma mark - Selection bottom sheet

@interface HQITSelectionDialog : HQITBaseDialog
@property (nonatomic, copy) NSArray<HQITSelectionOption *> *options;
@property (nonatomic, copy, nullable) NSString *selectedKey;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy, nullable) HQITSelectionConfirmBlock onConfirmBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onCancelBlock;
@property (nonatomic, strong) UIStackView *listStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *rowButtons;
@end

@implementation HQITSelectionDialog

- (void)configureWithTitle:(NSString *)title
                   options:(NSArray<HQITSelectionOption *> *)options
               selectedKey:(NSString *)selectedKey
                 onConfirm:(HQITSelectionConfirmBlock)onConfirm
                  onCancel:(HQITDialogActionBlock)onCancel {
    self.allowBackgroundDismiss = NO;
    self.options = options ?: @[];
    self.selectedKey = selectedKey;
    self.selectedIndex = NSNotFound;
    if (selectedKey.length > 0) {
        for (NSInteger i = 0; i < (NSInteger)self.options.count; i++) {
            if ([self.options[i].key isEqualToString:selectedKey]) {
                self.selectedIndex = i;
                break;
            }
        }
    }
    self.onConfirmBlock = onConfirm;
    self.onCancelBlock = onCancel;
    self.rowButtons = [NSMutableArray array];

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;

    UIColor *navy = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    UIColor *red = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    UIColor *pill = [UIColor colorWithRed:1.0 green:0.92 blue:0.90 alpha:1];
    UIColor *titleLine = [UIColor colorWithRed:0xEE/255.0 green:0xF0/255.0 blue:0xF3/255.0 alpha:1];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = title ?: @"";
    titleLab.font = [HQITFontHelper boldFontOfSize:16];
    titleLab.textColor = navy;
    titleLab.textAlignment = NSTextAlignmentCenter;
    [card addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(18);
        make.left.equalTo(card).offset(48);
        make.right.equalTo(card).offset(-48);
    }];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    close.backgroundColor = [UIColor colorWithRed:0xF2/255.0 green:0xF3/255.0 blue:0xF5/255.0 alpha:1];
    close.layer.cornerRadius = 14;
    UIImage *xImg = [[UIImage systemImageNamed:@"xmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [close setImage:xImg forState:UIControlStateNormal];
    close.tintColor = [UIColor colorWithWhite:0.4 alpha:1];
    [close addTarget:self action:@selector(onCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];
    [close mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(titleLab);
        make.right.equalTo(card).offset(-16);
        make.width.height.mas_equalTo(28);
    }];
    // Center the X glyph visually
    close.imageView.contentMode = UIViewContentModeScaleAspectFit;
    close.contentEdgeInsets = UIEdgeInsetsMake(7, 7, 7, 7);

    UIView *titleSep = [[UIView alloc] init];
    titleSep.backgroundColor = titleLine;
    [card addSubview:titleSep];
    [titleSep mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLab.mas_bottom).offset(16);
        make.left.right.equalTo(card);
        make.height.mas_equalTo(1);
    }];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsVerticalScrollIndicator = NO;
    [card addSubview:scroll];

    self.listStack = [[UIStackView alloc] init];
    self.listStack.axis = UILayoutConstraintAxisVertical;
    self.listStack.spacing = 8;
    [scroll addSubview:self.listStack];
    [self.listStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(scroll).insets(UIEdgeInsetsMake(12, 16, 12, 16));
        make.width.equalTo(scroll).offset(-32);
    }];

    for (NSInteger i = 0; i < (NSInteger)self.options.count; i++) {
        HQITSelectionOption *opt = self.options[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.tag = i;
        row.layer.cornerRadius = 16;
        row.clipsToBounds = YES;
        [row addTarget:self action:@selector(onRowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(44);
        }];

        UILabel *lab = [[UILabel alloc] init];
        lab.text = opt.label;
        lab.textAlignment = NSTextAlignmentCenter;
        lab.tag = 1001;
        lab.userInteractionEnabled = NO;
        [row addSubview:lab];

        UIImageView *check = [[UIImageView alloc] init];
        check.tag = 1002;
        check.contentMode = UIViewContentModeScaleAspectFit;
        check.userInteractionEnabled = NO;
        // Red circle check drawn as tinted SF Symbol
        UIImage *chk = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        check.image = [chk imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        check.tintColor = red;
        [row addSubview:check];

        [lab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(row);
            make.left.greaterThanOrEqualTo(row).offset(40);
            make.right.lessThanOrEqualTo(row).offset(-40);
        }];
        [check mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(row).offset(-14);
            make.centerY.equalTo(row);
            make.width.height.mas_equalTo(22);
        }];

        [self.listStack addArrangedSubview:row];
        [self.rowButtons addObject:row];
        (void)pill;
    }
    [self reloadSelectionUI];

    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat w = MAX(bg.size.width, 1);
        CGFloat h = MAX(bg.size.height, 1);
        UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
        [confirm setBackgroundImage:[bg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                           forState:UIControlStateNormal];
    } else {
        confirm.backgroundColor = red;
        confirm.layer.cornerRadius = 22;
        confirm.clipsToBounds = YES;
    }
    [confirm setTitle:@"Confirm" forState:UIControlStateNormal];
    [confirm setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirm.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [confirm addTarget:self action:@selector(onConfirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:confirm];

    [scroll mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleSep.mas_bottom);
        make.left.right.equalTo(card);
        make.height.mas_equalTo(MIN(44 * self.options.count + 8 * MAX((NSInteger)self.options.count - 1, 0) + 24, 320));
    }];
    UIView *footerSep = HQITDialogAddFooterSeparator(card, scroll);
    [confirm mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(footerSep.mas_bottom).offset(16);
        make.left.equalTo(card).offset(40);
        make.right.equalTo(card).offset(-40);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card.mas_safeAreaLayoutGuideBottom).offset(-16);
    }];
}

- (void)reloadSelectionUI {
    UIColor *navy = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    UIColor *red = [UIColor colorWithRed:0xC1/255.0 green:0x0A/255.0 blue:0x02/255.0 alpha:1];
    UIColor *pill = [UIColor colorWithRed:1.0 green:0.92 blue:0.90 alpha:1];
    for (NSInteger i = 0; i < (NSInteger)self.rowButtons.count; i++) {
        UIButton *row = self.rowButtons[i];
        BOOL sel = (i == self.selectedIndex);
        UILabel *lab = [row viewWithTag:1001];
        UIImageView *check = [row viewWithTag:1002];
        row.backgroundColor = sel ? pill : [UIColor clearColor];
        lab.font = sel ? [HQITFontHelper boldFontOfSize:15] : [HQITFontHelper regularFontOfSize:15];
        lab.textColor = sel ? red : navy;
        check.hidden = !sel;
    }
}

- (void)onRowTapped:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.options.count) return;
    self.selectedIndex = sender.tag;
    self.selectedKey = self.options[sender.tag].key;
    [self reloadSelectionUI];
}

- (void)onConfirmTapped {
    if (self.selectedIndex < 0 || self.selectedIndex >= (NSInteger)self.options.count) {
        return;
    }
    HQITSelectionOption *picked = self.options[self.selectedIndex];
    HQITSelectionConfirmBlock block = self.onConfirmBlock;
    [self dismissAnimated:YES];
    if (block) block(picked);
}

- (void)onCloseTapped {
    HQITDialogActionBlock cancel = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (cancel) cancel();
}

@end

#pragma mark - Version upgrade (white center card)

@interface HQITVersionUpdateDialog : HQITBaseDialog
@property (nonatomic, assign) BOOL forceUpdate;
@property (nonatomic, copy, nullable) NSString *updateURL;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onUpgradeBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onCancelBlock;
@end

@implementation HQITVersionUpdateDialog

- (void)configureWithVersion:(NSString *)version
                 forceUpdate:(BOOL)forceUpdate
                   updateURL:(NSString *)updateURL
                   onUpgrade:(HQITDialogActionBlock)onUpgrade
                    onCancel:(HQITDialogActionBlock)onCancel {
    self.forceUpdate = forceUpdate;
    self.updateURL = updateURL;
    self.onUpgradeBlock = onUpgrade;
    self.onCancelBlock = onCancel;
    self.allowBackgroundDismiss = NO;

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.12;
    card.layer.shadowRadius = 16;
    card.layer.shadowOffset = CGSizeMake(0, 8);

    UIColor *navy = [UIColor colorWithRed:0x00/255.0 green:0x1A/255.0 blue:0x41/255.0 alpha:1];
    UIColor *grey = [UIColor colorWithRed:0x8A/255.0 green:0x8F/255.0 blue:0x98/255.0 alpha:1];
    UIColor *cancelBg = [UIColor colorWithRed:0xF2/255.0 green:0xF3/255.0 blue:0xF5/255.0 alpha:1];
    UIColor *redFallback = [UIColor colorWithRed:0xE8/255.0 green:0x3B/255.0 blue:0x0B/255.0 alpha:1];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"new_icon"]];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(20);
        make.left.equalTo(card).offset(20);
        make.width.height.mas_equalTo(24);
    }];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = @"Upgrade";
    titleLab.font = [HQITFontHelper boldFontOfSize:18];
    titleLab.textColor = navy;
    [card addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(icon);
        make.left.equalTo(icon.mas_right).offset(8);
        make.right.lessThanOrEqualTo(card).offset(-20);
    }];

    UILabel *hintLab = [[UILabel alloc] init];
    hintLab.text = @"New version found";
    hintLab.font = [HQITFontHelper regularFontOfSize:14];
    hintLab.textColor = grey;
    hintLab.textAlignment = NSTextAlignmentCenter;
    [card addSubview:hintLab];
    [hintLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(icon.mas_bottom).offset(28);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
    }];

    NSString *verText = version.length > 0 ? version : @"";
    if (verText.length > 0 && ![verText.uppercaseString hasPrefix:@"V"]) {
        verText = [NSString stringWithFormat:@"V %@", verText];
    } else if (verText.length > 0 && [verText hasPrefix:@"V"] && ![verText hasPrefix:@"V "]) {
        // Normalize "V1.0.0" → "V 1.0.0"
        verText = [NSString stringWithFormat:@"V %@", [verText substringFromIndex:1]];
    }
    UILabel *verLab = [[UILabel alloc] init];
    verLab.text = verText;
    verLab.font = [HQITFontHelper boldFontOfSize:22];
    verLab.textColor = navy;
    verLab.textAlignment = NSTextAlignmentCenter;
    [card addSubview:verLab];
    [verLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(hintLab.mas_bottom).offset(8);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
    }];

    UIView *sep = HQITDialogAddFooterSeparator(card, verLab);

    UIButton *upgrade = [UIButton buttonWithType:UIButtonTypeCustom];
    upgrade.clipsToBounds = YES;
    upgrade.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat w = MAX(bg.size.width, 1);
        CGFloat h = MAX(bg.size.height, 1);
        UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
        [upgrade setBackgroundImage:[bg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                           forState:UIControlStateNormal];
    } else {
        upgrade.backgroundColor = redFallback;
    }
    [upgrade setTitle:@"Upgrade" forState:UIControlStateNormal];
    [upgrade setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    upgrade.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [upgrade addTarget:self action:@selector(onUpgradeTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:upgrade];

    if (forceUpdate) {
        [upgrade mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(sep.mas_bottom).offset(16);
            make.left.equalTo(card).offset(20);
            make.right.equalTo(card).offset(-20);
            make.height.mas_equalTo(44);
            make.bottom.equalTo(card).offset(-20);
        }];
    } else {
        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
        cancel.backgroundColor = cancelBg;
        cancel.layer.cornerRadius = 10;
        cancel.clipsToBounds = YES;
        [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
        [cancel setTitleColor:grey forState:UIControlStateNormal];
        cancel.titleLabel.font = [HQITFontHelper regularFontOfSize:15];
        [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];

        [cancel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(sep.mas_bottom).offset(16);
            make.left.equalTo(card).offset(20);
            make.height.mas_equalTo(44);
            make.bottom.equalTo(card).offset(-20);
        }];
        [upgrade mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.height.bottom.equalTo(cancel);
            make.left.equalTo(cancel.mas_right).offset(12);
            make.right.equalTo(card).offset(-20);
            make.width.equalTo(cancel);
        }];
    }

    [HQITBuryRecorder recordEventCode:30
                        eventContent:nil
                             remark1:(version.length > 0 ? version : nil)
                             remark2:nil
                             remark3:nil];
}

- (void)onUpgradeTapped {
    [HQITBuryRecorder recordEventCode:31
                        eventContent:nil
                             remark1:(self.updateURL.length > 0 ? self.updateURL : nil)
                             remark2:nil
                             remark3:nil];
    HQITDialogActionBlock block = self.onUpgradeBlock;
    if (self.forceUpdate) {
        // Keep dialog visible for force update
        if (block) block();
        return;
    }
    [self dismissAnimated:YES];
    if (block) block();
}

- (void)onCancelTapped {
    [HQITBuryRecorder recordEventCode:32 eventContent:nil remark1:nil remark2:nil remark3:nil];
    HQITDialogActionBlock block = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

@end

#pragma mark - White center confirm (KYC return / Sign Out)

@interface HQITWhiteConfirmDialog : HQITBaseDialog
@property (nonatomic, copy, nullable) HQITDialogActionBlock onConfirmBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onCancelBlock;
@property (nonatomic, strong, nullable) CAGradientLayer *primaryGradient;
@property (nonatomic, weak, nullable) UIButton *primaryButton;
@end

@implementation HQITWhiteConfirmDialog

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.primaryButton && self.primaryGradient) {
        self.primaryGradient.frame = self.primaryButton.bounds;
        self.primaryGradient.cornerRadius = self.primaryButton.layer.cornerRadius;
    }
}

- (void)configureWithTitle:(NSString *)title
                      body:(NSString *)body
                      icon:(UIImage *)icon
             confirmTitle:(NSString *)confirmTitle
              cancelTitle:(NSString *)cancelTitle
            cancelPrimary:(BOOL)cancelPrimary
                onConfirm:(HQITDialogActionBlock)onConfirm
                 onCancel:(HQITDialogActionBlock)onCancel {
    self.onConfirmBlock = onConfirm;
    self.onCancelBlock = onCancel;
    self.allowBackgroundDismiss = NO;

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.12;
    card.layer.shadowRadius = 16;
    card.layer.shadowOffset = CGSizeMake(0, 8);

    UIColor *navy = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    UIColor *bodyColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    UIColor *cancelBg = [UIColor colorWithRed:0xF2/255.0 green:0xF3/255.0 blue:0xF5/255.0 alpha:1];
    UIColor *mutedTitle = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    UIColor *redFallback = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];

    UIView *iconView = [self buildHeaderIconView:icon];
    [card addSubview:iconView];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(24);
        make.left.equalTo(card).offset(20);
        make.width.height.mas_equalTo(32);
    }];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = title ?: @"";
    titleLab.font = [HQITFontHelper boldFontOfSize:17];
    titleLab.textColor = navy;
    titleLab.numberOfLines = 0;
    [card addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(iconView);
        make.left.equalTo(iconView.mas_right).offset(10);
        make.right.equalTo(card).offset(-20);
    }];

    UILabel *bodyLab = [[UILabel alloc] init];
    bodyLab.text = body ?: @"";
    bodyLab.font = [HQITFontHelper regularFontOfSize:14];
    bodyLab.textColor = bodyColor;
    bodyLab.numberOfLines = 0;
    bodyLab.textAlignment = NSTextAlignmentLeft;
    [card addSubview:bodyLab];
    [bodyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(iconView.mas_bottom).offset(16);
        make.left.equalTo(card).offset(20);
        make.right.equalTo(card).offset(-20);
    }];

    UIButton * (^makeGrayButton)(NSString *) = ^UIButton *(NSString *text) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = cancelBg;
        btn.layer.cornerRadius = 10;
        btn.clipsToBounds = YES;
        [btn setTitle:text forState:UIControlStateNormal];
        [btn setTitleColor:mutedTitle forState:UIControlStateNormal];
        btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
        return btn;
    };

    UIButton * (^makePrimaryButton)(NSString *) = ^UIButton *(NSString *text) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.clipsToBounds = YES;
        btn.layer.cornerRadius = 10;
        btn.backgroundColor = redFallback;
        UIImage *bg = [UIImage imageNamed:@"button_bg"];
        if (bg) {
            CGFloat w = MAX(bg.size.width, 1);
            CGFloat h = MAX(bg.size.height, 1);
            UIEdgeInsets insets = UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45);
            [btn setBackgroundImage:[bg resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch]
                           forState:UIControlStateNormal];
        } else {
            CAGradientLayer *g = [CAGradientLayer layer];
            g.colors = @[
                (id)[UIColor colorWithRed:0xFF/255.0 green:0x8A/255.0 blue:0x1A/255.0 alpha:1].CGColor,
                (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
                (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
            ];
            g.locations = @[@0, @0.55, @1];
            g.startPoint = CGPointMake(0.5, 0);
            g.endPoint = CGPointMake(0.5, 1);
            [btn.layer insertSublayer:g atIndex:0];
            self.primaryGradient = g;
            self.primaryButton = btn;
        }
        [btn setTitle:text forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
        return btn;
    };

    NSString *confirmText = confirmTitle.length ? confirmTitle : @"Confirm";
    UIButton *confirm = cancelPrimary ? makeGrayButton(confirmText) : makePrimaryButton(confirmText);
    [confirm addTarget:self action:@selector(onConfirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:confirm];

    UIView *sep = HQITDialogAddFooterSeparator(card, bodyLab);

    if (cancelTitle.length > 0) {
        UIButton *cancel = cancelPrimary ? makePrimaryButton(cancelTitle) : makeGrayButton(cancelTitle);
        [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];

        [cancel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(sep.mas_bottom).offset(16);
            make.left.equalTo(card).offset(16);
            make.height.mas_equalTo(44);
            make.bottom.equalTo(card).offset(-20);
        }];
        [confirm mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.height.bottom.equalTo(cancel);
            make.left.equalTo(cancel.mas_right).offset(12);
            make.right.equalTo(card).offset(-16);
            make.width.equalTo(cancel);
        }];
    } else {
        [confirm mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(sep.mas_bottom).offset(16);
            make.left.equalTo(card).offset(16);
            make.right.equalTo(card).offset(-16);
            make.height.mas_equalTo(44);
            make.bottom.equalTo(card).offset(-20);
        }];
    }
}

- (UIView *)buildHeaderIconView:(UIImage *)icon {
    if (icon) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        return iv;
    }
    // Default: orange-red circle + white back chevron (KYC return)
    UIView *wrap = [[UIView alloc] init];
    wrap.clipsToBounds = YES;
    wrap.layer.cornerRadius = 16;

    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        UIImageView *bgIv = [[UIImageView alloc] initWithImage:bg];
        bgIv.contentMode = UIViewContentModeScaleAspectFill;
        bgIv.clipsToBounds = YES;
        [wrap addSubview:bgIv];
        [bgIv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(wrap);
        }];
    } else {
        wrap.backgroundColor = [UIColor colorWithRed:0xE8/255.0 green:0x3B/255.0 blue:0x0B/255.0 alpha:1];
    }

    UIImage *chevron = [[UIImage systemImageNamed:@"chevron.left"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *arrow = [[UIImageView alloc] initWithImage:chevron];
    arrow.tintColor = [UIColor whiteColor];
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [wrap addSubview:arrow];
    [arrow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(wrap);
        make.width.height.mas_equalTo(12);
    }];
    return wrap;
}

- (void)onConfirmTapped {
    HQITDialogActionBlock block = self.onConfirmBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

- (void)onCancelTapped {
    HQITDialogActionBlock block = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

@end

#pragma mark - Permission secondary (unified center)

@interface HQITPermissionGradientButton : UIButton
@property (nonatomic, strong) CAGradientLayer *hqit_gradient;
@end

@implementation HQITPermissionGradientButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 10;
        _hqit_gradient = [CAGradientLayer layer];
        _hqit_gradient.colors = @[
            (id)[UIColor colorWithRed:0xFF/255.0 green:0x8A/255.0 blue:0x1A/255.0 alpha:1].CGColor,
            (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
            (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
        ];
        _hqit_gradient.locations = @[@0, @0.55, @1];
        _hqit_gradient.startPoint = CGPointMake(0.5, 0);
        _hqit_gradient.endPoint = CGPointMake(0.5, 1);
        [self.layer insertSublayer:_hqit_gradient atIndex:0];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.hqit_gradient.frame = self.bounds;
    self.hqit_gradient.cornerRadius = self.layer.cornerRadius;
}
@end

@interface HQITPermissionIconCircle : UIView
@property (nonatomic, strong, nullable) CAGradientLayer *hqit_gradient;
@end

@implementation HQITPermissionIconCircle
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
    self.layer.cornerRadius = side * 0.5;
    if (self.hqit_gradient) {
        self.hqit_gradient.frame = self.bounds;
        self.hqit_gradient.cornerRadius = side * 0.5;
    }
}
@end

@interface HQITPermissionDialog : HQITBaseDialog
@property (nonatomic, copy, nullable) HQITDialogActionBlock onConfirmBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onCancelBlock;
@end

@implementation HQITPermissionDialog

- (UIView *)hqit_gradientCircleIcon:(UIImage *)icon symbolName:(NSString *)symbolName {
    HQITPermissionIconCircle *wrap = [[HQITPermissionIconCircle alloc] init];
    wrap.clipsToBounds = YES;

    if (icon) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        [wrap addSubview:iv];
        [iv mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(wrap);
        }];
        return wrap;
    }

    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[
        (id)[UIColor colorWithRed:0xFF/255.0 green:0x8A/255.0 blue:0x1A/255.0 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
    ];
    g.locations = @[@0, @0.55, @1];
    g.startPoint = CGPointMake(0.5, 0);
    g.endPoint = CGPointMake(0.5, 1);
    [wrap.layer insertSublayer:g atIndex:0];
    wrap.hqit_gradient = g;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
    NSString *name = symbolName.length ? symbolName : @"bell.fill";
    UIImage *sf = [[UIImage systemImageNamed:name withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (!sf) {
        sf = [[UIImage systemImageNamed:@"bell.fill" withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    UIImageView *iv = [[UIImageView alloc] initWithImage:sf];
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [wrap addSubview:iv];
    [iv mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(wrap);
        make.width.height.mas_equalTo(32);
    }];
    return wrap;
}

- (void)configureWithTitle:(NSString *)title
                      body:(NSString *)body
                      icon:(UIImage *)icon
                symbolName:(NSString *)symbolName
             confirmTitle:(NSString *)confirmTitle
              cancelTitle:(NSString *)cancelTitle
                onConfirm:(HQITDialogActionBlock)onConfirm
                 onCancel:(HQITDialogActionBlock)onCancel {
    self.onConfirmBlock = onConfirm;
    self.onCancelBlock = onCancel;
    self.allowBackgroundDismiss = NO;

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.12;
    card.layer.shadowRadius = 16;
    card.layer.shadowOffset = CGSizeMake(0, 8);

    UIColor *navy = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    UIColor *bodyColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    UIColor *cancelBg = [UIColor colorWithRed:0xF2/255.0 green:0xF3/255.0 blue:0xF5/255.0 alpha:1];
    UIColor *cancelTitleColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];

    UIView *iconView = [self hqit_gradientCircleIcon:icon symbolName:symbolName];
    [card addSubview:iconView];
    [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(28);
        make.centerX.equalTo(card);
        make.width.height.mas_equalTo(72);
    }];

    UIView *textAnchor = iconView;
    if (title.length > 0) {
        UILabel *titleLab = [[UILabel alloc] init];
        titleLab.text = title;
        titleLab.font = [HQITFontHelper boldFontOfSize:16];
        titleLab.textColor = navy;
        titleLab.textAlignment = NSTextAlignmentCenter;
        titleLab.numberOfLines = 0;
        [card addSubview:titleLab];
        [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(iconView.mas_bottom).offset(16);
            make.left.equalTo(card).offset(24);
            make.right.equalTo(card).offset(-24);
        }];
        textAnchor = titleLab;
    }

    UILabel *bodyLab = [[UILabel alloc] init];
    bodyLab.text = body ?: @"";
    bodyLab.font = [HQITFontHelper regularFontOfSize:14];
    bodyLab.textColor = bodyColor;
    bodyLab.textAlignment = NSTextAlignmentCenter;
    bodyLab.numberOfLines = 0;
    [card addSubview:bodyLab];
    [bodyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(textAnchor.mas_bottom).offset(16);
        make.left.equalTo(card).offset(24);
        make.right.equalTo(card).offset(-24);
    }];

    HQITPermissionGradientButton *confirm = [[HQITPermissionGradientButton alloc] initWithFrame:CGRectZero];
    confirm.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    [confirm setTitle:(confirmTitle.length ? confirmTitle : @"Confirm") forState:UIControlStateNormal];
    [confirm setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirm.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [confirm addTarget:self action:@selector(onConfirmTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *sep = HQITDialogAddFooterSeparator(card, bodyLab);

    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 12;
    btnRow.distribution = UIStackViewDistributionFillEqually;
    btnRow.alignment = UIStackViewAlignmentFill;
    [card addSubview:btnRow];

    if (cancelTitle.length > 0) {
        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
        cancel.backgroundColor = cancelBg;
        cancel.layer.cornerRadius = 10;
        cancel.clipsToBounds = YES;
        [cancel setTitle:cancelTitle forState:UIControlStateNormal];
        [cancel setTitleColor:cancelTitleColor forState:UIControlStateNormal];
        cancel.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
        [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [btnRow addArrangedSubview:cancel];
        [btnRow addArrangedSubview:confirm];
    } else {
        [btnRow addArrangedSubview:confirm];
    }

    [btnRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(sep.mas_bottom).offset(16);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card).offset(-20);
    }];
}

- (void)onConfirmTapped {
    HQITDialogActionBlock block = self.onConfirmBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

- (void)onCancelTapped {
    HQITDialogActionBlock block = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

@end

#pragma mark - Document verify fail (Aadhaar/PAN)

@interface HQITDocumentVerifyFailDialog : HQITBaseDialog
@property (nonatomic, copy, nullable) HQITDialogActionBlock onConfirmBlock;
@property (nonatomic, strong) CAGradientLayer *confirmGradient;
@end

@implementation HQITDocumentVerifyFailDialog

- (void)layoutSubviews {
    [super layoutSubviews];
    UIButton *btn = [self viewWithTag:9301];
    if ([btn isKindOfClass:[UIButton class]] && self.confirmGradient) {
        self.confirmGradient.frame = btn.bounds;
        self.confirmGradient.cornerRadius = 10;
    }
}

- (void)configureWithOnConfirm:(HQITDialogActionBlock)onConfirm {
    self.onConfirmBlock = onConfirm;
    self.allowBackgroundDismiss = NO;

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

    UIColor *navy = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];

    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.numberOfLines = 0;
    titleLab.font = [HQITFontHelper mediumFontOfSize:15];
    titleLab.textColor = navy;
    titleLab.text = @"Verification failed. Please upload the photo again.";
    [card addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(20);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
    }];

    UIImageView *guide = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"too_bg"]];
    guide.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:guide];
    [guide mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(titleLab.mas_bottom).offset(16);
        make.left.equalTo(card).offset(12);
        make.right.equalTo(card).offset(-12);
        make.height.equalTo(guide.mas_width).multipliedBy(231.0 / 583.0);
    }];

    UIButton *confirm = [UIButton buttonWithType:UIButtonTypeCustom];
    confirm.tag = 9301;
    confirm.clipsToBounds = YES;
    confirm.layer.cornerRadius = 10;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat w = MAX(bg.size.width, 1), h = MAX(bg.size.height, 1);
        [confirm setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(h * 0.45, w * 0.45, h * 0.45, w * 0.45)
                                                       resizingMode:UIImageResizingModeStretch]
                           forState:UIControlStateNormal];
    } else {
        self.confirmGradient = [CAGradientLayer layer];
        self.confirmGradient.colors = @[
            (id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
            (id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
        ];
        self.confirmGradient.startPoint = CGPointMake(0.5, 0);
        self.confirmGradient.endPoint = CGPointMake(0.5, 1);
        [confirm.layer insertSublayer:self.confirmGradient atIndex:0];
    }
    [confirm setTitle:@"Upload again" forState:UIControlStateNormal];
    [confirm setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirm.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [confirm addTarget:self action:@selector(onConfirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:confirm];
    [confirm mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(guide.mas_bottom).offset(20);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card).offset(-20);
    }];
}

- (void)onConfirmTapped {
    HQITDialogActionBlock block = self.onConfirmBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

@end

#pragma mark - Rating guide / thanks

@interface HQITRatingGuideDialog : HQITBaseDialog
@property (nonatomic, assign) NSInteger selectedStars;
@property (nonatomic, strong) NSMutableArray<UIButton *> *thumbButtons;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong, nullable) UIImage *cachedSelectedThumb;
@property (nonatomic, strong, nullable) UIImage *cachedUnselectedThumb;
@property (nonatomic, copy, nullable) HQITRatingSubmitBlock onSubmitBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onCancelBlock;
@property (nonatomic, copy, nullable) HQITDialogActionBlock onEmptySubmitBlock;
@end

@implementation HQITRatingGuideDialog

static const CGFloat kHQITRatingThumbSize = 34;

- (UIImage *)hqit_sizedThumb:(UIImage *)image {
    if (!image) return nil;
    CGFloat side = kHQITRatingThumbSize;
    CGSize sz = image.size;
    if (sz.width < 0.5 || sz.height < 0.5) return image;
    CGFloat fit = MIN(side / sz.width, side / sz.height);
    CGFloat dw = sz.width * fit;
    CGFloat dh = sz.height * fit;
    CGRect dst = CGRectMake((side - dw) * 0.5, (side - dh) * 0.5, dw, dh);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
    [image drawInRect:dst];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [out imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (UIImage *)hqit_thumbImageNamed:(NSString *)name fallbackSystem:(NSString *)systemName {
    UIImage *asset = [UIImage imageNamed:name];
    if (asset) {
        return [self hqit_sizedThumb:asset] ?: [asset imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:kHQITRatingThumbSize
                                                        weight:UIImageSymbolWeightRegular];
    UIImage *sys = [UIImage systemImageNamed:systemName withConfiguration:cfg];
    return [self hqit_sizedThumb:sys]
        ?: [sys imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)hqit_unselectedThumb {
    if (!self.cachedUnselectedThumb) {
        self.cachedUnselectedThumb = [self hqit_thumbImageNamed:@"hapingUnSuccess_icon" fallbackSystem:@"hand.thumbsup"];
    }
    return self.cachedUnselectedThumb;
}

- (UIImage *)hqit_selectedThumb {
    if (!self.cachedSelectedThumb) {
        self.cachedSelectedThumb = [self hqit_thumbImageNamed:@"hapSplease_icon" fallbackSystem:@"hand.thumbsup.fill"];
    }
    return self.cachedSelectedThumb;
}

- (void)configureWithOnSubmit:(HQITRatingSubmitBlock)onSubmit
                     onCancel:(HQITDialogActionBlock)onCancel
                onEmptySubmit:(HQITDialogActionBlock)onEmptySubmit {
    self.onSubmitBlock = onSubmit;
    self.onCancelBlock = onCancel;
    self.onEmptySubmitBlock = onEmptySubmit;
    self.allowBackgroundDismiss = NO;
    self.selectedStars = 0;
    self.thumbButtons = [NSMutableArray array];

    UIView *card = self.cardView;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20;
    card.clipsToBounds = YES;

    UIColor *bodyColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    UIColor *cancelBg = [UIColor colorWithRed:0xF2/255.0 green:0xF3/255.0 blue:0xF5/255.0 alpha:1];
    UIColor *cancelTitleColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1];

    UIStackView *thumbs = [[UIStackView alloc] init];
    thumbs.axis = UILayoutConstraintAxisHorizontal;
    thumbs.spacing = 14;
    thumbs.alignment = UIStackViewAlignmentCenter;
    thumbs.distribution = UIStackViewDistributionEqualSpacing;
    [card addSubview:thumbs];

    UIImage *off = [self hqit_unselectedThumb];
    for (NSInteger i = 1; i <= 5; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        if (@available(iOS 15.0, *)) {
            b.configuration = nil;
        }
        [b setImage:off forState:UIControlStateNormal];
        b.imageView.contentMode = UIViewContentModeCenter;
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        b.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        b.imageEdgeInsets = UIEdgeInsetsZero;
        b.contentEdgeInsets = UIEdgeInsetsZero;
        [b addTarget:self action:@selector(onThumb:) forControlEvents:UIControlEventTouchUpInside];
        [b mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(kHQITRatingThumbSize);
        }];
        [thumbs addArrangedSubview:b];
        [self.thumbButtons addObject:b];
    }

    UILabel *bodyLab = [[UILabel alloc] init];
    bodyLab.numberOfLines = 0;
    bodyLab.textAlignment = NSTextAlignmentCenter;
    bodyLab.font = [HQITFontHelper regularFontOfSize:14];
    bodyLab.textColor = bodyColor;
    bodyLab.text = @"If you like our app, please consider giving us a five-star rating, which would greatly support us!";
    [card addSubview:bodyLab];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.backgroundColor = cancelBg;
    cancel.layer.cornerRadius = 10;
    cancel.clipsToBounds = YES;
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancel setTitleColor:cancelTitleColor forState:UIControlStateNormal];
    cancel.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];

    self.submitButton = [[HQITPermissionGradientButton alloc] initWithFrame:CGRectZero];
    self.submitButton.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    [self.submitButton setTitle:@"Submit" forState:UIControlStateNormal];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [HQITFontHelper boldFontOfSize:15];
    [self.submitButton addTarget:self action:@selector(onSubmitTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 12;
    btnRow.distribution = UIStackViewDistributionFillEqually;
    [btnRow addArrangedSubview:cancel];
    [btnRow addArrangedSubview:self.submitButton];
    [card addSubview:btnRow];

    [thumbs mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(card).offset(28);
        make.centerX.equalTo(card);
    }];
    [bodyLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(thumbs.mas_bottom).offset(20);
        make.left.equalTo(card).offset(24);
        make.right.equalTo(card).offset(-24);
    }];
    UIView *sep = HQITDialogAddFooterSeparator(card, bodyLab);
    [btnRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(sep.mas_bottom).offset(16);
        make.left.equalTo(card).offset(16);
        make.right.equalTo(card).offset(-16);
        make.height.mas_equalTo(44);
        make.bottom.equalTo(card).offset(-20);
    }];
}

- (void)onThumb:(UIButton *)sender {
    self.selectedStars = sender.tag;
    UIImage *on = [self hqit_selectedThumb];
    UIImage *off = [self hqit_unselectedThumb];
    for (UIButton *b in self.thumbButtons) {
        BOOL selected = b.tag <= self.selectedStars;
        [b setImage:selected ? on : off forState:UIControlStateNormal];
        b.imageView.contentMode = UIViewContentModeCenter;
    }
}

- (void)onCancelTapped {
    HQITDialogActionBlock block = self.onCancelBlock;
    [self dismissAnimated:YES];
    if (block) block();
}

- (void)onSubmitTapped {
    if (self.selectedStars <= 0) {
        if (self.onEmptySubmitBlock) self.onEmptySubmitBlock();
        return;
    }
    HQITRatingSubmitBlock block = self.onSubmitBlock;
    NSInteger stars = self.selectedStars;
    [self dismissAnimated:YES];
    if (block) block(stars);
}

@end

@implementation HQITDialogs

+ (HQITBaseDialog *)showTitle:(NSString *)title
                         body:(NSString *)body
                confirmTitle:(NSString *)confirmTitle
                 cancelTitle:(NSString *)cancelTitle
                   placement:(HQITDialogPlacement)placement
                      inView:(UIView *)hostView
                   onConfirm:(HQITDialogActionBlock)onConfirm
                    onCancel:(HQITDialogActionBlock)onCancel {
    HQITStandardDialog *dialog = [[HQITStandardDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithTitle:title body:body icon:nil confirmTitle:confirmTitle cancelTitle:cancelTitle onConfirm:onConfirm onCancel:onCancel];
    [dialog showInView:hostView placement:placement];
    return dialog;
}

+ (HQITBaseDialog *)showBody:(NSString *)body
               confirmTitle:(NSString *)confirmTitle
                cancelTitle:(NSString *)cancelTitle
                  placement:(HQITDialogPlacement)placement
                     inView:(UIView *)hostView
                  onConfirm:(HQITDialogActionBlock)onConfirm
                   onCancel:(HQITDialogActionBlock)onCancel {
    return [self showTitle:nil body:body confirmTitle:confirmTitle cancelTitle:cancelTitle placement:placement inView:hostView onConfirm:onConfirm onCancel:onCancel];
}

+ (HQITBaseDialog *)showIcon:(UIImage *)icon
                       title:(NSString *)title
                        body:(NSString *)body
               confirmTitle:(NSString *)confirmTitle
                cancelTitle:(NSString *)cancelTitle
                     inView:(UIView *)hostView
                  onConfirm:(HQITDialogActionBlock)onConfirm
                   onCancel:(HQITDialogActionBlock)onCancel {
    HQITStandardDialog *dialog = [[HQITStandardDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithTitle:title body:body icon:icon confirmTitle:confirmTitle cancelTitle:cancelTitle onConfirm:onConfirm onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementBottom];
    return dialog;
}

+ (HQITBaseDialog *)showSelectionTitle:(NSString *)title
                               options:(NSArray<HQITSelectionOption *> *)options
                           selectedKey:(NSString *)selectedKey
                                inView:(UIView *)hostView
                            onConfirm:(HQITSelectionConfirmBlock)onConfirm
                             onCancel:(HQITDialogActionBlock)onCancel {
    HQITSelectionDialog *dialog = [[HQITSelectionDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithTitle:title options:options selectedKey:selectedKey onConfirm:onConfirm onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementBottom];
    return dialog;
}

+ (HQITBaseDialog *)showVersionUpgradeWithVersion:(NSString *)version
                                      forceUpdate:(BOOL)forceUpdate
                                        updateURL:(NSString *)updateURL
                                           inView:(UIView *)hostView
                                        onUpgrade:(HQITDialogActionBlock)onUpgrade
                                         onCancel:(HQITDialogActionBlock)onCancel {
    HQITVersionUpdateDialog *dialog = [[HQITVersionUpdateDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithVersion:version
                     forceUpdate:forceUpdate
                       updateURL:updateURL
                       onUpgrade:onUpgrade
                        onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (HQITBaseDialog *)showWhiteConfirmTitle:(NSString *)title
                                     body:(NSString *)body
                                     icon:(UIImage *)icon
                            confirmTitle:(NSString *)confirmTitle
                             cancelTitle:(NSString *)cancelTitle
                                  inView:(UIView *)hostView
                               onConfirm:(HQITDialogActionBlock)onConfirm
                                onCancel:(HQITDialogActionBlock)onCancel {
    return [self showWhiteConfirmTitle:title
                                  body:body
                                  icon:icon
                         confirmTitle:confirmTitle
                          cancelTitle:cancelTitle
                        cancelPrimary:NO
                               inView:hostView
                            onConfirm:onConfirm
                             onCancel:onCancel];
}

+ (HQITBaseDialog *)showWhiteConfirmTitle:(NSString *)title
                                     body:(NSString *)body
                                     icon:(UIImage *)icon
                            confirmTitle:(NSString *)confirmTitle
                             cancelTitle:(NSString *)cancelTitle
                           cancelPrimary:(BOOL)cancelPrimary
                                  inView:(UIView *)hostView
                               onConfirm:(HQITDialogActionBlock)onConfirm
                                onCancel:(HQITDialogActionBlock)onCancel {
    HQITWhiteConfirmDialog *dialog = [[HQITWhiteConfirmDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithTitle:title
                          body:body
                          icon:icon
                 confirmTitle:confirmTitle
                  cancelTitle:cancelTitle
                cancelPrimary:cancelPrimary
                    onConfirm:onConfirm
                     onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (HQITBaseDialog *)showPermissionTitle:(NSString *)title
                                   body:(NSString *)body
                                   icon:(UIImage *)icon
                             symbolName:(NSString *)symbolName
                          confirmTitle:(NSString *)confirmTitle
                           cancelTitle:(NSString *)cancelTitle
                                inView:(UIView *)hostView
                             onConfirm:(HQITDialogActionBlock)onConfirm
                              onCancel:(HQITDialogActionBlock)onCancel {
    HQITPermissionDialog *dialog = [[HQITPermissionDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithTitle:title
                          body:body
                          icon:icon
                    symbolName:symbolName
                 confirmTitle:confirmTitle
                  cancelTitle:cancelTitle
                    onConfirm:onConfirm
                     onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (HQITBaseDialog *)showDocumentVerifyFailInView:(UIView *)hostView
                                       onConfirm:(HQITDialogActionBlock)onConfirm {
    HQITDocumentVerifyFailDialog *dialog = [[HQITDocumentVerifyFailDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithOnConfirm:onConfirm];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (UIImage *)orangeCheckHeaderIcon {
    CGFloat side = 64.0;
    CGSize size = CGSizeMake(side, side);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, side, side);
    CGContextSaveGState(ctx);
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];
    [circle addClip];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[
        (__bridge id)[UIColor colorWithRed:0xFF/255.0 green:0x8A/255.0 blue:0x1A/255.0 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0xC5/255.0 green:0x06/255.0 blue:0x00/255.0 alpha:1].CGColor,
    ];
    CGFloat locs[] = {0, 0.55, 1};
    CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locs);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(side * 0.5, 0), CGPointMake(side * 0.5, side), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(ctx);

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImage *check = [UIImage systemImageNamed:@"checkmark" withConfiguration:cfg];
    if (@available(iOS 13.0, *)) {
        check = [check imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    CGSize cs = check.size;
    CGRect checkRect = CGRectMake((side - cs.width) * 0.5, (side - cs.height) * 0.5, cs.width, cs.height);
    [check drawInRect:checkRect];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (HQITBaseDialog *)showRatingGuideInView:(UIView *)hostView
                                 onSubmit:(HQITRatingSubmitBlock)onSubmit
                                  onCancel:(HQITDialogActionBlock)onCancel
                            onEmptySubmit:(HQITDialogActionBlock)onEmptySubmit {
    HQITRatingGuideDialog *dialog = [[HQITRatingGuideDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithOnSubmit:onSubmit onCancel:onCancel onEmptySubmit:onEmptySubmit];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (HQITBaseDialog *)showRatingThanksInView:(UIView *)hostView
                                 onConfirm:(HQITDialogActionBlock)onConfirm {
    return [self showPermissionTitle:@"Thank you very much!"
                                body:@"We have received your valuable feedback."
                                icon:[UIImage imageNamed:@"hapingSuccess_icon"]
                          symbolName:@"heart.fill"
                       confirmTitle:@"Confirm"
                        cancelTitle:nil
                             inView:hostView
                          onConfirm:onConfirm
                           onCancel:nil];
}

+ (HQITBaseDialog *)showMatchingProgressInView:(UIView *)hostView {
    HQITMatchingProgressDialog *dialog = [[HQITMatchingProgressDialog alloc] initWithFrame:hostView.bounds];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

+ (HQITBaseDialog *)showCaptureProgressInView:(UIView *)hostView {
    return [HQITCaptureProgressDialog showInView:hostView];
}

+ (HQITBaseDialog *)showLoanDetailsRows:(NSArray<HQITLoanApplyDetailRow *> *)rows
                                 inView:(UIView *)hostView
                               onCancel:(HQITDialogActionBlock)onCancel {
    HQITLoanDetailsDialog *dialog = [[HQITLoanDetailsDialog alloc] initWithFrame:hostView.bounds];
    [dialog configureWithRows:rows ?: @[] onCancel:onCancel];
    [dialog showInView:hostView placement:HQITDialogPlacementCenter];
    return dialog;
}

@end
