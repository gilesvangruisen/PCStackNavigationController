//
//  PCStackNavigationController.h
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import <UIKit/UIKit.h>


#pragma mark forward declarations

// Forward declare stack view controller protocol
@protocol PCStackViewController;

// Forward declare delegate protocol
@protocol PCStackNavigationControllerDelegate;

@interface PCStackNavigationController : UIViewController <UIGestureRecognizerDelegate>

#pragma mark PCStackNavigationController properties

// View controller at the bottom of the stack. Revealed when sliding rootViewController (first pushed to stack)
@property (nonatomic, strong) UIViewController<PCStackViewController> *bottomViewController;

// Returns the topmost view controller
@property (nonatomic, strong) UIViewController<PCStackViewController> *visibleViewController;

// Array of view controllers in current stack
@property (nonatomic, strong) NSMutableArray *viewControllers;

// Stack nav delegate receives
@property (nonatomic, strong) id<PCStackNavigationControllerDelegate> delegate;


#pragma mark PCStackNavigationController methods

// Push a view controller to the stack
- (void)pushViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated;

// Pop the top view controller off the stack
- (void)popViewControllerAnimated:(BOOL)animated;

// Pop to the root view controller
- (void)popToRootViewController:(BOOL)animated;

// Pop to a specific view controller on the stack
- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated;

@end


#pragma mark PCStackNavigationControllerDelegate protocol declaration

@protocol PCStackNavigationControllerDelegate <NSObject>

@optional

// Called before a view controller is pushed to the stack
- (void)navigationController:(PCStackNavigationController *)navigationController willShowViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated;

// Called after a view controller has been pushed to the stack
- (void)navigationController:(PCStackNavigationController *)navigationController didShowViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated;

@end


#pragma mark PCStackViewController protocol declaration

@protocol PCStackViewController <NSObject>

@required

// Returns the stack controller to which the view controller belongs
@property (nonatomic, strong) PCStackNavigationController *stackController;

// Returns the index of the view controller
@property (nonatomic) NSInteger *stackIndex;

@end

