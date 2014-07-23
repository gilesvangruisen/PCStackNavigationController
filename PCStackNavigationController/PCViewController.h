//
//  PCViewController.h
//  Remarkable
//
//  Created by Giles Van Gruisen on 3/8/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PCStackNavigationController.h"

@interface PCViewController : UIViewController

// Stack controller to which self was pushed
@property (nonatomic, strong) PCStackNavigationController *stackController;

// Index in radar correlates to suggestion user index
@property (nonatomic) NSNumber *index;

@end
