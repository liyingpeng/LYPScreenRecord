//
//  ViewController.m
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/19.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import "ViewController.h"
#import <Masonry/Masonry.h>
#import <LYPScreenRecord/LYPVideoWriter.h>
#import <LYPScreenRecord/LYPUIViewRecorder.h>
#import "ScreenRecordPlayerViewController.h"

@interface ViewController () {
    UIButton *_recordButton;
}
@property(nonatomic) BOOL recording;
@property(nonatomic, strong) LYPVideoWriter *videoWriter;
@property(nonatomic, strong) LYPUIViewRecorder *viewRecorder;

@end

@implementation ViewController

//- (instancetype)initWithCoder:(NSCoder *)coder
//{
//    self = [super initWithCoder:coder];
//    if (self) {
//        self.viewRecorder = [[LYPUIViewRecorder alloc] initWithView:self.view];
//        __weak __typeof(self) weakSelf = self;
//        self.videoWriter = [[LYPVideoWriter alloc] initWithRecordable:self.viewRecorder complete:^(NSURL *url, UIImage *coverImage, BOOL isScreenShot, float duration) {
//            __strong __typeof(weakSelf) strongSelf = weakSelf;
//            [strongSelf showScreenRecorderPlayer:url screenshot:coverImage];
//        }];
//    }
//    return self;
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.viewRecorder = [[LYPUIViewRecorder alloc] initWithView:self.view];
    __weak __typeof(self) weakSelf = self;
    self.videoWriter = [[LYPVideoWriter alloc] initWithRecordable:self.viewRecorder complete:^(NSURL *url, UIImage *coverImage, BOOL isScreenShot, float duration) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf showScreenRecorderPlayer:url screenshot:coverImage];
    }];
    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:indicator];
    [indicator startAnimating];
    [indicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
    
    UIButton *recordButton = [[UIButton alloc] init];
    [recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:recordButton];
    [recordButton addTarget:self action:@selector(recordClick:) forControlEvents:UIControlEventTouchUpInside];
    [recordButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(@(100));
        make.height.mas_equalTo(@(50));
        make.centerX.equalTo(self.view);
        make.bottom.mas_equalTo(@(-50));
    }];
    _recordButton = recordButton;
    self.recording = NO;
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)showScreenRecorderPlayer:(NSURL *)url screenshot:(UIImage *)screenshot {
    ScreenRecordPlayerViewController *previewViewController = [[ScreenRecordPlayerViewController alloc] initWithURL:url screenshot:screenshot closeHandle:^{
    }];
    previewViewController.view.alpha = 0;
    [self addChildViewController:previewViewController];
    [self.view addSubview:previewViewController.view];
    previewViewController.view.frame = self.view.bounds;
    [previewViewController didMoveToParentViewController:self];
    [UIView animateWithDuration:0.25 animations:^{
        previewViewController.view.alpha = 1;
    }];
}

- (void)recordClick:(UIButton *)sender {
    self.recording = !self.recording;
}

- (void)setRecording:(BOOL)recording {
    _recording = recording;
    if (recording) {
        [_recordButton setTitle:@"结束" forState:UIControlStateNormal];
        [_recordButton setBackgroundColor:[UIColor lightGrayColor]];
        if (![self.videoWriter isRecording]) [self.videoWriter start:nil];
    } else {
        [_recordButton setTitle:@"开始" forState:UIControlStateNormal];
        [_recordButton setBackgroundColor:[UIColor greenColor]];
        if ([self.videoWriter isRecording]) [self.videoWriter stop:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
