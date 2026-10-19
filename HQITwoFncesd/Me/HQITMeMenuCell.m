

#import "HQITMeMenuCell.h"
#import "HQITFontHelper.h"
#import <Masonry/Masonry.h>

@interface HQITMeMenuCell ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *arrowView;
@end

@implementation HQITMeMenuCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor whiteColor];
        self.contentView.layer.cornerRadius = 14;
        self.contentView.clipsToBounds = YES;

        self.iconView = [[UIImageView alloc] init];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.iconView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.font = [HQITFontHelper mediumFontOfSize:12];
        self.titleLabel.textColor = [UIColor colorWithRed:0x10/255.0 green:0x2B/255.0 blue:0x4B/255.0 alpha:1];
        self.titleLabel.numberOfLines = 2;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        self.titleLabel.minimumScaleFactor = 0.75;
        [self.contentView addSubview:self.titleLabel];

        self.arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"into_icon"]];
        self.arrowView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.arrowView];

        [self.iconView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView).offset(14);
            make.centerY.equalTo(self.contentView);
            make.width.height.mas_equalTo(32);
        }];
        [self.arrowView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.contentView).offset(-14);
            make.centerY.equalTo(self.contentView);
            make.width.height.mas_equalTo(12);
        }];
        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.iconView.mas_right).offset(10);
            make.right.equalTo(self.arrowView.mas_left).offset(-8);
            make.centerY.equalTo(self.contentView);
        }];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName {
    self.titleLabel.text = title;
    self.iconView.image = [UIImage imageNamed:iconName];
}

@end
