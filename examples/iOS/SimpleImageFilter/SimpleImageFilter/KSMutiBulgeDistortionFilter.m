//
//  KSMutiBulgeDistortionFilter.m
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/12/3.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "KSMutiBulgeDistortionFilter.h"

@implementation KSMutiBulgeDistortionFilter

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
    
    // TODO
    for (KSBulgeItem *item in self.items) {
        self.center = item.center;
        self.radius = item.radius;
        self.scale = item.scale;
        
        
    }
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture) {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

@end
