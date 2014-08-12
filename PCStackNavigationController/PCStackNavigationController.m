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

#define SPRING_BOUNCINESS 1
#define SPRING_SPEED 6
#define DISMISS_VELOCITY_THRESHOLD 150


#pragma mark initialization

- (id)init {
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


- (UIViewController<PCStackViewController> *)topViewController {
    // Visible view controller is last childViewController
    return [self.childViewControllers lastObject];
}


- (NSInteger)currentIndex {
    // Current index is index of last childViewController (count - 1)
    return self.childViewControllers.count - 1;
}


- (void)setBottomViewController:(UIViewController<PCStackViewController> *)bottomViewController {

    // Set _bottomViewController because custom setter
    _bottomViewController = bottomViewController ? bottomViewController : nil;

    // Set PCStackViewController properties on bottomViewController
    _bottomViewController.stackController = self;
    _bottomViewController.stackIndex = 0;

    // Prepend bottomViewController to viewController, add as subview
    [self addChildViewController:_bottomViewController];
    [self.view insertSubview:_bottomViewController.view atIndex:0];
    [_bottomViewController didMoveToParentViewController:self];

    [self updateStatusBarWithViewController:_bottomViewController];

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

- (void)panGestureRecognizer:(UIPanGestureRecognizer *)gesture {
    // Static variables set only on UIGestureRecognizerStateBegan
    static UIViewController<PCStackViewController> *viewController;
    static CGPoint originalCenter;
    static BOOL gestureIsNavigational = false;

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wswitch"

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
                [self disableScrollView:viewController.view];

                [self centerView:viewController.view onGesture:gesture];

            }

            break;
        }

        case UIGestureRecognizerStateChanged: {
            if (gestureIsNavigational) {

                // Gesture is indeed navigational, handle gesture
                [self centerView:viewController.view onGesture:gesture];

                [self updateStatusBar];
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

        case UIGestureRecognizerStateCancelled: {

            if (gestureIsNavigational) {

                // Gesture is indeed navigational, handle gesture ended
                [self handleNavigationGestureEnded:gesture withOriginalCenter:originalCenter viewController:viewController];
                viewController = nil;

            }

            break;
        }
    }
    #pragma clang diagnostic pop

}


- (void)handleNavigationGestureEnded:(UIPanGestureRecognizer *)gesture withOriginalCenter:(CGPoint)originalCenter viewController:(UIViewController <PCStackViewController> *)viewController {
    // Grab velocity and location from gesture
    CGPoint velocity = [gesture velocityInView:self.view];

    // Spring animation
    POPSpringAnimation *springAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    springAnimation.springBounciness = SPRING_BOUNCINESS;
    springAnimation.springSpeed = SPRING_SPEED;
    springAnimation.velocity = @(velocity.y);
    springAnimation.completionBlock = ^(POPAnimation *animation, BOOL completed) {
        [self enableScrollView:viewController.view];
    };

    if (velocity.y > DISMISS_VELOCITY_THRESHOLD && viewController.stackIndex <= 0) {

        // Velocity is positive and above threshold (downward "dismiss card" swipe)
        // Check index and presence of bottom vc

        if (self.bottomViewController) {

            // Bottom view controller exists, reveal it (w/ 80 px of vc still showing)
            springAnimation.toValue = @((self.view.frame.size.height * 1.5) - 80);

        } else {

            // No bottomViewController, return to visible center
            springAnimation.toValue = @([self restingCenterForViewController:viewController].y);

        }

    } else if (velocity.y > DISMISS_VELOCITY_THRESHOLD && viewController.stackIndex > 0) {

        // Dismiss view gesture, send it off screen
        springAnimation.toValue = @(self.view.frame.size.height * 1.5);
        springAnimation.springBounciness = 0;

        // On completion, remove from superview and self
        springAnimation.completionBlock = ^(POPAnimation *animation, BOOL completed) {

            // Upon completion, re-enable scroll view
            [self enableScrollView:viewController.view];

            // Check that animation successfully completed (wasn't interrupted by another gesture)
            if (completed) {

                // Not interrupted, remove from super view and self
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
                [self.topViewController viewDidAppear:YES];

            }

        };

    } else {

        // Velocity is negative and below threshold (upward "throw" swipe)
        springAnimation.toValue = @([self restingCenterForViewController:viewController].y);

    }

    // Finally, add the animation to the viewController
    [viewController.view.layer pop_addAnimation:springAnimation forKey:@"stackNav.navigate"];
    [self updateStatusBar];
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

        // Set spring animation bounciness and speed to stackNav defaults
        springEnterAnimation.springBounciness = SPRING_BOUNCINESS;
        springEnterAnimation.springSpeed = SPRING_SPEED;

        // To value is resting center view incoming view controller
        springEnterAnimation.toValue = @([self restingCenterForViewController:incomingViewController].y);

        // Add spring enter animation to incoming view controller
        [incomingViewController.view.layer pop_addAnimation:springEnterAnimation forKey:@"stackNav.enter"];

    } else {

        // Add incoming to view controller stack
        [self addChildViewController:incomingViewController];

        // Not animated so make sure frame (spec. origin) is correct upon adding as subview
        CGRect viewFrame = incomingViewController.view.frame;
        viewFrame.origin.y = [self restingCenterForViewController:incomingViewController].y - (viewFrame.size.height / 2);

        // Set frame with proper origin
        incomingViewController.view.frame = viewFrame;

        // Add incoming as visible subview
        [self.view addSubview:incomingViewController.view];

        [incomingViewController didMoveToParentViewController:self];

    }

    // Incoming moved to parent
    [incomingViewController didMoveToParentViewController:self];

    [self updateStatusBarWithViewController:incomingViewController];

}


- (void)popViewControllerAnimated:(BOOL)animated {

    // Grab top view controller to be dismissed
    UIViewController<PCStackViewController> *viewController = self.topViewController;

    if (animated) {

        // Spring animation
        POPSpringAnimation *springAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
        springAnimation.springBounciness = 0;
        springAnimation.springSpeed = SPRING_SPEED;

        // Dismiss view gesture, send it off screen
        springAnimation.toValue = @(self.view.frame.size.height * 1.5);

        // On completion, remove from superview and self
        springAnimation.completionBlock = ^(POPAnimation *animation, BOOL completed) {

            // Upon completion, re-enable scroll view
            [self enableScrollView:viewController.view];

            // Check that animation successfully completed (wasn't interrupted by another gesture)
            if (completed) {

                // Not interrupted, remove from super view and self
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];

            }

        };

        // Add animation with key stackNav.dismiss so we know not to let the user navigate while it's dismissing
        [viewController.view pop_addAnimation:springAnimation forKey:@"stackNav.dismiss"];

    } else {

        // Remove from superview
        [viewController.view removeFromSuperview];

        // Remove from parent
        [viewController removeFromParentViewController];

    }
}


- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {

}


- (void)popToRootViewController:(BOOL)animated {

}


// Returns true if gesture passed is intended to be navigational (combination of axis, state of view controller, gesture being within bounds)
- (BOOL)gesture:(UIPanGestureRecognizer *)gesture canNavigateViewController:(UIViewController<PCStackViewController> *)viewController {
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
    if ([self viewIsScrollView:viewController.view]) {

        // View is scroll view, add isScrolledToTop if content taller than frame and velocity > 0
        if ([self scrollViewContentIsTallerThanFrame:viewController.view]) {
            gestureIsNavigational = gestureIsNavigational && [self scrollViewIsScrolledToTop:viewController.view] && gestureVelocity.y > 0;
        }
    }

    // Check if viewController implements allowsNavigation and include
    if ([viewController respondsToSelector:@selector(allowsNavigation)]) {
        gestureIsNavigational = gestureIsNavigational && [viewController allowsNavigation];
    }

    // Check if view controller view has pop_animation of key stackNav.dismiss and if so, don't allow nav
    gestureIsNavigational = gestureIsNavigational && ![[viewController.view pop_animationKeys] containsObject:@"stackNav.dismiss"];

    // Check that we're not trying to navigate the root view controller
    gestureIsNavigational = gestureIsNavigational && viewController.stackIndex > 0;

    // Check if original gesture position is inside visibleViewController's view frame and let hat help determine if gesture is navigational
    gestureIsNavigational = gestureIsNavigational && [self point:gestureLocation isWithinBounds:viewController.view.frame];

    return gestureIsNavigational;
}


- (BOOL)point:(CGPoint)point isWithinBounds:(CGRect)bounds {

    // point.x is between origin.x and corrected size.width (accounting for origin.x possibly not being 0)
    BOOL pointWithinHorizontalBounds = point.x >= bounds.origin.x && point.x <= bounds.origin.x + bounds.size.width;

    // point.y is between origin.y and corrected size.height (accounting for origin.y possibly not being 0)
    BOOL pointWithinVerticalBounds = point.y >= bounds.origin.y && point.y <= bounds.origin.y + bounds.size.height;

    // Combine and return bools
    return pointWithinHorizontalBounds && pointWithinVerticalBounds;
}


- (BOOL)viewIsScrollView:(UIView *)view {
    // Returns true if visible view is scroll view
    return [view isKindOfClass:[UIScrollView class]];
}


- (BOOL)scrollViewContentIsTallerThanFrame:(UIView *)view {

    // First ensure view is a scroll view
    if ([self viewIsScrollView:view]) {

        // View is scroll view, cast as such and return boolean height check
        UIScrollView *scrollView = (UIScrollView *)view;

        return scrollView.contentSize.height > scrollView.frame.size.height;

    } else {

        // Not a scroll view
        return false;

    }

}


- (void)disableScrollView:(UIView *)view {

    // First ensure view is scroll view
    if ([self viewIsScrollView:view]) {

        // View is scroll view, cast as such
        UIScrollView *scrollView = (UIScrollView *)view;

        // Scroll to top and disable
        scrollView.contentOffset = CGPointMake(0, 0);
        scrollView.scrollEnabled = false;

    }
}


- (void)enableScrollView:(UIView *)view {

    // First ensure view is scroll view
    if ([self viewIsScrollView:view]) {

        // View is scroll view, cast as such
        UIScrollView *scrollView = (UIScrollView *)view;

        // Enable scroll view
        scrollView.scrollEnabled = true;

    }
}


- (BOOL)scrollViewIsScrolledToTop:(UIView *)view {

    // First ensure view is scroll view
    if ([self viewIsScrollView:view]) {

        // View is scroll view, cast as such
        UIScrollView *scrollView = (UIScrollView *)view;

        // Returns true if scroll view is scrolled to top
        return scrollView.contentOffset.y <= 0;

    } else {

        // Not a scroll view
        return false;

    }
}


- (CGPoint)restingCenterForViewController:(UIViewController *)viewController {

    // Check the height of the viewController's view
    if (viewController.view.frame.size.height == self.view.frame.size.height) {

        // viewController.view's height matches self.view's height, resting center is self.view.center
        return self.view.center;

    } else {

        // viewController.view's height does not match self.view's height, we can assume only
        // other possibility is 20px smaller so resting center should account for status bar
        return CGPointMake(self.view.center.x, self.view.center.y + 10);

    }
}


- (void)updateStatusBarWithViewController:(UIViewController <PCStackViewController> *)viewController {

    // Ignore undeclared selector (only in this method) because we're checking for it before any call is made
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"

    // Check if view controller has implemented updateStatusBar
    if ([viewController respondsToSelector:@selector(updateStatusBar)]) {

        // View controller implements updateStatusBar, call it
        [viewController performSelector:@selector(updateStatusBar)];

    }

    #pragma clang diagnostic pop
}

- (void)updateStatusBar {

    // Get reverse enumerator for childViewControllers
    NSEnumerator *childViewControllerEnumerator = [self.childViewControllers reverseObjectEnumerator];

    // Empty childViewController to be set
    UIViewController<PCStackViewController> *childViewController;

    // Empty previousViewController to be set
    UIViewController<PCStackViewController> *previousViewController;

    // Enumerate!
    while(childViewController = [childViewControllerEnumerator nextObject]) {

        // Set previousViewController
        previousViewController = [self viewControllerBeforeViewController:childViewController];

        // Array of pop animation keys to check
        NSArray *popAnimationKeys = childViewController.view.layer.pop_animationKeys;

        if (popAnimationKeys.count > 0) {

            // There's an animation in progress, fetch it
            POPSpringAnimation *springAnimation = [childViewController.view.layer pop_animationForKey:popAnimationKeys[0]];

            // Check view controller is not on its way to resting
            if (![springAnimation.toValue isEqual:@([self restingCenterForViewController:childViewController].y)] && previousViewController) {

                // Not on the way to resting, use previous view controller
                childViewController = previousViewController;
                break;

            } else {

                // Either on its way to resting or no previousViewController, break and use current
                break;

            }

        } else if (childViewController.view.frame.origin.y > 20 && previousViewController) {


            // Revealing and previousViewController exists, use it and break
            childViewController = previousViewController;
            break;

        } else {

            // Not revealing or animating, break and use current
            break;

        }
    }

    if (childViewController) {
        // Update status bar with childViewController
        [self updateStatusBarWithViewController:childViewController];
    }
}


- (UIViewController<PCStackViewController> *)viewControllerBeforeViewController:(UIViewController<PCStackViewController> *)viewController {

    // Init empty previousViewController
    UIViewController<PCStackViewController> *previousViewController;

    // Index of previous view controller
    NSUInteger previousViewControllerIndex = [self.childViewControllers indexOfObject:viewController] - 1;

    // View controller is revealing previous
    if (self.childViewControllers.count > previousViewControllerIndex) {

        // View controller underneath exists, use it to update status bar
        previousViewController = [self.childViewControllers objectAtIndex:previousViewControllerIndex];

    }

    return previousViewController;
}


#pragma mark etc.

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end
