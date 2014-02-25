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

float velocity;
float lastTouchY;
BOOL sliding;
BOOL rootVisible;
CGPoint originalLoc;
CGPoint originalCen;

- (id)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        // Start watching for pan gestures
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognizer:)];
        [self.view addGestureRecognizer:panGestureRecognizer];
        
        [self.viewControllers addObject:rootViewController];
        self.visibleViewController = rootViewController;
        panGestureRecognizer.delegate = self;
    }
    return self;
}

#pragma mark pan gesture

- (void)panGestureRecognizer:(UIPanGestureRecognizer *)gesture {
    
}

#pragma mark etc.

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
