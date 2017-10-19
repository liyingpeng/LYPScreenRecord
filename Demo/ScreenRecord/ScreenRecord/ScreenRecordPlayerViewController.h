//
//  ScreenRecordPlayerViewController.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ScreenRecordPlayerViewController : UIViewController
- (instancetype)initWithURL:(NSURL *)url screenshot:(UIImage *)screenshot closeHandle:(void(^)(void))closeHandle;
@end
