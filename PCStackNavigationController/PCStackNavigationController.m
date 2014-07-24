//
//  PCStackNavigationController.m
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCStackNavigationController.h"
#import <pop/POP.h>


#pragma mark PCStackNavigationController private interface

@interface PCStackNavigationController () {
    int currentIndex;
}

@end

@implementation PCStackNavigationController

#pragma mark initialization

@synthesize bottomViewController = _bottomViewController;

float velocity;
float lastTouchY;
bool sliding;
bool rootViewControllerVisible;
bool bottomViewControllerVisible;
CGPoint originalPosition;
CGPoint originalCenter;

- (id)init {
    self = [super init];
    if (self) {
        // Start watching for pan gestures

        currentIndex = -1;
        self.viewControllers = [@[] mutableCopy];
        self.view.backgroundColor = [UIColor clearColor];
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [self.view addGestureRecognizer:panGestureRecognizer];

        panGestureRecognizer.delegate = self;

    }
    return self;
}

- (void)setBottomViewController:(UIViewController<PCStackViewController> *)bottomViewController {
    _bottomViewController = bottomViewController ? bottomViewController : nil;
    _bottomViewController.stackController = self;

    [self.viewControllers insertObject:_bottomViewController atIndex:0];
    [self.view insertSubview:bottomViewController.view atIndex:0];

    [bottomViewController didMoveToParentViewController:self];

    currentIndex += 1;
}

#pragma mark Animations

- (float)smoothEdgeWithStart:(float)start limit:(float)limit point:(float)point {
    float areaHeight = abs(limit - start);
    float distance = abs(point - start);
    float smoothed = -((2 / M_PI) * atanf(distance / areaHeight)) + 1.0;
    float multiplied = smoothed * distance;
    float newPosition = limit - start < 0 ? start - multiplied : start + multiplied;
    return newPosition;
}

static CGPoint startCenter;
- (void)centerVisibleViewControllerOnGesture:(UIPanGestureRecognizer *)gesture {

    // Set initial start center only on began
    if (gesture.state == UIGestureRecognizerStateBegan) {
        startCenter = self.visibleViewController.view.center;
    }

    // To center is current center + translation, but not
    [self.visibleViewController.view.layer pop_removeAllAnimations];
    CGPoint toCenter = startCenter;
    toCenter.x = self.view.frame.size.width / 2;

    CGPoint translation = [gesture translationInView:self.view];

    toCenter.y += translation.y;

    self.visibleViewController.view.center = toCenter;
}

- (void)springCenterView:(UIView *)view toPoint:(CGPoint)point velocity:(CGPoint)velocity {
    POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPosition];
    animation.fromValue = [NSValue valueWithCGPoint:view.center];
    animation.toValue = [NSValue valueWithCGPoint:point];
    animation.velocity = [NSValue valueWithCGPoint:velocity];
    [view.layer pop_addAnimation:animation forKey:@"spring"];
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
    static CGFloat startY;
    CGPoint velocity = [gesture velocityInView:self.view];
    CGPoint popVelocity = CGPointMake(0, velocity.y);
    static BOOL vertical;

    switch (gesture.state) {

        case UIGestureRecognizerStateBegan:

            // Figure angle and disable/enable interaction
            if (fabsf(velocity.y) > fabsf(velocity.x)) {
                CGFloat viewY = self.visibleViewController.view.center.y;
                if (viewY == self.view.frame.size.height / 2 || viewY == self.view.frame.size.height * 1.5) {
                    startY = self.visibleViewController.view.center.y;
                }

                vertical = true;
                [self centerVisibleViewControllerOnGesture:gesture];
                // Navigation interaction, disable active view controller

            } else {
                vertical = false;
            }
            break;

        case UIGestureRecognizerStateChanged:

            //  Move y according to gesture
            if (vertical) {
                [self centerVisibleViewControllerOnGesture:gesture];
            } else {
                break;
            }
            break;

        case UIGestureRecognizerStateEnded:

            // Figure where to end up and spring the way there
            if (vertical && velocity.y > 300) {

                if (currentIndex > 0) {
                    [self popViewControllerAnimated:true];
                } else {
                    CGPoint toCenter = self.visibleViewController.view.center;
                    toCenter.y = self.view.frame.size.height * 1.5;
                    [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
                }

            } else if (vertical && velocity.y < -300) {
                CGPoint toCenter = self.visibleViewController.view.center;
                toCenter.y = self.view.frame.size.height / 2;
                [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
            } else if (vertical) {
                CGPoint toCenter = self.visibleViewController.view.center;
                toCenter.y = startY;
                [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
            }

            break;
    }
}

#pragma mark Push/Pop

- (void)pushViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {

    self.visibleViewController.view.userInteractionEnabled = NO;
    UIViewController<PCStackViewController> *outgoing = self.visibleViewController;
    [self.viewControllers addObject:viewController];

    [self addChildViewController:viewController];
    [viewController didMoveToParentViewController:self];

    self.visibleViewController = viewController;
    self.visibleViewController.stackController = self;

    if (bottomViewControllerVisible) {
        CGPoint center = outgoing.view.center;
        center.y = self.view.frame.size.height / 2;
        [self springCenterView:outgoing.view toPoint:center velocity:CGPointMake(0, 0)];
    }

    if (animated) {
        CGPoint center = self.visibleViewController.view.center;
        // Move off screen before we add to view stack
        center.y += self.view.frame.size.height;
        self.visibleViewController.view.center = center;
        // Reset proper center
        center.y -= self.view.frame.size.height;
        [self.view addSubview:self.visibleViewController.view];
        [self springCenterView:self.visibleViewController.view toPoint:center velocity:CGPointMake(50,50)];
    } else {
        [self.view addSubview:self.visibleViewController.view];
    }
    currentIndex += 1;
}

- (void)popViewControllerAnimated:(BOOL)animated {
    UIViewController<PCStackViewController> *outgoing = [self.viewControllers lastObject];
    [self.viewControllers removeLastObject];
    self.visibleViewController = [self.viewControllers lastObject];

    CGPoint center = self.visibleViewController.view.center;
    center.y += self.view.frame.size.height;

    [self centerView:outgoing.view onPoint:center withDuration:0.3 easing:UIViewAnimationOptionCurveEaseOut];
    self.visibleViewController.view.userInteractionEnabled = YES;

    currentIndex -= 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [outgoing.view removeFromSuperview];
    });
}

- (void)popToViewController:(UIViewController<PCStackViewController> *)viewController animated:(BOOL)animated {

}

- (void)popToRootViewController:(BOOL)animated {

}

#pragma mark etc.

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
