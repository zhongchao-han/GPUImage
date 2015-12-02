//
//  KSImagePicture.h
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/12/1.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "GPUImage.h"

@interface KSImagePicture : GPUImagePicture

/**
 * 图片在render buffer中的位置
 * 注意：坐标系和UIView 的相同
 */
@property(nonatomic, assign) CGRect frame;

@end
