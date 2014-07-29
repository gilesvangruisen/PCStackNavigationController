//
//  PCStackNavigationController.m
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCStackNavigationController.h"
#import <pop/POP.h>

@implementation PCStackNavigationController

#define SPRING_BOUNCINESS 4
#define SPRING_SPEED 4
#define DISMISS_VELOCITY_THRESHOLD 150

#pragma mark initialization

- (id)init
{
    self = [super init];
    if (self) {

        // Set stack nav background to transparent
        self.view.backgroundColor = [UIColor clearColor];

        // Init gesture recognizer, add it to view, set gesture delegate to self
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [self.view addGestureRecognizer:panGestureRecognizer];
        panGestureRecognizer.delegate = self;

    }

    return self;
}

- (UIViewController<PCStackViewController> *)visibleViewController
{
    // Visible view controller is last childViewController
    return [self.childViewControllers lastObject];
}

- (NSInteger)currentIndex
{
    // Current index is index of last childViewController (count - 1)
    return self.childViewControllers.count - 1;
}

- (void)setBottomViewController:(UIViewController<PCStackViewController> *)bottomViewController
{

    // Set _bottomViewController because custom setter
    _bottomViewController = bottomViewController ? bottomViewController : nil;

    // Set PCStackViewController properties on bottomViewController
    _bottomViewController.stackController = self;
    _bottomViewController.stackIndex = 0;

    // Prepend bottomViewController to viewController, add as subview
    [self addChildViewController:_bottomViewController];
    [self.view insertSubview:_bottomViewController.view atIndex:0];
    [_bottomViewController didMoveToParentViewController:self];

    // bottomViewController now contained by self
    [self.bottomViewController didMoveToParentViewController:self];

}

- (void)centerView:(UIView *)view onGesture:(UIPanGestureRecognizer *)gesture {
    // Static variable originalCenter
    static CGPoint originalCenter;

    // Remove any animations
    [view.layer pop_removeAllAnimations];

    // Set initial start center only on began
    if (gesture.state == UIGestureRecognizerStateBegan) {
        originalCenter = view.center;
    }

    // Calculate new center based on original + translation
    CGFloat newCenterY = originalCenter.y + [gesture translationInView:self.view].y;
    view.center = CGPointMake(originalCenter.x, newCenterY);
}

- (void)centerView:(UIView *)view onPoint:(CGPoint)point withDuration:(CGFloat)duration easing:(UIViewAnimationOptions)viewAnimationOptions {
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState|
     UIViewAnimationOptionAllowUserInteraction|
     viewAnimationOptions
                     animations:^{
                         view.center = point;
                     } completion:NULL];
}

#pragma mark Pan Gesture



- (void)panGestureRecognizer:(UIPanGestureRecognizer *)gesture
{
    // Static variables set only on UIGestureRecognizerStateBegan
    static UIViewController<PCStackViewController> *viewController;
    static CGPoint originalCenter;
    static BOOL gestureIsNavigational = false;

    switch (gesture.state) {

        // Gesture just began, determine angle from velocity
        // Enable interaction, disable scroll if gesture is vertical and (if applicable) only scroll view offset is 0
        case UIGestureRecognizerStateBegan: {
            originalCenter = [gesture locationInView:self.view];

            // Find the right view controller
            NSEnumerator *childViewControllerEnumerator = [self.childViewControllers reverseObjectEnumerator];
            UIViewController<PCStackViewController> *childViewController;
            while(childViewController = [childViewControllerEnumerator nextObject]) {
                if ([self gesture:gesture canNavigateViewController:childViewController]) {
                    viewController = childViewController;
                    gestureIsNavigational = true;
                    break;
                }
            }

            if (gestureIsNavigational) {

                // Gesture is indeed navigational
                // Set static originalCenter
                originalCenter = viewController.view.center;

                // Disable scroll if visible view is scroll view
//                [self disableScrollIfScrollView];

                [self centerView:viewController.view onGesture:gesture];

            }

            break;
        }

        case UIGestureRecognizerStateChanged: {
            if (gestureIsNavigational) {

                // Gesture is indeed navigational, handle gesture
                [self centerView:viewController.view onGesture:gesture];

            }

            break;
        }

        case UIGestureRecognizerStateEnded: {

            if (gestureIsNavigational) {

                // Gesture is indeed navigational, handle gesture ended
                [self handleNavigationGestureEnded:gesture withOriginalCenter:originalCenter viewController:viewController];
                viewController = nil;

            }

            break;
        }
    }
}

- (void)handleNavigationGestureEnded:(UIPanGestureRecognizer *)gesture withOriginalCenter:(CGPoint)originalCenter viewController:(UIViewController <PCStackViewController> *)viewController
{
    // Grab velocity and location from gesture
    CGPoint velocity = [gesture velocityInView:self.view];

    // Spring animation
    POPSpringAnimation *springAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    springAnimation.springBounciness = SPRING_BOUNCINESS;
    springAnimation.springSpeed = SPRING_SPEED;
    springAnimation.velocity = @(velocity.y);

    if (velocity.y > DISMISS_VELOCITY_THRESHOLD && viewController.stackIndex <= 0) {

        // Velocity is positive and above threshold (downward "dismiss card" swipe)
        // Check index and presence of bottom vc

        if (self.bottomViewController) {

            // Bottom view controller exists, reveal it (w/ 80 px of vc still showing)
            springAnimation.toValue = @((self.view.frame.size.height * 1.5) - 80);

        } else {

            // No bottomViewController, return to visible center
            springAnimation.toValue = @(self.view.center.y);

        }

    } else if (velocity.y > DISMISS_VELOCITY_THRESHOLD && viewController.stackIndex > 0) {

        // Dismiss view gesture, send it off screen
        springAnimation.toValue = @(self.view.frame.size.height * 1.5);

        // On completion, remove from superview
        springAnimation.completionBlock = ^(POPAnimation *animation, BOOL completed) {

            if (completed) {
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
            }

        };

    } else {

        // Velocity is negative and below threshold (upward "throw" swipe)
        springAnimation.toValue = @(self.view.center.y);

    }

    [viewController.view.layer pop_addAnimation:springAnimation forKey:@"stackNav.navigate"];

}


#pragma mark Push/Pop

- (void)pushViewController:(UIViewController<PCStackViewController> *)incomingViewController animated:(BOOL)animated {

    // Incoming needs to know its index and stack controller
    incomingViewController.stackIndex = self.childViewControllers.count;
    incomingViewController.stackController = self;

    // Add child view controller to self (calls willMoveToParent)
    [self addChildViewController:incomingViewController];

    if (animated) {

        // Animated, ensure initial frame is offscreen
        CGRect offScreenFrame = incomingViewController.view.frame;
        offScreenFrame.origin.y = self.view.frame.size.height;
        incomingViewController.view.frame = offScreenFrame;

        // Add incoming as subview
        [self.view addSubview:incomingViewController.view];

        // Build spring animation to animate incoming into view
        POPSpringAnimation *springEnterAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
        springEnterAnimation.springBounciness = SPRING_BOUNCINESS;
        springEnterAnimation.springSpeed = SPRING_SPEED;
        springEnterAnimation.toValue = @(self.view.center.y);

        // Add spring enter animation to incoming view controller
        [incomingViewController.view.layer pop_addAnimation:springEnterAnimation forKey:@"stackNav.enter"];

    } else {

        // Add incoming to view controller stack
        [self addChildViewController:incomingViewController];

        // Add incoming as visible subview
        [self.view addSubview:incomingViewController.view];

        [incomingViewController didMoveToParentViewController:self];

    }

    // Incoming moved to parent
    [incomingViewController didMoveToParentViewController:self];

}

- (void)popViewControllerAnimated:(BOOL)animated {

}

- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {

}

- (void)popToRootViewController:(BOOL)animated {

}

// Returns true if gesture passed is intended to be navigational (combination of axis, state of view controller, gesture being within bounds)
- (BOOL)gesture:(UIPanGestureRecognizer *)gesture canNavigateViewController:(UIViewController<PCStackViewController> *)viewController
{
    /*

     DETERMINING PRIMARY AXIS OF GESTURE (VERTICAL VS HORIZONTAL)

     Determine primary gesture axis by comparing absolute velocity on each axis
     If absolute velocity along y axis is greater than absolute velocity along x axis then gesture is primarily vertical
     If absolute velocity along x axis is greater than absolute velocity along y axis then gesture is primarily horizontal

     */

    // Grab velocity and location in view from gesture
    CGPoint gestureVelocity = [gesture velocityInView:self.view];
    CGPoint gestureLocation = [gesture locationInView:self.view];

    // will set to true if gesture is primarily vertical as noted above
    BOOL gestureIsNavigational = fabsf(gestureVelocity.y) > fabsf(gestureVelocity.x);

    // Check if visible view is scroll view and let that help determine if gesture is navigational
    if ([self visibleViewIsScrollView]) {

        // Visible view is scroll view, add isScrolledToTop to navigation boolean
        gestureIsNavigational = gestureIsNavigational && [self visibleViewIsScrolledToTop];

    }

    // Check that we're not trying to navigate the root view controller
    gestureIsNavigational = gestureIsNavigational && viewController.stackIndex > 0;

    // Check if original gesture position is inside visibleViewController's view frame and let hat help determine if gesture is navigational
    gestureIsNavigational = gestureIsNavigational && [self point:gestureLocation isWithinBounds:viewController.view.frame];

    return gestureIsNavigational;
}

- (BOOL)point:(CGPoint)point isWithinBounds:(CGRect)bounds
{
    BOOL pointWithinHorizontalBounds = point.x >= bounds.origin.x && point.x <= bounds.origin.x + bounds.size.width;
    BOOL pointWithinVerticalBounds = point.y >= bounds.origin.y && point.y <= bounds.origin.y + bounds.size.height;

    return pointWithinHorizontalBounds && pointWithinVerticalBounds;
}

- (BOOL)visibleViewIsScrollView
{
    // Returns true if visible view is scroll view
    return [[self visibleViewController].view isKindOfClass:[UIScrollView class]];
}

- (BOOL)visibleViewIsScrolledToTop
{

    // Check if visible view is scroll view or subclass thereof
    if ([[self visibleViewController].view isKindOfClass:[UIScrollView class]]) {

        // Cast visible view into scrollView to be able to check contentOffset
        UIScrollView *scrollView = (UIScrollView *)[self visibleViewController].view;

        // Returns true if scroll view is scrolled to top
        return scrollView.contentOffset.y <= 0;

    } else {

        // Not scroll view ergo cannot be scrolled to top
        return false;

    }
}

#pragma mark etc.

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
