//
//  ViewController.m
//  ImageToVideo
//
//  Created by 刘东旭 on 2017/9/3.
//  Copyright © 2017年 刘东旭. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

@interface ViewController ()

{
    NSMutableArray *imageArr;//未压缩的图片
    NSMutableArray *imageArray;//经过压缩的图片
}

@property (nonatomic, strong) NSString *theVideoPath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    imageArray = [[NSMutableArray alloc] init];
    imageArr =[[NSMutableArray alloc]initWithObjects:
               [UIImage imageNamed:@"1"],[UIImage imageNamed:@"2"],[UIImage imageNamed:@"3"],[UIImage imageNamed:@"4"],[UIImage imageNamed:@"5"],[UIImage imageNamed:@"6"],[UIImage imageNamed:@"0"],nil];
    
    for (int i = 0; i<imageArr.count; i++) {
        UIImage *imageNew = imageArr[i];
        //设置image的尺寸
        CGSize imagesize = imageNew.size;
        imagesize.height =480;
        imagesize.width =320;
        //对图片大小进行压缩--
        imageNew = [self imageWithImage:imageNew scaledToSize:imagesize];
        [imageArray addObject:imageNew];
    }
    
    UIButton * button =[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setFrame:CGRectMake(100,100, 100,50)];
    [button setTitle:@"视频合成"forState:UIControlStateNormal];
    [button addTarget:self action:@selector(testCompressionSession)forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor redColor];
    [self.view addSubview:button];
    
    UIButton * button1 =[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button1 setFrame:CGRectMake(100,200, 100,50)];
    [button1 setTitle:@"视频播放"forState:UIControlStateNormal];
    [button1 addTarget:self action:@selector(playAction)forControlEvents:UIControlEventTouchUpInside];
    button1.backgroundColor = [UIColor redColor];
    [self.view addSubview:button1];
}

//对图片尺寸进行压缩--

-(UIImage*)imageWithImage:(UIImage*)image scaledToSize:(CGSize)newSize
{
    //    新创建的位图上下文 newSize为其大小
    UIGraphicsBeginImageContext(newSize);
    //    对图片进行尺寸的改变
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    //    从当前上下文中获取一个UIImage对象  即获取新的图片对象
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // Return the new image.
    return newImage;
}

-(void)testCompressionSession
{
    //设置mov路径
    NSArray *paths =NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *moviePath =[[paths objectAtIndex:0]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov",@"test"]];
    self.theVideoPath=moviePath;
    
    //定义视频的大小320 480 倍数
    CGSize size =CGSizeMake(320,480);
    
    //        [selfwriteImages:imageArr ToMovieAtPath:moviePath withSize:sizeinDuration:4 byFPS:30];//第2中方法
    
    NSError *error =nil;
    //    转成UTF-8编码
    unlink([moviePath UTF8String]);
    NSLog(@"path->%@",moviePath);
    //     iphone提供了AVFoundation库来方便的操作多媒体设备，AVAssetWriter这个类可以方便的将图像和音频写成一个完整的视频文件
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:moviePath] fileType:AVFileTypeQuickTimeMovie error:&error];
    
    NSParameterAssert(videoWriter);
    if(error)
        NSLog(@"error =%@", [error localizedDescription]);
    //mov的格式设置 编码格式 宽度 高度
    NSDictionary *videoSettings =[NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264,AVVideoCodecKey,
                                  [NSNumber numberWithInt:size.width],AVVideoWidthKey,
                                  [NSNumber numberWithInt:size.height],AVVideoHeightKey,nil];
    
    AVAssetWriterInput *writerInput =[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary*sourcePixelBufferAttributesDictionary =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB],kCVPixelBufferPixelFormatTypeKey,nil];
//    AVAssetWriterInputPixelBufferAdaptor提供CVPixelBufferPool实例,
//    可以使用分配像素缓冲区写入输出文件。使用提供的像素为缓冲池分配通常
//    是更有效的比添加像素缓冲区分配使用一个单独的池
    AVAssetWriterInputPixelBufferAdaptor *adaptor =[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    if ([videoWriter canAddInput:writerInput])
    {
        NSLog(@"11111");
    }
    else
    {
        NSLog(@"22222");
    }
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
//合成多张图片为一个视频文件
    dispatch_queue_t dispatchQueue =dispatch_queue_create("mediaInputQueue",NULL);
    int __block frame =0;
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        //写入时的逻辑：将数组中的每一张图片多次写入到buffer中，
        while([writerInput isReadyForMoreMediaData])
        {//数组中一共7张图片此时写入490次
            if(++frame >=[imageArray count]*imageArray.count*10)
            {
                [writerInput markAsFinished];
                [videoWriter finishWriting];
                //              [videoWriterfinishWritingWithCompletionHandler:nil];
                break;
            }
            CVPixelBufferRef buffer =NULL;
            //每张图片写入70次换下一张
            int idx =frame/(imageArray.count*10);
            NSLog(@"idx==%d",idx);
            //将图片转成buffer
            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[imageArray objectAtIndex:idx] CGImage] size:size];
            
            if (buffer)
            {//添加buffer并设置每个buffer出现的时间，每个buffer的出现时间为第n张除以30（30是一秒30张图片，帧率，也可以自己设置其他值）所以为frame/30，即CMTimeMake(frame,30)为每一个buffer出现的时间点
                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,30)])//设置每秒钟播放图片的个数
                {
                    NSLog(@"FAIL");
                }
                else
                {
                    NSLog(@"OK");
                }
                
                CFRelease(buffer);
            }
        }
    }];
    
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size {
    NSDictionary *options =[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    CVPixelBufferRef pxbuffer =NULL;
    CVReturn status =CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef) options,&pxbuffer);
    
    NSParameterAssert(status ==kCVReturnSuccess && pxbuffer !=NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer,0);
    
    void *pxdata =CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata !=NULL);
    CGColorSpaceRef rgbColorSpace=CGColorSpaceCreateDeviceRGB();
//    当你调用这个函数的时候，Quartz创建一个位图绘制环境，也就是位图上下文。当你向上下文中绘制信息时，Quartz把你要绘制的信息作为位图数据绘制到指定的内存块。一个新的位图上下文的像素格式由三个参数决定：每个组件的位数，颜色空间，alpha选项
    CGContextRef context =CGBitmapContextCreate(pxdata,size.width,size.height,8,4*size.width,rgbColorSpace,kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);
//使用CGContextDrawImage绘制图片  这里设置不正确的话 会导致视频颠倒
//    当通过CGContextDrawImage绘制图片到一个context中时，如果传入的是UIImage的CGImageRef，因为UIKit和CG坐标系y轴相反，所以图片绘制将会上下颠倒
    CGContextDrawImage(context,CGRectMake(0,0,CGImageGetWidth(image),CGImageGetHeight(image)), image);
// 释放色彩空间
    CGColorSpaceRelease(rgbColorSpace);
// 释放context
    CGContextRelease(context);
// 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(pxbuffer,0);
    
    return pxbuffer;
}

//播放
-(void)playAction
{
    NSLog(@"************%@",self.theVideoPath);
    NSURL *sourceMovieURL = [NSURL fileURLWithPath:self.theVideoPath];
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:sourceMovieURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.frame = self.view.layer.bounds;
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerLayer];
    [player play];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
