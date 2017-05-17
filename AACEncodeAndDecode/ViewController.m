//
//  ViewController.m
//  AACEncodeAndDecode
//
//  Created by 刘金桥 on 2017/3/24.
//  Copyright © 2017年 JQJoe. All rights reserved.
//

#import "ViewController.h"
#import "AudioSource.h"
#import "AACEncoder.h"
#import "AACDecoder.h"
#import "AudioFileStream.h"
#import "PCMPlayer.h"

@interface ViewController ()<AudioSourceDelegate, AACEncoderDelegate, AACDecoderDelegate, AudioFileStreamDelegate>

@property (nonatomic, strong) AudioSource *audioSource;
@property (nonatomic, strong) AACEncoder  *aacEncoder;
@property (nonatomic, strong) AACDecoder  *aacDecoder;
@property (nonatomic, strong) AudioFileStream *audioFileStream;
@property (nonatomic, strong) PCMPlayer *pcmPlayer;

@property (nonatomic) int channelCount;
@property (nonatomic) int sampleRate;

@property (nonatomic) FILE *aacFp;
@property (nonatomic) FILE *pcmFp;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _channelCount = 2;
    _sampleRate = 44100;
    
//    _channelCount = 1;
//    _sampleRate = 8000;
    
    self.audioSource = [[AudioSource alloc] initWithSampleRate:_sampleRate channels:_channelCount];
    self.audioSource.delegate = self;
    
    self.aacEncoder = [[AACEncoder alloc] initAACEncoderWithSampleRate:_sampleRate channels:_channelCount];
    self.aacEncoder.delegate = self;
    
    self.aacDecoder = [[AACDecoder alloc] initAACDecoderWithSampleRate:_sampleRate channels:_channelCount];
    self.aacDecoder.delegate = self;
    
    self.audioFileStream = [[AudioFileStream alloc] initWithFileType:kAudioFileAAC_ADTSType fileSize:0 ];
    self.audioFileStream.delegate = self;
    
    self.pcmPlayer = [[PCMPlayer alloc] initWithSampleRate:_sampleRate channels:_channelCount];
}

- (IBAction)btnClick:(id)sender {
    UIButton *btn = (UIButton *)sender;
    btn.selected = !btn.selected;
    if (btn.selected) {
        [btn setTitle:@"Stop" forState:UIControlStateSelected];
        [self start];
    }else {
        [btn setTitle:@"Start" forState:UIControlStateNormal];
        [self stop];
    }
}

- (void)start {
    [_audioSource start];
    [_audioFileStream openAudioFileStream];
    
    //存储测试文件
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    
    NSString *pcmPath = [documentsPath stringByAppendingPathComponent: @"test.pcm"];
    const char *cPcmPath = [pcmPath cStringUsingEncoding:NSUTF8StringEncoding];
    _pcmFp = fopen(cPcmPath, "wb+");
    
    NSString *aacPath = [documentsPath stringByAppendingPathComponent: @"test.aac"];
    const char *cAacPath = [aacPath cStringUsingEncoding:NSUTF8StringEncoding];
    _aacFp = fopen(cAacPath, "wb+");
}

- (void)stop {
    [_audioSource stop];
    [_audioFileStream closeAudioFileStream];
    
    // 存储测试文件关闭
    if (_pcmFp != NULL) {
        fclose(_pcmFp);
        _pcmFp = NULL;
    }
    
    // 存储测试文件关闭
    if (_aacFp != NULL) {
        fclose(_aacFp);
        _aacFp = NULL;
    }
}

// audioSource Delegate
- (void)audioSourceOutputBuffer:(void *)pcmBuf size:(int)pcmSize {
    
    // 对麦克风输出的pcm进行AAC编码
    [_aacEncoder encodeWithPcmBuf: pcmBuf pcmLen: pcmSize];
}

// AAC encoder Delegate
- (void)aacEncoderOutputBuffer:(void *)aacBuf size:(int)aacSize {
    
    NSData *aacData = [NSData dataWithBytes:aacBuf length:aacSize];
    [_audioFileStream parseData: aacData error: nil];   // 把AAC_ADTS转成rawAAC
    
    if (_aacFp && aacSize > 0) {
        fwrite(aacBuf, aacSize, 1, _aacFp);
        printf("aac length: %lu \n",(unsigned long)aacSize);
    }
}

// AAC decoder Delegate
- (void)aacDecoderOutputBuffer:(void *)pcmBuf size:(int)pcmSize {
    
    [_pcmPlayer playAudioWithPcmBuf:pcmBuf pcmSize:pcmSize];
    
    if (_pcmFp && pcmSize > 0) {
        fwrite(pcmBuf, pcmSize, 1, _pcmFp);
        printf("pcm length: %lu \n",(unsigned long)pcmSize);
    }
}

// AudioFileStream Delegate
- (void)audioFileStream:(AudioFileStream *)audioFileStream audioDataParsed:(NSData *)audioData {
    // 解码rawAAC
    [_aacDecoder decodeWithAACBuf:(void *)audioData.bytes aacLen:(int)audioData.length];
}

@end
