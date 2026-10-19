

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HQITBankAccountItem : NSObject
@property (nonatomic, copy) NSString *recordId;
@property (nonatomic, copy) NSString *bankCode;
@property (nonatomic, copy) NSString *accountNo;
@property (nonatomic, copy) NSString *accountNoDisplay;
@property (nonatomic, copy) NSString *accountName;
@property (nonatomic, copy, nullable) NSString *creditCard;
@property (nonatomic, copy, nullable) NSString *bankName;
@property (nonatomic, assign) BOOL isDefault;

@property (nonatomic, copy, nullable, readonly) NSString *ifscPrefix;
@property (nonatomic, copy, readonly) NSString *ifscSuffix;
@end

@interface HQITBankAccountViewModel : NSObject
@property (nonatomic, strong, readonly, nullable) HQITBankAccountItem *displayItem;
@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, assign, readonly) BOOL hasLoadedOnce;
@property (nonatomic, assign, readonly) BOOL canModify;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, copy, nullable) void (^onToast)(NSString *message);

- (void)reload;
@end

NS_ASSUME_NONNULL_END
