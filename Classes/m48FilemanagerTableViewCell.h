/*
 *  m48FilemanagerTableViewCell.h
 *
 *  This file is part of m48
 *
 *  Copyright (C) 2009 Markus Gonser, m48@mksg.de
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 * 
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 */

#import <UIKit/UIKit.h>
#import "m48Filemanager.h"

#define M48FILEMANAGERHOLDTIME 0.5

@interface m48FilemanagerTableViewCell : UITableViewCell {
	NSTimer * _timer;
	BOOL _holdActionEnabled;
	BOOL _isHoldAction;
    m48Filemanager * _root;
    UITableView * _tableView2;
    NSIndexPath * _indexPath;
	
	NSSet * _currentTouches;
	UIEvent * _currentEvent;
}

@property (nonatomic, retain) NSTimer * timer;
@property (nonatomic, assign) BOOL holdActionEnabled;
@property (nonatomic, assign) BOOL isHoldAction;
@property (nonatomic, retain) m48Filemanager * root;
@property (nonatomic, retain) UITableView * tableView2;
@property (nonatomic, retain) NSIndexPath * indexPath;
@property (nonatomic, retain) NSSet * currentTouches;
@property (nonatomic, retain) UIEvent * currentEvent;

- (void)timerFired:(NSTimer*)theTimer;

@end
