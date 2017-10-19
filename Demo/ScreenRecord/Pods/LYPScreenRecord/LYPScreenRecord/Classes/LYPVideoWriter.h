//
//  LYPVideoWriter.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LYPRecordable.h"

@interface LYPVideoWriter : NSObject <SRAudioWriter>

- (instancetype)initWithRecordable:(id<SRRecordable>)recordable complete:(void(^)(NSURL *url, UIImage *coverImage, BOOL isScreenShot, float duration))completeHandle;

- (BOOL)start:(NSError **)error;

- (BOOL)isRecording;

- (BOOL)stop:(NSError **)error;

@end
