

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITSessionManager : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, nullable) NSString *userId;
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, assign) BOOL isRegister;
@property (nonatomic, copy, readonly) NSString *deviceId;

- (BOOL)isLoggedIn;
- (void)saveUserId:(nullable NSString *)userId token:(nullable NSString *)token;
- (void)saveUserId:(nullable NSString *)userId token:(nullable NSString *)token isRegister:(BOOL)isRegister;
- (void)clearSession;

@end

NS_ASSUME_NONNULL_END
