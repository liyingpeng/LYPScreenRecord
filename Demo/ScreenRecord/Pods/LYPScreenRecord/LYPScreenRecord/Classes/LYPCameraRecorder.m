//
//  LYPCameraRecorder.m
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import "LYPCameraRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface LYPCameraRecorder () <AVCaptureAudioDataOutputSampleBufferDelegate> {
    AVCaptureSession *_captureSession;
    AVCaptureConnection *_audioConnection;
    AVCaptureDeviceInput *_audioDeviceInput;
    AVCaptureAudioDataOutput *_audioDataOutput;
    dispatch_queue_t _audio_output_queue;
}

@end

@implementation LYPCameraRecorder

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audio_output_queue = dispatch_queue_create("lyp.screenRecorder.audio_output_queue", DISPATCH_QUEUE_SERIAL);
        self.presentationTime = kCMTimeNegativeInfinity;
    }
    return self;
}

- (void)dealloc {
    [self closeCaptureSession];
}

- (BOOL)start:(NSError **)error {
    return [self setupCaptureSession];
}

- (BOOL)stop:(NSError **)error {
    return [self closeCaptureSession];
}

- (BOOL)setupCaptureSession {
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    _audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    if (!_audioDeviceInput) {
//        _audioInitFailed = YES;
        [_captureSession commitConfiguration];
        return NO;
    }
    if ([_captureSession canAddInput:_audioDeviceInput]) {
        [_captureSession addInput:_audioDeviceInput];
    }
    if ([_captureSession canAddOutput:_audioDataOutput]) {
        [_captureSession addOutput:_audioDataOutput];
    }
    _audioConnection = [_audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    
    [_audioDataOutput setSampleBufferDelegate:self queue:_audio_output_queue];
    [_captureSession commitConfiguration];
    [_captureSession startRunning];
    return YES;
}

- (BOOL)closeCaptureSession {
    if (!_captureSession) return NO;
    [_captureSession stopRunning];
    // Wait until it stops
    NSUInteger i = 0;
    while (_captureSession.isRunning) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        if (i++ > 100) {
            NSLog(@"screen recorder: Timed out waiting for capture session to close");
            break;
        }
    }
    [_captureSession removeInput:_audioDeviceInput];
    [_captureSession removeOutput:_audioDataOutput];
    self.presentationTime = kCMTimeNegativeInfinity;

    _captureSession = nil;
    _audioDeviceInput = nil;
    _audioDataOutput = nil;
    return YES;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // 只采集音频数据
    if (CMSampleBufferDataIsReady(sampleBuffer) <= 0) {
        return;
    }
    if (connection == _audioConnection) {
        [self.audioWriter appendSampleBuffer:sampleBuffer];
        self.presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    }
}

- (void)renderInContext:(CGContextRef)context videoSize:(CGSize)videoSize {
    // 只采集音频数据
    return;
}

- (CGSize)size {
    return CGSizeMake(320, 480);
}

@end
