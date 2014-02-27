//
//  PCStackNavigationController.h
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PCStackNavigationControllerDelegate;

@interface PCStackNavigationController : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIViewController *bottomViewController;
@property (nonatomic, readonly, strong) UIViewController *visibleViewController;
@property (nonatomic, strong) NSMutableArray *viewControllers;

@property (nonatomic, strong) UIView *topBar;

@property (nonatomic, strong) id<PCStackNavigationControllerDelegate> delegate;

@property (nonatomic, assign) CGFloat rootViewControllerUpperBound;
@property (nonatomic, assign) CGFloat rootViewControllerLowerBound;

- (id)initWithRootViewController:(UIViewController *)rootViewController;

@end

@protocol PCStackNavigationControllerDelegate <NSObject>

@end
