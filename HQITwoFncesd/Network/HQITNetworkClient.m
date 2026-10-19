
#import "HQITNetworkClient.h"
#import "HQITNetworkConstants.h"
#import "HQITSigningHelper.h"
#import "HQITDomainManager.h"
#import "HQITSessionManager.h"
#import "HQITHUDHelper.h"
#import "HQITAppShell.h"
#import "HQITVersionUpdatePresenter.h"
#import <AFNetworking/AFHTTPSessionManager.h>

@interface HQITNetworkClient ()
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@end

@implementation HQITNetworkClient

+ (instancetype)shared {
    static HQITNetworkClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HQITNetworkClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionManager = [AFHTTPSessionManager manager];
        _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
        _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:
                                                                     @"application/json",
                                                                     @"text/json",
                                                                     @"text/javascript",
                                                                     @"text/plain",
                                                                     @"text/html",
                                                                     nil];
        _sessionManager.requestSerializer.timeoutInterval = 30;
        // UA：{appId}/{version}(Apple;Mobile;{model};iOS {systemVersion};)
        NSString *ua = HQITClientUserAgentString();
        [_sessionManager.requestSerializer setValue:ua forHTTPHeaderField:@"User-Agent"];
        NSLog(@"%@ User-Agent=%@", HQITLogTag, ua);
    }
    return self;
}

- (NSString *)clientVersion {
    NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return ver.length > 0 ? ver : @"1.0.0";
}

- (BOOL)isPublicParamOnlyEndpoint:(NSString *)endpoint {
    return [HQITPublicParamOnlyEndpoints() containsObject:endpoint];
}

- (BOOL)shouldShowLoadingForEndpoint:(NSString *)endpoint override:(NSNumber *)override {
    if (override) return override.boolValue;
    return ![HQITNoLoadingEndpoints() containsObject:endpoint];
}

- (BOOL)shouldShowErrorToastForEndpoint:(NSString *)endpoint
                                   code:(NSInteger)code
                               override:(NSNumber *)override {
    if (override) return override.boolValue;
    if ([HQITNoErrorToastEndpoints() containsObject:endpoint]) {
        return NO;
    }
    if ([HQITNoErrorToastCodes() containsObject:@(code)]) {
        return NO;
    }
    if ([endpoint isEqualToString:@"/app/v3/product/termV3"] &&
        [HQITTermV3NoToastCodes() containsObject:@(code)]) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)buildPOSTRequestBodyWithSignedData:(NSDictionary *)signedData
                                        unsignedData:(NSDictionary *)unsignedData
                                            endpoint:(NSString *)endpoint {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    if ([signedData isKindOfClass:[NSDictionary class]]) {
        [data addEntriesFromDictionary:signedData];
    }
    if ([unsignedData isKindOfClass:[NSDictionary class]]) {
        [data addEntriesFromDictionary:unsignedData];
    }

    HQITSessionManager *session = [HQITSessionManager shared];
    NSString *nonce = [HQITSigningHelper generateNonce];
    NSString *deviceId = session.deviceId;
    NSString *clientTime = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];

    // Business signed values: only keys from signedData, values from merged data
    NSMutableArray<NSString *> *businessValues = [NSMutableArray array];
    BOOL publicOnly = [self isPublicParamOnlyEndpoint:endpoint];
    if (!publicOnly && [signedData isKindOfClass:[NSDictionary class]] && signedData.count > 0) {
        NSArray *sortedKeys = [signedData.allKeys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *key in sortedKeys) {
            id value = data[key];
            [businessValues addObject:[HQITSigningHelper signValueString:value]];
        }
    }

    NSArray<NSString *> *publicValues = @[
        [HQITSigningHelper signValueString:HQITAppId],
        [HQITSigningHelper signValueString:deviceId],
        [HQITSigningHelper signValueString:HQITChannel],
        [HQITSigningHelper signValueString:nonce],
        [HQITSigningHelper signValueString:HQITAPIVersion],
        [HQITSigningHelper signValueString:clientTime],
        [HQITSigningHelper signValueString:HQITOSValue],
    ];

    NSString *sign = [HQITSigningHelper signWithBusinessValues:businessValues publicValues:publicValues];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"userId"] = session.userId ?: @"";
    body[@"token"] = session.token ?: @"";
    body[@"appId"] = HQITAppId;
    body[@"deviceId"] = deviceId;
    body[@"os"] = HQITOSValue;
    body[@"channel"] = HQITChannel;
    body[@"clientLanguage"] = HQITClientLanguage;
    body[@"clientVersion"] = [self clientVersion];
    body[@"clientTime"] = @([clientTime longLongValue]);
    body[@"version"] = HQITAPIVersion;
    body[@"nonce"] = nonce;
    body[@"sign"] = sign;
    body[@"data"] = data.count > 0 ? data : @{};
    return body;
}

- (void)requestWithEndpoint:(NSString *)endpoint
                 signedData:(NSDictionary *)signedData
               unsignedData:(NSDictionary *)unsignedData
                    success:(HQITNetworkSuccessBlock)success
                    failure:(HQITNetworkFailureBlock)failure {
    [self requestWithEndpoint:endpoint
                   signedData:signedData
                 unsignedData:unsignedData
                  showLoading:nil
               showErrorToast:nil
                      success:success
                      failure:failure];
}

- (void)requestWithEndpoint:(NSString *)endpoint
                 signedData:(NSDictionary *)signedData
               unsignedData:(NSDictionary *)unsignedData
                showLoading:(NSNumber *)showLoading
             showErrorToast:(NSNumber *)showErrorToast
                    success:(HQITNetworkSuccessBlock)success
                    failure:(HQITNetworkFailureBlock)failure {
    BOOL loading = [self shouldShowLoadingForEndpoint:endpoint override:showLoading];
    if (loading) {
        [HQITHUDHelper showLoading];
    }

    [[HQITDomainManager shared] ensureDomainReady:^(BOOL ok, NSString *baseURL, NSError *error) {
        if (!ok || baseURL.length == 0) {
            if (loading) [HQITHUDHelper hideLoading];
            NSString *msg = HQITSystemBusyMessage;
            if ([self shouldShowErrorToastForEndpoint:endpoint code:0 override:showErrorToast]) {
                [HQITHUDHelper showToast:msg];
            }
            if (failure) {
                failure(error ?: [NSError errorWithDomain:@"HQITNetwork" code:-100 userInfo:@{NSLocalizedDescriptionKey: msg}], msg);
            }
            return;
        }
        [self performRequestEndpoint:endpoint
                             baseURL:baseURL
                          signedData:signedData
                        unsignedData:unsignedData
                         showLoading:loading
                      showErrorToast:showErrorToast
                         cancelledOut:NULL
                             success:success
                             failure:failure];
    }];
}

- (void (^)(void))requestCancellableWithEndpoint:(NSString *)endpoint
                                      signedData:(NSDictionary *)signedData
                                    unsignedData:(NSDictionary *)unsignedData
                                     showLoading:(NSNumber *)showLoading
                                  showErrorToast:(NSNumber *)showErrorToast
                                         success:(HQITNetworkSuccessBlock)success
                                         failure:(HQITNetworkFailureBlock)failure {
    __block BOOL cancelled = NO;
    __block NSURLSessionDataTask *task = nil;
    BOOL loading = [self shouldShowLoadingForEndpoint:endpoint override:showLoading];
    if (loading) {
        [HQITHUDHelper showLoading];
    }

    [[HQITDomainManager shared] ensureDomainReady:^(BOOL ok, NSString *baseURL, NSError *error) {
        if (cancelled) {
            if (loading) [HQITHUDHelper hideLoading];
            return;
        }
        if (!ok || baseURL.length == 0) {
            if (loading) [HQITHUDHelper hideLoading];
            NSString *msg = HQITSystemBusyMessage;
            if ([self shouldShowErrorToastForEndpoint:endpoint code:0 override:showErrorToast]) {
                [HQITHUDHelper showToast:msg];
            }
            if (failure) {
                failure(error ?: [NSError errorWithDomain:@"HQITNetwork" code:-100 userInfo:@{NSLocalizedDescriptionKey: msg}], msg);
            }
            return;
        }
        task = [self performRequestEndpoint:endpoint
                                    baseURL:baseURL
                                 signedData:signedData
                               unsignedData:unsignedData
                                showLoading:loading
                             showErrorToast:showErrorToast
                                cancelledOut:&cancelled
                                    success:success
                                    failure:failure];
    }];

    return ^{
        cancelled = YES;
        [task cancel];
    };
}

- (nullable NSURLSessionDataTask *)performRequestEndpoint:(NSString *)endpoint
                                                  baseURL:(NSString *)baseURL
                                               signedData:(NSDictionary *)signedData
                                             unsignedData:(NSDictionary *)unsignedData
                                              showLoading:(BOOL)loading
                                           showErrorToast:(NSNumber *)showErrorToast
                                              cancelledOut:(BOOL * _Nullable)cancelledOut
                                                  success:(HQITNetworkSuccessBlock)success
                                                  failure:(HQITNetworkFailureBlock)failure {
    NSDictionary *body = [self buildPOSTRequestBodyWithSignedData:signedData unsignedData:unsignedData endpoint:endpoint];
    NSString *url = [baseURL stringByAppendingString:endpoint];
    NSLog(@"%@ POST %@ params=%@", HQITLogTag, endpoint, [self logFriendlyJSONObject:body]);

    __weak typeof(self) weakSelf = self;
    return [self.sessionManager POST:url parameters:body headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        __strong typeof(weakSelf) self = weakSelf;
        if (cancelledOut && *cancelledOut) return;
        if (loading) [HQITHUDHelper hideLoading];

        NSDictionary *dict = [responseObject isKindOfClass:[NSDictionary class]] ? responseObject : @{};
        NSLog(@"%@ RESP %@ %@", HQITLogTag, endpoint, dict);
        HQITNetworkResponse *resp = [HQITNetworkResponse responseWithDictionary:dict];

        if (resp.isSuccess) {
            if (success) success(resp);
            return;
        }

        // Token invalid / please sign in again → guest home + delayed login modal
        if (resp.resultCode == 2000001 || resp.resultCode == 2000002) {
            [[HQITAppShell shared] returnToGuestHomeThenShowLogin];
            NSString *msg = HQITSanitizeNetworkErrorMessage(resp.resultMsg.length > 0 ? resp.resultMsg : nil);
            NSError *bizError = [NSError errorWithDomain:@"HQITNetwork"
                                                    code:resp.resultCode
                                                userInfo:@{NSLocalizedDescriptionKey: msg}];
            if (failure) failure(bizError, msg);
            return;
        }

        if (resp.resultCode == 2009006) {
            [[HQITVersionUpdatePresenter shared] handleForceUpdateBusinessError];
            NSString *msg = HQITSanitizeNetworkErrorMessage(resp.resultMsg.length > 0 ? resp.resultMsg : @"Please upgrade to continue");
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = msg;
            if (resp.data) userInfo[@"HQITResponseData"] = resp.data;
            NSError *bizError = [NSError errorWithDomain:@"HQITNetwork"
                                                    code:resp.resultCode
                                                userInfo:userInfo];
            if (failure) failure(bizError, msg);
            return;
        }

        NSString *msg = HQITSanitizeNetworkErrorMessage(resp.resultMsg.length > 0 ? resp.resultMsg : nil);
        BOOL toast = [self shouldShowErrorToastForEndpoint:endpoint code:resp.resultCode override:showErrorToast];
        // termV3 special codes: never toast even if endpoint list changes
        if ([endpoint isEqualToString:@"/app/v3/product/termV3"] &&
            [HQITTermV3NoToastCodes() containsObject:@(resp.resultCode)]) {
            toast = NO;
        }
        if (toast) {
            [HQITHUDHelper showToast:msg];
        }

        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[NSLocalizedDescriptionKey] = msg;
        if (resp.data) userInfo[@"HQITResponseData"] = resp.data;
        NSError *bizError = [NSError errorWithDomain:@"HQITNetwork"
                                                code:resp.resultCode
                                            userInfo:userInfo];
        if (failure) failure(bizError, msg);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (cancelledOut && *cancelledOut) return;
        NSLog(@"%@ FAIL %@ %@", HQITLogTag, endpoint, error);
        if (loading) [HQITHUDHelper hideLoading];
        NSString *msg = HQITSystemBusyMessage;
        if ([self shouldShowErrorToastForEndpoint:endpoint code:0 override:showErrorToast]) {
            [HQITHUDHelper showToast:msg];
        }
        if (failure) failure(error, msg);
    }];
}

#pragma mark - Image Upload

- (nullable NSString *)hqit_stringFrom:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return s.length ? s : nil;
    }
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value stringValue];
    return nil;
}

- (nullable NSString *)hqit_parseUploadURLFrom:(id)obj {
    if (![obj isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *dict = (NSDictionary *)obj;
    for (NSString *key in @[@"src", @"url", @"imgUrl", @"imageUrl", @"link", @"href", @"fileUrl", @"path"]) {
        NSString *s = [self hqit_stringFrom:dict[key]];
        if (s.length) return s;
    }
    for (NSString *nest in @[@"data", @"result", @"file"]) {
        NSString *nested = [self hqit_parseUploadURLFrom:dict[nest]];
        if (nested.length) return nested;
    }
    return nil;
}

- (void)uploadJPEGData:(NSData *)jpegData
               success:(void (^)(NSString *imageURL))success
               failure:(HQITNetworkFailureBlock)failure {
    if (jpegData.length == 0) {
        if (failure) failure([NSError errorWithDomain:@"HQITNetwork" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to process image."}], @"Failed to process image.");
        return;
    }
    [HQITHUDHelper showLoading];
    NSString *endpoint = @"/app/v3/sys/upload";
    [[HQITDomainManager shared] ensureDomainReady:^(BOOL ok, NSString *baseURL, NSError *error) {
        if (!ok || baseURL.length == 0) {
            [HQITHUDHelper hideLoading];
            NSString *msg = HQITSystemBusyMessage;
            [HQITHUDHelper showToast:msg];
            if (failure) failure(error ?: [NSError errorWithDomain:@"HQITNetwork" code:-100 userInfo:@{NSLocalizedDescriptionKey: msg}], msg);
            return;
        }
        [self performUploadJPEG:jpegData endpoint:endpoint baseURL:baseURL success:success failure:failure];
    }];
}

- (void)performUploadJPEG:(NSData *)jpegData
                 endpoint:(NSString *)endpoint
                  baseURL:(NSString *)baseURL
                  success:(void (^)(NSString *imageURL))success
                  failure:(HQITNetworkFailureBlock)failure {
    NSDictionary *body = [self buildPOSTRequestBodyWithSignedData:@{} unsignedData:@{} endpoint:endpoint];
    NSString *url = [baseURL stringByAppendingString:endpoint];
    NSLog(@"%@ UPLOAD %@", HQITLogTag, endpoint);

    __weak typeof(self) weakSelf = self;
    [self.sessionManager POST:url parameters:nil headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        for (NSString *key in body) {
            id value = body[key];
            if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
                NSData *json = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
                if (json) {
                    [formData appendPartWithFormData:json name:key];
                }
            } else {
                NSString *str = [NSString stringWithFormat:@"%@", value ?: @""];
                NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
                if (data) [formData appendPartWithFormData:data name:key];
            }
        }
        [formData appendPartWithFileData:jpegData
                                    name:@"file"
                                fileName:@"feedback.jpg"
                                mimeType:@"image/jpeg"];
    } progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        __strong typeof(weakSelf) self = weakSelf;
        [HQITHUDHelper hideLoading];
        NSDictionary *dict = [responseObject isKindOfClass:[NSDictionary class]] ? responseObject : @{};
        NSLog(@"%@ UPLOAD RESP %@", HQITLogTag, dict);
        HQITNetworkResponse *resp = [HQITNetworkResponse responseWithDictionary:dict];
        if (!resp.isSuccess) {
            NSString *msg = HQITSanitizeNetworkErrorMessage(resp.resultMsg.length ? resp.resultMsg : nil);
            [HQITHUDHelper showToast:msg];
            if (failure) {
                failure([NSError errorWithDomain:@"HQITNetwork" code:resp.resultCode userInfo:@{NSLocalizedDescriptionKey: msg}], msg);
            }
            return;
        }
        NSString *imageURL = [self hqit_parseUploadURLFrom:resp.data] ?: [self hqit_parseUploadURLFrom:dict];
        if (imageURL.length == 0 && [resp.data isKindOfClass:[NSString class]]) {
            imageURL = (NSString *)resp.data;
        }
        if (imageURL.length == 0) {
            NSString *msg = HQITSystemBusyMessage;
            [HQITHUDHelper showToast:msg];
            if (failure) failure([NSError errorWithDomain:@"HQITNetwork" code:-2 userInfo:@{NSLocalizedDescriptionKey: msg}], msg);
            return;
        }
        if (success) success(imageURL);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [HQITHUDHelper hideLoading];
        NSString *msg = HQITSystemBusyMessage;
        [HQITHUDHelper showToast:msg];
        if (failure) failure(error, msg);
    }];
}

/// Truncate long strings (e.g. Base64) so console stays readable.
- (id)logFriendlyJSONObject:(id)obj {
    if (obj == nil || obj == [NSNull null]) return @{};
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)obj;
        if (s.length > 256) {
            return [NSString stringWithFormat:@"%@…(%lu chars)", [s substringToIndex:64], (unsigned long)s.length];
        }
        return s;
    }
    if ([obj isKindOfClass:[NSNumber class]] || [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:MIN(((NSArray *)obj).count, 50)];
        NSInteger i = 0;
        for (id item in (NSArray *)obj) {
            if (i++ >= 50) {
                [out addObject:[NSString stringWithFormat:@"…(+%lu more)", (unsigned long)(((NSArray *)obj).count - 50)]];
                break;
            }
            [out addObject:[self logFriendlyJSONObject:item] ?: [NSNull null]];
        }
        return out;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            out[key] = [self logFriendlyJSONObject:value] ?: [NSNull null];
        }];
        return out;
    }
    return [NSString stringWithFormat:@"%@", obj];
}

@end
