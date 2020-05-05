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

#import "m48EmulatorAudioEngine.h"
#import "m48Errors.h"

#import "patchwince.h"


#import <math.h>
#define M_LN_10 2.3025851

m48EmulatorAudioEngine * audioEngine = nil;
// Create some variables which contain current pointer
BOOL			_soundSlotIsActive[SOUNDPOLYPHONY];
unsigned long	_soundSlotsCurrentSessionID[SOUNDPOLYPHONY];
UInt32 *		_soundSlotsAudioDataRef[SOUNDPOLYPHONY];
BOOL			_soundSlotRepeats[SOUNDPOLYPHONY];
float			_soundSlotsVolume[SOUNDPOLYPHONY];
UInt32			_soundSlotsCurrentPosition[SOUNDPOLYPHONY];
UInt32			_soundSlotsTotalLength[SOUNDPOLYPHONY];
UInt32			_soundSlotsTotalPlayTime[SOUNDPOLYPHONY]; // To identify which one play the longest
// Beep synthesizer
int				_beepFreq;
int				_beepLengthMS;
// internal
BOOL			_beepIsActive;
UInt32			_beepLengthSamples;
UInt32			_beepCurrentPosition;
double			_beepFreqDivSAMPLERATE;
double			_beepSAMPLERATEDivBeepFreq;
float			_beepVolume;
XmlBeepType		_beepType;

// Callfunction for emulator
void inline playBeep(int freq, int lengthMS) {
	_beepFreq = freq;
	_beepLengthMS = lengthMS;
	[audioEngine performSelectorOnMainThread:(@selector(playBeep)) withObject:nil waitUntilDone:NO];
}

void inline stopBeep(void) {
	[audioEngine performSelectorOnMainThread:(@selector(stopBeep)) withObject:nil waitUntilDone:NO];
}

void playXmlSoundFX(XmlSoundFX * soundfx, BOOL predicate) {
	[audioEngine playXmlSoundFX:soundfx buttonDown:predicate];
}

#pragma mark Listeners

//this listens for changes to the audio session
void sessionPropertyListener(void *                  inClientData,
							 AudioSessionPropertyID  inID,
							 UInt32                  inDataSize,
							 const void *            inData){
	
	printf("property listener\n");
	
	if (inID == kAudioSessionProperty_AudioRouteChange){
		//this will get hit if headphones, get plugged in/unplugged on the ipod/iphone
	}
	
}

//this listens to interuptions to the audio session, possible interuptions could be the phone ringing, the phone getting locked
//and im sure there is a few more
void sessionInterruptionListener(void *inClientData, UInt32 inInterruption){
	if (inInterruption == kAudioSessionBeginInterruption) {
		//DEBUG NSLog(@"begin interuption");
    }
	else if (inInterruption == kAudioSessionEndInterruption) {
		//DEBUG NSLog(@"end interuption");
	}
}


#pragma mark Callbacks

static OSStatus soundCallback(void *inRefCon, 
									AudioUnitRenderActionFlags *ioActionFlags, 
									const AudioTimeStamp *inTimeStamp, 
									UInt32 inBusNumber, 
									UInt32 inNumberFrames, 
									AudioBufferList *ioData) {  
	int i, j;
	//cast the buffer as an UInt32, cause our samples are in that format
	UInt32 *frameBuffer = (UInt32 *) ioData->mBuffers[0].mData;
	SInt16 *monoFrameBufferLeft;
	SInt16 *monoFrameBufferRight;
	UInt32 *sourceBuffer;
	SInt16 *monoSourceBufferLeft;
	SInt16 *monoSourceBufferRight;
	UInt32 * sourceBufferCurrentPosition;
	UInt32 sourceBufferTotalPlayTime;
	UInt32 sourceBufferTotalLength;
	float  sourceBufferVolume;
	BOOL sourceBufferRepeats;
	SInt16 val;
	float dval;
	
	// zero memory
	memset(frameBuffer, 0, sizeof(UInt32)*inNumberFrames);
	
	// add everything together:
	for (i=0; i < SOUNDPOLYPHONY; i++) {
		if (_soundSlotIsActive[i]) {	
			// get our samples
			sourceBuffer = _soundSlotsAudioDataRef[i];
			sourceBufferCurrentPosition = _soundSlotsCurrentPosition + i;
			sourceBufferTotalPlayTime = _soundSlotsTotalPlayTime[i];
			sourceBufferTotalLength = _soundSlotsTotalLength[i];
			sourceBufferVolume = _soundSlotsVolume[i];
			sourceBufferRepeats = _soundSlotRepeats[i];
			
			// Init pointers:
			monoFrameBufferLeft = (SInt16 *) frameBuffer;
			monoFrameBufferRight = (SInt16 *) frameBuffer;
			monoFrameBufferRight++;
			monoSourceBufferLeft = (SInt16 *) (sourceBuffer + *sourceBufferCurrentPosition);
			monoSourceBufferRight = (SInt16 *) (sourceBuffer + *sourceBufferCurrentPosition);
			monoSourceBufferRight++;
			// Various modes are possible: repeat or single shot
			for (j=0; j < inNumberFrames; j++) {
				if ( (*sourceBufferCurrentPosition) >= sourceBufferTotalLength) {
					if (sourceBufferRepeats) {
						*sourceBufferCurrentPosition = 0;
						monoSourceBufferLeft = (SInt16 *) (sourceBuffer);
						monoSourceBufferRight = (SInt16 *) (sourceBuffer);
						monoSourceBufferRight++;
					}
					else {
						// Set slot inactive
						_soundSlotIsActive[i] = NO;
						NSNumber * aNumber = [[NSNumber alloc] initWithInt:i];
						[audioEngine performSelectorOnMainThread:@selector(stopRenderSlotID:) withObject:aNumber waitUntilDone:NO];
						[aNumber release];
						break;
					}
				}
				// To apply volume we must treat both channels seperately!
				*monoFrameBufferLeft = *monoFrameBufferLeft + sourceBufferVolume*(*(monoSourceBufferLeft));
				monoFrameBufferLeft++;
				monoFrameBufferLeft++;
				monoSourceBufferLeft++;
				monoSourceBufferLeft++;
				*monoFrameBufferRight = *monoFrameBufferRight + sourceBufferVolume*(*(monoSourceBufferRight));
				monoFrameBufferRight++;
				monoFrameBufferRight++;
				monoSourceBufferRight++;
				monoSourceBufferRight++;

				*sourceBufferCurrentPosition = *sourceBufferCurrentPosition + 1;
			}
			_soundSlotsTotalPlayTime[inBusNumber] = sourceBufferTotalPlayTime + inNumberFrames;
		}
	}
	// Do the beep
	if (_beepIsActive) {
		// Init pointers
		monoFrameBufferLeft = (SInt16 *) frameBuffer;
		monoFrameBufferRight = (SInt16 *) frameBuffer;
		monoFrameBufferRight++;
	
		// Do the actual rendering
		if (_beepType == XmlBeepTypeSquare) {
			for (j=0; j < inNumberFrames; j++) {
				if ( _beepCurrentPosition >= _beepLengthSamples) {
					// Set slot inactive
					_beepIsActive = NO;
					[audioEngine performSelectorOnMainThread:@selector(stopRenderBeep) withObject:nil waitUntilDone:NO];
					break;
				}
				// generate a square wave
				val = (((_beepCurrentPosition++)<<0x1)*_beepFreqDivSAMPLERATE);
				val = val  & 0x1;
				val = val?0x7FFF:0x8000;
				val = _beepVolume*val;
				*monoFrameBufferLeft = *monoFrameBufferLeft + val;
				monoFrameBufferLeft++;
				monoFrameBufferLeft++;
				*monoFrameBufferRight = *monoFrameBufferRight + val;
				monoFrameBufferRight++;
				monoFrameBufferRight++;
			}
		}
		else if (_beepType == XmlBeepTypeSine) {
			for (j=0; j < inNumberFrames; j++) {
				if ( _beepCurrentPosition >= _beepLengthSamples) {
					// Set slot inactive
					_beepIsActive = NO;
					[audioEngine performSelectorOnMainThread:@selector(stopRenderBeep) withObject:nil waitUntilDone:NO];
					break;
				}
				// generate a sine wave
				dval = sin(2*M_PI*(_beepCurrentPosition++)*_beepFreqDivSAMPLERATE);
				val = 0x7FFF*_beepVolume*dval;
				*monoFrameBufferLeft = *monoFrameBufferLeft + val;
				monoFrameBufferLeft++;
				monoFrameBufferLeft++;
				*monoFrameBufferRight = *monoFrameBufferRight + val;
				monoFrameBufferRight++;
				monoFrameBufferRight++;
			}
		}				
		else if (_beepType == XmlBeepTypeSawtooth) {
			for (j=0; j < inNumberFrames; j++) {
				if ( _beepCurrentPosition >= _beepLengthSamples) {
					// Set slot inactive
					_beepIsActive = NO;
					[audioEngine performSelectorOnMainThread:@selector(stopRenderBeep) withObject:nil waitUntilDone:NO];
					break;
				}
				// generate a sawtooth wave
				dval = ((_beepCurrentPosition++)%((UInt32) _beepSAMPLERATEDivBeepFreq))*_beepFreqDivSAMPLERATE*2 - 1.0;
				val = 0x7FFF*_beepVolume*dval;
				*monoFrameBufferLeft = *monoFrameBufferLeft + val;
				monoFrameBufferLeft++;
				monoFrameBufferLeft++;
				*monoFrameBufferRight = *monoFrameBufferRight + val;
				monoFrameBufferRight++;
				monoFrameBufferRight++;
			}
		}
		else if (_beepType == XmlBeepTypeTriangle) {
			for (j=0; j < inNumberFrames; j++) {
				if ( _beepCurrentPosition >= _beepLengthSamples) {
					// Set slot inactive
					_beepIsActive = NO;
					[audioEngine performSelectorOnMainThread:@selector(stopRenderBeep) withObject:nil waitUntilDone:NO];
					break;
				}
				// generate a triangle wave
				dval = (((_beepCurrentPosition++)%((UInt32) _beepSAMPLERATEDivBeepFreq))*_beepFreqDivSAMPLERATE - 0.5);
				dval = (dval>0)?dval:-dval;
				dval = dval-0.25;
				val = 0x7FFF*4*dval*_beepVolume;
				*monoFrameBufferLeft = *monoFrameBufferLeft + val;
				monoFrameBufferLeft++;
				monoFrameBufferLeft++;
				*monoFrameBufferRight = *monoFrameBufferRight + val;
				monoFrameBufferRight++;
				monoFrameBufferRight++;
			}
		}			
	}
	
	return 0;
}


@implementation m48EmulatorAudioEngine
@synthesize graph = _graph;
@synthesize inMemoryAudioFiles = _inMemoryAudioFiles;

-(void)dealloc {
	[_inMemoryAudioFiles release];
	[self destroyAudioGraph];
	[super dealloc];
}

-(id)init {
	if (self = [super init]) {
		_currentXml = NULL;
		_currentBeepType = XmlBeepTypeSquare;
		audioEngine = self;

		// Init Sound slots:
		_soundSlotUniqueSessionID = 0;
		for (int i=0; i < SOUNDPOLYPHONY; i++) {
			_soundSlotIsActive[i] = NO;
		}
		
		// Init Volume settinsg
		_audioEnabled = NO;
		_audioVolume = 0.0;
		_audioSkinEnabled = NO;
		_audioSkinVolume = 0.0;
		_audioEmulatorEnabled = NO;
		_audioEmulatorVolume = NO;
		_audioSubstituteClick = NO;
			
		
		// Beep synthesizer
		_beepIsActive = NO;
		
		
		// Start the audio session and init the audio graph
		[self initAudioGraph];
		_graphLock = OS_SPINLOCK_INIT;
		
	}
	return self;
}


-(BOOL)loadSoundsFromXml:(XmlRoot *)aXml error:(NSError **)error {
	*error = nil;
	if (!aXml) {
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESND userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"No xml file loaded, from which sounds can be loaded.", NSLocalizedDescriptionKey, nil]];
		return NO;
	}
	if (aXml->global->nSounds == 0) {
		// Nothing to be done
		return YES;
	}
	
	// Is any sound running?
	[self panic];
	// Previous sounds will automatically be cleared
	self.inMemoryAudioFiles = [NSMutableDictionary dictionaryWithCapacity:aXml->global->nSounds];
	
	NSString * aString;
	int status;
	m48InMemoryAudioFile * anAudioFile;
	int anID;
	unsigned long memorysize = 0;	
	for (int i=0; i<aXml->global->nSounds; i++) {
		aString = getFullDocumentsPathForFile((aXml->global->sounds + i)->filename);
		anID = (aXml->global->sounds + i)->xmlSoundId;
		anAudioFile = [[m48InMemoryAudioFile alloc] init];
		anAudioFile.volume = (aXml->global->sounds + i)->volume;
		[_inMemoryAudioFiles setObject:anAudioFile forKey:[NSNumber numberWithInt:anID]];
		status = [anAudioFile open:aString];
		[anAudioFile release];
		if (status) {
			[_inMemoryAudioFiles release];
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESND userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Sound file could not be loaded.", NSLocalizedDescriptionKey, nil]];
			return NO;
		}
		memorysize += 4*anAudioFile.packetCount; // SInt32 = 4 bytes
		
		if (memorysize > MAXMEMORYAUDIOFILES) {
			[_inMemoryAudioFiles release];
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:ESND userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Exceeded maximum allowed memory limit for audio unpacked audiofiles.", NSLocalizedDescriptionKey, nil]];
			return NO;
		}		
	}
	_currentXml = aXml;	
	_currentBeepType = _currentXml->global->beepType;
	return YES;
}

-(void)loadSettings {
	[self panic];
	
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	_audioEnabled = [defaults boolForKey:@"audioEnabled"];
	_audioVolume = [defaults doubleForKey:@"audioVolume"];
	//_audioVolume = exp(M_LN_10*_audioVolume/20);
	_audioSkinEnabled = [defaults boolForKey:@"audioSkinEnabled"];
	_audioSkinVolume = [defaults doubleForKey:@"audioSkinVolume"];
	//_audioSkinVolume = exp(M_LN_10*_audioSkinVolume/20);
	_audioEmulatorEnabled = [defaults boolForKey:@"audioEmulatorEnabled"];
	_audioEmulatorVolume =  [defaults doubleForKey:@"audioEmulatorVolume"];
	//_audioEmulatorVolume =  = exp(M_LN_10*_audioEmulatorVolume/20);
	_audioSubstituteClick = [defaults boolForKey:@"audioSubstituteClick"];
	
	// Set up a debug-timer
	//NSTimer * aTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(verboseRenderStatus:) userInfo:nil repeats:YES] retain];
}

-(void)panic {
	_beepIsActive = NO;
	[self stopRenderBeep];
	for (int i=0; i < SOUNDPOLYPHONY; i++) {
		_soundSlotIsActive[i] = NO;
		[self stopRenderSlotID:[NSNumber numberWithInt:i]];
	}
	// Force stop rendering
	[self resetRendering];
}

-(void)playXmlSoundFX:(XmlSoundFX *)soundfx buttonDown:(BOOL)isDown {	
	if (!(_audioEnabled && _audioSkinEnabled)) return;		

	// Lets figure out what to play:
	UINT soundIDToPlay = 0;
	BOOL repeats = NO;
	if (isDown) {
		if (soundfx->soundIDOnDown) {
			soundIDToPlay = soundfx->soundIDOnDown;
		}
		else if(soundfx->soundIDOnHold)  {
			soundIDToPlay = soundfx->soundIDOnHold;
			repeats = soundfx->repeat;
		}
	}
	else {
		if (soundfx->soundIDOnUp) {
			soundIDToPlay = soundfx->soundIDOnUp;
		}
	}
	
	if (soundIDToPlay && _audioSubstituteClick) {
		if (isDown) {
			//AudioServicesPlaySystemSound(0x44F);
			AudioServicesPlaySystemSound(0x451); // besser
		}
		return;
	}
	
	// First lets see if a sound regarding this button is still playing
	unsigned long tempSessionID = soundfx->currentSessionID;
	UINT soundIDToKill;
	BOOL foundSoundIDToKill = NO;
	for (int i=0; i < SOUNDPOLYPHONY; i++) {
		if (_soundSlotIsActive[i] && (_soundSlotsCurrentSessionID[i] == tempSessionID)) {
			// Potentially stop the sound later
			soundIDToKill = i;
			foundSoundIDToKill = TRUE;
			break;
		}
	}
	
	if (foundSoundIDToKill && (soundIDToPlay || (!isDown && soundfx->soundIDOnHold))) {
		// Set slot inactive 
		_soundSlotIsActive[soundIDToKill] = NO;
		[self stopRenderSlotID:[NSNumber numberWithInt:soundIDToKill]];
	}
		
	if (!soundIDToPlay) return;
	
	
	// Find free slot:
	int freeSlot = 0;
	BOOL foundFreeSlot = NO;
	for (int i=0; i < SOUNDPOLYPHONY; i++) {
		if (_soundSlotIsActive[i] == NO) {
			freeSlot = i;
			foundFreeSlot = YES;
			break;
		}
	}
	// If we didnt find one, use oldest one without repeat
	UInt32 playTime = 0;
	if (!foundFreeSlot) {
		for (int i=0; i < SOUNDPOLYPHONY; i++) {
			if ((_soundSlotRepeats[i] == NO) && (_soundSlotsTotalPlayTime[i] > playTime)) {
				playTime = _soundSlotsTotalPlayTime[i];
				freeSlot = i;
			}
		}
		foundFreeSlot = playTime > 0;
	}
	// Find oldest one no matter what
	if (!foundFreeSlot) {
		for (int i=0; i < SOUNDPOLYPHONY; i++) {
			if (_soundSlotsTotalPlayTime[i] > playTime) {
				playTime = _soundSlotsTotalPlayTime[i];
				freeSlot = i;
			}
		}
	}	
	// In case something is playing, stop it.
	
	
	_soundSlotIsActive[freeSlot] = NO;
	[self stopRenderSlotID:[NSNumber numberWithInt:freeSlot]];
	
	// HOOK everything up
	m48InMemoryAudioFile * theAudioFile = [_inMemoryAudioFiles objectForKey:[NSNumber numberWithInt:soundIDToPlay]];
	_soundSlotsCurrentPosition[freeSlot] = 0;
	_soundSlotsTotalPlayTime[freeSlot] = 0;	
	_soundSlotRepeats[freeSlot] = repeats;
	soundfx->currentSessionID = ++_soundSlotUniqueSessionID;
	_soundSlotsCurrentSessionID[freeSlot] = soundfx->currentSessionID;
	_soundSlotsAudioDataRef[freeSlot] = theAudioFile.audioData;
	_soundSlotsTotalLength[freeSlot] = theAudioFile.packetCount;
	_soundSlotsVolume[freeSlot] = _audioVolume*_audioSkinVolume*(soundfx->volume)*(theAudioFile.volume);
	
	// Start it!
	_soundSlotIsActive[freeSlot] = YES;
	[self startRenderSlotID:[NSNumber numberWithInt:freeSlot]];
}



-(void)playBeep {
	if (!(_audioEmulatorEnabled && _audioEnabled)) return;
	
	// Halt if already playing
	if (_beepIsActive) {
		_beepIsActive = NO;
		[self stopRenderBeep];
	}
	
	// Precalculate some values:
	_beepLengthSamples = _beepLengthMS*BEEPSAMPLERATE/1000.0;
	_beepFreqDivSAMPLERATE = _beepFreq/((float) BEEPSAMPLERATE);
	_beepSAMPLERATEDivBeepFreq = ((float) BEEPSAMPLERATE)/_beepFreq;
	_beepCurrentPosition = 0;
	_beepVolume = _audioVolume*_audioEmulatorVolume;
	_beepType = xml->global->beepType;
	
	_beepIsActive = YES;
	[self startRenderBeep];
	return;
}

-(void)stopBeep {
	if (!(_audioEmulatorEnabled && _audioEnabled)) return;
	
	// Halt if already playing
	if (_beepIsActive) {
		_beepIsActive = NO;
		[self stopRenderBeep];
	}
}

#pragma mark Helper to count rendering
-(void)startRenderSlotID:(NSNumber *)slotID {
	OSSpinLockLock(&_graphLock);
	if (_slotIsRendered[[slotID intValue]] == NO) {
#ifndef AUDIOCONTINUOUSRENDERING
		AUGraphStart(_graph);
#endif
		_slotIsRendered[[slotID intValue]] = YES;
	}
	OSSpinLockUnlock(&_graphLock);
}

-(void)stopRenderSlotID:(NSNumber *)slotID {
	OSSpinLockLock(&_graphLock);
	if (_slotIsRendered[[slotID intValue]] == YES) {
#ifndef AUDIOCONTINUOUSRENDERING
		AUGraphStop(_graph);
#endif
		_slotIsRendered[[slotID intValue]] = NO;
	}	
	OSSpinLockUnlock(&_graphLock);
}


-(void)startRenderBeep {
	OSSpinLockLock(&_graphLock);
	if (_beepIsRendered == NO) {
#ifndef AUDIOCONTINUOUSRENDERING
		AUGraphStart(_graph);
#endif
		_beepIsRendered = YES;
	}
	OSSpinLockUnlock(&_graphLock);
}

-(void)stopRenderBeep {
	OSSpinLockLock(&_graphLock);
	if (_beepIsRendered == YES) {
#ifndef AUDIOCONTINUOUSRENDERING
		AUGraphStop(_graph);
#endif
		_beepIsRendered = NO;
	}
	OSSpinLockUnlock(&_graphLock);
}

-(void)resetRendering {
	OSSpinLockLock(&_graphLock);
	for (int i=0; i < SOUNDPOLYPHONY; i++) {
		_slotIsRendered[i] = NO;
	}
	_beepIsRendered = NO;
	
#ifndef AUDIOCONTINUOUSRENDERING
	Boolean isRunning;
	AUGraphIsRunning(_graph, &isRunning);
	while (isRunning) {		
		AUGraphStop(_graph);
		AUGraphIsRunning(_graph, &isRunning);
	}
#endif
	OSSpinLockUnlock(&_graphLock);
}

-(void)verboseRenderStatus:(NSTimer *)firedTimer {
	OSSpinLockLock(&_graphLock);
	NSMutableString * string = [NSMutableString stringWithCapacity:0];
	
	if (_beepIsRendered) {
		[string appendString:@"BEEP: 1 "];
	}
	else {
		[string appendString:@"BEEP: 0 "];
	}
	
	
	
	for (int i=0; i < SOUNDPOLYPHONY; i++) {
		[string appendFormat:@"SLOT%d %d ",i,_slotIsRendered[i]];
	}
	
	Boolean isRunning;
	AUGraphIsRunning(_graph, &isRunning);
	[string appendFormat:@"GRAHP %d\n",isRunning];
	//DEBUG NSLog(string);
	OSSpinLockUnlock(&_graphLock);
}
#pragma mark Initialization


-(void)setupAudioSession{
	
	// Initialize and configure the audio session, and add an interuption listener
    AudioSessionInitialize(NULL, NULL, sessionInterruptionListener, self);
	
	//set the audio category, depending on your app you need different categories, look them all up in the documentation 
	//by holding the option key (cursor changes to a + sign) and double clicking on the word kAudioSessionCategory_LiveAudio
	//or here http://developer.apple.com/iPhone/library/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionCategories/AudioSessionCategories.html
	//UInt32 audioCategory = kAudioSessionCategory_LiveAudio;
	UInt32 audioCategory = kAudioSessionCategory_AmbientSound;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory);
	
	//make sure we set the category
	UInt32 getAudioCategory = sizeof(audioCategory);
	AudioSessionGetProperty(kAudioSessionProperty_AudioCategory, &getAudioCategory, &getAudioCategory);
	
	//print out some diagnostics. we could throw an exception here instead.
	//if(getAudioCategory == kAudioSessionCategory_LiveAudio){
	//	//DEBUG NSLog(@"kAudioSessionCategory_LiveAudio");
	//}
	//else{
	//	//DEBUG NSLog(@"Could not get kAudioSessionCategory_LiveAudio");
	//}
	
	//add a property listener, to listen to changes to the session
	AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, sessionPropertyListener, self);
	
	//set the buffer size, this will affect the number of samples that get rendered every time the audio callback is fired
	//a small number will get you lower latency audio, but will make your processor work harder
	//Float32 preferredBufferSize = .0025;
	Float32 preferredBufferSize = .010; // 10ms
	AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize);
	
	//set the audio session active
	AudioSessionSetActive(YES);
}

-(void)destroyAudioSession {
	AudioSessionSetActive(NO);
	// Nothing else to be done!?
}

-(void)initAudioGraph{
	// **********************************
	// SETUP AUDIO SESSION
	// **********************************
	[self setupAudioSession];
	
	// **********************************
	// CREATE GRAPH
	// **********************************
	OSErr err = noErr;
	err = NewAUGraph(&_graph);
	//NSAssert(err == noErr, @"Error creating graph.");
	
	// **********************************
	// SETUP RemoteIO Audio UNIT
	// **********************************
	AudioComponentDescription outputDescription;
	AUNode outputNode;
	outputDescription.componentFlags = 0;
	outputDescription.componentFlagsMask = 0;
	outputDescription.componentType = kAudioUnitType_Output;
	outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	err = AUGraphAddNode(_graph, &outputDescription, &outputNode);
	//NSAssert(err == noErr, @"Error creating output node.");
	
			
	// **********************************
	// OPEN GRAPH AND GET AudioUnits
	// **********************************
	//there are three steps, we open the graph, initialise it and start it.
	//when we open it (from the doco) the audio units belonging to the graph are open but not initialized. Specifically, no resource allocation occurs.
	err = AUGraphOpen(_graph);
	//NSAssert(err == noErr, @"Error opening graph.");
	
	//now that the graph is open we can get the AudioUnits that are in the nodes (or node in this case)
	//get the output AudioUnit from the graph, we supply a node and a description and the graph creates the AudioUnit which
	//we then request back from the graph, so we can set properties on it, such as its audio format
	//get the mixer
	err = AUGraphNodeInfo(_graph, outputNode, &outputDescription, &_output);
	//NSAssert(err == noErr, @"Error getting AudioUnit.");
	
	// **********************************
	// SETUP CALLBACK STRUCTS
	// **********************************
	// Set up the soundCallback
	
	AURenderCallbackStruct soundCallbackStruct;
	soundCallbackStruct.inputProc = soundCallback;
	//set the reference to "self" this becomes *inRefCon in the playback callback
	//as the callback is just a straight C method this is how we can pass it an objective-C class
	soundCallbackStruct.inputProcRefCon = self;
	//now set the callback on the soundMixer node, this callback gets called whenever the AUGraph needs samples
	err = AUGraphSetNodeInputCallback(_graph, outputNode, 0, &soundCallbackStruct);
	//NSAssert(err == noErr, @"Error setting effects callback.");
	
	// **********************************
	// SETUP NODE PROPERTIES
	// **********************************	
	//lets actually set the audio format
	AudioStreamBasicDescription audioFormat;
	
	// Describe format
	audioFormat.mSampleRate			= 44100.00;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= 2;
	audioFormat.mBitsPerChannel		= 16;
	audioFormat.mBytesPerPacket		= 4;
	audioFormat.mBytesPerFrame		= 4;
	//IMPORTANT: --- the audio unit will play without the setting of the format, it seems to default to 44100khz, 16 bit, stereo, interleaved pcm
	//but who can tell if this will always be the case?
	
	// _output - Input
	err = AudioUnitSetProperty(_output, 
							   kAudioUnitProperty_StreamFormat, 
							   kAudioUnitScope_Input, 
							   0, 
							   &audioFormat, 
							   sizeof(audioFormat));
	//NSAssert(err == noErr, @"Error setting output - Input property.");		
	
	// **********************************
	// INITIALIZE GRAPH
	// **********************************	
	//we then initiailze the graph, this (from the doco):
	//Calling this function calls the AudioUnitInitialize function on each opened node or audio unit that is involved in a interaction. 
	//If a node is not involved, it is initialized after it becomes involved in an interaction.
	err = AUGraphInitialize(_graph);
	//NSAssert(err == noErr, @"Error initializing graph.");
	
	//this prints out a description of the graph, showing the nodes and connections, really handy.
	//this shows in the console (Command-Shift-R to see it)
	//CAShow(_graph); 
	
	//the final step, as soon as this is run, the graph will start requesting samples. some people would put this on the play button
	//but ive found that sometimes i get a bit of a pause so i let the callback get called from the start and only start filling the buffer
	//with samples when the play button is hit.
	//the doco says :
	//this function starts rendering by starting the head node of an audio processing graph. The graph must be initialized before it can be started.
	//err = AUGraphStart(_graph);
	////NSAssert(err == noErr, @"Error starting graph.");
#ifdef AUDIOCONTINUOUSRENDERING
	AUGraphStart(_graph);
#endif
}

-(void)destroyAudioGraph{
	[self panic];
#ifdef AUDIOCONTINUOUSRENDERING	
	AUGraphStop(_graph);
#endif
	AUGraphUninitialize(_graph);
	AUGraphClose (_graph);
	DisposeAUGraph(_graph);	
	[self destroyAudioSession];
}		

//-(void)setVolumes {
//	AudioUnitSetParameter(_mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, _audioVolume*_audioEmulatorVolume, 0);
//	AudioUnitSetParameter(_mixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, _audioVolume*_audioSkinVolume, 0);
//}

@end
