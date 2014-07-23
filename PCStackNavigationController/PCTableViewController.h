//
//  PCTableViewController.h
//  Remarkable
//
//  Created by Giles Van Gruisen on 3/8/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCViewController.h"
#import "PCStackNavigationController.h"

@interface PCTableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) PCStackNavigationController *stackController;

@end
