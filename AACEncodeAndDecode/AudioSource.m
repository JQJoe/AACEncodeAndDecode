//
//  AudioSource.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "AudioSource.h"

@interface AudioSource()

@property (nonatomic) AudioComponentInstance m_audioUnit;
@property (nonatomic) AudioStreamBasicDescription pcmDesc;

@property (nonatomic) int samplerate;
@property (nonatomic) int channels;

@end

@implementation AudioSource

- (instancetype)initWithSampleRate:(int)sample_rate channels:(int)channel {
    if (self = [super init]) {
        _samplerate = sample_rate;
        _channels = channel;
        _pcmDesc = [self setupPCMDesc];
        [self setupAudioUnit];
    }
    return self;
}

- (void)start {
    OSStatus status = AudioOutputUnitStart(_m_audioUnit);
    if (status != noErr) {
        NSLog(@"Failed to start microphone!");
    }
}

- (void)stop {
    AudioOutputUnitStop(_m_audioUnit);
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
    
    AudioComponentDescription component;
    component.componentType = kAudioUnitType_Output;
    component.componentSubType = kAudioUnitSubType_RemoteIO;
    component.componentManufacturer = kAudioUnitManufacturer_Apple;
    component.componentFlags = 0;
    component.componentFlagsMask = 0;
    
    AudioComponent m_component = AudioComponentFindNext(NULL, &component);
    AudioComponentInstanceNew(m_component, &_m_audioUnit);
    if (!_m_audioUnit) {
        NSLog(@"AudioComponentInstanceNew Fail !!");
        return;
    }
    
    UInt32 flagOne = 1;
    AudioUnitSetProperty(_m_audioUnit, kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         1,
                         &flagOne,
                         sizeof(flagOne));
    
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void * _Nullable)(self);
    cb.inputProc = inputProc;
    AudioUnitSetProperty(_m_audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         1,
                         &_pcmDesc,
                         sizeof(_pcmDesc));
    
    AudioUnitSetProperty(_m_audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         1,
                         &cb,
                         sizeof(cb));
    
    AudioUnitInitialize(_m_audioUnit);
    
}

static OSStatus inputProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber,
                          UInt32 inNumberFrames,
                          AudioBufferList *ioData) {
    
    AudioSource *src = (__bridge AudioSource*)inRefCon;
    
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = src.pcmDesc.mChannelsPerFrame;
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    
    OSStatus status = AudioUnitRender(src.m_audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      &buffers);
    
    if (status == noErr) {
        [src handleInputData:buffers.mBuffers[0].mData size:buffers.mBuffers[0].mDataByteSize frameCount:inNumberFrames];
    }
    return status;
}

- (void)handleInputData:(void *)pcmBuf size:(int)pcmSize frameCount:(int)inNumberFrames {
    [_delegate audioSourceOutputBuffer: pcmBuf size: pcmSize];
}


@end
