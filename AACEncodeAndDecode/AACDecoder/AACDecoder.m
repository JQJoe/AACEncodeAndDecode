//
//  AACDecoder.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "AACDecoder.h"
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    void *source;
    UInt32 sourceSize;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDescriptions;
}FillComplexInputParam;

@interface AACDecoder()

@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic, assign)UInt32 samplerate;
@property (nonatomic, assign)UInt32 channels;

@end

@implementation AACDecoder

-(void)dealloc {
    AudioConverterDispose(_audioConverter);
}

OSStatus audioConverterDecodeProc(  AudioConverterRef               inAudioConverter,
                                            UInt32*                         ioNumberDataPackets,
                                            AudioBufferList*                ioData,
                                            AudioStreamPacketDescription**  outDataPacketDescription,
                                            void*                           inUserData)
{
    FillComplexInputParam* param = (FillComplexInputParam*)inUserData;
    if (param->sourceSize <= 0) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    
    *outDataPacketDescription = &param->packetDescriptions;
    (*outDataPacketDescription)[0].mStartOffset = 0;
    (*outDataPacketDescription)[0].mVariableFramesInPacket = 0;
    (*outDataPacketDescription)[0].mDataByteSize = param->sourceSize;
    
    ioData->mBuffers[0].mData = param->source;
    ioData->mBuffers[0].mDataByteSize = param->sourceSize;
    ioData->mBuffers[0].mNumberChannels = param->channelCount;
    
    param->channelCount = 0;
    param->sourceSize = 0;
    param->source = NULL;
    
    return noErr;
}

- (instancetype)initAACDecoderWithSampleRate:(int)sample_rate channels:(int)channel {
    if (self = [super init]) {
        _samplerate = sample_rate;
        _channels = channel;
        
        AudioStreamBasicDescription pcmDes = [self setupPCMDesc];
        AudioStreamBasicDescription aacDes = [self setupAACDesc];
        
        UInt32 size = sizeof(pcmDes);
        AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                               0,
                               NULL,
                               &size,
                               &pcmDes);
        
        AudioClassDescription audioClassDes;
        memset(&audioClassDes, 0, sizeof(AudioClassDescription));
        AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders,
                                   sizeof(pcmDes.mFormatID),
                                   &pcmDes.mFormatID,
                                   &size);
        
        int encoderCount = size / sizeof(AudioClassDescription);
        AudioClassDescription descriptions[encoderCount];
        AudioFormatGetProperty(kAudioFormatProperty_Decoders,
                               sizeof(pcmDes.mFormatID),
                               &pcmDes.mFormatID,
                               &size,
                               descriptions);
        
        for (int pos = 0; pos < encoderCount; pos ++) {
            if (pcmDes.mFormatID == descriptions[pos].mSubType && descriptions[pos].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
                memcpy(&audioClassDes, &descriptions[pos], sizeof(AudioClassDescription));
                break;
            }
        }
        
        OSStatus ret = AudioConverterNewSpecific(&aacDes,
                                                 &pcmDes,
                                                 1,
                                                 &audioClassDes,
                                                 &_audioConverter);
        if (ret == noErr) {
            UInt32 bitRate = _samplerate * _channels;
            UInt32 size = sizeof(bitRate);
            AudioConverterSetProperty(_audioConverter,
                                      kAudioConverterEncodeBitRate,
                                      size,
                                      &bitRate);
        }else{
            NSLog(@"AAC Encoder init Fail!!");
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

- (NSData *)decodeWithAACBuf:(void *)srcdata aacLen:(int)srclen {
    if (_audioConverter) {
        UInt32 theOuputBufSize = 2048 * _channels;
        UInt32 packetSize = 1024;
        void *outBuffer = malloc(theOuputBufSize);
        memset(outBuffer, 0, theOuputBufSize);
        
        FillComplexInputParam userParam;
        userParam.source = srcdata;
        userParam.sourceSize = srclen;
        userParam.channelCount = _channels;
        
        AudioBufferList outputBuffers;
        outputBuffers.mNumberBuffers = 1;
        outputBuffers.mBuffers[0].mDataByteSize = theOuputBufSize;
        outputBuffers.mBuffers[0].mData = outBuffer;
        outputBuffers.mBuffers[0].mNumberChannels = _channels;
        
        OSStatus ret = noErr;
        NSMutableData *pcmData = [NSMutableData dataWithCapacity:0];
        AudioStreamPacketDescription outputPacketDescriptions[packetSize];
        
        ret = AudioConverterFillComplexBuffer(_audioConverter,
                                              audioConverterDecodeProc,
                                              &userParam,
                                              &packetSize,
                                              &outputBuffers,
                                              outputPacketDescriptions);
        
        if (ret == noErr) {
            if (outputBuffers.mBuffers[0].mDataByteSize > 0) {
                
                NSData* rawPCM = [NSData dataWithBytes:outputBuffers.mBuffers[0].mData length:outputBuffers.mBuffers[0].mDataByteSize];
            
                [pcmData appendData: rawPCM];
            }
        }else{
           NSLog(@"AAC Decoder Fail %d !!",ret);
        }
        
        free(outBuffer);
        
        if (_delegate && [_delegate respondsToSelector:@selector(aacDecoderOutputBuffer:size:)]) {
            [_delegate aacDecoderOutputBuffer:(void *)pcmData.bytes size:(int)pcmData.length];
        }
        
        return pcmData;
    }
    return nil;
}


@end
