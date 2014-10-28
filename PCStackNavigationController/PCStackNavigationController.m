//
//  PCStackNavigationController.m
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCStackNavigationController.h"
#import <pop/POP.h>

@interface PCStackNavigationController ()

@property (nonatomic, strong) UIView *snapshotView;

@end

@implementation PCStackNavigationController

typedef void(^completion_block)(POPAnimation *animation, BOOL completed);

#define SPRING_BOUNCINESS 1
#define SPRING_SPEED 3
#define DISMISS_VELOCITY_THRESHOLD 200
#define DOWN_SCALE 0.95
#define DOWN_OPACITY 0.5

#pragma mark initialization

- (id)init {
    self = [super init];
    if (self) {
        // Set stack nav background to transparent
        self.view.backgroundColor = [UIColor clearColor];

        // Init gesture recognizer, add it to view, set gesture delegate to self
        self.screenEdgePanGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(screenEdgePanGestureRecognizer:)];
        self.screenEdgePanGestureRecognizer.edges = UIRectEdgeLeft;
        [self.view addGestureRecognizer:self.screenEdgePanGestureRecognizer];
        self.screenEdgePanGestureRecognizer.delegate = self;
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


#pragma mark Pan Gesture

- (void)screenEdgePanGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)gesture {
    // Static variables set only on UIGestureRecognizerStateBegan
    static UIViewController<PCStackViewController> *viewController;
    static CGPoint originalCenter;
    static BOOL gestureIsNavigational = false;

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wswitch"

    switch (gesture.state) {

        // Gesture just began, determine angle from velocity
        // Find view controller, check navigability,
        case UIGestureRecognizerStateBegan: {
            originalCenter = [gesture locationInView:self.view];

            UIViewController<PCStackViewController> *childViewController;
            childViewController = self.topViewController;

            if ([self gesture:gesture canNavigateViewController:childViewController]) {
                // View controller is navigable
                viewController = childViewController;

                // Gesture is navigational
                gestureIsNavigational = true;

                // Disable interaction for now
                self.view.userInteractionEnabled = false;

                // Gesture is indeed navigational
                // Set static originalCenter
                originalCenter = viewController.view.center;

                // Set up snapshot view to be animated
                self.snapshotView = [viewController.view resizableSnapshotViewFromRect:viewController.view.bounds afterScreenUpdates:true withCapInsets:UIEdgeInsetsZero];
                self.snapshotView.frame = viewController.view.frame;
                [self.view addSubview:self.snapshotView];

                // Hide view controller's real view so as not to interfere with snapshot animation
                viewController.view.layer.opacity = 0;

                // Reposition controller's view.frame.origin.y according to gesture
                [self centerView:self.snapshotView onGesture:gesture];
            }  else {
                gestureIsNavigational = false;
            }

            break;
        }

        case UIGestureRecognizerStateChanged: {
            if (gestureIsNavigational) {
                // Gesture is indeed navigational, handle gesture
                [self centerView:self.snapshotView onGesture:gesture];

                CGFloat progress = [self trackingProgressWithPosition:self.snapshotView.center.x start:self.view.frame.size.width / 2 end:self.view.frame.size.width * 1.5];

                CGFloat newPrevOpacity = [self positionWithProgress:progress start:DOWN_OPACITY end:1];
                CGFloat newPrevScale = [self positionWithProgress:progress start:DOWN_SCALE end:1];

                [self updatePreviousViewWithOpacity:newPrevOpacity scale:newPrevScale animated:NO];

                [self updateStatusBar];
            }

            break;
        }

        case UIGestureRecognizerStateEnded: {

            if (gestureIsNavigational) {

                // Gesture is indeed navigational, handle gesture ended
                [self handleNavigationGestureEnded:gesture withOriginalCenter:originalCenter viewController:viewController];
                viewController = nil;
                self.view.userInteractionEnabled = true;

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


- (void)handleNavigationGestureEnded:(UIScreenEdgePanGestureRecognizer *)gesture withOriginalCenter:(CGPoint)originalCenter viewController:(UIViewController <PCStackViewController> *)viewController {
    // Grab velocity and location from gesture
    CGPoint velocity = [gesture velocityInView:self.view];

    // Prev view
    CGFloat newPrevOpacity;
    CGFloat newPrevScale;

    // Spring animation
    POPSpringAnimation *springAnimation;

    // Popability check
    BOOL shouldPop = [self shouldPopViewController:viewController animated:YES];

    UIViewController<PCStackViewController> *previousViewController = [self viewControllerBeforeViewController:viewController];

    if (velocity.x > DISMISS_VELOCITY_THRESHOLD && viewController.stackIndex > 0 && shouldPop == true) {

        if (previousViewController) {

            // See if we can send it a viewWillAppear so it knows it's about to appear again
            if ([previousViewController respondsToSelector:@selector(viewWillReappear:)]) {
                [previousViewController viewWillReappear:YES];
            }
        }

        // Should pop, animation should go off screen
        springAnimation = [self springDismissAnimationWithVelocity:velocity.x completion:^(POPAnimation *animation, BOOL completed) {
            // Re-enable UI after animation
            [self enableGesture];

            // Check that animation successfully completed (wasn't interrupted by another gesture)
            if (completed) {

                // Kill the snapshot view
                [self.snapshotView removeFromSuperview];
                self.snapshotView = nil;

                // Not interrupted, remove from super view and self
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
                [self.topViewController viewDidAppear:YES];
            }
        }];

        newPrevOpacity = 1;
        newPrevScale = 1;

        [self disableGesture];

        // Add the animation
        [self.snapshotView.layer pop_addAnimation:springAnimation forKey:@"stackNav.dismiss"];

    } else {

        newPrevOpacity = DOWN_OPACITY;
        newPrevScale = DOWN_SCALE;

        springAnimation = [self springEnterAnimationWithVelocity:velocity.x viewController:viewController completion:^(POPAnimation *animation, BOOL completed) {

            // Kill the snapshot view
            [self.snapshotView removeFromSuperview];
            self.snapshotView = nil;

            // Check a previous view controller exists
            if (previousViewController) {
                // Previous view controller exists, hide it!
                [previousViewController.view.layer pop_removeAllAnimations];
                previousViewController.view.layer.opacity = 0;

                viewController.view.layer.opacity = 1;
            }

            [self enableGesture];
        }];

        [self disableGesture];

        // Add the animation
        [self.snapshotView.layer pop_addAnimation:springAnimation forKey:@"stackNav.flick"];

    }

    if (newPrevScale && newPrevOpacity) {
        [self updatePreviousViewWithOpacity:newPrevOpacity scale:newPrevScale animated:YES];
    }

    [self updateStatusBar];
}



#pragma mark Push/Pop

- (void)pushViewController:(UIViewController<PCStackViewController> *)incomingViewController animated:(BOOL)animated {

    // Incoming needs to know its index and stack controller
    incomingViewController.stackIndex = self.childViewControllers.count;
    incomingViewController.stackController = self;

    // Add child view controller to self (calls willMoveToParent)
    [self addChildViewController:incomingViewController];

    // Incoming moved to parent
    [incomingViewController didMoveToParentViewController:self];

    if (animated) {

        // Disable UI during transition
        // TODO: maybe find a better solution that doesn't prevent immediate dismissal unless we want immediate dismissal for accident prevention
        [self disableGesture];

        // Animated, ensure initial frame is offscreen
        CGRect offScreenFrame = incomingViewController.view.frame;
        offScreenFrame.origin.x = self.view.frame.size.width;
        incomingViewController.view.frame = offScreenFrame;

        // Add incoming as subview
        [self.view addSubview:incomingViewController.view];

        // Build spring animation to animate incoming into view
        // Re-enable previous upon completion

        POPSpringAnimation *springEnterAnimation = [self springEnterAnimationWithVelocity:0 viewController:incomingViewController completion:^(POPAnimation *animation, BOOL completed) {
            [self enableGesture];

            // Grab previous view controller
            UIViewController<PCStackViewController> *previousViewController = [self viewControllerBeforeViewController:incomingViewController];

            // Check a previous view controller exists
            if (previousViewController) {

                // Previous view controller exists, hide it!
                [previousViewController.view.layer pop_removeAllAnimations];
                previousViewController.view.layer.opacity = 0;

            }
        }];

        // Add spring enter animation to incoming view controller
        [incomingViewController.view.layer pop_addAnimation:springEnterAnimation forKey:@"stackNav.enter"];

        [self updatePreviousViewWithOpacity:DOWN_OPACITY scale:DOWN_SCALE animated:YES];

    } else {

        // Not animated so make sure frame (spec. origin.y) is correct upon adding as subview
        CGRect viewFrame = incomingViewController.view.frame;
        viewFrame.origin.y = [self restingCenterForViewController:incomingViewController].y - (viewFrame.size.height / 2);

        // Set frame with proper origin
        incomingViewController.view.frame = viewFrame;

        // Add incoming as visible subview
        [self.view addSubview:incomingViewController.view];

        [incomingViewController didMoveToParentViewController:self];

        [self updatePreviousViewWithOpacity:0 scale:DOWN_SCALE animated:NO];

    }

    [self updateStatusBarWithViewController:incomingViewController];

}


- (void)popViewControllerAnimated:(BOOL)animated {

    // Grab top view controller to be dismissed
    UIViewController<PCStackViewController> *viewController = self.topViewController;

    // Get the view controller below it too
    NSInteger belowIndex = self.topViewController.stackIndex - 1;

    if (belowIndex >= 0) {
        UIViewController<PCStackViewController> *belowViewController = [self.childViewControllers objectAtIndex:belowIndex];

        // See if we can send it a viewWillAppear so it knows it's about to appear again
        if ([belowViewController respondsToSelector:@selector(viewWillReappear:)]) {
            [belowViewController viewWillReappear:YES];
        }
    }

    BOOL shouldPop = [self shouldPopViewController:viewController animated:animated];

    if (animated && shouldPop) {

        // Disable while animating
        [self disableGesture];

        // Spring animation
        POPSpringAnimation *springAnimation = [self springDismissAnimationWithVelocity:0 completion:^(POPAnimation *animation, BOOL completed) {
            // On completion, remove from superview and self
            // Re-enable UI after animation
            [self enableGesture];

            // Check that animation successfully completed (wasn't interrupted by another gesture)
            if (completed) {

                // Not interrupted, remove from super view and self
                [viewController.view removeFromSuperview];
                [viewController removeFromParentViewController];
                [self.topViewController viewDidAppear:YES];
            }
        }];

        // Add animation with key stackNav.dismiss so we know not to let the user navigate while it's dismissing
        [viewController.view.layer pop_addAnimation:springAnimation forKey:@"stackNav.dismiss"];

        // Update scale and opacity of previous vc animated
        [self updatePreviousViewWithOpacity:1 scale:1 animated:YES];

    } else if (shouldPop) {

        if ([self shouldPopViewController:viewController animated:animated]) {

            // Don't animate but go immediately
            [self updatePreviousViewWithOpacity:1 scale:1 animated:NO];

            // Remove from superview
            [viewController.view removeFromSuperview];

            // Remove from parent
            [viewController removeFromParentViewController];
        }

    }
}


- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {

}


- (void)popToRootViewController:(BOOL)animated {

}


// Returns true if gesture passed is intended to be navigational (combination of axis, state of view controller, gesture being within bounds)
- (BOOL)gesture:(UIScreenEdgePanGestureRecognizer *)gesture canNavigateViewController:(UIViewController<PCStackViewController> *)viewController {
    /*

     DETERMINING PRIMARY AXIS OF GESTURE (VERTICAL VS HORIZONTAL)

     Determine primary gesture axis by comparing absolute velocity on each axis
     If absolute velocity along y axis is greater than absolute velocity along x axis then gesture is primarily vertical
     If absolute velocity along x axis is greater than absolute velocity along y axis then gesture is primarily horizontal

     */

    // Grab velocity and location in view from gesture
    CGPoint gestureVelocity = [gesture velocityInView:self.view];

    // will set to true if gesture is primarily vertical as noted above
    BOOL gestureIsNavigational = fabsf(gestureVelocity.x) > fabsf(gestureVelocity.y);

    // Check if view controller view has pop_animation of key stackNav.dismiss and if so, don't allow nav
    gestureIsNavigational = gestureIsNavigational && !viewController.view.pop_animationKeys.count > 0;

    // Check that we're not trying to navigate the root view controller
    gestureIsNavigational = gestureIsNavigational && viewController.stackIndex > 0;

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


- (void)updatePreviousViewWithOpacity:(CGFloat)opacity scale:(CGFloat)scale animated:(BOOL)animated {

    if (self.childViewControllers.count > 1 && ![self.topViewController.view.layer pop_animationForKey:@"stackNav.navigate"]) {

        UIViewController<PCStackViewController> *viewController = [self previousViewController];

        if (viewController) {

            // Remove animations before updating
            [viewController pop_removeAllAnimations];

            if (animated) {

                // Opacity animation
                POPBasicAnimation *opacityAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
                opacityAnimation.toValue = @(opacity);
                [viewController.view.layer pop_addAnimation:opacityAnimation forKey:@"previousVC.fade"];

                // Scale aniamtion, bounce
                POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
                scaleAnimation.springBounciness = SPRING_BOUNCINESS;
                scaleAnimation.springSpeed = SPRING_SPEED;
                scaleAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(scale, scale)];

                [viewController.view.layer pop_addAnimation:scaleAnimation forKey:@"previousVC.scale"];

            } else {

                // Set opacity
                viewController.view.layer.opacity = opacity;

                // Transform view for scale
                CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
                viewController.view.transform = transform;

            }
        }
    }
}


- (UIViewController<PCStackViewController> *)previousViewController {
    // The view controller to be updated
    UIViewController<PCStackViewController> *viewController;

    // Potential to use in nsenum
    @autoreleasepool {

        // Copy childViewControlelrs mutably so we can pop off the last one
        NSMutableArray *possibleViewControllers = [self.childViewControllers mutableCopy];

        // Top vc def can't be "previous"
        [possibleViewControllers removeLastObject];

        // Enumerate view controllers in reverse order (top to bottom)
        NSEnumerator *reverseControllerEnumerator = [possibleViewControllers reverseObjectEnumerator];
        UIViewController<PCStackViewController> *possibleViewController;
        while (possibleViewController = [reverseControllerEnumerator nextObject]) {

            // Fixes corner case where new view controller is pushed before another's dismissal has completed
            if (![possibleViewController.view.layer pop_animationForKey:@"stackNav.dismiss"]) {
                viewController = possibleViewController;
                break;
            }
        }
    }

    return viewController;
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


- (void)disableGesture {
    self.screenEdgePanGestureRecognizer.enabled = false;
}

- (void)enableGesture {
    self.screenEdgePanGestureRecognizer.enabled = true;
}

- (void)returnViewControllerToRestingCenter:(UIViewController <PCStackViewController> *)viewController completion:(void(^)())completion {

    // Find proper resting center
    CGPoint restingCenter = [self restingCenterForViewController:viewController];

    // Build animation
    POPSpringAnimation *springReturnAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    springReturnAnimation.toValue = [NSValue valueWithCGPoint:restingCenter];
    springReturnAnimation.springBounciness = SPRING_BOUNCINESS;
    springReturnAnimation.springSpeed = SPRING_SPEED;

    if (completion) {
        springReturnAnimation.completionBlock = ^ (POPAnimation *animation, BOOL completed) {
            completion();
        };
    }

    // Add animation
    [viewController.view.layer pop_addAnimation:springReturnAnimation forKey:@"stackNav.return"];
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

#pragma mark animations

- (POPSpringAnimation *)springCenterXAnimationWithVelocity:(CGFloat)velocity completion:(completion_block)completionBlock {
    POPSpringAnimation *springAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionX];
    springAnimation.springBounciness = SPRING_BOUNCINESS;
    springAnimation.springSpeed = SPRING_SPEED;
    springAnimation.velocity = @(velocity);
    springAnimation.completionBlock = completionBlock;
    return springAnimation;
}

- (POPSpringAnimation *)springEnterAnimationWithVelocity:(CGFloat)velocity viewController:(UIViewController<PCStackViewController> *)viewController completion:(completion_block)completionBlock {
    POPSpringAnimation *springAnimation = [self springCenterXAnimationWithVelocity:velocity completion:completionBlock];
    springAnimation.toValue = @([self restingCenterForViewController:viewController].x);
    return springAnimation;
}

- (POPSpringAnimation *)springDismissAnimationWithVelocity:(CGFloat)velocity completion:(completion_block)completionBlock {
    POPSpringAnimation *springAnimation = [self springCenterXAnimationWithVelocity:velocity completion:completionBlock];
    springAnimation.toValue = @(self.view.frame.size.width * 1.5);
    springAnimation.springBounciness = 0;
    return springAnimation;
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
    CGPoint newCenter = [self newCenterWithOriginalCenter:originalCenter translation:[gesture translationInView:self.view]];
    view.center = newCenter;
}


- (CGPoint)newCenterWithOriginalCenter:(CGPoint)original translation:(CGPoint)translation {
    CGPoint newCenter = original;

    // Add translation x to original x
    newCenter.x += translation.x;

    return newCenter;
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


#pragma mark etc.

- (BOOL)shouldPopViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {
    if ([viewController respondsToSelector:@selector(shouldPopAnimated:)]) {
        return [viewController shouldPopAnimated:animated];
    } else {
        return true;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (CGFloat)trackingProgressWithPosition:(CGFloat)position start:(CGFloat)start end:(CGFloat)end {
    // Get offset starting at zero
    CGFloat offset = position - start;
    // Max offset from zero
    CGFloat maxOffset = end / 2;
    // Progress of offset between zero and max offset, capped at one
    CGFloat progress = fmaxf(fminf(offset / maxOffset, 1), 0);

    return progress;
}

- (CGFloat)positionWithProgress:(CGFloat)progress start:(CGFloat)start end:(CGFloat)end {
    // Get total distance
    CGFloat distance = end - start;
    // Position accounting for offset
    CGFloat position = (progress * distance) + start;
    return position;
}

#pragma mark Math

- (CGFloat)smoothStep:(CGFloat)value {
    // Smoothstep = x^2 • (3 - 2x)
    CGFloat smoothstep = powf(value, 2) * (3 - 2 * value);
    return smoothstep;
}

@end
