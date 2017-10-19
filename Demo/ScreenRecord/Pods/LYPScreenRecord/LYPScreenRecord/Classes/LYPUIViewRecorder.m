//
//  LYPUIViewRecorder.m
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import "LYPUIViewRecorder.h"

@interface LYPUIViewRecorder ()

@property(nonatomic, weak) UIView *view;

@end

@implementation LYPUIViewRecorder

- (CGSize)size {
    return _view.bounds.size;
}

- (id)initWithView:(UIView *)view {
    if ((self = [super init])) {
        self.view = view;
    }
    return self;
}

- (void)renderInContext:(CGContextRef)context videoSize:(CGSize)videoSize {
    [_view drawViewHierarchyInRect:_view.bounds afterScreenUpdates:NO];
}

@end
