/*
 *  m48MenuSettingsVolumeSlider.m
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

#import "m48MenuSettingsVolumeSlider.h"
#import <math.h>

@implementation m48MenuSettingsVolumeSlider

@synthesize key = _key;
@synthesize label = _label;
@synthesize slider = _slider;

- (id)initWithFrame:(CGRect)rect andSettingsDict:(NSDictionary *)aDict {
	if (self = [super initWithFrame:rect]) {
		// setup slider and label
		CGRect myBounds = self.bounds;
		_label = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 60, 16.0)];
		_slider = [[UISlider alloc] initWithFrame:CGRectMake(65, 10, myBounds.size.width-65, 16.0)];
		_slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self addSubview:_label];
		[_label setTextAlignment:NSTextAlignmentRight];
		[self addSubview:_slider];
		
		self.key = [aDict objectForKey:@"Key"];
        _slider.minimumValue = 0.1;
        _slider.maximumValue = 1.25;
        _slider.continuous = YES;
		float val = [[NSUserDefaults standardUserDefaults] floatForKey:_key];
		val = pow(10,2.0*log10(1.25)*log10(val));
		_slider.value = val;
		
		[_slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        // in case the parent view draws with a custom color or gradient, use a transparent color
        self.backgroundColor = [UIColor clearColor];
		_slider.backgroundColor = self.backgroundColor;
		_label.backgroundColor = self.backgroundColor;
		
		[self setLabelVal];
	}
	return self;
}

//- (void)layoutSubviews {
//	CGRect myBounds = self.bounds;
//	[_label setFrame:CGRectMake(0, 0.5*myBounds.size.height, 60, 16.0)];
//	[_slider setFrame:CGRectMake(65, 0.5*(myBounds.size.height-8), myBounds.size.width-65, 8.0)];
//}

- (void)sliderAction:(id)sender {
	float val = [_slider value];
	val = 10.0/log10(1.25)*log10(val);
	val = pow(10.0,val/20.0);
	if (val < 0.0001) { // -100dB
		[[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:_key];
	}
	else {
		[[NSUserDefaults standardUserDefaults] setFloat:val forKey:_key];
	}
	[self setLabelVal];
}
		
- (void)setLabelVal {
	float val;
	val = [_slider value];
	val = 10.0/log10(1.25)*log10(val);
	if (val > -100.0) {
		_label.text = [NSString stringWithFormat:@"%.0f dB", val];
	}
	else {
		_label.text = [NSString stringWithUTF8String:"-\xE2\x88\x9E dB"];
	}
		
}

- (void)dealloc {
	[_label release];
	[_slider release];
	[_key release];
	[super dealloc];
}


@end
