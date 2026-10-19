

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITKYCImageHelper : NSObject

/// Normalize EXIF to .up, compress JPEG ≤600KB, return Base64 (no prefix).
+ (nullable NSString *)jpegBase64Under600KBFromImage:(UIImage *)image;

/// Compress JPEG ≤600KB for multipart upload.
+ (nullable NSData *)jpegDataUnder600KBFromImage:(UIImage *)image;

/// Liveness: normalize + horizontal mirror + compress.
+ (nullable NSString *)livenessBase64FromImage:(UIImage *)image;

+ (UIImage *)documentOrientedImageFromImage:(UIImage *)image;

/// ID document: oriented image + compress Base64.
+ (nullable NSString *)documentBase64FromImage:(UIImage *)image;

+ (UIImage *)normalizeOrientation:(UIImage *)image;
+ (UIImage *)mirrorHorizontally:(UIImage *)image;
+ (UIImage *)rotateLeft90:(UIImage *)image;

+ (nullable UIImage *)cropImage:(UIImage *)image
          aspectFillInViewBounds:(CGRect)viewBounds
                   cropRectInView:(CGRect)cropRectInView;

@end

NS_ASSUME_NONNULL_END
