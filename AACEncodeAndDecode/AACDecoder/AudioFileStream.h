//
//  AudioFileStream.h
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class AudioFileStream;

@protocol AudioFileStreamDelegate <NSObject>

@optional
- (void)audioFileStream:(AudioFileStream *)audioFileStream audioDataParsed:(NSData *)audioData;
- (void)audioFileStreamReadyToProducePackets:(AudioFileStream *)audioFileStream;

@end

@interface AudioFileStream : NSObject

@property (nonatomic,weak) id<AudioFileStreamDelegate> delegate;

@property (nonatomic,readonly) UInt32 bitRate;
@property (nonatomic,readonly) UInt32 maxPacketSize;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(UInt64)fileSize;

- (BOOL)openAudioFileStream;
- (void)closeAudioFileStream;

- (BOOL)parseData:(NSData *)data error:(NSError **)error;

@end
