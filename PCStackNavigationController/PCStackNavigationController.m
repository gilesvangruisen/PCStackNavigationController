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

- (void)centerView:(UIView *)view onGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint center = view.center;
    center.y = originalCenter.y + [gesture translationInView:self.view].y;
    static CGFloat kMovementSmoothing = 0.1f;
    [UIView animateWithDuration:kMovementSmoothing
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState|
     UIViewAnimationOptionAllowUserInteraction|
     UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.visibleViewController.view.center = center;
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
        [self centerView:self.visibleViewController.view onGesture:gesture];
    } else if (sliding && gesture.state == UIGestureRecognizerStateEnded) {
        [self centerView:self.visibleViewController.view onGesture:gesture];
        sliding = false;
    }
}

@end
