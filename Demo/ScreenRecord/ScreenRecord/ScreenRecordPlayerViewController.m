//
//  ScreenRecordPlayerViewController.m
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import "ScreenRecordPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>

@interface ScreenRecordPlayerViewController ()
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) UIImage *screenshot;
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, strong) UIImageView *screenShotImageView;

@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;
@property(nonatomic, strong) AVPlayerItem *item;
@property(nonatomic, copy) void(^closeHandle)(void);

@end

@implementation ScreenRecordPlayerViewController

- (instancetype)initWithURL:(NSURL *)url screenshot:(UIImage *)screenshot closeHandle:(void(^)(void))closeHandle {
    self = [super init];
    if (self) {
        self.closeHandle = closeHandle;
        self.url = url;
        self.screenshot = screenshot;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.player name:AVPlayerItemDidPlayToEndTimeNotification object:self.item];
    [self.item removeObserver:self forKeyPath:@"status"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //背景
    UIView *cover = [UIView new];
    [self.view addSubview:cover];
    cover.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3f];
    [cover mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    CGFloat scale = 300.0f / 375.0f;
    CGRect playerRect = CGRectApplyAffineTransform(self.view.frame, CGAffineTransformScale(CGAffineTransformIdentity, scale, scale));
    
    [self.view addSubview:self.container];
    self.container.frame = CGRectMake(0, 0, playerRect.size.width + 5, playerRect.size.height + 5);
    self.container.center = self.view.center;
    
    CGRect containerRect = self.container.frame;
    CGRect assetContentRect = CGRectMake((containerRect.size.width - playerRect.size.width) / 2, (containerRect.size.height - playerRect.size.height) / 2, playerRect.size.width, playerRect.size.height);
    if (self.url) {
        [self.container.layer addSublayer:self.playerLayer];
        self.playerLayer.frame = assetContentRect;
    } else {
        [self.container addSubview:self.screenShotImageView];
        self.screenShotImageView.frame = assetContentRect;
    }
    
    [self.container addSubview:self.closeButton];
    
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.equalTo(self.container);
    }];
}

- (void)playReachedEnd:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay){
            [self.player play];
        } else if(playerItem.status==AVPlayerStatusUnknown){
            NSLog(@"playerItem Unknown");
        } else if (playerItem.status==AVPlayerStatusFailed){
            NSError *error = [object error];
            NSLog(@"playerItem error:%@", error);
        }
    }
}

- (void)close:(UIButton *)sender {
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
    if (self.closeHandle) {
        self.closeHandle();
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - getters

- (UIView *)container {
    if (!_container) {
        UIView *container = [UIView new];
        container.clipsToBounds = YES;
        _container = container;
        container.backgroundColor = [UIColor blackColor];
        container.layer.cornerRadius = 8.0f;
    }
    return _container;
}

- (AVPlayerItem *)item {
    if (!_item) {
        AVAsset *asset = [AVAsset assetWithURL:self.url];
        _item = [AVPlayerItem playerItemWithAsset:asset];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playReachedEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
        [_item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    }
    return _item;
}

- (AVPlayer *)player {
    if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:self.item];
        _player.volume = 0.0f;
    }
    return _player;
}

- (AVPlayerLayer *)playerLayer {
    if (!_playerLayer) {
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        layer.contentsScale = [UIScreen mainScreen].scale;
        layer.backgroundColor = [UIColor clearColor].CGColor;
        layer.cornerRadius = 8.0f;
        layer.masksToBounds = YES;
        _playerLayer = layer;
    }
    return _playerLayer;
}

- (UIButton *)closeButton {
    if (!_closeButton) {
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.backgroundColor = [UIColor lightGrayColor];
        [closeButton addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
        _closeButton = closeButton;
    }
    return _closeButton;
}

- (UIImageView *)screenShotImageView {
    if (!_screenShotImageView) {
        UIImageView *imageview = [[UIImageView alloc] initWithImage:self.screenshot];
        _screenShotImageView = imageview;
    }
    return _screenShotImageView;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
