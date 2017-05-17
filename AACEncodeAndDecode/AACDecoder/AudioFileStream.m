//
//  AudioFileStream.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "AudioFileStream.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 10

@interface AudioFileStream ()

@property (nonatomic) SInt64 dataOffset;
@property (nonatomic) NSTimeInterval packetDuration;
@property (nonatomic) UInt64 processedPacketsCount;
@property (nonatomic) UInt64 processedPacketsSizeTotal;

@property (nonatomic) AudioFileStreamID audioFileStreamID;
@property (nonatomic) AudioStreamBasicDescription format;
@property (nonatomic) AudioFileTypeID fileType;
@property (nonatomic) UInt64 fileSize;

- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins;
@end

@implementation AudioFileStream

#pragma init & dealloc
- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(UInt64)fileSize {
    if (self = [super init]) {
        _fileType = fileType;
        _fileSize = fileSize;
    }
    return self;
}

- (void)dealloc {
    [self closeAudioFileStream];
}


#pragma mark - open & close
- (BOOL)openAudioFileStream {
    OSStatus status = AudioFileStreamOpen((__bridge void *)self,
                                          AudioFileStreamPropertyListener,
                                          AudioFileStreamPacketsCallBack,
                                          _fileType,
                                          &_audioFileStreamID);
    
    if (status != noErr) {
        _audioFileStreamID = NULL;
    }
    return status == noErr;
}

- (void)closeAudioFileStream {
    if (_audioFileStreamID != NULL) {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}

- (BOOL)parseData:(NSData *)data error:(NSError **)error {
    if (_audioFileStreamID == NULL) {
        return NO;
    }
    
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID,
                                                (UInt32)[data length],
                                                [data bytes],
                                                0);
    
    if (status != noErr) {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                     code:status
                                 userInfo:nil];
    }
    
    return status == noErr;
}

#pragma mark - static callbacks
static void AudioFileStreamPropertyListener(void *inClientData,
                                            AudioFileStreamID inAudioFileStream,
                                            AudioFileStreamPropertyID inPropertyID,
                                            UInt32 *ioFlags)
{
    AudioFileStream *audioFileStream = (__bridge AudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamProperty:inPropertyID];
}

static void AudioFileStreamPacketsCallBack(void *inClientData,
                                           UInt32 inNumberBytes,
                                           UInt32 inNumberPackets,
                                           const void *inInputData,
                                           AudioStreamPacketDescription *inPacketDescriptions)
{
    AudioFileStream *audioFileStream = (__bridge AudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamPackets:inInputData
                                    numberOfBytes:inNumberBytes
                                  numberOfPackets:inNumberPackets
                               packetDescriptions:inPacketDescriptions];
}

#pragma mark - callbacks
- (void)calculateBitRate {
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketsSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}

- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID {
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
        
        UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID,
                                                     kAudioFileStreamProperty_PacketSizeUpperBound,
                                                     &sizeOfUInt32,
                                                     &_maxPacketSize);
        
        if (status != noErr || _maxPacketSize == 0) {
            AudioFileStreamGetProperty(_audioFileStreamID,
                                       kAudioFileStreamProperty_MaximumPacketSize,
                                       &sizeOfUInt32,
                                       &_maxPacketSize);
        }
        
        if (_delegate && [_delegate respondsToSelector:@selector(audioFileStreamReadyToProducePackets:)]) {
            [_delegate audioFileStreamReadyToProducePackets:self];
        }
    }
    else if (propertyID == kAudioFileStreamProperty_DataOffset) {
        UInt32 offsetSize = sizeof(_dataOffset);
        AudioFileStreamGetProperty(_audioFileStreamID,
                                   kAudioFileStreamProperty_DataOffset,
                                   &offsetSize,
                                   &_dataOffset);
    }
    else if (propertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 asbdSize = sizeof(_format);
        AudioFileStreamGetProperty(_audioFileStreamID,
                                   kAudioFileStreamProperty_DataFormat,
                                   &asbdSize,
                                   &_format);
    }
    else if (propertyID == kAudioFileStreamProperty_FormatList) {
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID,
                                                         kAudioFileStreamProperty_FormatList,
                                                         &formatListSize,
                                                         &outWriteable);
        
        if (status == noErr) {
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID,
                                                         kAudioFileStreamProperty_FormatList,
                                                         &formatListSize,
                                                         formatList);
            if (status == noErr) {
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs,
                                                    0,
                                                    NULL,
                                                    &supportedFormatsSize);
                if (status != noErr) {
                    free(formatList);
                    return;
                }
                
                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs,
                                                0,
                                                NULL,
                                                &supportedFormatsSize,
                                                supportedFormats);
                if (status != noErr) {
                    free(formatList);
                    free(supportedFormats);
                    return;
                }
                
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i ++) {
                    AudioStreamBasicDescription format = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; ++j) {
                        if (format.mFormatID == supportedFormats[j]) {
                            _format = format;
                            break;
                        }
                    }
                }
                free(supportedFormats);
            }
            free(formatList);
        }
    }
}

- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins {
    
    if (numberOfBytes == 0 || numberOfPackets == 0) { return; }
    
    BOOL deletePackDesc = NO;
    if (packetDescriptioins == NULL) {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        AudioStreamPacketDescription *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
        
        for (int i = 0; i < numberOfPackets; i++) {
            UInt32 packetOffset = packetSize * i;
            descriptions[i].mStartOffset = packetOffset;
            descriptions[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets - 1) {
                descriptions[i].mDataByteSize = numberOfBytes - packetOffset;
            }else {
                descriptions[i].mDataByteSize = packetSize;
            }
        }
        packetDescriptioins = descriptions;
    }
    
    NSMutableData *parsedData = [NSMutableData dataWithCapacity:0];
    for (int i = 0; i < numberOfPackets; ++i) {
        SInt64 packetOffset = packetDescriptioins[i].mStartOffset;
        const void *bytes = packets + packetOffset;
        NSUInteger length = packetDescriptioins[i].mDataByteSize;
        
        NSData *data = [NSData dataWithBytes:bytes length: length];
        [parsedData appendData:data];
        
        if (_processedPacketsCount < BitRateEstimationMaxPackets) {
            _processedPacketsSizeTotal += packetDescriptioins[i].mDataByteSize;
            _processedPacketsCount += 1;
            [self calculateBitRate];
        }
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(audioFileStream:audioDataParsed:)]) {
        [_delegate audioFileStream:self audioDataParsed:parsedData];
    }
    
    if (deletePackDesc) {
        free(packetDescriptioins);
    }
}


@end
