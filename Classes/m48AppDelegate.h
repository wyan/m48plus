/*
 *  m48AppDelegate.h
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
#import "m48EmulatorViewController.h"

#ifdef VERSIONPLUS
@class   HTTPServer;
#endif

@interface m48AppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow	* _window;
	UINavigationController *	_navigationController;
	m48EmulatorViewController * _emulatorViewController;

#ifdef VERSIONPLUS
	// HTTP server
	HTTPServer * _httpServer;
	NSDictionary * _addresses;
	BOOL _serverIsRunning;
#endif
	
	// Universal binary:
	BOOL _isIPad;
}

@property (retain, nonatomic) UIWindow * window;
@property (nonatomic, retain) UINavigationController * navigationController;
@property (retain, nonatomic) m48EmulatorViewController * emulatorViewController;
@property (nonatomic, assign) BOOL isIPad;

#ifdef VERSIONPLUS
@property (nonatomic, retain) HTTPServer * httpServer;
@property (nonatomic, retain) NSDictionary * addresses;
@property (nonatomic, readonly, assign) BOOL serverIsRunning;

- (void)setupAndStartServer;
- (void)startStopServer:(BOOL)isOn;
- (void)toggleServer:(BOOL)status;
#endif

@end
