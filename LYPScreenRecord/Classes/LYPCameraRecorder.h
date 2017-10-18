//
//  LYPCameraRecorder.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LYPRecordable.h"

@interface LYPCameraRecorder : NSObject <SRRecordable>
@property (nonatomic, weak) id<SRAudioWriter> audioWriter;
@property (nonatomic) CMTime presentationTime;
@end
