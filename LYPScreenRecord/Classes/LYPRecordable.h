//
//  LYPRecordable.h
//  ScreenRecord
//
//  Created by 李应鹏 on 2017/10/18.
//  Copyright © 2017年 李应鹏. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>

@protocol SRRecordable <NSObject>

/*!
 Render the recordable in the specified context.
 @param context Context to render in
 @param videoSize Video size
 */
- (void)renderInContext:(CGContextRef)context videoSize:(CGSize)videoSize;

/*!
 @result The size of the recordable. This size must be fixed and is required before any rendering begins.
 */
- (CGSize)size;

@optional

/*!
 When the recording is started, we will notify the recordable.
 @param error Out error
 @result YES if started successfully, NO otherwise
 */
- (BOOL)start:(NSError **)error;

/*!
 When the recording is stopped, we will notify the recordable.
 @param error Out error
 @result YES if stopped successfully, NO otherwise
 */
- (BOOL)stop:(NSError **)error;

@end

@protocol SRAudioWriter <NSObject>
/*!
 Append audio sample buffer.
 @param sampleBuffer Audio sample buffer
 */
- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
