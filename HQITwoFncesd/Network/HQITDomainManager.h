
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITDomainReadyBlock)(BOOL success, NSString * _Nullable baseURL, NSError * _Nullable error);

@interface HQITDomainManager : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly) NSString *currentBaseURL;

- (void)ensureDomainReady:(HQITDomainReadyBlock)completion;

- (void)invalidateCurrentDomain;

@end

NS_ASSUME_NONNULL_END
