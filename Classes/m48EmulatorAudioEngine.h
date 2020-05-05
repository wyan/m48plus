/*
 *  m48EmulatorAudioEngine.h
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
#include <AudioUnit/AudioUnit.h>
#import "AudioToolbox/AudioToolbox.h"
#import "m48InMemoryAudioFile.h"
#import <libkern/OSAtomic.h>
#import "xml.h"
//#import "patchwintypes.h"

#define BEEPSAMPLERATE 44100.0
#define BEEPBYTESPERSAMPLE 1
#define BEEPSAMPLEVALHALFMAX 128

#define SOUNDPOLYPHONY 3 // plus beepsound

#define MAXMEMORYAUDIOFILES 6*1024*1024 // 2MB

#define AUDIOCONTINUOUSRENDERING // Mainly for debugging purposes

void playBeep(int freq, int lengthMS);
void stopBeep(void);
void playXmlSoundFX(XmlSoundFX * soundfx, BOOL predicate);

@interface m48EmulatorAudioEngine : NSObject {
	//the graph of audio connections
	AUGraph _graph;
	
	//the audio output
	AudioUnit _output;
	
	//the audio files to play
	NSMutableDictionary	*		_inMemoryAudioFiles;
	
	
	unsigned long   _soundSlotUniqueSessionID;
	
	// Volume settings
	BOOL	_audioEnabled;
	double	_audioVolume;
	BOOL	_audioSkinEnabled;
	double	_audioSkinVolume;
	BOOL	_audioEmulatorEnabled;
	double	_audioEmulatorVolume;
	BOOL	_audioSubstituteClick;
	
	// Xml stuff
	XmlRoot *		_currentXml;
	XmlBeepType		_currentBeepType;
	
	// Render management
	OSSpinLock		_graphLock;
	BOOL			_slotIsRendered[SOUNDPOLYPHONY];
	BOOL			_beepIsRendered;
	
}
@property AUGraph graph;
@property (nonatomic, retain) NSMutableDictionary * inMemoryAudioFiles;

-(BOOL)loadSoundsFromXml:(XmlRoot *)aXml error:(NSError **)error;
-(void)loadSettings;
-(void)playXmlSoundFX:(XmlSoundFX *)soundfx buttonDown:(BOOL)isDown;
-(void)playBeep;
-(void)stopBeep;
-(void)panic;

-(void)setupAudioSession;
-(void)destroyAudioSession;
-(void)initAudioGraph;
-(void)destroyAudioGraph;

// Helper
-(void)startRenderSlotID:(NSNumber *)slotID;
-(void)stopRenderSlotID:(NSNumber *)slotID;
-(void)startRenderBeep;
-(void)stopRenderBeep;
-(void)resetRendering;

// Debug 
-(void)verboseRenderStatus:(NSTimer *)firedTimer;

@end
