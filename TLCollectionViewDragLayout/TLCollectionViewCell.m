//
//  CollectionViewCell.m
//  UICollectionView
//
//  Created by andezhou on 15/7/17.
//  Copyright (c) 2015年 andezhou. All rights reserved.
//

#import "TLCollectionViewCell.h"

@implementation TLCollectionViewCell

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

- (void)awakeFromNib {
    self.label.backgroundColor = [self getColor];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.label.alpha = highlighted ? 0.75f : 1.0f;
}

- (UIColor *)getColor {
    CGFloat red = arc4random() % 256;
    CGFloat green = arc4random() % 256;
    CGFloat blue = arc4random() % 256;
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:1];
}

@end
