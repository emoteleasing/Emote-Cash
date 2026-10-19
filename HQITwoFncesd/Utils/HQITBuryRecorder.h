

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITBuryRecorder : NSObject

+ (void)recordEventCode:(NSInteger)eventCode
           eventContent:(nullable NSString *)eventContent
                remark1:(nullable NSString *)remark1
                remark2:(nullable NSString *)remark2
                remark3:(nullable NSString *)remark3;

+ (void)recordCameraPermissionGranted:(BOOL)granted;
+ (void)recordLocationPermissionGranted:(BOOL)granted;
+ (void)recordContactsPermissionGranted:(BOOL)granted;
+ (void)recordContactsPermissionLimited;
+ (void)recordIDFAPermissionGranted:(BOOL)granted;

@end

NS_ASSUME_NONNULL_END
