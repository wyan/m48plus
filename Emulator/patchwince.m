/*
 *  patchwince.m
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

#import "patchwinpch.h"
#import "patchwince.h"

inline void QueryPerformanceCounter(PLARGE_INTEGER x) {
	double d;
	d = CFAbsoluteTimeGetCurrent();
	x->QuadPart = round(PerformanceCounterFreq * d);
}

inline bool QueryPerformanceFrequency(PLARGE_INTEGER x) {
	x->QuadPart = PerformanceCounterFreq;
	return true;
}

inline void WaitForCondition(NSCondition * aCondition, BOOL * aPredicate) {
	[aCondition lock];
	while (!(*aPredicate)) {
		[aCondition wait];
	}
	*aPredicate = NO;
	[aCondition unlock];
}

inline void SignalCondition(NSCondition * aCondition, BOOL * aPredicate) {
	[aCondition lock];
	*aPredicate = YES;
	[aCondition signal];
	[aCondition unlock];
}

inline void ResetCondition(NSCondition * aCondition, BOOL * aPredicate) {
	[aCondition lock];
	*aPredicate = NO;
	[aCondition unlock];
}

// Parths of iPhone-Application
NSString * getFullDocumentsPathForFile(NSString * filename) {
	return [[NSHomeDirectory() stringByAppendingPathComponent:@"/Documents/"] stringByAppendingPathComponent:filename];
}

NSString * getFullDocumentsPathForFileUTF8(char * filename) {
	return getFullDocumentsPathForFile([NSString stringWithUTF8String:filename]);
}

// Parths of iPhone-Application
NSString * getFullApplicationsPathForFile(NSString * filename) {
	return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
}



// Memory
void inline ZeroMemory(void * ptr, long int len) {
	long int i;
	for(i=0; i < len; i++) {
		*((char *) ptr+i) = 0;
	}
}

void inline FillMemory(void * ptr, long int len, BYTE val) {
	long int i;
	for(i=0; i < len; i++) {
		*((BYTE *) ptr+i) = val;
	}
}

// File-Reading and Writing
void ReadFile(NSFileHandle * file, void * buffer, DWORD numberOfBytesToRead, DWORD * numberOfBytesRead, void * dummy) {
	NSData * data = [file readDataOfLength:numberOfBytesToRead];
	[data getBytes:buffer];
	*numberOfBytesRead = numberOfBytesToRead;
}

void WriteFile(NSFileHandle * file, void * buffer, DWORD numberOfBytesToWrite, DWORD * numberOfBytesWritten, void * dummy) {
	NSData * data = [NSData dataWithBytes:buffer length:numberOfBytesToWrite];
	[file writeData:data];
	*numberOfBytesWritten = numberOfBytesToWrite;
}

/* ****************
 POSIX Threading 
 **************** */
inline void CreateEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate ) {
	pthread_mutex_init(mutex, NULL);
	pthread_cond_init(condition, NULL);
	*predicate = FALSE;
}

inline void DeleteEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate ) {
	pthread_mutex_destroy(mutex);
	//*mutex = NULL;
	pthread_cond_destroy(condition);
	//*condition = NULL;
	*predicate = FALSE;
}

inline int WaitForEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate) {
	int retval;
	// Lock the mutex.
	pthread_mutex_lock(mutex);	
	// If the predicate is already set, then the while loop is bypassed;
	// otherwise, the thread sleeps until the predicate is set.
	while(*predicate == FALSE)
	{
		retval = pthread_cond_wait(condition, mutex);
	}
	// DO WORK
	// Reset the predicate and release the mutex.
	*predicate = FALSE;
	pthread_mutex_unlock(mutex);
	return retval;
}

inline int TimedWaitForEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate, DWORD miliseconds) {
	int retval;
	struct timespec ts;
	ts.tv_sec = miliseconds / 1000;
	ts.tv_nsec =  (miliseconds - 1000*ts.tv_sec) * 1000000;
	
	
	// Lock the mutex.
	pthread_mutex_lock(mutex);	
	// If the predicate is already set, then the while loop is bypassed;
	// otherwise, the thread sleeps until the predicate is set.
	//while ((*predicate == FALSE) || (retval == ETIMEDOUT))
	//{
		retval = pthread_cond_timedwait_relative_np(condition, mutex, &ts);
		//retval = pthread_cond_timedwait(condition, mutex, time)
	//}
	// If a signal was there we want to reset the retval
	if (*predicate)
		retval = 0; // Has to be unequal ETIMEDOUT (=62)
	// Reset the predicate and release the mutex.
	*predicate = FALSE;
	pthread_mutex_unlock(mutex);
	return retval;
}

inline void SetEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate) {
    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(mutex);
    *predicate = TRUE;
    // Signal the other thread to begin work.
    pthread_cond_signal(condition);
    pthread_mutex_unlock(mutex);
}

inline void ResetEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate) {
    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(mutex);
    *predicate = FALSE;
    pthread_mutex_unlock(mutex);
}

inline void CreateThread(pthread_t * thread, void *(* startRoutine)(void *) ) {
	// Create the thread using POSIX routines.
	pthread_attr_t  attr;
	int             returnVal;
	returnVal = pthread_attr_init(&attr);
	//pthread_attr_setstacksize (&attr, 1*1024*1024);
	
	_ASSERT(!returnVal);
	//returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
	//_ASSERT(!returnVal);
	int     threadError = pthread_create(thread, &attr, startRoutine, NULL);
	//int     threadError = pthread_create(thread, NULL, startRoutine, NULL);

//	size_t mystacksize;
//	pthread_attr_getstacksize(&attr,&mystacksize);
//	if (mystacksize > 7000000) {
//		mystacksize = mystacksize;
//	}
	
	returnVal = pthread_attr_destroy(&attr);
	_ASSERT(!returnVal);
	if (threadError != 0) {
		; // Report an error.
	}
	

}
