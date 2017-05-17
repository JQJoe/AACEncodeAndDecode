//
//  PCMPlayer.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "PCMPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif

#define kBUFF_MAX_SIZE 512*40
#define kOutputBus 0
#define kInputBus 1

@interface PCMPlayer ()

@property (nonatomic) AudioComponentInstance m_audioUnit;
@property (nonatomic) AudioStreamBasicDescription pcmDesc;

//@property (nonatomic) AudioBuffer tempBuffer;

@property (nonatomic) int samplerate;
@property (nonatomic) int channels;

@property (nonatomic, strong) NSMutableData *bufferData;
@property (nonatomic, strong) NSLock *playLock;

@end

@implementation PCMPlayer

void checkStatus(int status, int line){
    if (status) {
        printf("Status not 0! %d %d\n", status, line);
    }
}

- (void) dealloc {
    AudioUnitUninitialize(_m_audioUnit);
//    free(_tempBuffer.mData);
}

- (instancetype)initWithSampleRate:(int)sample_rate channels:(int)channel {
    if (self = [super init]) {
        _samplerate = sample_rate;
        _channels = channel;
        _pcmDesc = [self setupPCMDesc];
        
        self.bufferData = [NSMutableData dataWithCapacity:0];
        self.playLock = [[NSLock alloc] init];
        [self setupAudioUnit];
        
        AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
        [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:NULL];
    }
    return self;
}

- (void)start {
    [_bufferData setLength:0];
    OSStatus status = AudioOutputUnitStart(_m_audioUnit);
    checkStatus(status, __LINE__);
}

- (void)stop {
    AudioOutputUnitStop(_m_audioUnit);
    [_bufferData setLength:0];
}

- (void)playAudioWithPcmBuf:(const void*)pcmBuf pcmSize:(int)pcmSize {
    
//    memcpy(_tempBuffer.mData, pcmBuf, pcmSize);
//    _tempBuffer.mDataByteSize = pcmSize;
    
    [_playLock lock];
    [_bufferData appendBytes:pcmBuf length:pcmSize];
    [_playLock unlock];
}

- (AudioStreamBasicDescription)setupPCMDesc {
    AudioStreamBasicDescription pcmDesc = {0};
    pcmDesc.mSampleRate = _samplerate;
    pcmDesc.mFormatID = kAudioFormatLinearPCM;
    pcmDesc.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked);
    pcmDesc.mChannelsPerFrame = _channels;
    pcmDesc.mFramesPerPacket = 1;
    pcmDesc.mBitsPerChannel = 16;
    pcmDesc.mBytesPerFrame = pcmDesc.mBitsPerChannel / 8 * pcmDesc.mChannelsPerFrame;
    pcmDesc.mBytesPerPacket = pcmDesc.mBytesPerFrame * pcmDesc.mFramesPerPacket;
    pcmDesc.mReserved = 0;
    return pcmDesc;
}

- (void)setupAudioUnit {
    
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
//    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    
    AudioComponent m_component = AudioComponentFindNext(NULL, &acd);
    
    AudioComponentInstanceNew(m_component, &_m_audioUnit);
    if(!_m_audioUnit) {
        NSLog(@"AudioComponentInstanceNew Failed");
        return ;
    }
    
    OSStatus status;
    status = AudioUnitSetProperty(_m_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &_pcmDesc,
                                  sizeof(_pcmDesc));
    checkStatus(status, __LINE__);
    
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void * _Nullable)(self);
    cb.inputProc = outputProc;
    status = AudioUnitSetProperty(_m_audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &cb,
                                  sizeof(cb));
    checkStatus(status, __LINE__);
    
//    _tempBuffer.mNumberChannels = 1;
//    _tempBuffer.mDataByteSize = kBUFF_MAX_SIZE;
//    _tempBuffer.mData = malloc(kBUFF_MAX_SIZE);
    
    if (status == noErr) {
        status = AudioUnitInitialize(_m_audioUnit);
    }
    checkStatus(status, __LINE__);
}

static OSStatus outputProc(void *inRefCon,
                           AudioUnitRenderActionFlags *ioActionFlags,
                           const AudioTimeStamp *inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList *ioData)
{
    PCMPlayer *player = (__bridge PCMPlayer *)inRefCon;
    
    for (int i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer ab = ioData->mBuffers[i];
        memset(ab.mData, 0, ab.mDataByteSize);
        
        int length = (int)min(ab.mDataByteSize, player.bufferData.length);
        memcpy(ab.mData, player.bufferData.bytes, length);
        NSData *data = [player.bufferData subdataWithRange:NSMakeRange(length, player.bufferData.length - length)];
        [player.bufferData setData:data];
        
        if (player.bufferData.length > kBUFF_MAX_SIZE) {
            printf("累积太多，清空缓存\n");
            [player.bufferData setLength:0];
        }
    }
    return noErr;
}


@end
