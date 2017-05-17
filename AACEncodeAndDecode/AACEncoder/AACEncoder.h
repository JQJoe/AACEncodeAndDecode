//
//  AACEncoder.h
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AACEncoderDelegate <NSObject>

@optional
- (void)aacEncoderOutputBuffer:(void *)aacBuf size:(int)aacSize;

@end

@interface AACEncoder : NSObject

@property (nonatomic, weak)id<AACEncoderDelegate> delegate;

- (instancetype)initAACEncoderWithSampleRate:(int)sample_rate channels:(int)channel;

- (NSData *)encodeWithPcmBuf:(void *)srcdata pcmLen:(int)srclen ;

@end
