

#import "HQITBuryRecorder.h"
#import "HQITNetworkClient.h"

@implementation HQITBuryRecorder

+ (NSString *)nullPlaceholder:(NSString *)value {
    return value.length > 0 ? value : @"NULL";
}

+ (void)recordEventCode:(NSInteger)eventCode
           eventContent:(NSString *)eventContent
                remark1:(NSString *)remark1
                remark2:(NSString *)remark2
                remark3:(NSString *)remark3 {
    NSDictionary *signedData = @{
        @"eventCode": @(eventCode),
        @"eventContent": [self nullPlaceholder:eventContent],
        @"remark1": [self nullPlaceholder:remark1],
        @"remark2": [self nullPlaceholder:remark2],
        @"remark3": [self nullPlaceholder:remark3],
    };
    [[HQITNetworkClient shared] requestWithEndpoint:@"/app/v3/bury/record"
                                         signedData:signedData
                                       unsignedData:nil
                                        showLoading:@NO
                                     showErrorToast:@NO
                                            success:^(HQITNetworkResponse *response) {
        NSLog(@"[HQITBury] ok code=%ld", (long)eventCode);
    } failure:^(NSError *error, NSString *message) {
        NSLog(@"[HQITBury] fail code=%ld msg=%@", (long)eventCode, message);
    }];
}

+ (void)recordCameraPermissionGranted:(BOOL)granted {
    [self recordEventCode:(granted ? 11 : 12) eventContent:nil remark1:nil remark2:nil remark3:nil];
}

+ (void)recordLocationPermissionGranted:(BOOL)granted {
    [self recordEventCode:(granted ? 15 : 16) eventContent:nil remark1:nil remark2:nil remark3:nil];
}

+ (void)recordContactsPermissionGranted:(BOOL)granted {
    [self recordEventCode:(granted ? 19 : 20) eventContent:nil remark1:nil remark2:nil remark3:nil];
}

+ (void)recordContactsPermissionLimited {
    [self recordEventCode:198 eventContent:nil remark1:nil remark2:nil remark3:nil];
}

+ (void)recordIDFAPermissionGranted:(BOOL)granted {
    [self recordEventCode:(granted ? 17 : 18) eventContent:nil remark1:nil remark2:nil remark3:nil];
}

@end
