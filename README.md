# ImageToVideo
核心代码为，给AVAssetWriterInput加一个适配器对象这样就可以写入PixelBuffer，之后将图片转成PixelBuffer写入即可
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
    以下为图片转buffer
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
