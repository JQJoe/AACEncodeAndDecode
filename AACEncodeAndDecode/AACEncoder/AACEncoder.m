//
//  AACEncoder.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "AACEncoder.h"
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    void *source;
    UInt32 sourceSize;
    UInt32 channelCount;
    AudioStreamPacketDescription *packetDescriptions;
}FillComplexInputParam;

@interface AACEncoder()

@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic, assign)UInt32 samplerate;
@property (nonatomic, assign)UInt32 channels;

@end

@implementation AACEncoder

-(void)dealloc {
    AudioConverterDispose(_audioConverter);
}

OSStatus audioConverterEncodeProc(  AudioConverterRef               inAudioConverter,
                                            UInt32*                         ioNumberDataPackets,
                                            AudioBufferList*                ioData,
                                            AudioStreamPacketDescription**  outDataPacketDescription,
                                            void*                           inUserData) {
    FillComplexInputParam* param = (FillComplexInputParam*)inUserData;
    if (param->sourceSize <= 0) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    ioData->mBuffers[0].mData = param->source;
    ioData->mBuffers[0].mNumberChannels = param->channelCount;
    ioData->mBuffers[0].mDataByteSize = param->sourceSize;
    *ioNumberDataPackets = 1;
    param->sourceSize = 0;
    param->channelCount = 0;
    param->packetDescriptions = NULL;
    param->source = NULL;
    
    return noErr;
}

- (instancetype)initAACEncoderWithSampleRate:(int)sample_rate channels:(int)channel {
    if (self = [super init]) {
        _samplerate = sample_rate;
        _channels = channel;
        
        AudioStreamBasicDescription pcmDes = [self setupPCMDesc];
        AudioStreamBasicDescription aacDes = [self setupAACDesc];
        
        UInt32 size = sizeof(aacDes);
        AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                               0,
                               NULL,
                               &size,
                               &aacDes);
        
        AudioClassDescription audioClassDes;
        memset(&audioClassDes, 0, sizeof(AudioClassDescription));
        AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                   sizeof(aacDes.mFormatID),
                                   &aacDes.mFormatID,
                                   &size);
        
        int encoderCount = size / sizeof(AudioClassDescription);
        AudioClassDescription descriptions[encoderCount];
        AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                               sizeof(aacDes.mFormatID),
                               &aacDes.mFormatID,
                               &size,
                               descriptions);
        
        for (int pos = 0; pos < encoderCount; pos ++) {
            if (aacDes.mFormatID == descriptions[pos].mSubType && descriptions[pos].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
                memcpy(&audioClassDes, &descriptions[pos], sizeof(AudioClassDescription));
                break;
            }
        }
        
        OSStatus status = AudioConverterNewSpecific(&pcmDes,
                                                    &aacDes,
                                                    1,
                                                    &audioClassDes,
                                                    &_audioConverter);
        if (status == noErr) {
            UInt32 bitRate = _samplerate * _channels;
            UInt32 size = sizeof(bitRate);
            AudioConverterSetProperty(_audioConverter,
                                      kAudioConverterEncodeBitRate,
                                      size,
                                      &bitRate);
        }else{
            NSLog(@"AAC Encoder init Fail %d !!", status);
        }
    }
    return self;
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

- (AudioStreamBasicDescription)setupAACDesc {
    AudioStreamBasicDescription aacDesc = {0};
    aacDesc.mFormatID = kAudioFormatMPEG4AAC;
    aacDesc.mFormatFlags = kMPEG4Object_AAC_LC;
    aacDesc.mFramesPerPacket = 1024;
    aacDesc.mSampleRate = _samplerate;
    aacDesc.mChannelsPerFrame = _channels;
    return aacDesc;
}

- (NSData *)encodeWithPcmBuf:(void *)srcdata pcmLen:(int)srclen {
    if (_audioConverter) {
        
        UInt32 theOuputBufSize = 2048 * _channels;
        UInt32 packetSize = 1;
        void *outBuffer = malloc(theOuputBufSize);
        memset(outBuffer, 0, theOuputBufSize);
        
        AudioStreamPacketDescription outputPacketDescriptions;
        
        FillComplexInputParam userParam;
        userParam.source = srcdata;
        userParam.sourceSize = srclen;
        userParam.channelCount = _channels;
        userParam.packetDescriptions = NULL;
        
        OSStatus status = noErr;
        
        NSMutableData *fullData = [NSMutableData dataWithCapacity:0];
        
        AudioBufferList outputBuffers;
        outputBuffers.mNumberBuffers = 1;
        outputBuffers.mBuffers[0].mNumberChannels = _channels;
        outputBuffers.mBuffers[0].mData = outBuffer;
        outputBuffers.mBuffers[0].mDataByteSize = theOuputBufSize;
        status = AudioConverterFillComplexBuffer(_audioConverter,
                                                 audioConverterEncodeProc,
                                                 &userParam,
                                                 &packetSize,
                                                 &outputBuffers,
                                                 &outputPacketDescriptions);
        if (status == noErr) {
            if (outputBuffers.mBuffers[0].mDataByteSize > 0) {
                
                NSData* rawAAC = [NSData dataWithBytes:outputBuffers.mBuffers[0].mData length:outputBuffers.mBuffers[0].mDataByteSize];
#pragma mark  AACDecoder只能把rawAAC转成PCM, 而AudioFileStream可以把AAC_ADTS格式转成rawAAC
#if 1
                NSData *adtsHeader = [self addAdtsDataForPacketLength:rawAAC.length];
                [fullData appendData: [NSMutableData dataWithData:adtsHeader]];
#endif
                [fullData appendData:rawAAC];
            }
        }else {
            NSLog(@"AAC Encoder Fail %d !!",status);
        }
        
        free(outBuffer);
        
        if (_delegate && [_delegate respondsToSelector:@selector(aacEncoderOutputBuffer:size:)]) {
            [_delegate aacEncoderOutputBuffer:(void *)fullData.bytes size:(int)fullData.length];
        }
        
        return fullData;
    }
    return nil;
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer {
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus status;
    
    UInt32 size;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (status) {
        NSLog(@"error getting audio format propery info: %d", (int)(status));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (status) {
        NSLog(@"error getting audio format propery: %d", (int)(status));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

- (NSData *)addAdtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    int profile = 2; 
    int freqIdx = [self freqIdxForAdtsHeader:_samplerate];
    int chanCfg = _channels;
    NSUInteger fullLength = adtsLength + packetLength;

    packet[0] = (char)0xFF;
    packet[1] = (char)0xF9;
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

- (int)freqIdxForAdtsHeader:(int)samplerate {
    int idx = 4;
    if (samplerate >= 7350 && samplerate < 8000) {
        idx = 12;
    }
    else if (samplerate >= 8000 && samplerate < 11025) {
        idx = 11;
    }
    else if (samplerate >= 11025 && samplerate < 12000) {
        idx = 10;
    }
    else if (samplerate >= 12000 && samplerate < 16000) {
        idx = 9;
    }
    else if (samplerate >= 16000 && samplerate < 22050) {
        idx = 8;
    }
    else if (samplerate >= 22050 && samplerate < 24000) {
        idx = 7;
    }
    else if (samplerate >= 24000 && samplerate < 32000) {
        idx = 6;
    }
    else if (samplerate >= 32000 && samplerate < 44100) {
        idx = 5;
    }
    else if (samplerate >= 44100 && samplerate < 48000) {
        idx = 4;
    }
    else if (samplerate >= 48000 && samplerate < 64000) {
        idx = 3;
    }
    else if (samplerate >= 64000 && samplerate < 88200) {
        idx = 2;
    }
    else if (samplerate >= 88200 && samplerate < 96000) {
        idx = 1;
    }
    else if (samplerate >= 96000) {
        idx = 0;
    }
    return idx;
}

@end
