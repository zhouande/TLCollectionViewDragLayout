//
//  ViewController.m
//  UICollectionView
//
//  Created by andezhou on 15/7/15.
//  Copyright (c) 2015年 andezhou. All rights reserved.
//

#import "TLCollectionViewController.h"
#import "TLCollectionViewCell.h"
#import "TLCollectionViewDragLayout.h"

static NSString *identifier = @"UICollectionViewCellID";

@interface TLCollectionViewController ()

@property (nonatomic, strong) NSMutableArray *dataList;

@end

@implementation TLCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TLCollectionViewDragLayout";
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    self.dataList = [NSMutableArray array];
    for (NSInteger x = 0; x < 40; x ++) {
        [self.dataList addObject:@(x)];
    }

    // Do any additional setup after loading the view, typically from a nib.
}


#pragma mark -
#pragma mark UICollectionViewDatasoure
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataList.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TLCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];    
    cell.label.text = [NSString stringWithFormat:@"%@", self.dataList[indexPath.item]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"你选中了%zi", indexPath.row);
}

/*=======================此代理方法必须执行=======================*/
- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)fromIndexPath willMoveToIndexPath:(NSIndexPath *)toIndexPath {
    NSString *str = self.dataList[fromIndexPath.item];
    [self.dataList removeObjectAtIndex:fromIndexPath.item];
    [self.dataList insertObject:str atIndex:toIndexPath.item];
}
/*=======================此代理方法必须执行=======================*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
