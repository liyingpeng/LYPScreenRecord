//
//  LYPUIViewRecorder.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LYPRecordable.h"

@interface LYPUIViewRecorder : NSObject <SRRecordable>
- (id)initWithView:(UIView *)view;
@end
