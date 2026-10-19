

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITMeViewModel : NSObject

@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *maskedMobile;
@property (nonatomic, assign, readonly) NSInteger userStatus;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);

- (void)reloadUserInfo;
- (void)clearCachedProfile;

@end

NS_ASSUME_NONNULL_END
