//
//  PCStackNavigationController.h
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import <UIKit/UIKit.h>

#pragma mark forward declarations

// Forward declare delegate protocol
@protocol PCStackNavigationControllerDelegate;

// Forward declare PCViewController
@class PCViewController;


@interface PCStackNavigationController : UIViewController <UIGestureRecognizerDelegate>

#pragma mark PCStackNavigationController properties

// View controller at the bottom of the stack. Revealed when sliding rootViewController (first pushed to stack)
@property (nonatomic, strong) PCViewController *bottomViewController;

// Returns the topmost view controller
@property (nonatomic, strong) PCViewController *visibleViewController;

// Array of view controllers in current stack
@property (nonatomic, strong) NSMutableArray *viewControllers;

// Stack nav delegate receives
@property (nonatomic, strong) id<PCStackNavigationControllerDelegate> delegate;


#pragma mark PCStackNavigationController methods

// Push a view controller to the stack
- (void)pushViewController:(PCViewController *)viewController animated:(BOOL)animated;

// Pop the top view controller off the stack
- (void)popViewControllerAnimated:(BOOL)animated;

// Pop to the root view controller
- (void)popToRootViewController:(BOOL)animated;

// Pop to a specific view controller on the stack
- (void)popToViewController:(PCViewController *)viewController animated:(BOOL)animated;

@end


#pragma mark PCStackNavigationControllerDelegate protocol declaration

@protocol PCStackNavigationControllerDelegate <NSObject>

// Called before a view controller is pushed to the stack
- (void)navigationController:(PCStackNavigationController *)navigationController willShowViewController:(PCViewController *)viewController animated:(BOOL)animated;

// Called after a view controller has been pushed to the stack
- (void)navigationController:(PCStackNavigationController *)navigationController didShowViewController:(PCViewController *)viewController animated:(BOOL)animated;

@end
