/*
 *   lowbat.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2006 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "emu48.h"
#import "io.h"								// I/O definitions

#define BAT_FREQ	(60*1000)				// bat update time in ms (real machine = 60us, HP28C = 60s)

BOOL bLowBatDisable = FALSE;

static pthread_t		hCThreadBat = NULL;
static pthread_cond_t	hEventBat;
static pthread_mutex_t	hEventBatLock;
static BOOL				hEventBatPredicate;

static void* LowBatThread(void * pParam)
{
	BOOL bLBI,bVLBI;

	do
	{
		GetBatteryState(&bLBI,&bVLBI);		// get battery state

		// very low bat detection
		bVLBI = bVLBI && (Chipset.IORam[LPE] & EVLBI) != 0;

		IOBit(LPD,VLBI,bVLBI);				// set VLBI
		IOBit(SRQ1,VSRQ,bVLBI);				// and service bit

		if (bVLBI)							// VLBI detected
		{
			Chipset.SoftInt = TRUE;
			bInterrupt = TRUE;

			if (Chipset.Shutdn)				// CPU shut down
			{
				Chipset.bShutdnWake = TRUE;	// wake up from SHUTDN mode
				SignalCondition(_shutdnCondition, &_shutdnConditionPredicate); // wake up emulation thread
			}
		}
	}
	while (TimedWaitForEvent(&hEventBat, &hEventBatLock, &hEventBatPredicate, BAT_FREQ) == ETIMEDOUT);

	return 0;
	UNREFERENCED_PARAMETER(pParam);
}

VOID StartBatMeasure(VOID)
{
	if (hCThreadBat)						// Bat measuring thread running
		return;								// -> quit

	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	
	// event to cancel Bat refresh loop
	CreateEvent(&hEventBat, &hEventBatLock, &hEventBatPredicate);

	CreateThread(&hCThreadBat, &LowBatThread);
	return;
}

VOID StopBatMeasure(VOID)
{
	if (hCThreadBat == NULL)				// thread stopped
		return;								// -> quit
	
	[UIDevice currentDevice].batteryMonitoringEnabled = NO;
	
	_ASSERT(hCThreadBat);
	SetEvent(&hEventBat, &hEventBatLock, &hEventBatPredicate);	// leave update thread
	(void) pthread_join(hCThreadBat, NULL);
	hCThreadBat = NULL;		// set flag update stopped								
	DeleteEvent(&hEventBat, &hEventBatLock, &hEventBatPredicate);  // close event
	return;
}

VOID GetBatteryState(BOOL *pbLBI, BOOL *pbVLBI)
{
	*pbLBI = FALSE;							// no battery warning
	*pbVLBI = FALSE;

	
	UIDevice * currentDevice = [UIDevice currentDevice];
	float batLevel = currentDevice.batteryLevel;
	UIDeviceBatteryState batState = currentDevice.batteryState;
	
	////DEBUG NSLog([NSString stringWithFormat:@"%.2f, %u", batLevel, batState]);
	
	// low bat emulation enabled and battery powered
	if (!bLowBatDisable && (batState == UIDeviceBatteryStateUnplugged))
	{
		// on critical battery state make sure that lowbat flag is also set
		if (batLevel < 0.2) {
			// low bat detection
			*pbLBI = TRUE;
		}
		
		if (batLevel < 0.05) {
			// very low bat detection
			*pbVLBI = TRUE;
		}
		
	}
	return;
}
