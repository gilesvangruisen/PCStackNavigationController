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

// Stack nav delegate
@property (nonatomic, strong) id<PCStackNavigationControllerDelegate> delegate;

// Returns the index of visible view controller in the stack, also equal to the size of the stack itself
@property (nonatomic) NSInteger currentIndex;

// View controller at the bottom of the stack
@property (nonatomic, weak) UIViewController<PCStackViewController> *bottomViewController;

// Returns the top (i.e. last) view controller in viewControllers
- (UIViewController<PCStackViewController> *)topViewController;

#pragma mark PCStackNavigationController methods

// Push a view controller to the stack
- (void)pushViewController:(UIViewController<PCStackViewController> *)incomingViewController animated:(BOOL)animated;

// Pop the top view controller off the stack
- (void)popViewControllerAnimated:(BOOL)animated;

// Pop to the root view controller
- (void)popToRootViewController:(BOOL)animated;

// Pop to a specific view controller on the stack
- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated;

// Call and pass a view controller and optional completion block to return that view controller to its resting position
- (void)returnViewControllerToRestingCenter:(UIViewController <PCStackViewController> *)viewController completion:(void(^)())completion;

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
@property (nonatomic) NSInteger stackIndex;


@optional

// If implemented, the view controller will only be navigable w/ a gesture on this view
@property (nonatomic, strong) UIView *navigationHandle;

// If implemented, this will be called when the view controller is about to reappear
// on the stack after the view controller above it was popped
- (void)viewWillReappear:(BOOL)animated;

// If implemented, this will be called immediately before the view controller
// begins animating downward and if false spring stops around halfway.
// Note that returning false does NOT return the view controller to visibility. (see returnViewControllerToRestingCenter:completion:)
- (BOOL)shouldPopAnimated:(BOOL)animated;

// If implemented, this method will be called on a view controller being pushed
// or the new top view controller after another has been popped
- (void)updateStatusBar;

// If implemented, this method will determine whether or not a navigation
// gesture will have any affect on the implementing view controller, true to
// allow, false to disable
- (BOOL)allowsNavigation;

@end
