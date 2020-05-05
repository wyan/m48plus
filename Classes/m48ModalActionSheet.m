/*
 *  m48ModalActionSheet.m
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

#import "m48ModalActionSheet.h"


@implementation m48ModalActionSheet

@synthesize target = _target;
@synthesize selector = _selector;
@synthesize optionalObject = _optionalObject;
@synthesize evolutionStage = _evolutionStage;
@synthesize didDismissWithButtonIndex = _didDismissWithButtonIndex;
@dynamic buttonTexts;


- (NSMutableArray *)buttonTexts {
	if (_buttonTexts == nil) {
		_buttonTexts = [NSMutableArray arrayWithCapacity:0];
		[_buttonTexts retain];
	}
	return _buttonTexts;
}

- (void)setButtonTexts:(NSMutableArray *)buttonTexts {
	[buttonTexts retain];
	[_buttonTexts release];
	_buttonTexts = buttonTexts;
}


- (id)initBlank {
    if (self = [super initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]) {
		_didDismissWithButtonIndex = -1;
		_evolutionStage = 0;		
    }
    return self;
}

- (void)addButtonTitles {
	if (self.numberOfButtons == 0) {
		for (int i=0; i < [self.buttonTexts count]; i++) {
			[self addButtonWithTitle:[self.buttonTexts objectAtIndex:i]];
		}
	}
}

- (void)showFromToolbar:(UIToolbar *)view {
	[self addButtonTitles];
	[super showFromToolbar:view];
}

- (void)showFromTabBar:(UITabBar *)view {
	[self addButtonTitles];
	[super showFromTabBar:view];
}	
	

- (void)showInView:(UIView *)view {
	[self addButtonTitles];
	[super showInView:view];
}

- (void)dealloc {
	[_optionalObject release];
	[_target release];
	[_buttonTexts release];
    [super dealloc];
}

#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	self.didDismissWithButtonIndex = buttonIndex;
	_evolutionStage++;
	if ((buttonIndex != -1) && (_target != nil)) {
		NSMethodSignature * signature = [_target methodSignatureForSelector:_selector];
		if ([signature numberOfArguments] == 0) {
			[_target performSelector:_selector];
		}
		else {
			[_target performSelector:_selector withObject:_optionalObject];
		}
	}
}

@end

