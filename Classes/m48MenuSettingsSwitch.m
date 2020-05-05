/*
 *  m48MenuSettingsSwitch.m
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

#import "m48MenuSettingsSwitch.h"


@implementation m48MenuSettingsSwitch

@synthesize key = _key;

- (id)initWithFrame:(CGRect)rect andSettingsDict:(NSDictionary *)aDict {
	if (self = [super initWithFrame:rect]) {
		self.key = [aDict objectForKey:@"Key"];
		BOOL val = [[NSUserDefaults standardUserDefaults] boolForKey:_key];
		[self setOn:val];
		[self addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
        // in case the parent view draws with a custom color or gradient, use a transparent color
        self.backgroundColor = [UIColor clearColor];
	}
	return self;
}

- (void)switchAction:(id)sender {
	BOOL val = [sender isOn];
	[[NSUserDefaults standardUserDefaults] setBool:val forKey:_key];
}

- (void)dealloc {
	[_key release];
	[super dealloc];
}

@end
