#import "GPUImagePicture.h"

@implementation GPUImagePicture

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithURL:(NSURL *)url;
{
    NSData *imageData = [[NSData alloc] initWithContentsOfURL:url];
    
    if (!(self = [self initWithData:imageData]))
    {
        return nil;
    }
    
    return self;
}

- (id)initWithData:(NSData *)imageData;
{
    UIImage *inputImage = [[UIImage alloc] initWithData:imageData];
    
    if (!(self = [self initWithImage:inputImage]))
    {
		return nil;
    }
    
    return self;
}

- (id)initWithImage:(UIImage *)newImageSource;
{
    if (!(self = [self initWithImage:newImageSource smoothlyScaleOutput:NO]))
    {
		return nil;
    }
    
    return self;
}

- (id)initWithCGImage:(CGImageRef)newImageSource;
{
    if (!(self = [self initWithCGImage:newImageSource smoothlyScaleOutput:NO]))
    {
		return nil;
    }
    return self;
}

- (id)initWithImage:(UIImage *)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput;
{
    return [self initWithCGImage:[newImageSource CGImage] smoothlyScaleOutput:smoothlyScaleOutput];
}

- (id)initWithCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    hasProcessedImage = NO;
    self.shouldSmoothlyScaleOutput = smoothlyScaleOutput;
    // 图片更新信号,起始是可用状态
    // 保证同时只有一个图片更新
    imageUpdateSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_signal(imageUpdateSemaphore);


    // TODO: Dispatch this whole thing asynchronously to move image loading off main thread
    CGFloat widthOfImage = CGImageGetWidth(newImageSource);
    CGFloat heightOfImage = CGImageGetHeight(newImageSource);

    // If passed an empty image reference, CGContextDrawImage will fail in future versions of the SDK.
    NSAssert( widthOfImage > 0 && heightOfImage > 0, @"Passed image must not be empty - it should be at least 1px tall and wide");
    
    pixelSizeOfImage = CGSizeMake(widthOfImage, heightOfImage);
    CGSize pixelSizeToUseForTexture = pixelSizeOfImage;
    
    BOOL shouldRedrawUsingCoreGraphics = NO;
    
    // For now, deal with images larger than the maximum texture size by resizing to be within that limit
    CGSize scaledImageSizeToFitOnGPU = [GPUImageContext sizeThatFitsWithinATextureForSize:pixelSizeOfImage];
    if (!CGSizeEqualToSize(scaledImageSizeToFitOnGPU, pixelSizeOfImage))
    {
        pixelSizeOfImage = scaledImageSizeToFitOnGPU;
        pixelSizeToUseForTexture = pixelSizeOfImage;
        
        // 资源宽高太大，就用core graphic重绘
        shouldRedrawUsingCoreGraphics = YES;
    }
    
    if (self.shouldSmoothlyScaleOutput)
    {
        // In order to use mipmaps, you need to provide power-of-two textures, so convert to the next largest power of two and stretch to fill
        CGFloat powerClosestToWidth = ceil(log2(pixelSizeOfImage.width));
        CGFloat powerClosestToHeight = ceil(log2(pixelSizeOfImage.height));
        
        // 转换为2的n次幂的大小
        pixelSizeToUseForTexture = CGSizeMake(pow(2.0, powerClosestToWidth), pow(2.0, powerClosestToHeight));
        
        shouldRedrawUsingCoreGraphics = YES;
    }
    
    GLubyte *imageData = NULL;
    CFDataRef dataFromImageDataProvider = NULL;
    GLenum format = GL_BGRA;
    
    if (!shouldRedrawUsingCoreGraphics) {
        /* Check that the memory layout is compatible with GL, as we cannot use glPixelStore to
         * tell GL about the memory layout with GLES.
         */
        // 保证图片格式是正确的
        if (CGImageGetBytesPerRow(newImageSource) != CGImageGetWidth(newImageSource) * 4 || // 每个像素是否是4字节
            CGImageGetBitsPerPixel(newImageSource) != 32 || // 每个像素是否是32bit
            CGImageGetBitsPerComponent(newImageSource) != 8) // 每个构件是否是8bit
        {
            shouldRedrawUsingCoreGraphics = YES;
        } else {
            /* Check that the bitmap pixel format is compatible with GL */
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(newImageSource);
            if ((bitmapInfo & kCGBitmapFloatComponents) != 0) {
                /* We don't support float components for use directly in GL */
                // 如果是float component就重绘
                shouldRedrawUsingCoreGraphics = YES;
            } else {
                CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
                if (byteOrderInfo == kCGBitmapByteOrder32Little) {
                    /* Little endian, for alpha-first we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedFirst && alphaInfo != kCGImageAlphaFirst &&
                        alphaInfo != kCGImageAlphaNoneSkipFirst) {
                        shouldRedrawUsingCoreGraphics = YES;
                    }
                } else if (byteOrderInfo == kCGBitmapByteOrderDefault || byteOrderInfo == kCGBitmapByteOrder32Big) {
                    /* Big endian, for alpha-last we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedLast && alphaInfo != kCGImageAlphaLast &&
                        alphaInfo != kCGImageAlphaNoneSkipLast) {
                        shouldRedrawUsingCoreGraphics = YES;
                    } else {
                        /* Can access directly using GL_RGBA pixel format */
                        format = GL_RGBA;
                    }
                }
            }
        }
    }
    
    //    CFAbsoluteTime elapsedTime, startTime = CFAbsoluteTimeGetCurrent();
    
    if (shouldRedrawUsingCoreGraphics)
    {
        // For resized or incompatible image: redraw
        imageData = (GLubyte *) calloc(1, (int)pixelSizeToUseForTexture.width * (int)pixelSizeToUseForTexture.height * 4);
        
        CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef imageContext = CGBitmapContextCreate(imageData, (size_t)pixelSizeToUseForTexture.width, (size_t)pixelSizeToUseForTexture.height, 8, (size_t)pixelSizeToUseForTexture.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        //        CGContextSetBlendMode(imageContext, kCGBlendModeCopy); // From Technical Q&A QA1708: http://developer.apple.com/library/ios/#qa/qa1708/_index.html
        CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, pixelSizeToUseForTexture.width, pixelSizeToUseForTexture.height), newImageSource);
        CGContextRelease(imageContext);
        CGColorSpaceRelease(genericRGBColorspace);
    }
    else
    {
        // Access the raw image bytes directly
        dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(newImageSource));
        imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    }
    
    //    elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0;
    //    NSLog(@"Core Graphics drawing time: %f", elapsedTime);
    
    //    CGFloat currentRedTotal = 0.0f, currentGreenTotal = 0.0f, currentBlueTotal = 0.0f, currentAlphaTotal = 0.0f;
    //	NSUInteger totalNumberOfPixels = round(pixelSizeToUseForTexture.width * pixelSizeToUseForTexture.height);
    //
    //    for (NSUInteger currentPixel = 0; currentPixel < totalNumberOfPixels; currentPixel++)
    //    {
    //        currentBlueTotal += (CGFloat)imageData[(currentPixel * 4)] / 255.0f;
    //        currentGreenTotal += (CGFloat)imageData[(currentPixel * 4) + 1] / 255.0f;
    //        currentRedTotal += (CGFloat)imageData[(currentPixel * 4 + 2)] / 255.0f;
    //        currentAlphaTotal += (CGFloat)imageData[(currentPixel * 4) + 3] / 255.0f;
    //    }
    //
    //    NSLog(@"Debug, average input image red: %f, green: %f, blue: %f, alpha: %f", currentRedTotal / (CGFloat)totalNumberOfPixels, currentGreenTotal / (CGFloat)totalNumberOfPixels, currentBlueTotal / (CGFloat)totalNumberOfPixels, currentAlphaTotal / (CGFloat)totalNumberOfPixels);
    
    runSynchronouslyOnVideoProcessingQueue(^{
        
        // 使用图片处理上下文
        [GPUImageContext useImageProcessingContext];
        
        // 得到可用的frame buffer
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:pixelSizeToUseForTexture onlyTexture:YES];
        [outputFramebuffer disableReferenceCounting];

        // 绑定纹理到framebuffer中
        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        if (self.shouldSmoothlyScaleOutput)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        }
        // no need to use self.outputTextureOptions here since pictures need this texture formats and type
        // 导入数据到纹理
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)pixelSizeToUseForTexture.width, (int)pixelSizeToUseForTexture.height, 0, format, GL_UNSIGNED_BYTE, imageData);
        
        if (self.shouldSmoothlyScaleOutput)
        {
            glGenerateMipmap(GL_TEXTURE_2D);
        }
        // 解除纹理的当前使用
        glBindTexture(GL_TEXTURE_2D, 0);
    });
    
    if (shouldRedrawUsingCoreGraphics)
    {
        free(imageData);
    }
    else
    {
        if (dataFromImageDataProvider)
        {
            CFRelease(dataFromImageDataProvider);
        }
    }
    
    return self;
}

// ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
- (void)dealloc;
{
    [outputFramebuffer enableReferenceCounting];
    [outputFramebuffer unlock];

#if !OS_OBJECT_USE_OBJC
    if (imageUpdateSemaphore != NULL)
    {
        dispatch_release(imageUpdateSemaphore);
    }
#endif
}

#pragma mark -
#pragma mark Image rendering

- (void)removeAllTargets;
{
    [super removeAllTargets];
    hasProcessedImage = NO;
}

- (void)processImage;
{
    [self processImageWithCompletionHandler:nil];
}

- (BOOL)processImageWithCompletionHandler:(void (^)(void))completion;
{
    hasProcessedImage = YES;
    
    //    dispatch_semaphore_wait(imageUpdateSemaphore, DISPATCH_TIME_FOREVER);
    
    // 等待图片更新
    if (dispatch_semaphore_wait(imageUpdateSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return NO;
    }
    
    runAsynchronouslyOnVideoProcessingQueue(^{        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setCurrentlyReceivingMonochromeInput:NO];
            [currentTarget setInputSize:pixelSizeOfImage atIndex:textureIndexOfTarget];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            // 通知下一个filter
            [currentTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureIndexOfTarget];
        }
        
        // 设置更新完毕
        dispatch_semaphore_signal(imageUpdateSemaphore);
        
        if (completion != nil) {
            completion();
        }
    });
    
    return YES;
}

- (void)processImageUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(UIImage *processedImage))block;
{
    [finalFilterInChain useNextFrameForImageCapture];
    [self processImageWithCompletionHandler:^{
        // 从output中获取图片，base中的实现是空的
        UIImage *imageFromFilter = [finalFilterInChain imageFromCurrentFramebuffer];
        block(imageFromFilter);
    }];
}

- (CGSize)outputImageSize;
{
    return pixelSizeOfImage;
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    
    if (hasProcessedImage)
    {
        [newTarget setInputSize:pixelSizeOfImage atIndex:textureLocation];
        [newTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureLocation];
    }
}

@end
