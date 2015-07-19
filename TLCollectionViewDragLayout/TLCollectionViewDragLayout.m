//
//  TLCollectionViewDragLayout.m
//  UICollectionView
//
//  Created by andezhou on 15/7/17.
//  Copyright (c) 2015年 andezhou. All rights reserved.
//

#import "TLCollectionViewDragLayout.h"
#import <objc/runtime.h>

static NSString * const kTLCollectionViewKeyPath = @"collectionView";
static NSString * const kTLScrollingDirectionKey = @"kTLScrollingDirectionKey";
static NSString * const kTLDisplayLinkUserInfoPath = @"kTLDisplayLinkUserInfoPath";

CGPoint TLCGPointAdd(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}

typedef NS_ENUM(NSInteger, TLScrollingDirection) {
    kTLScrollingDirectionUnknown = 0,
    kTLScrollingDirectionUp,
    kTLScrollingDirectionDown,
    kTLScrollingDirectionLeft,
    kTLScrollingDirectionRight
};

@interface UICollectionViewCell (TLCollectionViewDragLayout)

- (UIView *)snapshotView;

@end

@implementation UICollectionViewCell (TLCollectionViewDragLayout)

- (UIView *)snapshotView {
    if ([self respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)]) {
        return [self snapshotViewAfterScreenUpdates:YES];
    } else {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0f);
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return [[UIImageView alloc] initWithImage:image];
    }
}

@end

@interface CADisplayLink (TLCollectionViewDragLayout)

@property (strong, nonatomic) NSDictionary *userInfo;

@end

@implementation CADisplayLink (TLCollectionViewDragLayout)

- (void)setUserInfo:(NSDictionary *)userInfo {
    objc_setAssociatedObject(self, (__bridge const void *)(kTLDisplayLinkUserInfoPath), userInfo, OBJC_ASSOCIATION_RETAIN);
}

- (NSDictionary *)userInfo {
    return objc_getAssociatedObject(self, (__bridge const void *)(kTLDisplayLinkUserInfoPath));
}

@end

@interface TLCollectionViewDragLayout () <UIGestureRecognizerDelegate>

@property (nonatomic, assign) CGPoint startPoint;

@property (nonatomic, strong) UIView *currentView;
@property (nonatomic, assign) CGPoint currentViewCenter;
@property (nonatomic, assign) CGPoint translationPoint;
@property (nonatomic, strong) NSIndexPath *selectedItemIndexPath;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;

@property (strong, nonatomic) CADisplayLink *displayLink;

@property (nonatomic, assign, readonly) id<TLReorderCollectionViewDataSource> dataSource;
@property (nonatomic, assign, readonly) id<TLReorderCollectionViewDelegateFlowLayout> delegate;

@end

@implementation TLCollectionViewDragLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:kTLCollectionViewKeyPath options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self addObserver:self forKeyPath:kTLCollectionViewKeyPath options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:kTLCollectionViewKeyPath];
}

- (id<TLReorderCollectionViewDataSource>)dataSource {
    return (id<TLReorderCollectionViewDataSource>)self.collectionView.dataSource;
}

- (id<TLReorderCollectionViewDelegateFlowLayout>)delegate {
    return (id<TLReorderCollectionViewDelegateFlowLayout>)self.collectionView.delegate;
}

- (void)addGestureRecognizer {
    self.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressed:)];
    self.longPressGesture.delegate = self;
    [self.collectionView addGestureRecognizer:self.longPressGesture];
    
    // 遍历UIScrollView自带手势
    for (UIGestureRecognizer *gestureRecognizer in self.collectionView.gestureRecognizers) {
        if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            // 设定当self.longPressGesture失败后才执行UIScrollView自带长按手势
            [gestureRecognizer requireGestureRecognizerToFail:self.longPressGesture];
        }
    }
}

#pragma mark -
#pragma mark UILongPressGestureRecognizer
- (void)handleLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        [self touchesBegan:gestureRecognizer];
        
    } else if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        
        [self touchesMoved:gestureRecognizer];
        
    } else {
        [self touchesEnded:gestureRecognizer];
    }
}

// 拖拽开始
- (void)touchesBegan:(UILongPressGestureRecognizer *)gestureRecognizer {
    self.startPoint = [gestureRecognizer locationInView:self.collectionView];
    self.selectedItemIndexPath = [self.collectionView indexPathForItemAtPoint:self.startPoint];
    
    // 判断点击的cell能否移动
    if ([self.dataSource respondsToSelector:@selector(collectionView:canMoveItemAtIndexPath:)] && ![self.dataSource collectionView:self.collectionView canMoveItemAtIndexPath:self.selectedItemIndexPath]) {
        return;
    }
    
    // 点击的cell将要移动时
    if ([self.delegate respondsToSelector:@selector(collectionView:layout:willBeginDraggingItemAtIndexPath:)]) {
        [self.delegate collectionView:self.collectionView layout:self didBeginDraggingItemAtIndexPath:self.selectedItemIndexPath
         ];
    }
    
    UICollectionViewCell *collectionViewCell = [self.collectionView cellForItemAtIndexPath:self.selectedItemIndexPath];
    self.currentView = [[UIView alloc] initWithFrame:collectionViewCell.frame];
    self.currentViewCenter = self.currentView.center;
    
    collectionViewCell.highlighted = YES;
    UIView *highlightedImageView = [collectionViewCell snapshotView];
    highlightedImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    highlightedImageView.alpha = 1.0f;
    
    collectionViewCell.highlighted = NO;
    UIView *imageView = [collectionViewCell snapshotView];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.alpha = 0.0f;

    [self.currentView addSubview:imageView];
    [self.currentView addSubview:highlightedImageView];
    [self.collectionView addSubview:self.currentView];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:.3 animations:^{
        weakSelf.currentView.transform = CGAffineTransformMakeScale(1.15, 1.15);
        highlightedImageView.alpha = 0.0f;
        imageView.alpha = 1.0f;
    }
    completion:^(BOOL finished) {
        [highlightedImageView removeFromSuperview];

        if ([weakSelf.delegate respondsToSelector:@selector(collectionView:layout:didBeginDraggingItemAtIndexPath:)]) {
            [weakSelf.delegate collectionView:weakSelf.collectionView layout:weakSelf didBeginDraggingItemAtIndexPath:weakSelf.selectedItemIndexPath];
        }
    }];
    
    [self invalidateLayout];
}

// 拖拽移动
- (void)touchesMoved:(UILongPressGestureRecognizer *)gestureRecognizer {
    // 调整被拖拽按钮的center， 保证它根手指一起滑动
    CGPoint newPoint = [gestureRecognizer locationInView:self.collectionView];
    self.translationPoint = CGPointMake(newPoint.x - self.startPoint.x, newPoint.y - self.startPoint.y);
    CGPoint viewCenter = self.currentView.center = TLCGPointAdd(self.currentViewCenter, self.translationPoint);
    
    // 当currentView移动的时候，重新给CollectionView布局
    [self collectionViewLayoutIfNeed];
    
    if (self.scrollDirection == UICollectionViewScrollDirectionVertical) {
        if (viewCenter.y <= self.collectionView.contentOffset.y + CGRectGetHeight(self.currentView.bounds)/2.0) {
            [self setupScrollTimerInDirection:kTLScrollingDirectionUp];
            NSLog(@"向上移动");
        } else if (viewCenter.y >=  CGRectGetMaxY(self.collectionView.frame) - CGRectGetHeight(self.currentView.bounds)/2.0) {
            NSLog(@"向下移动");
            [self setupScrollTimerInDirection:kTLScrollingDirectionDown];
        } else {
            NSLog(@"正常移动");
            [self invalidatesScrollTimer];
        }
    }
    
    [self invalidateLayout];
}

// 拖拽结束
- (void)touchesEnded:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    NSIndexPath *currentIndexPath = self.selectedItemIndexPath;

    if ([self.delegate respondsToSelector:@selector(collectionView:layout:willEndDraggingItemAtIndexPath:)]) {
        [self.delegate collectionView:self.collectionView layout:self willEndDraggingItemAtIndexPath:currentIndexPath];
    }
    
    self.selectedItemIndexPath = nil;
    self.currentViewCenter = CGPointZero;
    UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForItemAtIndexPath:currentIndexPath];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:.3 animations:^{
        weakSelf.currentView.transform = CGAffineTransformIdentity;
        weakSelf.currentView.center = layoutAttributes.center;
    }
    completion:^(BOOL finished) {
        [weakSelf.currentView removeFromSuperview];
        weakSelf.currentView = nil;
        [weakSelf invalidateLayout];
        
        if ([weakSelf.delegate respondsToSelector:@selector(collectionView:layout:didEndDraggingItemAtIndexPath:)]) {
            [weakSelf.delegate collectionView:weakSelf.collectionView layout:weakSelf didEndDraggingItemAtIndexPath:currentIndexPath];
        }
    }];
    
    [self invalidatesScrollTimer];
}

- (void)collectionViewLayoutIfNeed {
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:self.currentView.center];
    NSIndexPath *previousIndexPath = self.selectedItemIndexPath;
    
    if ([newIndexPath isEqual:previousIndexPath] || nil == newIndexPath) {
        return;
    }
    
    if ([self.dataSource respondsToSelector:@selector(collectionView:itemAtIndexPath:canMoveToIndexPath:)] &&
        ![self.dataSource collectionView:self.collectionView itemAtIndexPath:previousIndexPath canMoveToIndexPath:newIndexPath]) {
        return;
    }
    
    self.selectedItemIndexPath = newIndexPath;
    if ([self.dataSource respondsToSelector:@selector(collectionView:itemAtIndexPath:willMoveToIndexPath:)]) {
        [self.dataSource collectionView:self.collectionView itemAtIndexPath:previousIndexPath willMoveToIndexPath:newIndexPath];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.collectionView performBatchUpdates:^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf.collectionView deleteItemsAtIndexPaths:@[previousIndexPath]];
        [strongSelf.collectionView insertItemsAtIndexPaths:@[newIndexPath]];
    }
    completion:^(BOOL finished) {
        __strong typeof(self) strongSelf = weakSelf;
        if ([strongSelf.dataSource respondsToSelector:@selector(collectionView:itemAtIndexPath:didMoveToIndexPath:)]) {
            [strongSelf.dataSource collectionView:strongSelf.collectionView itemAtIndexPath:previousIndexPath didMoveToIndexPath:newIndexPath];
        }
    }];
}

- (void)setupScrollTimerInDirection:(TLScrollingDirection)direction {
    if (!self.displayLink.paused) {
        TLScrollingDirection oldDirection = [self.displayLink.userInfo[kTLScrollingDirectionKey] integerValue];
        
        if (direction == oldDirection) {
            return;
        }
    }
    
    [self invalidatesScrollTimer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
    self.displayLink.userInfo = @{kTLScrollingDirectionKey : @(direction)};
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)handleScroll:(CADisplayLink *)displayLink {
    TLScrollingDirection direction = (TLScrollingDirection)[displayLink.userInfo[kTLScrollingDirectionKey] integerValue];
    if (direction == kTLScrollingDirectionUnknown) {
        return;
    }
    
    CGSize frameSize = self.collectionView.bounds.size;
    CGSize contentSize = self.collectionView.contentSize;
    CGPoint contentOffset = self.collectionView.contentOffset;
    UIEdgeInsets contentInset = self.collectionView.contentInset;

    CGFloat distance = rint(200 * displayLink.duration);
    CGPoint translation = CGPointZero;
    
    switch(direction) {
        case kTLScrollingDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f - contentInset.top;
            
            if ((contentOffset.y + distance) <= minY) {
                distance = -contentOffset.y - contentInset.top;
            }
            
            translation = CGPointMake(0.0f, distance);
        }
            break;
            
        case kTLScrollingDirectionDown: {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            
            translation = CGPointMake(0.0f, distance);
        }
            break;
            
        case kTLScrollingDirectionLeft:
        case kTLScrollingDirectionRight:
        default:
            break;
    }
    
    self.currentViewCenter = TLCGPointAdd(self.currentViewCenter, translation);
    self.currentView.center = TLCGPointAdd(self.currentViewCenter, self.translationPoint);
    self.collectionView.contentOffset = TLCGPointAdd(contentOffset, translation);
}

- (void)invalidatesScrollTimer {
    if (!self.displayLink.paused) {
        [self.displayLink invalidate];
    }
    self.displayLink = nil;
}

#pragma mark - Key-Value Observing methods
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kTLCollectionViewKeyPath]) {
        if (nil != self.collectionView) {
            [self addGestureRecognizer];
        }
    }
}

#pragma mark - UICollectionViewLayout methods
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *layoutAttributes = [super layoutAttributesForItemAtIndexPath:indexPath];
    
    if (layoutAttributes.representedElementCategory == UICollectionElementCategoryCell) {
        [self applyLayoutAttributes:layoutAttributes];
    }
    
    return layoutAttributes;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSArray *array = [super layoutAttributesForElementsInRect:rect];
    
    for (UICollectionViewLayoutAttributes *layoutAttributes in array) {
        if (layoutAttributes.representedElementCategory == UICollectionElementCategoryCell) {
            [self applyLayoutAttributes:layoutAttributes];
        }
    }
    
    return array;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    if ([layoutAttributes.indexPath isEqual:self.selectedItemIndexPath]) {
        layoutAttributes.hidden = YES;
    }
}

@end
