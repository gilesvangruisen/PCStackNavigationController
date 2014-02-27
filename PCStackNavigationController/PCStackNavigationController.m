//
//  PCStackNavigationController.m
//  PCStackNavigationController
//
//  Created by Giles Van Gruisen on 2/24/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCStackNavigationController.h"

@interface PCStackNavigationController ()

@property (nonatomic, strong) UIViewController *visibleViewController;

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

- (id)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        // Start watching for pan gestures
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [self.view addGestureRecognizer:panGestureRecognizer];
        [self.view addSubview:rootViewController.view];
        [self.viewControllers addObject:rootViewController];
        self.visibleViewController = rootViewController;
        panGestureRecognizer.delegate = self;
        self.rootViewControllerLowerBound = rootViewController.view.center.y - 50;
        self.rootViewControllerUpperBound = (rootViewController.view.frame.size.height * 1.5) + 25;
    }
    return self;
}

- (void)setBottomViewController:(UIViewController *)bottomViewController {
    _bottomViewController = bottomViewController ? bottomViewController : nil;
    _bottomViewController = bottomViewController;
    [self.view insertSubview:_bottomViewController.view atIndex:0];
    [self.viewControllers insertObject:_bottomViewController atIndex:0];
}

#pragma mark Animations

- (float)smoothEdgeWithStart:(float)start limit:(float)limit point:(float)point {
    float areaHeight = abs(limit - start);
    float distance = abs(point - start);
    float smoothed = ((2 / M_PI) * atanf(distance/(0.7*areaHeight)));
    float multiplied = smoothed * areaHeight;
    float newPosition = limit - start < 0 ? start - multiplied : start + multiplied;
    return newPosition;
}

- (void)centerVisibleViewControllerOnGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint center = self.visibleViewController.view.center;
    center.y = originalCenter.y + [gesture translationInView:self.view].y;
    if (center.y > self.visibleViewController.view.frame.size.height * 1.5) {
        float start = self.visibleViewController.view.frame.size.height * 1.5;
        center.y = [self smoothEdgeWithStart:start limit:self.rootViewControllerUpperBound point:center.y];
    } else if (center.y < self.visibleViewController.view.frame.size.height / 2) {
        float start = self.visibleViewController.view.frame.size.height / 2;
        center.y = [self smoothEdgeWithStart:start limit:self.rootViewControllerLowerBound point:center.y];
    }
    [self centerView:self.visibleViewController.view onPoint:center withDuration:0.0f easing:UIViewAnimationOptionCurveEaseOut];
}

- (void)centerView:(UIView *)view onPoint:(CGPoint)point withDuration:(CGFloat)duration easing:(UIViewAnimationOptions)viewAnimationOptions {
    [UIView animateWithDuration:duration
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState|
     UIViewAnimationOptionAllowUserInteraction|
     viewAnimationOptions
                     animations:^{
                         self.visibleViewController.view.center = point;
                     } completion:NULL];
}

#pragma mark Pan Gesture

- (void)panGestureRecognizer:(UIPanGestureRecognizer *)gesture {
    [self.visibleViewController.view.layer removeAllAnimations];
    lastTouchY = [gesture locationInView:self.view].y;
    if (!sliding && gesture.state == UIGestureRecognizerStateBegan) {
        // Set original visible view center, touch position relative to visible view
        originalPosition = [gesture locationInView:self.visibleViewController.view];
        originalCenter = self.visibleViewController.view.center;
        // Get out if touch is out of bounds
        if (!CGRectContainsPoint(self.visibleViewController.view.frame, originalCenter))
            return;
        sliding = true;
    } else if (sliding && gesture.state == UIGestureRecognizerStateChanged) {
        [self centerVisibleViewControllerOnGesture:gesture];
    } else if (sliding && gesture.state == UIGestureRecognizerStateEnded) {
        [self centerView:self.visibleViewController.view onPoint:originalCenter withDuration:0.2 easing:UIViewAnimationOptionCurveEaseInOut];
        sliding = false;
    }
}

#pragma mark FIN.
#pragma-mark--------------____
#pragma-mark-------------/---/\
#pragma-mark------------/---/##\
#pragma-mark-----------/---/####\
#pragma-mark----------/---/######\
#pragma-mark---------/---/###/\###\
#pragma-mark--------/---/###/++\###\
#pragma-mark-------/---/###/\+++\###\
#pragma-mark------/---/###/--\+++\###\
#pragma-mark-----/---/###/----\+++\###\
#pragma-mark----/---/###/------\+++\###\
#pragma-mark---/---/###/--------\+++\###\
#pragma-mark--/---/###/_____________\+++\###\
#pragma-mark-/--------------------\+++\###\
#pragma-mark-\+++++++++++++++++++++\##/
#pragma-mark--````````````````````````````

@end
