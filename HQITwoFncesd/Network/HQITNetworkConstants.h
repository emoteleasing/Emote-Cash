

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const HQITAppId;
FOUNDATION_EXPORT NSString * const HQITSalt;
FOUNDATION_EXPORT NSString * const HQITAdjustAppToken;
FOUNDATION_EXPORT NSString * const HQITSecretKey;
FOUNDATION_EXPORT NSString * const HQITAPIVersion;
FOUNDATION_EXPORT NSString * const HQITChannel;
FOUNDATION_EXPORT NSString * const HQITOSValue;
FOUNDATION_EXPORT NSString * const HQITClientLanguage;
FOUNDATION_EXPORT NSString * const HQITFixedBaseURL;
FOUNDATION_EXPORT NSString * const HQITLogTag;

FOUNDATION_EXPORT NSString * HQITClientUserAgentString(void);

FOUNDATION_EXPORT NSString * const HQITSystemBusyMessage;

FOUNDATION_EXPORT NSString * HQITSanitizeNetworkErrorMessage(NSString * _Nullable raw);

/// Endpoints that only sign public params (ignore signedData for signature).
FOUNDATION_EXPORT NSArray<NSString *> * HQITPublicParamOnlyEndpoints(void);

/// Endpoints that skip HUD loading by default.
FOUNDATION_EXPORT NSArray<NSString *> * HQITNoLoadingEndpoints(void);

/// Endpoints that skip error Toast by default.
FOUNDATION_EXPORT NSArray<NSString *> * HQITNoErrorToastEndpoints(void);

/// termV3 codes that must not show error Toast.
FOUNDATION_EXPORT NSArray<NSNumber *> * HQITTermV3NoToastCodes(void);

FOUNDATION_EXPORT NSArray<NSNumber *> * HQITNoErrorToastCodes(void);

NS_ASSUME_NONNULL_END
