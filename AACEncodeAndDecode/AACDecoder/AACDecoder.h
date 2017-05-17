//
//  AACDecoder.h
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AACDecoderDelegate <NSObject>

@optional
- (void)aacDecoderOutputBuffer:(void *)pcmBuf size:(int)pcmSize;

@end

@interface AACDecoder : NSObject

@property (nonatomic, weak) id<AACDecoderDelegate> delegate;

- (instancetype)initAACDecoderWithSampleRate:(int)sample_rate channels:(int)channel;

- (NSData *)decodeWithAACBuf:(void *)srcdata aacLen:(int)srclen;


@end
