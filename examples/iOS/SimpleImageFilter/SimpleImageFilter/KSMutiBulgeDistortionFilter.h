//
//  KSMutiBulgeDistortionFilter.h
//  SimpleImageFilter
//
//  Created by zhongchao.han on 15/12/3.
//  Copyright © 2015年 Cell Phone. All rights reserved.
//

#import "GPUImageBulgeDistortionFilter.h"

@interface KSBulgeItem : NSObject

// 膨胀的位置,默认(0.5, 0.5)
@property(readwrite, nonatomic) CGPoint center;
// 膨胀的半径，默认0.25，0到1之间
@property(readwrite, nonatomic) CGFloat radius;
// 扭转的程度，默认0.5，-1.0到1.0之间
@property(readwrite, nonatomic) CGFloat scale;

@end

@implementation KSBulgeItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _center = CGPointMake(0.5, 0.5);
        _radius = 0.25;
        _scale = 0.5;
    }
    return self;
}
@end

@interface KSMutiBulgeDistortionFilter : GPUImageBulgeDistortionFilter

@property(nonatomic, strong) NSMutableArray *items;

@end
