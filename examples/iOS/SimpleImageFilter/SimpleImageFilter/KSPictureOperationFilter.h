//
//  KSPictureOperationFilter.h
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/12/1.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "GPUImage.h"

/**
 * 绘制图片的filter
 */
@interface KSPictureOperationFilter : GPUImageFilter

@property(nonatomic, strong, readonly) NSMutableArray *pictures;

@end
