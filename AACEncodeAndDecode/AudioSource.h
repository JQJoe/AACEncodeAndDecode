//
//  AudioSource.h
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AudioSourceDelegate <NSObject>

- (void)audioSourceOutputBuffer:(void *)pcmBuf size:(int)pcmSize ;

@end

@interface AudioSource : NSObject

@property (nonatomic, weak)id<AudioSourceDelegate> delegate;

- (instancetype)initWithSampleRate:(int)sample_rate channels:(int)channel;

- (void)start;
- (void)stop;

@end
