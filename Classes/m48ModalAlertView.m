/*
 *  m48ModalAlertView.m
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

#import "m48ModalAlertView.h"

const NSString *tModalAlertViewWait = @"Loading ...";
const NSString *tModalAlertViewSuccess = @"Success!";
const NSString *tModalAlertViewError = @"Error!";

@implementation m48ModalAlertView

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
    if (self = [super initWithTitle:nil message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:nil]) {
		_didDismissWithButtonIndex = -1;
		_evolutionStage = 0;		
    }
    return self;
}

- (id)initWait {
    if (self = [super initWithTitle:tModalAlertViewWait message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:nil]) {
		_didDismissWithButtonIndex = -1;
		_evolutionStage = 0;
    }
    return self;	
}

- (id)initForError {
    if (self = [super initWithTitle:tModalAlertViewError message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil]) {
		_didDismissWithButtonIndex = -1;
		_evolutionStage = 0;
    }
    return self;
}

-(void)show {
	if (self.numberOfButtons == 0) {
		for (int i=0; i < [self.buttonTexts count]; i++) {
			[self addButtonWithTitle:[self.buttonTexts objectAtIndex:i]];
		}
	}
	[super show];
}

- (void)dealloc {
	[_optionalObject release];
	[_target release];
	[_buttonTexts release];
    [super dealloc];
}

#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
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

- (void)didPresentAlertView:(UIAlertView *)alertView {
	if ([alertView.title isEqual:tModalAlertViewWait] == YES) {
		UIActivityIndicatorView * activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		//[activityIndicator setHidesWhenStopped:NO];
		CGRect r = [alertView bounds];
		[activityIndicator setCenter:CGPointMake(0.5*r.size.width,0.6*r.size.height)];	
		[alertView addSubview:activityIndicator];
		[activityIndicator startAnimating];
		[activityIndicator release];
	}
}

@end
