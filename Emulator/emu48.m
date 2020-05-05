/*
 *   Emu48.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gieﬂelink
 *
 */
#import <UIKit/UIKit.h>
#import "emu48.h"
#import "io.h"

#define VERSION   "i1.16"

#define MAXPORTS  9							// number of COM ports

NSLock *		_csLCDLock;					// critical section for hWindowDC
NSLock *		_csKeyLock;					// critical section for key scan
NSLock *		_csIOLock;					// critical section for I/O access
NSLock *		_csT1Lock;					// critical section for timer1 access
NSLock *		_csT2Lock;					// critical section for timer2 access
//NSLock *		_csSlowLock;				// critical section for speed slow down
OSSpinLock		_slSlowLock = OS_SPINLOCK_INIT;

NSCondition *	_shutdnCondition;			// Condition for shutting down the thread
BOOL			_shutdnConditionPredicate;  // predicate for the condition to shut down a thread


LARGE_INTEGER   lFreq;						// high performance counter frequency
LARGE_INTEGER   lAppStart;					// high performance counter value at Appl. start

pthread_t		hThread = NULL;

DWORD            dwWakeupDelay = 200;		// ON key hold time to switch on calculator
