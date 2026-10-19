

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITDeviceInfoCollector : NSObject

+ (NSDictionary<NSString *, NSString *> *)collectDeviceInfoIncludeWiFiDetails:(BOOL)includeWiFiDetails;

+ (NSDictionary<NSString *, NSString *> *)collectDeviceInfoWithOrderId:(nullable NSString *)orderId
                                                 includeWiFiDetails:(BOOL)includeWiFiDetails;

+ (void)collectDeviceInfoForOrder:(NSString *)orderId
                       completion:(void (^)(NSDictionary<NSString *, NSString *> *info))completion;

+ (NSString *)deviceModelMachine;

+ (NSString *)deviceMarketingModelName;

@end

NS_ASSUME_NONNULL_END
