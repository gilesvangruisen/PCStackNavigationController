//
//  PCStackNavigationController.h
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PCStackNavigationControllerDelegate;

@class PCViewController;

@interface PCStackNavigationController : UIViewController <UIGestureRecognizerDelegate>

// View controller at the bottom of the stack. Revealed when sliding rootViewController (first pushed to stack)
@property (nonatomic, strong) PCViewController *bottomViewController;

// Returns the topmost view controller
@property (nonatomic, readonly, strong) PCViewController *visibleViewController;

// Array of view controllers in current stack
@property (nonatomic, strong) NSMutableArray *viewControllers;

@property (nonatomic, strong) UIView *topBar;

@property (nonatomic, strong) id<PCStackNavigationControllerDelegate> delegate;

@property (nonatomic, assign) CGFloat rootViewControllerUpperBound;
@property (nonatomic, assign) CGFloat rootViewControllerLowerBound;

@property (nonatomic) BOOL trackingEnabled;

- (void)pushViewController:(PCViewController *)viewController animated:(BOOL)animated;
- (void)popViewControllerAnimated:(BOOL)animated;
- (void)popToRootViewController:(BOOL)animated;
- (void)popToViewController:(PCViewController *)viewController animated:(BOOL)animated;

@end

@protocol PCStackNavigationControllerDelegate <NSObject>

@end
