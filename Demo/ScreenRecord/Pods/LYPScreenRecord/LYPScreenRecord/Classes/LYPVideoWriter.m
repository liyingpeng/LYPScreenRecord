//
//  LYPVideoWriter.m
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import "LYPVideoWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "LYPSRDefine.h"
#import "LYPCameraRecorder.h"

@interface LYPVideoWriter () {
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_bufferAdapter;
    AVAssetWriterInput *_audioWriterInput;
    CVPixelBufferPoolRef _outputBufferPool;

    CGSize _videoSize;
    CGFloat _scale;
    
    dispatch_queue_t _render_queue;
    dispatch_queue_t _append_pixelBuffer_queue;
    dispatch_semaphore_t _frameRenderingSemaphore;
    dispatch_semaphore_t _pixelAppendSemaphore;
    
    CFTimeInterval _firstTimeStamp;
    CMTime _lastSampleTime;
    CMTime _startTime;
    CADisplayLink *_displayLink;
    
    LYPCameraRecorder *_userRecorder;
    id<SRRecordable> _recordable;
}
@property(nonatomic, copy) void(^completeHandle)(NSURL *url, UIImage *coverImage, BOOL isScreenShot, float duration);
@end

@implementation LYPVideoWriter

- (instancetype)initWithRecordable:(id<SRRecordable>)recordable complete:(void(^)(NSURL *url, UIImage *coverImage, BOOL isScreenShot, float duration))completeHandle
{
    self = [super init];
    if (self) {
        self.completeHandle = completeHandle;
        _recordable = recordable;
        _videoSize = recordable.size;
        _scale = [UIScreen mainScreen].scale;
        _append_pixelBuffer_queue = dispatch_queue_create("lyp.screenRecorder.append_queue", DISPATCH_QUEUE_SERIAL);
        _render_queue = dispatch_queue_create("lyp.screenRecorder.render_queue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_render_queue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _frameRenderingSemaphore = dispatch_semaphore_create(1);
        _pixelAppendSemaphore = dispatch_semaphore_create(1);
#if !TARGET_IPHONE_SIMULATOR
        _userRecorder = [[LYPCameraRecorder alloc] init];
        _userRecorder.audioWriter = self;
#endif
    }
    return self;
}

- (void)dealloc {
    [self destryDisplayLink];
    if ([self isRecording]) [self stop:nil];
}

- (BOOL)start:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[self outputFileURL].path]) {
        NSError* error;
        if ([fileManager removeItemAtPath:[self outputFileURL].path error:&error] == NO) {
            NSLog(@"screen recorder: Could not delete old recording:%@", [error localizedDescription]);
        }
    }
    if (_writer) {
        SRErrorSetter(error, LYPSRErrorCodeInvalidState, @"asset writer is already started recording.");
        return NO;
    }
    
    _writer = [[AVAssetWriter alloc] initWithURL:[self outputFileURL] fileType:AVFileTypeMPEG4 error:error];
    if (!_writer) {
        return NO;
    }
    
    NSDictionary* videoCompressionProperties = @{AVVideoAverageBitRateKey: @(1024.0 * 1024.0)};
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecTypeH264,
                                    AVVideoWidthKey: @(_videoSize.width),
                                    AVVideoHeightKey: @(_videoSize.height),
                                    AVVideoCompressionPropertiesKey: videoCompressionProperties};
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    if (!_videoWriterInput) {
        SRErrorSetter(error, 0, @"Error with audio writer input");
        return NO;
    }
    
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    _bufferAdapter = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    if (![_writer canAddInput:_videoWriterInput]) {
        SRErrorSetter(error, LYPSRErrorCodeInvalidState, @"asset writer can not add video input");
        return NO;
    }
    [_writer addInput:_videoWriterInput];
    
    NSDictionary *audioOutputSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                          AVNumberOfChannelsKey: @(1),
                                          AVSampleRateKey: @(12000)};
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    if (![_writer canAddInput:_audioWriterInput]) {
        SRErrorSetter(error, LYPSRErrorCodeInvalidState, @"asset writer can not add audio input");
        return NO;
    }
    [_writer addInput:_audioWriterInput];
    
    NSDictionary *pbAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                   (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                                   (id)kCVPixelBufferWidthKey : @(_videoSize.width * _scale),
                                   (id)kCVPixelBufferHeightKey : @(_videoSize.height * _scale),
                                   (id)kCVPixelBufferBytesPerRowAlignmentKey : @(_videoSize.width * _scale * 4)
                                   };
    _outputBufferPool = NULL;
    CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)(pbAttributes), &_outputBufferPool);
    
    [self setupDisplayLink];
    
    return YES;
}

- (BOOL)stop:(NSError **)error {
    if (!_writer) {
        SRErrorSetter(error, 0, @"Can't stop, asset writer is not running");
        return NO;
    }
    SRDebug(@"Stopping");
    [self destryDisplayLink];
    
    if (_writer.status != AVAssetWriterStatusUnknown) {
        dispatch_async(_render_queue, ^{
            dispatch_sync(_append_pixelBuffer_queue, ^{
                if (!self) { return; }
                [_videoWriterInput markAsFinished];
                [_audioWriterInput markAsFinished];
                _videoWriterInput = nil;
                _audioWriterInput = nil;
                _bufferAdapter = nil;
                
                SRDebug(@"Waiting to mark finished");
                NSUInteger i = 0;
                while (_writer.status == AVAssetWriterStatusUnknown) {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    if (i++ > 100) {
                        SRWarn(@"Timed out waiting for writer to finish");
                        break;
                    }
                }
                SRDebug(@"Finishing");
                [_writer endSessionAtSourceTime:_lastSampleTime];
                __weak __typeof(self) weakSelf = self;
                [_writer finishWritingWithCompletionHandler:^{
                    __strong __typeof(weakSelf) strongSelf = weakSelf;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (weakSelf.completeHandle) weakSelf.completeHandle([weakSelf outputFileURL], nil, NO, 0);
                    });
                    [strongSelf cleanup];
                }];
                
                if (_writer.error) {
                    SRWarn(@"Writer error: %@", _writer.error);
                }
                _writer = nil;
                SRDebug(@"Finished");
            });
        });
    }
    return YES;
}

- (void)cleanup
{
    _firstTimeStamp = 0;
    _lastSampleTime = kCMTimeZero;
    _startTime = kCMTimeZero;
    CVPixelBufferPoolRelease(_outputBufferPool);
}

- (void)setupDisplayLink {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrame:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)destryDisplayLink {
    _displayLink.paused = YES;
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)captureFrame:(CADisplayLink *)displayLink {
    if (_writer.status != AVAssetWriterStatusWriting) {
        [_writer startWriting];
        //获取开始写入的CMTime
        _startTime = kCMTimeZero;
        [_writer startSessionAtSourceTime:_startTime];
    }
    if (dispatch_semaphore_wait(_frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0) {
        return;
    }
    dispatch_async(_render_queue, ^{
//        CMTime time = kCMTimeNegativeInfinity;
//        if (!_firstTimeStamp) {
//            _firstTimeStamp = displayLink.timestamp;
//        }
//        if (_userRecorder) {
//            time = [_userRecorder presentationTime];
//            if (CMTIME_IS_NEGATIVE_INFINITY(time)) {
//                SRDebug(@"No presentation time, skipping");
//                dispatch_semaphore_signal(_frameRenderingSemaphore);
//                return;
//            }
//        } else {
//            CFTimeInterval elapsed = (displayLink.timestamp - _firstTimeStamp);
//            time = CMTimeMake(elapsed, 1000);
//            CMTime realTime = CMTimeAdd(_startTime, time);
//        }
//        if (_writer.status != AVAssetWriterStatusWriting) {
//            [_writer startWriting];
//            _startTime = time;
//            [_writer startSessionAtSourceTime:_startTime];
//        }
//
        if (!_videoWriterInput.readyForMoreMediaData) {
            dispatch_semaphore_signal(_frameRenderingSemaphore);
            return;
        }

        if (!_firstTimeStamp) {
            _firstTimeStamp = displayLink.timestamp;
        }
        CFTimeInterval elapsed = (_displayLink.timestamp - _firstTimeStamp);
        CMTime time = CMTimeMakeWithSeconds(elapsed, 1000);
        CMTime realTime = CMTimeAdd(_startTime, time);
        CVPixelBufferRef pixelBuffer = NULL;
        CGContextRef bitmapContext = [self createPixelBufferAndBitmapContext:&pixelBuffer];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            UIGraphicsPushContext(bitmapContext);
            [_recordable renderInContext:bitmapContext videoSize:_videoSize];
            UIGraphicsPopContext();
        });
        
        if (dispatch_semaphore_wait(_pixelAppendSemaphore, DISPATCH_TIME_NOW) == 0) {
            dispatch_async(_append_pixelBuffer_queue, ^{
                BOOL success = [_bufferAdapter appendPixelBuffer:pixelBuffer withPresentationTime:realTime];
                if (!success) {
                    NSLog(@"screen recorder: Unable to write buffer to video");
                } else {
                    NSLog(@"screen recorder: success write to video at tiem: %f", CMTimeGetSeconds(time));
                }
                _lastSampleTime = realTime;
                CGContextRelease(bitmapContext);
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                CVPixelBufferRelease(pixelBuffer);
                
                dispatch_semaphore_signal(_pixelAppendSemaphore);
            });
        } else {
            CGContextRelease(bitmapContext);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
        }
        
        dispatch_semaphore_signal(_frameRenderingSemaphore);
    });
}

- (CGContextRef)createPixelBufferAndBitmapContext:(CVPixelBufferRef *)pixelBuffer
{
    CVPixelBufferPoolCreatePixelBuffer(NULL, _outputBufferPool, pixelBuffer);
    CVPixelBufferLockBaseAddress(*pixelBuffer, 0);
    
    CGContextRef bitmapContext = NULL;
    static CGColorSpaceRef ColorSpace = NULL;
    if (ColorSpace == NULL) ColorSpace = CGColorSpaceCreateDeviceRGB();
    bitmapContext = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(*pixelBuffer),
                                          CVPixelBufferGetWidth(*pixelBuffer),
                                          CVPixelBufferGetHeight(*pixelBuffer),
                                          8, CVPixelBufferGetBytesPerRow(*pixelBuffer), ColorSpace,
                                          kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst
                                          );
    CGContextScaleCTM(bitmapContext, _scale, _scale);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, _videoSize.height);
    CGContextConcatCTM(bitmapContext,
                       flipVertical);
    
    return bitmapContext;
}

- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (![_audioWriterInput isReadyForMoreMediaData]) {
        SRDebug(@"Audio writer input is not ready for more data");
        return NO;
    }
    //CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    //CRDebug(@"Audio timestamp: %0.2f", ((double)time.value * time.timescale));
    return [_audioWriterInput appendSampleBuffer:sampleBuffer];
}

- (BOOL)isRecording {
    return !!_writer;
}

- (NSURL *)outputFileURL
{
    NSString *outputPath = [NSHomeDirectory() stringByAppendingPathComponent:@"tmp/screenCapture.mp4"];
    return [NSURL fileURLWithPath:outputPath];
}

@end
