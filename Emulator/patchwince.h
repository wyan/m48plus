/*
 *  patchwince.h
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
#import "patchwintypes.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>

// Strings
//#define _T(expr) @expr // NSString
#define _T(expr) expr // UTF8Char
#define _istdigit(expr) ((expr >= '0') && (expr <= '9'))

// PerformanceFrequencyCounter
#define PerformanceCounterFreq 10000000 // 10MHz
void QueryPerformanceCounter(PLARGE_INTEGER x);
bool QueryPerformanceFrequency(PLARGE_INTEGER x);

// Threading
void WaitForCondition(NSCondition * aCondition, BOOL * aPredicate);
void SignalCondition(NSCondition * aCondition, BOOL * aPredicate);
void ResetCondition(NSCondition * aCondition, BOOL * aPredicate);

// Parths of iPhone-Application
NSString * getFullDocumentsPathForFile(NSString * filename);
NSString * getFullDocumentsPathForFileUTF8(char * filename);
NSString * getFullApplicationsPathForFile(NSString * filename);

// Memory
void ZeroMemory(void * ptr, long int len);
void FillMemory(void * ptr, long int len, BYTE val);

// File-Reading and Writing
void ReadFile(NSFileHandle * file, void * buffer, DWORD numberOfBytesToRead, DWORD * numberOfBytesRead, void * dummy);
void WriteFile(NSFileHandle * file, void * buffer, DWORD numberOfBytesToWrite, DWORD * numberOfBytesWritten, void * dummy);

/* ****************
 POSIX Threading 
 **************** */
void CreateEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate );
void DeleteEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate );
int WaitForEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate);
int TimedWaitForEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate, DWORD miliseconds);
void SetEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate);
void ResetEvent(pthread_cond_t * condition, pthread_mutex_t * mutex, BOOL * predicate);
void CreateThread(pthread_t * thread, void *(* startRoutine)(void *) );


