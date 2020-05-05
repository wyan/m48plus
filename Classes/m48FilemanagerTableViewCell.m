/*
 *  m48FilemanagerTableViewCell.m
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

#import "m48FilemanagerTableViewCell.h"


@implementation m48FilemanagerTableViewCell

@synthesize timer = _timer;
@synthesize holdActionEnabled = _holdActionEnabled;
@synthesize isHoldAction = _isHoldAction;
@synthesize root = _root;
@synthesize tableView2 = _tableView2;
@synthesize indexPath = _indexPath;
@synthesize currentTouches = _currentTouches;
@synthesize currentEvent = _currentEvent;

- (void)dealloc {
	[_currentEvent release];
	[_currentTouches release];
	[_timer release];
    [super dealloc];
}

- (void)timerFired:(NSTimer*)theTimer {
    [_timer invalidate];
	self.timer = nil;
	_isHoldAction = YES;
	//[super touchesEnded:_currentTouches withEvent:_currentEvent];
    [_root tableView:_tableView2 didSelectRowAtIndexPath:_indexPath];
	self.currentTouches = nil;
	self.currentEvent = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if (_holdActionEnabled) {
		self.timer = [NSTimer scheduledTimerWithTimeInterval:M48FILEMANAGERHOLDTIME target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
	}
	self.currentTouches = touches;
	self.currentEvent = event;
	[super touchesBegan:touches withEvent:event];	
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesCancelled:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesMoved:touches withEvent:event];
}
	
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_isHoldAction == NO) {
        [super touchesEnded:touches withEvent:event];
    }
    if ((_holdActionEnabled == NO) || (_timer != nil)) {
		// Regular tap
		[_timer invalidate];
		self.timer = nil;
		_isHoldAction = NO;
	}
	self.currentTouches = nil;
	self.currentEvent = nil;
}

@end
