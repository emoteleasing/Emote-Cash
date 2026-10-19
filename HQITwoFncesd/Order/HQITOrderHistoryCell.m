

#import "HQITOrderHistoryCell.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>

@interface HQITOrderHistoryCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UIView *statusWrap;
@property (nonatomic, strong) UILabel *statusBadge;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic, strong) UILabel *leftTitleLab;
@property (nonatomic, strong) UILabel *leftValueLab;
@property (nonatomic, strong) UILabel *rightTitleLab;
@property (nonatomic, strong) UILabel *rightValueLab;
@end

@implementation HQITOrderHistoryCell

+ (NSString *)reuseId { return @"HQITOrderHistoryCell"; }

+ (CGFloat)itemHeight { return 132; }
+ (CGFloat)itemSpacing { return 10; }

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

- (NSAttributedString *)hqit_attr:(NSString *)text
                            font:(UIFont *)font
                           color:(UIColor *)color
                      lineHeight:(CGFloat)lineHeight
                       alignment:(NSTextAlignment)alignment {
    if (text.length == 0) text = @"";
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.minimumLineHeight = lineHeight;
    ps.maximumLineHeight = lineHeight;
    ps.alignment = alignment;
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: ps,
    }];
}

- (void)buildUI {
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor whiteColor];
    self.card.layer.cornerRadius = 16;
    self.card.clipsToBounds = YES;
    [self.contentView addSubview:self.card];
    [self.card mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView);
        make.left.equalTo(self.contentView).offset(16);
        make.right.equalTo(self.contentView).offset(-16);
        make.height.mas_equalTo([HQITOrderHistoryCell itemHeight]);
        make.bottom.equalTo(self.contentView).offset(-[HQITOrderHistoryCell itemSpacing]);
    }];

    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.numberOfLines = 1;
    [self.card addSubview:self.nameLabel];

    self.amountLabel = [[UILabel alloc] init];
    self.amountLabel.numberOfLines = 1;
    [self.card addSubview:self.amountLabel];

    self.statusWrap = [[UIView alloc] init];
    self.statusWrap.layer.cornerRadius = 6;
    self.statusWrap.clipsToBounds = YES;
    [self.card addSubview:self.statusWrap];

    self.statusBadge = [[UILabel alloc] init];
    self.statusBadge.font = [HQITFontHelper mediumFontOfSize:12];
    self.statusBadge.textAlignment = NSTextAlignmentCenter;
    [self.statusWrap addSubview:self.statusBadge];

    self.divider = [[UIView alloc] init];
    self.divider.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF5/255.0 alpha:1];
    [self.card addSubview:self.divider];

    self.leftTitleLab = [[UILabel alloc] init];
    self.leftTitleLab.numberOfLines = 1;
    [self.card addSubview:self.leftTitleLab];

    self.leftValueLab = [[UILabel alloc] init];
    self.leftValueLab.numberOfLines = 1;
    [self.card addSubview:self.leftValueLab];

    self.rightTitleLab = [[UILabel alloc] init];
    self.rightTitleLab.numberOfLines = 1;
    [self.card addSubview:self.rightTitleLab];

    self.rightValueLab = [[UILabel alloc] init];
    self.rightValueLab.numberOfLines = 1;
    [self.card addSubview:self.rightValueLab];

    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.card).offset(14);
        make.left.equalTo(self.card).offset(14);
        make.right.lessThanOrEqualTo(self.statusWrap.mas_left).offset(-10);
        make.height.mas_equalTo(21);
    }];
    [self.amountLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.nameLabel.mas_bottom);
        make.left.equalTo(self.card).offset(14);
        make.right.lessThanOrEqualTo(self.statusWrap.mas_left).offset(-10);
        make.height.mas_equalTo(21);
    }];
    [self.statusWrap mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.card).offset(22);
        make.right.equalTo(self.card).offset(-14);
        make.height.mas_equalTo(26);
    }];
    [self.statusBadge mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(self.statusWrap);
        make.left.equalTo(self.statusWrap).offset(10);
        make.right.equalTo(self.statusWrap).offset(-10);
    }];
    [self.divider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.card).offset(66);
        make.left.right.equalTo(self.card);
        make.height.mas_equalTo(1);
    }];
    [self.leftTitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.divider.mas_bottom).offset(10);
        make.left.equalTo(self.card).offset(14);
        make.right.equalTo(self.card.mas_centerX).offset(-7);
        make.height.mas_equalTo(17);
    }];
    [self.leftValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.leftTitleLab.mas_bottom).offset(2);
        make.left.equalTo(self.card).offset(14);
        make.right.equalTo(self.leftTitleLab);
    }];
    [self.rightTitleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.divider.mas_bottom).offset(10);
        make.left.equalTo(self.card.mas_centerX).offset(7);
        make.right.equalTo(self.card).offset(-14);
        make.height.mas_equalTo(17);
    }];
    [self.rightValueLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.rightTitleLab.mas_bottom).offset(2);
        make.left.equalTo(self.rightTitleLab);
        make.right.equalTo(self.card).offset(-14);
    }];
}

- (void)applyItem:(HQITOrderHistoryItem *)item {
    UIColor *nameColor = [UIColor colorWithRed:0x34/255.0 green:0x34/255.0 blue:0x36/255.0 alpha:1];
    UIColor *amountColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
    UIColor *dateTitleColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1];

    self.nameLabel.attributedText = [self hqit_attr:item.productName.length ? item.productName : @"—"
                                               font:[HQITFontHelper boldFontOfSize:14]
                                              color:nameColor
                                         lineHeight:21
                                          alignment:NSTextAlignmentLeft];
    self.amountLabel.attributedText = [self hqit_attr:item.amountText.length ? item.amountText : @"₹0"
                                                 font:[HQITFontHelper boldFontOfSize:14]
                                                color:amountColor
                                           lineHeight:21
                                            alignment:NSTextAlignmentLeft];

    self.statusBadge.text = item.statusTitle ?: @"";
    self.statusBadge.textColor = item.statusTextColor;
    self.statusWrap.backgroundColor = item.statusBgColor;

    self.leftTitleLab.attributedText = [self hqit_attr:item.leftDateLabel ?: @""
                                                  font:[HQITFontHelper regularFontOfSize:11]
                                                 color:dateTitleColor
                                            lineHeight:17
                                             alignment:NSTextAlignmentLeft];
    self.leftValueLab.attributedText = [self hqit_attr:item.leftDateValue.length ? item.leftDateValue : @"—"
                                                  font:[HQITFontHelper mediumFontOfSize:14]
                                                 color:nameColor
                                            lineHeight:21
                                             alignment:NSTextAlignmentLeft];
    self.rightTitleLab.attributedText = [self hqit_attr:item.rightDateLabel ?: @""
                                                   font:[HQITFontHelper regularFontOfSize:11]
                                                  color:dateTitleColor
                                             lineHeight:17
                                              alignment:NSTextAlignmentRight];
    self.rightValueLab.attributedText = [self hqit_attr:item.rightDateValue.length ? item.rightDateValue : @"-"
                                                   font:[HQITFontHelper mediumFontOfSize:14]
                                                  color:nameColor
                                             lineHeight:21
                                              alignment:NSTextAlignmentRight];
}

@end
