//
//  KSStickersFilter.m
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/11/30.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "KSStickersFilter.h"

NSString *const kKSStickerFragmentShaderString = SHADER_STRING
(
 precision lowp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform float intensity;
 uniform vec3 firstColor;
 uniform vec3 secondColor;
 
 const mediump vec3 luminanceWeighting = vec3(0.2125, 0.7154, 0.0721);
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);


@implementation KSStickersFilter

- (instancetype)initWithStickers:(NSArray*)stickers
{
    self = [super initWithFragmentShaderFromString:kKSStickerFragmentShaderString];
    if (self) {
        
    }
    return self;
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    // 处理中间数据
    [self renderToTextureWithVertices:imageVertices textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
    
    // 通知下一个filter
    [self informTargetsAboutNewFrameAtTime:frameTime];
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    // 使用本filter Program
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    // 创建包含纹理对象的outputFrameBuffer
    // 每一个filter都用新的framebuffer
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    
    // 激活framebuffer，下面的绘制将会绘制到这里
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    // 清除屏幕
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 使用纹理，将上一个framebuffer作为纹理绘制到当前的framebuffer
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    // 设置filterInputTextureUniform的值
    glUniform1i(filterInputTextureUniform, 2);
    
    // 设置filterPositionAttribute和filterTextureCoordinateAttribute的值
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 解除当前纹理的绑定
//    glBindTexture(GL_TEXTURE_2D, 0);
    
    GLfloat imageVertices[] = {
        -0.5f, -0.5f,
        0.5f, -0.5f,
        -0.5f,  0.5f,
        0.5f,  0.5f,
    };
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

@end
