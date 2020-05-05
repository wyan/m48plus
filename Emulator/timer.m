/*
 *   timer.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "patchwince.h"
#import "emu48.h"
#import "ops.h"
#import "io.h"								// I/O definitions

#import <time.h>


#define AUTO_OFF    10						// Time in minutes for 'auto off'

// Ticks for 01.01.1970 00:00:00
#define UNIX_0_TIME	((ULONGLONG) 0x0001cf2e8f800000)

// Ticks for 'auto off'
#define OFF_TIME	((ULONGLONG) (AUTO_OFF * 60) << 13)

// memory address for clock and auto off
// S(X) = 0x70052-0x70070, G(X) = 0x80058-0x80076, 49G = 0x80058-0x80076
#define RPLTIME		((cCurrentRomType=='S')?0x52:0x58)

#define T1_FREQ		62						// Timer1 1/frequency in ms
#define T2_FREQ		8192					// Timer2 frequency

static BOOL   bStarted   = FALSE;

static pthread_t		hCThreadT1 = NULL;			// timer1 thread control
static pthread_cond_t	hEventT1;
static pthread_mutex_t	hEventT1Lock;
static BOOL				hEventT1Predicate;

static pthread_t		hCThreadT2 = NULL;			// timer2 thread control
static pthread_cond_t	hEventT2;
static pthread_mutex_t	hEventT2Lock;
static BOOL				hEventT2Predicate;

static BOOL   bNINT2T1 = FALSE;				// state of NINT2 affected from timer1
static BOOL   bNINT2T2 = FALSE;				// state of NINT2 affected from timer2

static LARGE_INTEGER lT2Ref;				// counter value at timer2 start
static DWORD  dwT2Ref;						// timer2 value at last timer2 access
static DWORD  dwT2Cyc;						// cpu cycle counter at last timer2 access

static BOOL   bT2Running;



static inline DWORD __max(DWORD a,DWORD b) {
	return ((a>b)?a:b);
}
	

static __inline VOID SetT2Refpoint(VOID)
{
	dwT2Ref = Chipset.t2;					// timer2 value at last timer2 access
	dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF); // cpu cycle counter at last timer2 access
	QueryPerformanceCounter(&lT2Ref);		// time of corresponding Chipset.t2 value
}

static DWORD CalcT2(VOID)					// calculate timer2 value
{
	DWORD dwT2 = Chipset.t2;				// get value from chipset
	if (bStarted)							// timer2 running
	{
		LARGE_INTEGER lT2Act;
		DWORD         dwT2Dif;
		
		// timer should run a much faster for fixing long freeze times
		DWORD dwCycPerTick = (3 * T2CYCLES) / 5;
		
		QueryPerformanceCounter(&lT2Act);	// actual time
		// calculate realtime timer2 ticks since reference point
		dwT2 -= (DWORD) 
		(((lT2Act.QuadPart - lT2Ref.QuadPart) * T2_FREQ)
		 / lFreq.QuadPart);
		
		dwT2Dif = dwT2Ref - dwT2;			// timer2 ticks since last request
		
		// 2nd timer call in a 156ms time frame or elapsed time is negative (Win2k bug)
		if (!Chipset.Shutdn && ((dwT2Dif > 0x01 && dwT2Dif <= 0x500) || (dwT2Dif & 0x80000000) != 0))
		{
			DWORD dwT2Ticks = ((DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwT2Cyc) / dwCycPerTick;
			
			// estimated < real elapsed timer2 ticks or negative time
			if (dwT2Ticks < dwT2Dif || (dwT2Dif & 0x80000000) != 0)
			{
				// real time too long or got negative time elapsed
				dwT2 = dwT2Ref - dwT2Ticks;	// estimated timer2 value from CPU cycles
				dwT2Cyc += dwT2Ticks * dwCycPerTick; // estimated CPU cycles for the timer2 ticks
			}
			else
			{
				// reached actual time -> new synchronizing
				dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
			}
		}
		else
		{
			// valid actual time -> new synchronizing
			dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
		}
		
		// check if timer2 interrupt is active -> no timer2 value below 0xFFFFFFFF
		if (   Chipset.inte
			&& (dwT2 & 0x80000000) != 0
			&& (!Chipset.Shutdn || (Chipset.IORam[TIMER2_CTRL]&WKE))
			&& (Chipset.IORam[TIMER2_CTRL]&INTR)
			)
		{
			dwT2 = 0xFFFFFFFF;
			dwT2Cyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF) - dwCycPerTick;
		}
		
		dwT2Ref = dwT2;						// new reference time
	}
	return dwT2;
}

static VOID CheckT1(BYTE nT1)
{
	// implementation of TSRQ
	bNINT2T1 = (Chipset.IORam[TIMER1_CTRL]&INTR) != 0 && (nT1&8) != 0;
	IOBit(SRQ1,TSRQ,bNINT2T1 || bNINT2T2);
	
	if ((nT1&8) == 0)						// timer1 MSB not set
	{
		Chipset.IORam[TIMER1_CTRL] &= ~SRQ;	// clear SRQ bit
		return;
	}
	
	_ASSERT((nT1&8) != 0);					// timer1 MSB set
	
	// timer MSB and INT or WAKE bit is set
	if ((Chipset.IORam[TIMER1_CTRL]&(WKE|INTR)) != 0)
		Chipset.IORam[TIMER1_CTRL] |= SRQ;	// set SRQ
	// cpu not sleeping and T1 -> Interrupt
	if (   (!Chipset.Shutdn || (Chipset.IORam[TIMER1_CTRL]&WKE))
		&& (Chipset.IORam[TIMER1_CTRL]&INTR))
	{
		Chipset.SoftInt = TRUE;
		bInterrupt = TRUE;
	}
	// cpu sleeping and T1 -> Wake Up
	if (Chipset.Shutdn && (Chipset.IORam[TIMER1_CTRL]&WKE))
	{
		Chipset.IORam[TIMER1_CTRL] &= ~WKE;	// clear WKE bit
		Chipset.bShutdnWake = TRUE;			// wake up from SHUTDN mode
		SignalCondition(_shutdnCondition, &_shutdnConditionPredicate); // wake up emulation thread			
	}
	return;
}

static VOID CheckT2(DWORD dwT2)
{
	// implementation of TSRQ
	bNINT2T2 = (Chipset.IORam[TIMER2_CTRL]&INTR) != 0 && (dwT2&0x80000000) != 0;
	IOBit(SRQ1,TSRQ,bNINT2T1 || bNINT2T2);
	
	if ((dwT2&0x80000000) == 0)				// timer2 MSB not set
	{
		Chipset.IORam[TIMER2_CTRL] &= ~SRQ;	// clear SRQ bit
		return;
	}
	
	_ASSERT((dwT2&0x80000000) != 0);		// timer2 MSB set
	
	// timer MSB and INT or WAKE bit is set
	if ((Chipset.IORam[TIMER2_CTRL]&(WKE|INTR)) != 0)
		Chipset.IORam[TIMER2_CTRL] |= SRQ;	// set SRQ
	// cpu not sleeping and T2 -> Interrupt
	if (   (!Chipset.Shutdn || (Chipset.IORam[TIMER2_CTRL]&WKE))
		&& (Chipset.IORam[TIMER2_CTRL]&INTR))
	{
		Chipset.SoftInt = TRUE;
		bInterrupt = TRUE;
	}
	// cpu sleeping and T2 -> Wake Up
	if (Chipset.Shutdn && (Chipset.IORam[TIMER2_CTRL]&WKE))
	{
		Chipset.IORam[TIMER2_CTRL] &= ~WKE;	// clear WKE bit
		Chipset.bShutdnWake = TRUE;			// wake up from SHUTDN mode
		SignalCondition(_shutdnCondition, &_shutdnConditionPredicate); // wake up emulation thread
	}
	return;
}

static void* T1Thread(void * pParam)
{
	while (TimedWaitForEvent(&hEventT1, &hEventT1Lock, &hEventT1Predicate, T1_FREQ) == ETIMEDOUT)
	{
		[_csT1Lock lock];
		{
			Chipset.t1 = (Chipset.t1-1)&0xF;// decrement timer value
			CheckT1(Chipset.t1);			// test timer1 control bits
		}
		[_csT1Lock unlock];
	}
	
	pthread_exit(NULL);
	return 0;
	UNREFERENCED_PARAMETER(pParam);
}

static void* T2Thread(void * pParam)
{
	DWORD dwDelay;
	BOOL  bOutRange = FALSE;
	
	while (bT2Running)
	{
		[_csT2Lock lock];
		{
			if (!bOutRange)					// save reference time
			{
				SetT2Refpoint();			// reference point for CalcT2()
				dwDelay = Chipset.t2;		// timer value for delay
			}
			else							// called without new refpoint, restart t2 with actual value
			{
				dwDelay = CalcT2();			// actual timer value for delay
			}
			
			// delay too big for multiplication
			if ((bOutRange = dwDelay > (0xFFFFFFFF - 1023) / 125))
				dwDelay = (0xFFFFFFFF - 1023) / 125; // wait maximum delay time
		}
		[_csT2Lock unlock];
		
		dwDelay = (dwDelay * 125 + 1023) / 1024; // timer delay in ms (1000/8192 = 125/1024)
		dwDelay = __max(1,dwDelay);			// wait minimum delay of timer
		
		if (TimedWaitForEvent(&hEventT2, &hEventT2Lock, &hEventT2Predicate, dwDelay) != ETIMEDOUT)
		{
			// got new timer2 value
			bOutRange = FALSE;				// set new refpoint
			continue;
		}
		
		[_csT2Lock lock];
		{
			// timer2 overrun, test timer2 control bits
			Chipset.t2 = CalcT2();			// calculate new timer2 value
			CheckT2(Chipset.t2);			// test timer2 control bits
		}
		[_csT2Lock unlock];
	}

	pthread_exit(NULL);
	return 0;
	UNREFERENCED_PARAMETER(pParam);
}

static VOID AbortT1(VOID)
{
	_ASSERT(hCThreadT1);
	SetEvent(&hEventT1, &hEventT1Lock, &hEventT1Predicate);	// leave timer1 update thread
	(void) pthread_join(hCThreadT1, NULL);
	hCThreadT1 = NULL;						// set flag display update stopped
	return;
}

static VOID AbortT2(VOID)
{
	_ASSERT(hCThreadT2);
	bT2Running = FALSE;						// leave working loop
	SetEvent(&hEventT2, &hEventT2Lock, &hEventT2Predicate);	// leave timer2 update thread
	(void) pthread_join(hCThreadT2, NULL);
	hCThreadT2 = NULL;						// set flag display update stopped
	return;
}

VOID SetHP48Time(VOID)						// set date and time
{	
	//SYSTEMTIME ts;
	ULONGLONG  ticks, time;
	DWORD      dw;
	WORD       crc, i;
	BYTE       p[4];
	NSTimeInterval tempInterval;
	
	_ASSERT(sizeof(ULONGLONG) == 8);		// check size of datatype
	
    tempInterval = [[NSDate date] timeIntervalSince1970] + [[NSTimeZone localTimeZone] secondsFromGMT];

	tempInterval = 8192.0*tempInterval;
	ticks = tempInterval;
	
	ticks += UNIX_0_TIME;					// add offset ticks from year 0
	ticks += Chipset.t2;					// add actual timer2 value
	
	time = ticks;							// save for calc. timeout
	time += OFF_TIME;						// add 10 min for auto off
	
	dw = RPLTIME;							// HP addresses for clock in port0
	
	crc = 0x0;								// reset crc value
	for (i = 0; i < 13; ++i, ++dw)			// write date and time
	{
		*p = (BYTE) ticks & 0xf;
		crc = (crc >> 4) ^ (((crc ^ ((WORD) *p)) & 0xf) * 0x1081);
		Chipset.Port0[dw] = *p;				// always store in port0
		ticks >>= 4;
	}
	
	Nunpack(p,crc,4);						// write crc
	memcpy(Chipset.Port0+dw,p,4);			// always store in port0
	
	dw += 4;								// HP addresses for timeout
	
	for (i = 0; i < 13; ++i, ++dw)			// write time for auto off
	{
		// always store in port0
		Chipset.Port0[dw] = (BYTE) time & 0xf;
		time >>= 4;
	}
	
	Chipset.Port0[dw] = 0xf;				// always store in port0
	return;
}

VOID StartTimers(VOID)
{
	if (bStarted)							// timer running
		return;								// -> quit
	if (Chipset.IORam[TIMER2_CTRL]&RUN)		// start timer1 and timer2 ?
	{
		bStarted = TRUE;					// flag timer running
		// initialisation of NINT2 lines
		bNINT2T1 = (Chipset.IORam[TIMER1_CTRL]&INTR) != 0 && (Chipset.t1 & 8) != 0;
		bNINT2T2 = (Chipset.IORam[TIMER2_CTRL]&INTR) != 0 && (Chipset.t2 & 0x80000000) != 0;
		CheckT1(Chipset.t1);				// check for timer1 interrupts
		CheckT2(Chipset.t2);				// check for timer2 interrupts
		
		// events to cancel timer loops
		CreateEvent(&hEventT1, &hEventT1Lock, &hEventT1Predicate);
		CreateEvent(&hEventT2, &hEventT2Lock, &hEventT2Predicate);
		
		bT2Running = TRUE;					// don't leave worker thread
		
		// start timer1 update thread
		CreateThread(&hCThreadT1, &T1Thread);
		
		// start timer2 update thread
		SetT2Refpoint();					// reference point for CalcT2()
		CreateThread(&hCThreadT2, &T2Thread);	
	}
	return;
}

VOID StopTimers(VOID)
{
	if (!bStarted)							// timer stopped
		return;								// -> quit
	if (hCThreadT1 != NULL)					// timer1 running
	{
		// Critical Section handler may cause a dead lock
		AbortT1();							// stop timer1
	}
	if (hCThreadT2 != NULL)					// timer2 running
	{
		[_csT2Lock lock];
		{
			Chipset.t2 = CalcT2();			// update chipset timer2 value
		}
		[_csT2Lock unlock];
		AbortT2();							// stop timer2 outside critical section
	}
	DeleteEvent(&hEventT1, &hEventT1Lock, &hEventT1Predicate); // close timer1 event
	DeleteEvent(&hEventT2, &hEventT2Lock, &hEventT2Predicate); // close timer2 event			
	bStarted = FALSE;
	return;
}

DWORD ReadT2(VOID)
{
	DWORD dwT2;
	[_csT2Lock lock];
	{
		dwT2 = CalcT2();					// calculate timer2 value or if stopped last timer value
		CheckT2(dwT2);						// update timer2 control bits
	}
	[_csT2Lock unlock];
	return dwT2;
}

VOID SetT2(DWORD dwValue)
{
	[_csT2Lock lock];
	{
		Chipset.t2 = dwValue;				// set new value
		CheckT2(Chipset.t2);				// test timer2 control bits
		if (bStarted)						// timer running
		{
			SetT2Refpoint();				// reference point for CalcT2()
			SetEvent(&hEventT2,&hEventT2Lock,&hEventT2Predicate);				// new delay
		}
	}
	[_csT2Lock unlock];
	return;
}

BYTE ReadT1(VOID)
{
	BYTE nT1;
	[_csT1Lock lock];
	{
		nT1 = Chipset.t1;					// read timer1 value
		CheckT1(nT1);						// update timer1 control bits
	}
	[_csT1Lock unlock];
	return nT1;
}

VOID SetT1(BYTE byValue)
{
	BOOL bEqual;
	
	_ASSERT(byValue < 0x10);				// timer1 is only a 4bit counter
	
	[_csT1Lock lock];
	{
		bEqual = (Chipset.t1 == byValue);	// check for same value
	}
	[_csT1Lock unlock];
	if (bEqual) return;						// same value doesn't restart timer period
	if (hCThreadT1 != NULL)					// timer1 running
	{
		AbortT1();							// stop timer1
	} 
	[_csT1Lock lock];
	{
		Chipset.t1 = byValue;				// set new timer1 value
		CheckT1(Chipset.t1);				// test timer1 control bits
	}
	[_csT1Lock unlock];
	if (bStarted)							// timer running
	{
		// restart timer1 to get full period of frequency
		// Ist der Thread hier noch am Leben?????? Sonst müsste er vorher beendet werden
		
		CreateThread(&hCThreadT1, &T1Thread);
	} 
	return;
}
