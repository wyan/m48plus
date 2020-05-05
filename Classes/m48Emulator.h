/*
 *  m48Emulator.h
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

#import <Foundation/Foundation.h>

extern const NSString * kUnsavedFileFilename;
extern const NSString * kUnsavedFileDisplayText;

#define KEYBOARDQUEUEMAX 40
typedef struct keyboardQueueData {
	int  out;
	int  in;
	BOOL bDown;
} KeyboardQueueData;

@interface m48Emulator : NSObject {
	BOOL _contentChanged;
	
	// KeyboardEventQueue
	KeyboardQueueData _queue[KEYBOARDQUEUEMAX];
	int _currentQueuePosition;
	int _currentQueueLength;
}

@property (nonatomic, assign) BOOL contentChanged;

- (BOOL)newDocumentWithXml:(NSString *) filename error:(NSError **)error;
- (BOOL)loadDocument:(NSString *) filename error:(NSError **)error;
- (BOOL)saveDocument:(NSString *) filename error:(NSError **)error;
- (BOOL)loadXmlDocument:(NSString *) filename error:(NSError **)error;
- (BOOL)closeDocument;
#ifdef VERSIONPLUS
- (BOOL)loadObject:(NSString *) filename error:(NSError **)error;
- (BOOL)saveObject:(NSString *) filename error:(NSError **)error;
#endif

- (void)reset;

-(void)run;
-(BOOL)pause;
-(void)stop;
-(BOOL)isRunning;

-(void)loadSettings;

// Threading
-(void)workerThreadsWrapperMethod;
//-(void)highRateMemoryWatch; // Debugging

-(void)queueKeyboardEventOut:(int)_out In:(int)_in Predicate:(BOOL)predicate;
-(void)processKeyboardEventQueue;


@end
