/*
 *  m48Emulator.m
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

#import "m48Emulator.h"
#import "emu48.h"
#import "io.h"
#import "xml.h"
#import "m48Errors.h"

//#import "io.h" // Temporary

const NSString * kUnsavedFileFilename = @".unsaved_file";
const NSString * kUnsavedFileDisplayText = @"<Unsaved File>";

@implementation m48Emulator
@synthesize contentChanged = _contentChanged;
	
-(id)init {
	if ((self = [super init])) {
		//Allokieren von Objekten für die Locks
		[_csLCDLock release];
		_csLCDLock = [[NSLock alloc] init];
		[_csKeyLock release];
		_csKeyLock = [[NSLock alloc] init];
		[_csIOLock release];
		_csIOLock = [[NSLock alloc] init];
		[_csT1Lock release];
		_csT1Lock = [[NSLock alloc] init];
		[_csT2Lock release];
		_csT2Lock = [[NSLock alloc] init];
		//_csSlowLock = [[NSLock alloc] init];		
		_slSlowLock = OS_SPINLOCK_INIT;
		
		//Allokieren von Objekten für die Conditions
		[_shutdnCondition release];
		_shutdnCondition = [[NSCondition alloc] init];
		_shutdnConditionPredicate = NO;
		
		// Teil I der Emulator-Initialisierung: DARF NUR EINMAL AUSGEFÜHRT WERDEN!!!!! (sonst werden mehrere threads gestartet)
		// Settings
		SetSpeed(bRealSpeed);
		QueryPerformanceFrequency(&lFreq);
		// Set up the worker thread
		nState = SM_RUN;
		nNextState = SM_INVALID;
				
		// Hier muss jetzt der Thread mit WorkerThread erzeugt werden
		[self performSelectorInBackground:@selector(workerThreadsWrapperMethod) withObject:nil];
		//NSThread *newThread = [[NSThread alloc] initWithTarget:self selector:@selector(workerThreadsWrapperMethod) object:nil];
		//[newThread setStackSize:0x400000];
		//[newThread start];
		
		while (nState != nNextState) {
			[NSThread sleepForTimeInterval:0];
		}
		
		//[self performSelectorInBackground:@selector(highRateMemoryWatch) withObject:nil];
		
		
		for (int i=0; i < BTNHISTMAX; i++) {
			buttonHistory[i][0] = 0;
			buttonHistory[i][1] = 0;
		}
		buttonHistoryNext = 0;
		
		_contentChanged = NO;
		_currentQueueLength = 0;
		_currentQueuePosition = 0;
	}
	return self;
}


// Debug
/*
- (void)highRateMemoryWatch {
	//NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
	BYTE * p;
	static BYTE * p_old;
	static BYTE p_old_val;
	[NSThread setThreadPriority:0.95];
	while(1) {
		p = RMap[129];
		if (p) {
			p = p+588+32;
			if ((p_old != p) && (*p != p_old_val)) {
				if ([_csLCDLock tryLock]) {
					[_csLCDLock unlock];
				}
				p_old = p;
				p_old_val = *p;
			}
			else if (*p != p_old_val) {
				if ([_csLCDLock tryLock]) {
					[_csLCDLock unlock];
				}
				p_old_val = *p;
			}
		}
		sleep(0); 
	}
	//[pool release];
}
*/

-(void)queueKeyboardEventOut:(int)_out In:(int)_in Predicate:(BOOL)predicate {
	// Add this event to the queue
	// Calculate end of queue
	int i = _currentQueuePosition + _currentQueueLength;
	if (i >= KEYBOARDQUEUEMAX) i -= KEYBOARDQUEUEMAX;
	_queue[i].out = _out;
	_queue[i].in = _in;
	_queue[i].bDown = predicate;
	_currentQueueLength++;
	if (_currentQueueLength > KEYBOARDQUEUEMAX) {
		NSLog(@"Overfull!!!!");
	}
	
	if (_currentQueueLength == 1) {
		[self processKeyboardEventQueue];
	}
}

// Dieses tuning  (60ms) funktioniert gut auf einem iPod Touch 1G (15.01.2010) -> Führt aber mit dem HP49 zu Problemen
// Tuning mit 100ms funktioniert auch für den HP49
-(void)processKeyboardEventQueue {
	static CFAbsoluteTime prev = 0;
	static DWORD oldCycles;
	CFAbsoluteTime cur = CFAbsoluteTimeGetCurrent();
	
	if (((Chipset.cycles - oldCycles) < 90000 ) && ((cur - prev) < 1.0)) {
		[self performSelector:@selector(processKeyboardEventQueue) withObject:nil afterDelay:0.06];
	}
	else {
		prev = cur;
		
		
		// Read out
		KeyboardEvent(_queue[_currentQueuePosition].bDown, _queue[_currentQueuePosition].out, _queue[_currentQueuePosition].in);
		//NSLog([NSString stringWithFormat:@"DeltaCycles = %d",Chipset.cycles-oldCycles]);
		
		oldCycles = Chipset.cycles;
		//[NSThread sleepForTimeInterval:0.1];
		
		// Now we have to increment position by one, and decrease length by one
		_currentQueueLength--;
		if ((++_currentQueuePosition) == KEYBOARDQUEUEMAX) _currentQueuePosition = 0;
		// if we still have something in the queue, lets call ourselfes again in few msec. That way, we don't block the main thread (using sleep would) and still have the proper spacing for the keyboard events
		if (_currentQueueLength > 0) {
			[self performSelector:@selector(processKeyboardEventQueue) withObject:nil afterDelay:0.06];
		}
	}
}

// Diese Methode ist nur ein erster Versuch den Emulator zu starten:
- (BOOL)newDocumentWithXml:(NSString *) filename error:(NSError **)error {
	// Teil II 
	if (error != NULL) {
		*error = nil;
	}
	if (NewDocument(filename, error)) {
		// Save in NSUserDefaults
		[[NSUserDefaults standardUserDefaults] setObject:kUnsavedFileFilename forKey:@"internalCurrentDocumentFilename"];
		[[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"internalCurrentDocumentDirectory"];	
		return YES;
	}
	else {
		return NO;
	}
	
}


- (BOOL)loadDocument:(NSString *) filename error:(NSError **)error {
	// Teil II 
	if (error != NULL) {
		*error = nil;
	}
	if (OpenDocument(filename, error)) {
		// Save in NSUserDefaults
		[[NSUserDefaults standardUserDefaults] setObject:[filename lastPathComponent] forKey:@"internalCurrentDocumentFilename"];
		NSArray * pathComponents1 = [getFullDocumentsPathForFile(@".") pathComponents];
		NSArray * pathComponents2 = [filename pathComponents];
		NSRange range = {[pathComponents1 count]-1, [pathComponents2 count] - [pathComponents1 count]};
		NSString * temp2  = [NSString pathWithComponents:[pathComponents2 objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]]];
		temp2 = [temp2 stringByAppendingString:@"/"];
		[[NSUserDefaults standardUserDefaults] setObject:temp2 forKey:@"internalCurrentDocumentDirectory"];	
		return YES;
	} 
	else {
		return NO;
	}
}

- (BOOL)saveDocument:(NSString *) filename error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
	if (WriteDocument(filename, error)) {
		// Save in NSUserDefaults
		[[NSUserDefaults standardUserDefaults] setObject:[filename lastPathComponent] forKey:@"internalCurrentDocumentFilename"];
		NSArray * pathComponents1 = [getFullDocumentsPathForFile(@".") pathComponents];
		NSArray * pathComponents2 = [filename pathComponents];
		NSRange range = {[pathComponents1 count]-1, [pathComponents2 count] - [pathComponents1 count]};
		NSString * temp2  = [NSString pathWithComponents:[pathComponents2 objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]]];
		temp2 = [temp2 stringByAppendingString:@"/"];
		[[NSUserDefaults standardUserDefaults] setObject:temp2 forKey:@"internalCurrentDocumentDirectory"];
		_contentChanged = !(nState == SM_SLEEP);
		return YES;
	}
	else {
		return NO ;
	}
}

// Diese Methode ist nur ein erster Versuch den Emulator zu starten:
- (BOOL)loadXmlDocument:(NSString *) filename error:(NSError **)error {
	XmlRoot * backup = NULL;
	BYTE * pbyRomBackup = NULL;
	
	
	// Teil II 
	if (error != NULL) {
		*error = nil;
	}

	// Create backup
	backup = xml;
	xml = NULL;
	
	pbyRomBackup = pbyRom;
	pbyRom = NULL;
	
	
	if (!InitXML(filename, error)) {
		goto restore3;
		
	}

	if (xml && xml->global && (!MapRom(getFullDocumentsPathForFile(xml->global->romFilename)))) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not load ROM.", NSLocalizedDescriptionKey, nil]];
		}
		goto restore2;
	}
	
	if (xml && xml->global && (xml->global->patchFilename != nil)) {
		if (!PatchRom(getFullDocumentsPathForFile(xml->global->patchFilename))) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not patch ROM.", NSLocalizedDescriptionKey, nil]];
			goto restore;
		}
	}
	
	// For now lets gte rid of the old rom the hard way
	if (pbyRomBackup) {
		free(pbyRomBackup);
	}
	if (backup != NULL) {
		killXmlRoot(backup);
		free(backup);
	}
	
	return YES;
restore:
	free(pbyRom);
restore2:
	killXmlRoot(xml);
	free(xml);
restore3:
	xml = backup;
	pbyRom = pbyRomBackup;
	return NO;
}

- (BOOL)closeDocument {
	ResetDocument();
	DeleteXmlCacheFile();
	NSUserDefaults * myDefaults = [NSUserDefaults standardUserDefaults];
	[myDefaults setObject:@"" forKey:@"internalCurrentXmlFilename"];
	[myDefaults setObject:@"" forKey:@"internalCurrentXmlDirectory"];
	[myDefaults setObject:@"" forKey:@"internalCurrentDocumentFilename"];
	[myDefaults setObject:@"" forKey:@"internalCurrentDocumentDirectory"];
	return YES;
}
#ifdef VERSIONPLUS
- (BOOL)loadObject:(NSString *) filename error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
	
	
	// calculator off, turn on
	if (!(Chipset.IORam[BITOFFSET]&DON))
	{
		KeyboardEvent(TRUE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];
		KeyboardEvent(FALSE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];
		
		// wait for sleep mode
		while (Chipset.Shutdn == FALSE) {
			[NSThread sleepForTimeInterval:0];
		}
	}
	
	BOOL isAsleep = (nState == SM_SLEEP);
	
	if (!isAsleep && (nState != SM_RUN))
	{
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The emulator must be running to load an object.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	if (!isAsleep && WaitForSleepState())				// wait for cpu SHUTDN then sleep state
	{
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The emulator is busy.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	//_ASSERT(nState == SM_SLEEP);
	
	if (!LoadObject(filename, error))
	{
		if (!isAsleep) SwitchToState(SM_RUN);
		return NO;
	}
	
	
	SwitchToState(SM_RUN);					// run state
	while (nState!=nNextState) {
		[NSThread sleepForTimeInterval:0];
	}

	
	//_ASSERT(nState == SM_RUN);
	KeyboardEvent(TRUE,0,0x8000);
	[NSThread sleepForTimeInterval:0.2];
	KeyboardEvent(FALSE,0,0x8000);
	[NSThread sleepForTimeInterval:0.05];
	while (Chipset.Shutdn == FALSE) { 
		[NSThread sleepForTimeInterval:0];
	}
	
	if (isAsleep) {
		WaitForSleepState();
	}
	return YES;
}


- (BOOL)saveObject:(NSString *) filename error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
	
	// calculator off, turn on
	if (!(Chipset.IORam[BITOFFSET]&DON))
	{
		KeyboardEvent(TRUE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];
		KeyboardEvent(FALSE,0,0x8000);
		[NSThread sleepForTimeInterval:0.05];
		
		// wait for sleep mode
		while (Chipset.Shutdn == FALSE) {
			[NSThread sleepForTimeInterval:0];
		}
	}
	
	BOOL isAsleep = (nState == SM_SLEEP);
	
	if (!isAsleep && (nState != SM_RUN))
	{
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The emulator must be running to load an object.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	if (!isAsleep && WaitForSleepState())				// wait for cpu SHUTDN then sleep state
	{
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EEMU userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The emulator is busy.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	
	//_ASSERT(nState == SM_SLEEP);
	
	if (!SaveObject(filename, error))
	{
		if (!isAsleep) SwitchToState(SM_RUN);
		return NO;
	}
	
	
	SwitchToState(SM_RUN);					// run state
	while (nState!=nNextState) {
		[NSThread sleepForTimeInterval:0];
	}
	
	
	//_ASSERT(nState == SM_RUN);
	KeyboardEvent(TRUE,0,0x8000);
	[NSThread sleepForTimeInterval:0.2];
	KeyboardEvent(FALSE,0,0x8000);
	while (Chipset.Shutdn == FALSE) { 
		[NSThread sleepForTimeInterval:0];
	}
	
	if (isAsleep) {
		WaitForSleepState();
	}
	return YES;
}
#endif

- (void)reset {
	// Can be running or sleeping
	if (nState == SM_SLEEP) {
		CpuReset();
	}
	else if (nState == SM_RUN) {
		SwitchToState(SM_SLEEP);
		CpuReset();							// register setting after Cpu Reset
		SwitchToState(SM_RUN);
	}
	return;	
}


// Threading
-(void)workerThreadsWrapperMethod {
	// Setup Autorelease pool
	NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
	// RunLoop needed here?
	
	// Call the actual C-Worker Thread of EMU48
	WorkerThread(NULL);
	
	// Run Loop needed to be released here?
	// release Autorelease pool
	[pool release];
}



-(void)run {
	if (pbyRom) {
		SwitchToState(SM_RUN);
	}
	_contentChanged = YES;
}


-(BOOL)pause {
	return WaitForSleepState();
}
	

-(void)stop {	
	SwitchToState(SM_RETURN);
}

-(BOOL)isRunning {
	return ((nState == SM_RUN) || (nState == SM_SLEEP));
}

-(void)loadSettings {
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	bRealSpeed = [defaults boolForKey:@"emulatorAuthenticCalculatorSpeed"];
	SetSpeed(bRealSpeed);
	bLowBatDisable = [defaults boolForKey:@"emulatorLowBatDisable"];
	//dwSXCycles =  [defaults integerForKey:@"emulatorSXCycles"];
	//dwGXCycles =  [defaults integerForKey:@"emulatorGXCycles"];
}

- (void)dealloc {	
	[self stop];
	
	[_shutdnCondition release];
	_shutdnCondition = nil;
	[_csLCDLock release];
	_csLCDLock = nil;
	[_csKeyLock release];
	_csKeyLock = nil;
	[_csIOLock release];
	_csIOLock = nil;
	[_csT1Lock release];
	_csT1Lock = nil;
	[_csT2Lock release];
	_csT2Lock = nil;
	//[_csSlowLock release];
	
	[super dealloc];
}

@end
