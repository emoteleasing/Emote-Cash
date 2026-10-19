

#import "HQITAccurateRecommendSuccessOrderCell.h"
#import "HQITAccurateRecommendSuccessViewModel.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>
#import <SDWebImage/SDWebImage.h>

@interface HQITAccurateRecommendSuccessOrderCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIStackView *rowsStack;
@property (nonatomic, strong) MASConstraint *badgeWidthConstraint;
@end

@implementation HQITAccurateRecommendSuccessOrderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        [self buildUI];
    }
    return self;
}

- (UIColor *)navy { return [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1]; }
- (UIColor *)gray { return [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1]; }

- (void)buildUI {
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor whiteColor];
    self.card.layer.cornerRadius = 16;
    self.card.clipsToBounds = YES;
    [self.contentView addSubview:self.card];
    [self.card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(6);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.bottom.equalTo(self.contentView).offset(-6);
    }];

    self.logoView = [[UIImageView alloc] init];
    self.logoView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoView.clipsToBounds = YES;
    self.logoView.layer.cornerRadius = 8;
    self.logoView.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF8/255.0 alpha:1];
    [self.card addSubview:self.logoView];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [HQITFontHelper boldFontOfSize:15];
    self.nameLabel.textColor = [self navy];
    [self.card addSubview:self.nameLabel];

    self.badgeLabel = [[UILabel alloc] init];
    self.badgeLabel.font = [HQITFontHelper mediumFontOfSize:11];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.layer.cornerRadius = 4;
    self.badgeLabel.clipsToBounds = YES;
    [self.card addSubview:self.badgeLabel];

    self.rowsStack = [[UIStackView alloc] init];
    self.rowsStack.axis = UILayoutConstraintAxisVertical;
    self.rowsStack.spacing = 0;
    [self.card addSubview:self.rowsStack];

    [self.logoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.card).offset(16);
        make.top.equalTo(self.card).offset(16);
        make.width.height.mas_equalTo(36);
    }];
    [self.badgeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.card).offset(-16);
        make.centerY.equalTo(self.logoView);
        make.height.mas_equalTo(22);
        self.badgeWidthConstraint = make.width.mas_equalTo(80);
    }];
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.logoView.mas_right).offset(10);
        make.centerY.equalTo(self.logoView);
        make.right.lessThanOrEqualTo(self.badgeLabel.mas_left).offset(-8);
    }];
    [self.rowsStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.logoView.mas_bottom).offset(8);
        make.left.equalTo(self.card).offset(16);
        make.right.equalTo(self.card).offset(-16);
        make.bottom.equalTo(self.card).offset(-8);
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onInfoTap = nil;
    [self.logoView sd_cancelCurrentImageLoad];
    self.logoView.image = nil;
    for (UIView *v in self.rowsStack.arrangedSubviews) {
        [self.rowsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
}

- (void)configureWithItem:(HQITAccurateRecommendSuccessOrderItem *)item {
    UIImage *ph = [UIImage imageNamed:@"samll_icon"] ?: [UIImage imageNamed:@"amount_icon"];
    if (item.productLogoURL.length) {
        [self.logoView sd_setImageWithURL:[NSURL URLWithString:item.productLogoURL] placeholderImage:ph];
    } else {
        self.logoView.image = ph;
    }
    self.nameLabel.text = item.productName.length ? item.productName : @"—";
    self.badgeLabel.text = item.statusTitle.length ? item.statusTitle : @"Under review";
    self.badgeLabel.textColor = item.statusTextColor ?: [UIColor colorWithRed:0x7B/255.0 green:0x1F/255.0 blue:0xA2/255.0 alpha:1];
    self.badgeLabel.backgroundColor = item.statusBgColor ?: [UIColor colorWithRed:0xF3/255.0 green:0xE5/255.0 blue:0xF5/255.0 alpha:1];
    CGFloat badgeW = [self.badgeLabel.text sizeWithAttributes:@{NSFontAttributeName: self.badgeLabel.font}].width + 16;
    [self.badgeWidthConstraint setOffset:MAX(badgeW, 80)];

    for (UIView *v in self.rowsStack.arrangedSubviews) {
        [self.rowsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    NSArray *rows = item.detailRows ?: @[];
    for (NSInteger i = 0; i < (NSInteger)rows.count; i++) {
        HQITAccurateRecommendSuccessDetailRow *r = rows[i];
        [self.rowsStack addArrangedSubview:[self rowTitle:r.title value:r.value infoKey:r.infoKey]];
        if (i < (NSInteger)rows.count - 1) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = [UIColor colorWithRed:0xF0/255.0 green:0xF0/255.0 blue:0xF0/255.0 alpha:1];
            [line mas_makeConstraints:^(MASConstraintMaker *make) {
                make.height.mas_equalTo(1.0 / UIScreen.mainScreen.scale);
            }];
            [self.rowsStack addArrangedSubview:line];
        }
    }
}

- (UIView *)rowTitle:(NSString *)title value:(NSString *)value infoKey:(NSString *)infoKey {
    UIView *wrap = [[UIView alloc] init];
    UILabel *t = [[UILabel alloc] init];
    t.text = title;
    t.font = [HQITFontHelper regularFontOfSize:13];
    t.textColor = [self gray];
    [wrap addSubview:t];
    UIButton *info = nil;
    if (infoKey.length) {
        info = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *img = [[UIImage systemImageNamed:@"info.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [info setImage:img forState:UIControlStateNormal];
        info.tintColor = [self gray];
        info.accessibilityIdentifier = infoKey;
        [info addTarget:self action:@selector(onInfo:) forControlEvents:UIControlEventTouchUpInside];
        [wrap addSubview:info];
    }
    UILabel *v = [[UILabel alloc] init];
    v.text = value;
    v.font = [HQITFontHelper boldFontOfSize:13];
    v.textColor = [self navy];
    v.textAlignment = NSTextAlignmentRight;
    [wrap addSubview:v];
    [t mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(wrap);
        make.top.equalTo(wrap).offset(14);
        make.bottom.equalTo(wrap).offset(-14);
    }];
    if (info) {
        [info mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(t.mas_right).offset(4);
            make.centerY.equalTo(t);
            make.width.height.mas_equalTo(14);
        }];
    }
    [v mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(wrap);
        make.centerY.equalTo(wrap);
        make.left.greaterThanOrEqualTo(info ? info.mas_right : t.mas_right).offset(8);
    }];
    return wrap;
}

- (void)onInfo:(UIButton *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key.length && self.onInfoTap) self.onInfoTap(key);
}

@end
