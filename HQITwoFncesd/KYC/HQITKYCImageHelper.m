
#import "HQITKYCImageHelper.h"

@implementation HQITKYCImageHelper

+ (UIImage *)normalizeOrientation:(UIImage *)image {
    if (!image || image.imageOrientation == UIImageOrientationUp) return image;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

+ (UIImage *)mirrorHorizontally:(UIImage *)image {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, image.size.width, 0);
    CGContextScaleCTM(ctx, -1.0, 1.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

+ (UIImage *)rotateLeft90:(UIImage *)image {
    if (!image) return nil;
    CGSize size = CGSizeMake(image.size.height, image.size.width);
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, 0, size.height);
    CGContextRotateCTM(ctx, -M_PI_2);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: image;
}

+ (NSData *)jpegDataUnder600KB:(UIImage *)image {
    if (!image) return nil;
    UIImage *img = [self normalizeOrientation:image];
    CGFloat quality = 0.85;
    NSData *data = UIImageJPEGRepresentation(img, quality);
    NSUInteger limit = 600 * 1024;
    while (data.length > limit && quality > 0.25) {
        quality -= 0.1;
        data = UIImageJPEGRepresentation(img, quality);
    }
    while (data.length > limit && img.size.width > 400) {
        CGSize ns = CGSizeMake(img.size.width * 0.75, img.size.height * 0.75);
        UIGraphicsBeginImageContextWithOptions(ns, YES, 1);
        [img drawInRect:CGRectMake(0, 0, ns.width, ns.height)];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        quality = 0.75;
        data = UIImageJPEGRepresentation(img, quality);
    }
    return data;
}

+ (NSString *)jpegBase64Under600KBFromImage:(UIImage *)image {
    NSData *data = [self jpegDataUnder600KBFromImage:image];
    if (!data.length) return nil;
    return [data base64EncodedStringWithOptions:0];
}

+ (NSData *)jpegDataUnder600KBFromImage:(UIImage *)image {
    return [self jpegDataUnder600KB:image];
}

+ (NSString *)livenessBase64FromImage:(UIImage *)image {
    UIImage *norm = [self normalizeOrientation:image];
    UIImage *mirrored = [self mirrorHorizontally:norm];
    return [self jpegBase64Under600KBFromImage:mirrored];
}

+ (UIImage *)documentOrientedImageFromImage:(UIImage *)image {
    if (!image) return nil;
    UIImage *norm = [self normalizeOrientation:image];
    if (norm.size.height > norm.size.width) {
        norm = [self rotateLeft90:norm];
    }
    return norm;
}

+ (NSString *)documentBase64FromImage:(UIImage *)image {
    UIImage *oriented = [self documentOrientedImageFromImage:image];
    return [self jpegBase64Under600KBFromImage:oriented];
}

+ (UIImage *)cropImage:(UIImage *)image
 aspectFillInViewBounds:(CGRect)viewBounds
          cropRectInView:(CGRect)cropRectInView {
    if (!image || image.size.width < 1 || image.size.height < 1) return nil;
    if (viewBounds.size.width < 1 || viewBounds.size.height < 1) return image;

    UIImage *src = [self normalizeOrientation:image];
    CGFloat imgW = src.size.width;
    CGFloat imgH = src.size.height;
    CGFloat viewW = viewBounds.size.width;
    CGFloat viewH = viewBounds.size.height;

    CGFloat scale = MAX(viewW / imgW, viewH / imgH);
    CGFloat displayW = imgW * scale;
    CGFloat displayH = imgH * scale;
    CGFloat offsetX = (viewW - displayW) * 0.5;
    CGFloat offsetY = (viewH - displayH) * 0.5;

    CGRect cropInView = CGRectIntersection(cropRectInView, viewBounds);
    if (CGRectIsEmpty(cropInView)) return src;

    CGFloat x = (CGRectGetMinX(cropInView) - offsetX) / scale;
    CGFloat y = (CGRectGetMinY(cropInView) - offsetY) / scale;
    CGFloat w = CGRectGetWidth(cropInView) / scale;
    CGFloat h = CGRectGetHeight(cropInView) / scale;

    CGRect pixelRect = CGRectMake(x * src.scale, y * src.scale, w * src.scale, h * src.scale);
    CGRect imageBounds = CGRectMake(0, 0, imgW * src.scale, imgH * src.scale);
    pixelRect = CGRectIntersection(pixelRect, imageBounds);
    if (CGRectIsEmpty(pixelRect) || pixelRect.size.width < 1 || pixelRect.size.height < 1) {
        return src;
    }

    CGImageRef cg = CGImageCreateWithImageInRect(src.CGImage, pixelRect);
    if (!cg) return src;
    UIImage *cropped = [UIImage imageWithCGImage:cg scale:src.scale orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return cropped ?: src;
}

@end
