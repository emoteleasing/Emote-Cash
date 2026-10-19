

#import <Foundation/Foundation.h>
#import "HQITNetworkResponse.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HQITNetworkSuccessBlock)(HQITNetworkResponse *response);
typedef void (^HQITNetworkFailureBlock)(NSError *error, NSString *message);

@interface HQITNetworkClient : NSObject

+ (instancetype)shared;

/// Build POST body with method-2 sign. Merges signed+unsigned into data.
- (NSDictionary *)buildPOSTRequestBodyWithSignedData:(nullable NSDictionary *)signedData
                                        unsignedData:(nullable NSDictionary *)unsignedData
                                            endpoint:(NSString *)endpoint;

/**
 POST JSON request.
 @param showLoading Override; pass nil to use endpoint default rules.
 @param showErrorToast Override; pass nil to use endpoint default rules.
 */
- (void)requestWithEndpoint:(NSString *)endpoint
                 signedData:(nullable NSDictionary *)signedData
               unsignedData:(nullable NSDictionary *)unsignedData
                showLoading:(nullable NSNumber *)showLoading
             showErrorToast:(nullable NSNumber *)showErrorToast
                    success:(nullable HQITNetworkSuccessBlock)success
                    failure:(nullable HQITNetworkFailureBlock)failure;

- (void)requestWithEndpoint:(NSString *)endpoint
                 signedData:(nullable NSDictionary *)signedData
               unsignedData:(nullable NSDictionary *)unsignedData
                    success:(nullable HQITNetworkSuccessBlock)success
                    failure:(nullable HQITNetworkFailureBlock)failure;

- (void (^)(void))requestCancellableWithEndpoint:(NSString *)endpoint
                                      signedData:(nullable NSDictionary *)signedData
                                    unsignedData:(nullable NSDictionary *)unsignedData
                                     showLoading:(nullable NSNumber *)showLoading
                                  showErrorToast:(nullable NSNumber *)showErrorToast
                                         success:(nullable HQITNetworkSuccessBlock)success
                                         failure:(nullable HQITNetworkFailureBlock)failure;

- (void)uploadJPEGData:(NSData *)jpegData
               success:(nullable void (^)(NSString *imageURL))success
               failure:(nullable HQITNetworkFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
