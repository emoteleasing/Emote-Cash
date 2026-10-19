

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HQITFontWeight) {
    HQITFontWeightLight = 0,
    HQITFontWeightRegular,
    HQITFontWeightMedium,
    HQITFontWeightBold,
};

/// Ubuntu third-party font helper (UIAppFonts). Falls back to system UIFont if unavailable.
@interface HQITFontHelper : NSObject

/// No-op retained for call-site compatibility. Fonts come from Info.plist UIAppFonts.
+ (void)registerBundledFontsIfNeeded;

+ (UIFont *)fontWithSize:(CGFloat)size;
+ (UIFont *)fontWithSize:(CGFloat)size weight:(HQITFontWeight)weight;
+ (UIFont *)fontWithSize:(CGFloat)size weight:(HQITFontWeight)weight italic:(BOOL)italic;

+ (UIFont *)lightFontOfSize:(CGFloat)size;
+ (UIFont *)regularFontOfSize:(CGFloat)size;
+ (UIFont *)mediumFontOfSize:(CGFloat)size;
+ (UIFont *)boldFontOfSize:(CGFloat)size;

/// Map UIFontWeight to Ubuntu (light/regular/medium/bold).
+ (UIFont *)fontWithSize:(CGFloat)size uiFontWeight:(UIFontWeight)weight;

@end

NS_ASSUME_NONNULL_END
