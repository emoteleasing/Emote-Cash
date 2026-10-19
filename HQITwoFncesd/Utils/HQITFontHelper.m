

#import "HQITFontHelper.h"

@implementation HQITFontHelper

+ (void)registerBundledFontsIfNeeded {
    // Fonts are registered via Info.plist UIAppFonts. Do not call CTFontManagerRegisterFontsForURL —
    // that duplicates registration and logs "file already registered" / Code=105.
}

+ (NSString *)postScriptNameForWeight:(HQITFontWeight)weight italic:(BOOL)italic {
    switch (weight) {
        case HQITFontWeightLight:
            return italic ? @"Ubuntu-LightItalic" : @"Ubuntu-Light";
        case HQITFontWeightMedium:
            return italic ? @"Ubuntu-MediumItalic" : @"Ubuntu-Medium";
        case HQITFontWeightBold:
            return italic ? @"Ubuntu-BoldItalic" : @"Ubuntu-Bold";
        case HQITFontWeightRegular:
        default:
            // Ubuntu-Regular.ttf PostScript name is "Ubuntu"
            return italic ? @"Ubuntu-Italic" : @"Ubuntu";
    }
}

+ (UIFont *)systemFallbackWithSize:(CGFloat)size weight:(HQITFontWeight)weight italic:(BOOL)italic {
    UIFontWeight w = UIFontWeightRegular;
    switch (weight) {
        case HQITFontWeightLight: w = UIFontWeightLight; break;
        case HQITFontWeightMedium: w = UIFontWeightMedium; break;
        case HQITFontWeightBold: w = UIFontWeightBold; break;
        default: w = UIFontWeightRegular; break;
    }
    UIFont *font = [UIFont systemFontOfSize:size weight:w];
    if (italic) {
        UIFontDescriptor *desc = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
        if (desc) {
            UIFont *italicFont = [UIFont fontWithDescriptor:desc size:size];
            if (italicFont) return italicFont;
        }
    }
    return font;
}

+ (UIFont *)fontWithSize:(CGFloat)size weight:(HQITFontWeight)weight italic:(BOOL)italic {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *primary = [self postScriptNameForWeight:weight italic:italic];
    if (primary.length) [candidates addObject:primary];
    if (weight == HQITFontWeightRegular && !italic) {
        [candidates addObject:@"Ubuntu-Regular"];
    }
    for (NSString *name in candidates) {
        UIFont *font = [UIFont fontWithName:name size:size];
        if (font) return font;
    }
    NSLog(@"[HQITFont] missing %@, fallback system", primary);
    return [self systemFallbackWithSize:size weight:weight italic:italic];
}

+ (UIFont *)fontWithSize:(CGFloat)size {
    return [self fontWithSize:size weight:HQITFontWeightRegular italic:NO];
}

+ (UIFont *)fontWithSize:(CGFloat)size weight:(HQITFontWeight)weight {
    return [self fontWithSize:size weight:weight italic:NO];
}

+ (UIFont *)lightFontOfSize:(CGFloat)size {
    return [self fontWithSize:size weight:HQITFontWeightLight];
}

+ (UIFont *)regularFontOfSize:(CGFloat)size {
    return [self fontWithSize:size weight:HQITFontWeightRegular];
}

+ (UIFont *)mediumFontOfSize:(CGFloat)size {
    return [self fontWithSize:size weight:HQITFontWeightMedium];
}

+ (UIFont *)boldFontOfSize:(CGFloat)size {
    return [self fontWithSize:size weight:HQITFontWeightBold];
}

+ (UIFont *)fontWithSize:(CGFloat)size uiFontWeight:(UIFontWeight)weight {
    HQITFontWeight mapped = HQITFontWeightRegular;
    if (weight >= UIFontWeightBold - 0.01) {
        mapped = HQITFontWeightBold;
    } else if (weight >= UIFontWeightMedium - 0.01) {
        mapped = HQITFontWeightMedium;
    } else if (weight <= UIFontWeightLight + 0.01) {
        mapped = HQITFontWeightLight;
    }
    return [self fontWithSize:size weight:mapped];
}

@end
