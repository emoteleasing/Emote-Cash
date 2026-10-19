

#import "HQITNetworkResponse.h"

@implementation HQITNetworkResponse

+ (instancetype)responseWithDictionary:(NSDictionary *)dict {
    HQITNetworkResponse *resp = [[HQITNetworkResponse alloc] init];
    NSDictionary *raw = [dict isKindOfClass:[NSDictionary class]] ? dict : @{};
    resp.rawDictionary = raw;

    id codeVal = raw[@"resultCode"];
    id msgVal = raw[@"resultMsg"];
    id dataVal = raw[@"data"];
    id tsVal = raw[@"timestamp"];

    resp.resultCode = [codeVal respondsToSelector:@selector(integerValue)] ? [codeVal integerValue] : 0;
    resp.resultMsg = [msgVal isKindOfClass:[NSString class]] ? msgVal : ([msgVal description] ?: @"");
    resp.data = (dataVal == [NSNull null]) ? nil : dataVal;
    resp.timestamp = [tsVal respondsToSelector:@selector(longLongValue)] ? [tsVal longLongValue] : 0;
    return resp;
}

- (BOOL)isSuccess {
    return self.resultCode == 200;
}

@end
