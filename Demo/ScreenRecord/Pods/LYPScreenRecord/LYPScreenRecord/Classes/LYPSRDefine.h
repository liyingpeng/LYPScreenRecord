//
//  LYPSRDefine.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#ifndef LYPSRDefine_h
#define LYPSRDefine_h

#define SRErrorSetter(__ERROR__, __ERROR_CODE__, __DESC__, ...) do { \
NSString *message = [NSString stringWithFormat:__DESC__, ##__VA_ARGS__]; \
NSLog(@"%@", message); \
if (__ERROR__) *__ERROR__ = [NSError errorWithDomain:LYPErrorDomain code:__ERROR_CODE__ \
userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey,  \
nil]]; \
} while (0)

#define SRDebug(...) NSLog(__VA_ARGS__)
#define SRWarn(...) NSLog(__VA_ARGS__)

static NSString *const LYPErrorDomain = @"LYPErrorDomain";

typedef NS_ENUM(NSUInteger, LYPSRErrorCode) {
    LYPSRErrorCodeInvalidVideo = -100,
    LYPSRErrorCodeInvalidState = -101
};

#endif /* LYPSRDefine_h */
