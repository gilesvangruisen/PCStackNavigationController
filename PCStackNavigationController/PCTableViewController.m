//
//  PCTableViewController.m
//  Remarkable
//
//  Created by Giles Van Gruisen on 3/8/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

#import "PCTableViewController.h"

@interface PCTableViewController ()

@end

@implementation PCTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] bounds] style:UITableViewStylePlain];
        self.view.layer.cornerRadius = 4.0f;
    }
    return self;
}

@end
