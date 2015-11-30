//
//  KSStickersFilter.h
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/11/30.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "GPUImage.h"

/**
 * 贴纸过滤器
 */
@interface KSStickersFilter : GPUImageFilter

/**
 * sticker的frame，单位是像素
 */
@property (nonatomic,strong) NSMutableArray *stickerFrames;

- (instancetype)initWithStickers:(NSArray*)stickers;

@end
