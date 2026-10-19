
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITNetworkResponse : NSObject

@property (nonatomic, assign) NSInteger resultCode;
@property (nonatomic, copy) NSString *resultMsg;
@property (nonatomic, strong, nullable) id data;
@property (nonatomic, assign) long long timestamp;
@property (nonatomic, strong, nullable) NSDictionary *rawDictionary;

@property (nonatomic, readonly) BOOL isSuccess;

+ (instancetype)responseWithDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
