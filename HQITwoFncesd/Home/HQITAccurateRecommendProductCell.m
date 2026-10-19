

#import "HQITAccurateRecommendProductCell.h"
#import "HQITAccurateRecommendViewModel.h"
#import "HQITFontHelper.h"
#import "HQITAmountFormatter.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

static const CGFloat kHQITAmountNodeSize = 32.0;
static const CGFloat kHQITAmountTrackHeight = 12.0;

@interface HQITAccurateRecommendProductCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIButton *checkButton;
@property (nonatomic, strong) UIView *amountBox;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UILabel *minAmountLabel;
@property (nonatomic, strong) UILabel *maxAmountLabel;
@property (nonatomic, strong) UIView *trackContainer;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIStackView *stepStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *stepButtons;
@property (nonatomic, strong) UIButton *detailsButton;
@property (nonatomic, strong) UIView *termRow;
@property (nonatomic, strong) UILabel *termTitleLabel;
@property (nonatomic, strong) UILabel *termValueLabel;
@property (nonatomic, strong) UIImageView *termChevron;
@property (nonatomic, strong) UIButton *termHitButton;
@property (nonatomic, strong) UILabel *arrivalTitleLabel;
@property (nonatomic, strong) UILabel *arrivalValueLabel;
@property (nonatomic, assign) NSInteger stepCount;
@property (nonatomic, assign) NSInteger selectedStepIndex;
@property (nonatomic, weak) HQITAccurateRecommendProductItem *boundItem;
@end

@implementation HQITAccurateRecommendProductCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.stepButtons = [NSMutableArray array];
        [self buildUI];
    }
    return self;
}

- (UIColor *)color102B4B {
    return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
}

- (UIColor *)colorE95702 {
    return [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
}

- (UIColor *)colorFFF3EE {
    return [UIColor colorWithRed:0xFF/255.0 green:0xF3/255.0 blue:0xEE/255.0 alpha:1];
}

- (UIColor *)colorTrack {
    return [UIColor colorWithRed:0xFF/255.0 green:0xD9/255.0 blue:0xAF/255.0 alpha:1];
}

- (void)buildUI {
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor whiteColor];
    self.card.layer.cornerRadius = 14;
    self.card.layer.shadowColor = [UIColor blackColor].CGColor;
    self.card.layer.shadowOpacity = 0.06;
    self.card.layer.shadowRadius = 8;
    self.card.layer.shadowOffset = CGSizeMake(0, 2);
    [self.contentView addSubview:self.card];
    [self.card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(6);
        make.bottom.equalTo(self.contentView).offset(-6);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
    }];

    self.logoView = [[UIImageView alloc] init];
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    self.logoView.layer.cornerRadius = 8;
    self.logoView.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self.card addSubview:self.logoView];
    [self.logoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.card).offset(14);
        make.top.equalTo(self.card).offset(10);
        make.width.height.mas_equalTo(36);
    }];

    self.checkButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.checkButton addTarget:self action:@selector(onCheck) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.checkButton];
    [self.checkButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.card).offset(-14);
        make.centerY.equalTo(self.logoView);
        make.width.height.mas_equalTo(18);
    }];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [HQITFontHelper boldFontOfSize:14];
    self.nameLabel.textColor = [self color102B4B];
    [self.card addSubview:self.nameLabel];
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.logoView.mas_right).offset(10);
        make.centerY.equalTo(self.logoView);
        make.right.lessThanOrEqualTo(self.checkButton.mas_left).offset(-8);
    }];

    self.amountBox = [[UIView alloc] init];
    self.amountBox.backgroundColor = [self colorFFF3EE];
    self.amountBox.layer.cornerRadius = 16;
    self.amountBox.clipsToBounds = YES;
    [self.card addSubview:self.amountBox];
    [self.amountBox mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.logoView.mas_bottom).offset(7);
        make.left.equalTo(self.card).offset(10);
        make.right.equalTo(self.card).offset(-10);
    }];

    self.amountLabel = [[UILabel alloc] init];
    self.amountLabel.font = [HQITFontHelper fontWithSize:20 weight:HQITFontWeightBold italic:YES];
    self.amountLabel.textColor = [self color102B4B];
    self.amountLabel.textAlignment = NSTextAlignmentCenter;
    self.amountLabel.adjustsFontSizeToFitWidth = YES;
    self.amountLabel.minimumScaleFactor = 0.7;
    [self.amountLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.amountBox addSubview:self.amountLabel];
    [self.amountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.amountBox).offset(8);
        make.left.equalTo(self.amountBox).offset(40);
        make.right.equalTo(self.amountBox).offset(-40);
    }];

    self.minAmountLabel = [[UILabel alloc] init];
    self.minAmountLabel.font = [HQITFontHelper regularFontOfSize:12];
    self.minAmountLabel.textColor = [self color102B4B];
    self.minAmountLabel.textAlignment = NSTextAlignmentLeft;
    [self.amountBox addSubview:self.minAmountLabel];
    [self.minAmountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.greaterThanOrEqualTo(self.amountBox).offset(21);
        make.top.greaterThanOrEqualTo(self.amountLabel.mas_bottom);
        make.left.equalTo(self.amountBox).offset(7);
        make.height.mas_equalTo(14);
    }];

    self.maxAmountLabel = [[UILabel alloc] init];
    self.maxAmountLabel.font = [HQITFontHelper regularFontOfSize:12];
    self.maxAmountLabel.textColor = [self color102B4B];
    self.maxAmountLabel.textAlignment = NSTextAlignmentRight;
    [self.amountBox addSubview:self.maxAmountLabel];
    [self.maxAmountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.minAmountLabel);
        make.right.equalTo(self.amountBox).offset(-7);
        make.left.greaterThanOrEqualTo(self.minAmountLabel.mas_right).offset(8);
    }];

    self.trackContainer = [[UIView alloc] init];
    [self.amountBox addSubview:self.trackContainer];
    [self.trackContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.minAmountLabel.mas_bottom);
        make.top.greaterThanOrEqualTo(self.amountLabel.mas_bottom).offset(10);
        make.left.equalTo(self.amountBox).offset(2);
        make.right.equalTo(self.amountBox).offset(-2);
        make.height.mas_equalTo(kHQITAmountNodeSize);
    }];

    self.trackView = [[UIView alloc] init];
    self.trackView.backgroundColor = [self colorTrack];
    self.trackView.layer.cornerRadius = kHQITAmountTrackHeight / 2.0;
    [self.trackContainer addSubview:self.trackView];
    [self.trackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.trackContainer);
        make.centerY.equalTo(self.trackContainer);
        make.height.mas_equalTo(kHQITAmountTrackHeight);
    }];

    self.stepStack = [[UIStackView alloc] init];
    self.stepStack.axis = UILayoutConstraintAxisHorizontal;
    self.stepStack.alignment = UIStackViewAlignmentCenter;
    self.stepStack.distribution = UIStackViewDistributionEqualSpacing;
    self.stepStack.spacing = 0;
    [self.trackContainer addSubview:self.stepStack];
    [self.stepStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.trackContainer);
    }];

    self.detailsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.detailsButton.clipsToBounds = YES;
    self.detailsButton.layer.cornerRadius = 14;
    UIImage *bg = [UIImage imageNamed:@"button_bg"];
    if (bg) {
        CGFloat bw = MAX(bg.size.width, 1), bh = MAX(bg.size.height, 1);
        [self.detailsButton setBackgroundImage:[bg resizableImageWithCapInsets:UIEdgeInsetsMake(bh * 0.45, bw * 0.45, bh * 0.45, bw * 0.45)
                                                                  resizingMode:UIImageResizingModeStretch]
                                      forState:UIControlStateNormal];
    } else {
        self.detailsButton.backgroundColor = [UIColor colorWithRed:0xE9/255.0 green:0x57/255.0 blue:0x02/255.0 alpha:1];
    }
    self.detailsButton.titleLabel.font = [HQITFontHelper fontWithSize:11 weight:HQITFontWeightBold italic:YES];
    [self.detailsButton setTitle:@"Loan details >>>" forState:UIControlStateNormal];
    [self.detailsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.detailsButton addTarget:self action:@selector(onDetails) forControlEvents:UIControlEventTouchUpInside];
    [self.amountBox addSubview:self.detailsButton];
    [self.detailsButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.trackContainer.mas_bottom);
        make.centerX.equalTo(self.amountBox);
        make.height.mas_equalTo(28);
        make.width.mas_equalTo(130);
        make.bottom.equalTo(self.amountBox).offset(-14);
    }];

    self.termRow = [[UIView alloc] init];
    [self.card addSubview:self.termRow];
    [self.termRow mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.amountBox.mas_bottom).offset(14);
        make.left.equalTo(self.card).offset(14);
        make.right.equalTo(self.card).offset(-14);
        make.height.mas_equalTo(20);
    }];

    self.termTitleLabel = [self metaTitleLabel:@"Loan term"];
    self.termValueLabel = [self metaValueLabel];
    UIImage *arrow = [UIImage imageNamed:@"an_into_icon"];
    self.termChevron = [[UIImageView alloc] initWithImage:arrow
                          ? [arrow imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                          : [UIImage systemImageNamed:@"chevron.right"]];
    self.termChevron.contentMode = UIViewContentModeScaleAspectFit;
    self.termChevron.hidden = YES;
    [self.termRow addSubview:self.termTitleLabel];
    [self.termRow addSubview:self.termValueLabel];
    [self.termRow addSubview:self.termChevron];

    [self.termTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.centerY.equalTo(self.termRow);
    }];
    [self.termChevron mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.centerY.equalTo(self.termRow);
        make.width.height.mas_equalTo(14); // an_into_icon 14×14
    }];
    [self.termValueLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.termRow);
        make.right.equalTo(self.termRow);
        make.left.greaterThanOrEqualTo(self.termTitleLabel.mas_right).offset(8);
    }];

    self.termHitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.termHitButton.hidden = YES;
    [self.termHitButton addTarget:self action:@selector(onTermTap) forControlEvents:UIControlEventTouchUpInside];
    [self.termRow addSubview:self.termHitButton];
    [self.termHitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.termRow);
    }];

    self.arrivalTitleLabel = [self metaTitleLabel:@"Amount received"];
    self.arrivalValueLabel = [self metaValueLabel];
    [self.card addSubview:self.arrivalTitleLabel];
    [self.card addSubview:self.arrivalValueLabel];

    [self.arrivalTitleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.termRow.mas_bottom).offset(12);
        make.left.equalTo(self.card).offset(14);
        make.bottom.equalTo(self.card).offset(-14);
    }];
    [self.arrivalValueLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.arrivalTitleLabel);
        make.right.equalTo(self.card).offset(-14);
        make.left.greaterThanOrEqualTo(self.arrivalTitleLabel.mas_right).offset(8);
    }];
}

- (UILabel *)metaTitleLabel:(NSString *)text {
    UILabel *lab = [[UILabel alloc] init];
    lab.text = text;
    lab.font = [HQITFontHelper regularFontOfSize:14];
    lab.textColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1];
    return lab;
}

- (UILabel *)metaValueLabel {
    UILabel *lab = [[UILabel alloc] init];
    lab.font = [HQITFontHelper regularFontOfSize:14];
    lab.textColor = [self color102B4B];
    lab.textAlignment = NSTextAlignmentRight;
    return lab;
}

- (void)rebuildStepButtons:(NSInteger)count {
    for (UIView *v in [self.stepStack.arrangedSubviews copy]) {
        [self.stepStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.stepButtons removeAllObjects];
    self.stepCount = MAX(count, 1);
    if (self.stepCount == 1) {
        UIView *spacer = [[UIView alloc] init];
        [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [self.stepStack addArrangedSubview:spacer];
    }
    for (NSInteger i = 0; i < self.stepCount; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.clipsToBounds = YES;
        btn.backgroundColor = [UIColor clearColor];
        btn.adjustsImageWhenHighlighted = NO;
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [btn setImage:[[UIImage imageNamed:@"amountUnSel_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
             forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(onStepTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(kHQITAmountNodeSize);
        }];
        [self.stepStack addArrangedSubview:btn];
        [self.stepButtons addObject:btn];
    }
}

- (void)refreshStepSelection {
    for (NSInteger i = 0; i < (NSInteger)self.stepButtons.count; i++) {
        UIButton *btn = self.stepButtons[i];
        BOOL on = (i == self.selectedStepIndex);
        btn.selected = on;
        UIImage *img = [UIImage imageNamed:on ? @"amountSel_icon" : @"amountUnSel_icon"];
        [btn setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    }
}

- (void)configureWithItem:(HQITAccurateRecommendProductItem *)item {
    self.boundItem = item;
    self.nameLabel.text = item.productName;
    UIImage *ph = [UIImage imageNamed:@"samll_icon"] ?: [UIImage imageNamed:@"amount_icon"];
    if (item.productLogo.length) {
        [self.logoView sd_setImageWithURL:[NSURL URLWithString:item.productLogo] placeholderImage:ph];
    } else {
        self.logoView.image = ph;
    }
    UIImage *check = [UIImage imageNamed:item.selected ? @"read_icon" : @"and_icon"];
    [self.checkButton setImage:[check imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];

    self.amountLabel.text = item.displayLoanAmount;
    self.arrivalValueLabel.text = item.displayArrivalAmount;
    [self refreshTermRowWithItem:item];

    NSInteger count = MAX(item.amountStepCount, 1);
    if ((NSInteger)self.stepButtons.count != count) {
        [self rebuildStepButtons:count];
    } else {
        self.stepCount = count;
    }
    self.selectedStepIndex = MIN(MAX(item.selectedAmountIndex, 0), count - 1);
    [self refreshStepSelection];

    BOOL showRange = count > 1;
    self.minAmountLabel.hidden = !showRange;
    self.maxAmountLabel.hidden = !showRange;
    if (showRange) {
        self.minAmountLabel.text = [HQITAmountFormatter formatPlainAmount:@([item loanAmountAtIndex:0]) prefixCurrency:YES];
        self.maxAmountLabel.text = item.displayMaxLoanAmount;
        [self.minAmountLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.greaterThanOrEqualTo(self.amountBox).offset(21);
            make.top.greaterThanOrEqualTo(self.amountLabel.mas_bottom);
            make.left.equalTo(self.amountBox).offset(7);
            make.height.mas_equalTo(14);
        }];
        [self.trackContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.minAmountLabel.mas_bottom);
            make.top.greaterThanOrEqualTo(self.amountLabel.mas_bottom).offset(10);
            make.left.equalTo(self.amountBox).offset(2);
            make.right.equalTo(self.amountBox).offset(-2);
            make.height.mas_equalTo(kHQITAmountNodeSize);
        }];
    } else {
        self.minAmountLabel.text = @"";
        self.maxAmountLabel.text = @"";
        [self.minAmountLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.amountLabel.mas_bottom);
            make.left.equalTo(self.amountBox).offset(7);
            make.height.mas_equalTo(0);
        }];
        [self.trackContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.amountLabel.mas_bottom).offset(10);
            make.left.equalTo(self.amountBox).offset(2);
            make.right.equalTo(self.amountBox).offset(-2);
            make.height.mas_equalTo(kHQITAmountNodeSize);
        }];
    }
    [self.contentView setNeedsLayout];
}

- (void)refreshTermRowWithItem:(HQITAccurateRecommendProductItem *)item {
    BOOL multi = item.isMultiTerm;
    self.termTitleLabel.text = item.termRowTitle;
    self.termValueLabel.text = item.currentTermDisplay;
    self.termValueLabel.textColor = [self color102B4B];
    self.termValueLabel.font = [HQITFontHelper regularFontOfSize:14];
    self.termChevron.hidden = !multi;
    self.termHitButton.hidden = !multi;
    [self.termValueLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.termRow);
        if (multi) {
            make.right.equalTo(self.termChevron.mas_left).offset(-4);
        } else {
            make.right.equalTo(self.termRow);
        }
        make.left.greaterThanOrEqualTo(self.termTitleLabel.mas_right).offset(8);
    }];
}

- (void)onCheck {
    if (self.onToggleSelect) self.onToggleSelect();
}

- (void)onDetails {
    if (self.onLoanDetails) self.onLoanDetails();
}

- (void)onTermTap {
    if (self.onTermSelect) self.onTermSelect();
}

- (void)onStepTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= self.stepCount) return;
    if (idx == self.selectedStepIndex) return;
    self.selectedStepIndex = idx;
    [self refreshStepSelection];
    if (self.onAmountStepChanged) self.onAmountStepChanged(idx);
    HQITAccurateRecommendProductItem *item = self.boundItem;
    if (item) {
        self.amountLabel.text = item.displayLoanAmount;
        self.arrivalValueLabel.text = item.displayArrivalAmount;
        [self refreshTermRowWithItem:item];
    }
}

@end
