//
//  PCStackNavigationController.m
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCStackNavigationController.h"
#import "PCGroupsTableViewController.h"
#import "PCRadarViewController.h"
#import "PCViewController.h"
#import "PCAnimation.h"
#import <pop/POP.h>

@interface PCStackNavigationController () {
    int currentIndex;
}

@property (nonatomic, strong) UIView *statusBarCover;
@property (nonatomic, strong) PCViewController *visibleViewController;

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
        self.trackingEnabled = YES;
        self.viewControllers = [@[] mutableCopy];
        self.view.backgroundColor = [UIColor clearColor];
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [self.view addGestureRecognizer:panGestureRecognizer];

        PCRadarViewController *rootViewController = [PCRadarViewController radarViewController];
        [self pushViewController:(PCViewController *)rootViewController animated:NO];
        panGestureRecognizer.delegate = self;

        self.rootViewControllerLowerBound = rootViewController.view.center.y;
        self.rootViewControllerUpperBound = rootViewController.view.center.y;
    }
    return self;
}

- (void)setBottomViewController:(PCViewController *)bottomViewController {
    _bottomViewController = bottomViewController ? bottomViewController : nil;
    self.rootViewControllerUpperBound = (bottomViewController.view.frame.size.height * 1.5) - 60;

    [self.viewControllers insertObject:_bottomViewController atIndex:0];
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
    if (toCenter.y > self.rootViewControllerUpperBound) {
        toCenter.y = [self smoothEdgeWithStart:self.rootViewControllerUpperBound limit:self.rootViewControllerUpperBound+60 point:toCenter.y];
    } else if (toCenter.y < self.rootViewControllerLowerBound) {
        toCenter.y = [self smoothEdgeWithStart:self.rootViewControllerLowerBound limit:self.rootViewControllerLowerBound-50 point:toCenter.y];
    }

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
                if (viewY == self.rootViewControllerLowerBound || viewY == self.rootViewControllerUpperBound) {
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
                CGPoint toCenter = self.visibleViewController.view.center;
                toCenter.y = self.rootViewControllerUpperBound;
                [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
            } else if (vertical && velocity.y < -300) {
                CGPoint toCenter = self.visibleViewController.view.center;
                toCenter.y = self.rootViewControllerLowerBound;
                [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
            } else if (vertical) {
                CGPoint toCenter = self.visibleViewController.view.center;
                toCenter.y = startY;
                [self springCenterView:self.visibleViewController.view toPoint:toCenter velocity:popVelocity];
            }

            break;
    }
}

- (void)updateStatusBarCoverWithCenter:(CGPoint)center animated:(BOOL)animated {
    CGFloat alpha;
    if (self.viewControllers.count < 3) {
        CGFloat progress = [PCAnimation trackingProgressWithPosition:center.y start:self.rootViewControllerLowerBound end:self.rootViewControllerUpperBound];
        alpha = [PCAnimation positionWithProgress:[PCAnimation smoothStep:progress] start:0.7 end:0.3];
        [self.statusBarCover.layer removeAllAnimations];
    } else {
        alpha = 1;
    }
    if (animated) {
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionBeginFromCurrentState|
         UIViewAnimationOptionAllowUserInteraction|
         UIViewAnimationCurveEaseOut
                         animations:^{
                             self.statusBarCover.alpha = alpha;
                         } completion:NULL];
    } else {
        self.statusBarCover.alpha = alpha;
    }
}

- (void)updateAlphaScaleOfView:(UIView *)view withCenter:(CGPoint)center animated:(BOOL)animated {
    CGFloat progress = [PCAnimation trackingProgressWithPosition:center.y start:self.rootViewControllerLowerBound end:self.rootViewControllerUpperBound];
    CGFloat scaleFactor = [PCAnimation positionWithProgress:[PCAnimation smoothStep:progress] start:0.92 end:1];
    CGFloat alpha = [PCAnimation positionWithProgress:[PCAnimation smoothStep:progress] start:0.25 end:1];
    CGAffineTransform scale = CGAffineTransformMakeScale(scaleFactor, scaleFactor);
    CGFloat heightDifference = view.frame.size.height - (view.frame.size.height * scaleFactor);
    CGAffineTransform translate = CGAffineTransformMakeTranslation(0, -heightDifference / 4);
    [self.visibleViewController.view.layer removeAllAnimations];
    if (animated) {
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionBeginFromCurrentState|
         UIViewAnimationOptionAllowUserInteraction|
         UIViewAnimationCurveEaseOut
                         animations:^{
                             view.transform = CGAffineTransformConcat(scale, translate);
                             view.alpha = alpha;
                         } completion:NULL];
    } else {
        view.transform = CGAffineTransformConcat(scale, translate);
        view.alpha = alpha;
    }
}

#pragma mark Push/Pop

- (void)pushViewController:(PCViewController *)viewController animated:(BOOL)animated {
    self.visibleViewController.view.userInteractionEnabled = NO;
    PCViewController *outgoing = self.visibleViewController;
    [self.viewControllers addObject:viewController];

    [self addChildViewController:viewController];
    [viewController didMoveToParentViewController:self];

    [self updateStatusBarCoverWithCenter:self.visibleViewController.view.center animated:NO];
    self.visibleViewController = viewController;
    self.visibleViewController.stackController = self;
    if (bottomViewControllerVisible) {
        CGPoint center = outgoing.view.center;
        center.y = self.rootViewControllerLowerBound;
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
        [self updateAlphaScaleOfView:outgoing.view withCenter:center animated:YES];
        [self springCenterView:self.visibleViewController.view toPoint:center velocity:CGPointMake(50,50)];
    } else {
        [self.view addSubview:self.visibleViewController.view];
    }
    currentIndex += 1;
}

- (void)popViewControllerAnimated:(BOOL)animated {
    PCViewController *outgoing = [self.viewControllers lastObject];
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

- (void)popToViewController:(PCViewController *)viewController animated:(BOOL)animated {

}

- (void)popToRootViewController:(BOOL)animated {

}

#pragma mark etc.

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    self.statusBarCover = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 20)];
    self.statusBarCover.backgroundColor = [UIColor blackColor];
    self.statusBarCover.alpha = 0.5;
    [self.view addSubview:self.statusBarCover];
    [self.view sendSubviewToBack:self.statusBarCover];
    return UIStatusBarStyleLightContent;
}

@end
