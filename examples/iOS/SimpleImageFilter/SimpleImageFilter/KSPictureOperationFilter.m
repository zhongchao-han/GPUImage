//
//  KSPictureOperationFilter.m
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/12/1.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "KSPictureOperationFilter.h"
#import "KSImagePicture.h"
#import "GPUImageOutput+KSAddtion.h"

NSString *const kKSDoNotingShaderString = SHADER_STRING(
                                                        precision lowp float;
                                                        
                                                        varying highp vec2 textureCoordinate;
                                                        
                                                        uniform sampler2D inputImageTexture; uniform float intensity;
                                                        uniform vec3 firstColor; uniform vec3 secondColor;
                                                        
                                                        const mediump vec3 luminanceWeighting = vec3(0.2125, 0.7154, 0.0721);
                                                        
                                                        void main() {
                                                            gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
                                                        });

@implementation KSPictureOperationFilter

- (instancetype)init {
    self = [super initWithFragmentShaderFromString:kKSDoNotingShaderString];
    if (self) {
        _pictures = NSMutableArray.array;
    }
    return self;
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices
                 textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering) {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache]
                         fetchFramebufferForSize:[self sizeOfFBO]
                         textureOptions:self.outputTextureOptions
                         onlyTexture:NO];
    
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture) {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue,
                 backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    glUniform1i(filterInputTextureUniform, 2);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0,
                          textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    GLboolean isBlend;
    glGetBooleanv(GL_BLEND, &isBlend);
    if (!isBlend) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    CGSize renderBufferSize = [self outputFrameSize];
    for (KSImagePicture *picture in self.pictures) {
        
        glBindTexture(GL_TEXTURE_2D, 0);
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, picture.pictureFrameBuffer.texture);
        
        GLfloat imageVertices[] = {
            picture.frame.origin.x/renderBufferSize.width - 1., picture.frame.origin.y/renderBufferSize.height - 1.,
            (picture.frame.origin.x+picture.frame.size.width)/renderBufferSize.width - 1., picture.frame.origin.y/renderBufferSize.height - 1.,
            picture.frame.origin.x/renderBufferSize.width - 1., (picture.frame.origin.y+picture.frame.size.height)/renderBufferSize.height - 1.,
            (picture.frame.origin.x+picture.frame.size.width)/renderBufferSize.width - 1., (picture.frame.origin.y+picture.frame.size.height)/renderBufferSize.height - 1.,
        };
        
        static const GLfloat noRotationTextureCoordinates[] = {
            0.0f, 0.0f,
            1.0f, 0.0f,
            0.0f, 1.0f,
            1.0f, 1.0f,
        };
        
        glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0,
                              imageVertices);
        glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0,
                              0, noRotationTextureCoordinates);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    if (!isBlend) {
        glDisable(GL_BLEND);
    }
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture) {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

@end
