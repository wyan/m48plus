/*
 *  m48EmulatorStartupPreview.m
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

#import "m48EmulatorStartupPreview.h"
#import "patchwince.h"

@implementation m48EmulatorStartupPreview

@synthesize image = _image;
@synthesize activityIndicator = _activityIndicator;

-(id)initWithFrame:(CGRect)aRect {
	if ((self = [super initWithFrame:aRect])) {
		NSString * filename = getFullDocumentsPathForFile(@".cached_screenshot.png");
		BOOL isIPad = [[NSUserDefaults standardUserDefaults] boolForKey:@"internalIsIPad"];
		if ((isIPad == NO) && ([[NSFileManager defaultManager] fileExistsAtPath:filename] == YES)) {
			self.image = [UIImage imageWithContentsOfFile:filename];
		}
		else {
			[self loadDefaultImage];
		}	
		_activityIndicator =  [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[_activityIndicator setHidesWhenStopped:YES];
		[self addSubview:_activityIndicator];		
	}
	return self;
}

-(void)loadDefaultImage {
    /*
	BOOL isIPad = [[NSUserDefaults standardUserDefaults] boolForKey:@"internalIsIPad"];
	BOOL isIPhone5 = [[NSUserDefaults standardUserDefaults] boolForKey:@"internalIsIPhone5"];
	BOOL isRetina = [[NSUserDefaults standardUserDefaults] boolForKey:@"internalIsRetina"];
    
    
	if (isIPad) {

            if (isRetina) {
                self.image = [UIImage imageNamed:@"Default-Portrait@2x.png"];
            }
            else {
                self.image = [UIImage imageNamed:@"Default-Portrait.png"];
            }
			
		}
		else {
            if (isRetina) {
                self.image = [UIImage imageNamed:@"Default-Landscape@2x.png"];
            }
            else {
                self.image = [UIImage imageNamed:@"Default-Landscape.png"];
            }
		}

	}
     */
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    bool isLandscape = true;
	if ((orientation == UIDeviceOrientationPortrait) || (orientation == UIDeviceOrientationPortraitUpsideDown) || (orientation == UIDeviceOrientationUnknown) || (orientation == UIDeviceOrientationFaceUp) || (orientation == UIDeviceOrientationFaceDown)) {
        isLandscape = false;
    }
    
    NSString * model = [[NSUserDefaults standardUserDefaults] objectForKey:@"device_model"];
    NSString * filename = nil;
    if ([model isEqualToString:@""]) {
        filename = @"Default.png";
    }
    else if ([model isEqualToString:@"@2x"]) {
        filename = @"Default@2x.png";
    }
    else if ([model isEqualToString:@"-568h@2x"]) {
        filename = @"Default-568h@2x.png";
    }
    else if ([model isEqualToString:@"-667h@2x"]) {
        filename = @"Default-667h@2x.png";
    }
    else if ([model isEqualToString:@"-736h@3x"]) {
        filename = @"Default-736h@3x.png";
    }
    else if ([model isEqualToString:@"2x~iPad"]) {
        if (isLandscape) {
            filename = @"Default-Landscape@2x.png";
        }
        else {
            filename = @"Default-Portrait@2x.png";
        }
    }
    else if ([model isEqualToString:@"~iPad"]) {
        if (isLandscape) {
            filename = @"Default-Landscape.png";
        }
        else {
            filename = @"Default-Portrait.png";
        }
    }
    else {
        filename = @"Default.png";
    }
    
    self.image = [UIImage imageNamed:filename];
    //self.image = [UIImage imageNamed:@"LaunchImage"];
    
	return;
}

-(void)drawRect:(CGRect)rect {
	CGSize imageSize = [_image size];
	// Zoom it with correct aspect ratio:
	CGFloat zoom;
	if ((rect.size.width/imageSize.width) < (rect.size.height/imageSize.height)) {
		zoom = (rect.size.width/imageSize.width);
	}
	else {
		zoom = (rect.size.height/imageSize.height);
	}
	
	rect.origin.x += (rect.size.width - (zoom*imageSize.width))/2;
	rect.origin.y = rect.size.height - (zoom*imageSize.height);
	rect.size.width = zoom*imageSize.width;
	rect.size.height = zoom*imageSize.height;
	
	[_image drawInRect:rect];
}

-(void)startAnimating {
	[_activityIndicator setCenter:[self center]];
	[_activityIndicator startAnimating];
}

-(void)stopAnimating {
	[_activityIndicator stopAnimating];
}

-(void)dealloc {
	[_activityIndicator release];
	[_image release];	
	[super dealloc];
}

@end
