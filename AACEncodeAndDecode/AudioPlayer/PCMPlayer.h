//
//  PCMPlayer.h
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PCMPlayer : NSObject

- (instancetype)initWithSampleRate:(int)sample_rate channels:(int)channel;

- (void)start;
- (void)stop;

- (void)playAudioWithPcmBuf:(const void*)pcmBuf pcmSize:(int)pcmSize;

@end
