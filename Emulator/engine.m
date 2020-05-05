/*
 *   engine.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "patchwince.h"

#import "emu48.h"

#import "opcodes.h"
#import "ops.h"
#import "io.h"

#define SAMPLE    16384						// speed adjust sample frequency

BOOL    bInterrupt = FALSE;
UINT    nState = SM_INVALID;
UINT    nNextState = SM_RUN;
BOOL    bRealSpeed = FALSE;
BOOL    bKeySlow = FALSE;					// slow down for key emulation
BOOL    bCommInit = FALSE;					// COM port not open

BOOL	contentChanged = YES;

CHIPSET Chipset;							// chipset of master Lewis

//TCHAR   szSerialWire[16];					// devicename for wire port
//TCHAR   szSerialIr[16];						// devicename for IR port

DWORD   dwSXCycles = 82;					// SX cpu cycles in interval
DWORD   dwGXCycles = 123;					// GX cpu cycles in interval

static BOOL  bCpuSlow = FALSE;				// enable/disable real speed

static DWORD dwOldCyc;						// cpu cycles at last event
static DWORD dwSpeedRef;					// timer value at last event
static DWORD dwTickRef;						// sample timer ticks

#import "ops.h"


static inline VOID AdjustSpeed(VOID)		// adjust emulation speed
{
	if (bCpuSlow || bKeySlow)				// emulation slow down
	{
		DWORD dwCycles,dwTicks;

		//[_csSlowLock lock];
		OSSpinLockLock(&_slSlowLock);
		{
			// cycles elapsed for next check
			if ((dwCycles = (DWORD) (Chipset.cycles & 0xFFFFFFFF)-dwOldCyc) >= (DWORD) T2CYCLES)
			{
				LARGE_INTEGER lAct;
				do
				{
					QueryPerformanceCounter(&lAct);

					// get time difference
					dwTicks = lAct.LowPart - dwSpeedRef;
				}
				// ticks elapsed or negative number (workaround for QueryPerformanceCounter() in Win2k)
				while (dwTicks <= dwTickRef); //mksg || (dwTicks & 0x80000000) != 0);

				dwOldCyc += T2CYCLES;		// adjust cycles reference
				dwSpeedRef += dwTickRef;	// adjust reference time
			}
		}
		//[_csSlowLock unlock];
		OSSpinLockUnlock(&_slSlowLock);
	}
	return;
}

VOID CheckSerial(VOID)
{
	// COM port closed and serial on
	if (bCommInit == FALSE && (Chipset.IORam[IOC] & SON) != 0)
	{
		//mksg bCommInit = CommOpen(szSerialWire,szSerialIr); // open COM ports
		bCommInit = FALSE;
	}

	// COM port opened and serial off
	if (bCommInit == TRUE && (Chipset.IORam[IOC] & SON) == 0)
	{
		//mksg CommClose();					// close COM port
		bCommInit = FALSE;
	}
	return;
}

VOID AdjKeySpeed(VOID)						// slow down key repeat
{
	WORD i;
	BOOL bKey;

	if (bCpuSlow) return;					// no need to slow down

	bKey = FALSE;							// search for a pressed key
	for (i = 0;i < ARRAYSIZEOF(Chipset.Keyboard_Row) && !bKey;++i)
		bKey = (Chipset.Keyboard_Row[i] != 0);

	//[_csSlowLock lock];
	OSSpinLockLock(&_slSlowLock);
	{
		if (!bKeySlow && bKey)				// key pressed, init variables
		{
			LARGE_INTEGER lTime;			// sample timer ticks
			// save reference cycles
			dwOldCyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF);
			QueryPerformanceCounter(&lTime); // get timer ticks
			dwSpeedRef = lTime.LowPart;		// save reference time
		}
		bKeySlow = bKey;					// save new state
	}
	//[_csSlowLock unlock];
	OSSpinLockUnlock(&_slSlowLock);
	return;
}

VOID SetSpeed(BOOL bAdjust)					// set emulation speed
{
	//[_csSlowLock lock];
	OSSpinLockLock(&_slSlowLock);
	{
		if (bAdjust)						// switch to real speed
		{
			LARGE_INTEGER lTime;			// sample timer ticks
			// save reference cycles
			dwOldCyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF);
			QueryPerformanceCounter(&lTime); // get timer ticks
			dwSpeedRef = lTime.LowPart;		// save reference time
		}
		bCpuSlow = bAdjust;					// save emulation speed
	}
	//[_csSlowLock unlock];
	OSSpinLockUnlock(&_slSlowLock);
	return;
}

VOID UpdateKdnBit(VOID)						// update KDN bit
{
	if (   Chipset.intk
		&& (Chipset.IORam[TIMER2_CTRL]&RUN) != 0
		&& (DWORD) (Chipset.cycles & 0xFFFFFFFFF) - Chipset.dwKdnCycles > (DWORD) T2CYCLES * 16)
		IOBit(SRQ2,KDN,Chipset.in != 0);
	return;
}

BOOL WaitForSleepState(VOID)				// wait for cpu SHUTDN then sleep state
{
	CFAbsoluteTime dwRefTime;

	dwRefTime = CFAbsoluteTimeGetCurrent();
	// wait for the SHUTDN command with 1.5 sec timeout
	while (CFAbsoluteTimeGetCurrent() - dwRefTime < 1.5 && !Chipset.Shutdn)
		 sleep(0);

	if (Chipset.Shutdn)						// not timeout, cpu is down
		SwitchToState(SM_SLEEP);			// go to sleep state

	return SM_SLEEP != nNextState;			// state not changed, emulator was busy
}

UINT SwitchToState(UINT nNewState)
{
	UINT nOldState = nState;

	if (nState == nNewState) return nOldState;
	switch (nState)
	{
	case SM_RUN: // Run
		switch (nNewState)
		{
		case SM_INVALID: // -> Invalid
			nNextState = SM_INVALID;
			if (Chipset.Shutdn)
				SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			else
				bInterrupt = TRUE;
				while (nState!=nNextState) sleep(0);
			break;
		case SM_RETURN: // -> Return
			nNextState = SM_INVALID;
			if (Chipset.Shutdn)
				SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			else
				bInterrupt = TRUE;
			while (nState!=nNextState) sleep(0);
			nNextState = SM_RETURN;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			pthread_join(hThread,NULL);
			break;
		case SM_SLEEP: // -> Sleep
			nNextState = SM_SLEEP;
			bInterrupt = TRUE;				// exit main loop
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);	// exit shutdown
			while (nState!=nNextState) sleep(0);
			bInterrupt = FALSE;
			ResetCondition(_shutdnCondition, &_shutdnConditionPredicate);
			break;
		}
		break;
	case SM_INVALID: // Invalid
		switch (nNewState)
		{
		case SM_RUN: // -> Run
			nNextState = SM_RUN;
			// don't enter opcode loop on interrupt request
			bInterrupt = Chipset.Shutdn || Chipset.SoftInt;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			while (nState!=nNextState) sleep(0);
			break;
		case SM_RETURN: // -> Return
			nNextState = SM_RETURN;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			pthread_join(hThread,NULL);
			break;
		case SM_SLEEP: // -> Sleep
			nNextState = SM_SLEEP;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			while (nState!=nNextState) sleep(0);
			break;
		}
		break;
	case SM_SLEEP: // Sleep
		switch (nNewState)
		{
		case SM_RUN: // -> Run
			nNextState = SM_RUN;
			// don't enter opcode loop on interrupt request
			bInterrupt = (Chipset.Shutdn || Chipset.SoftInt);
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);		// leave sleep state
			break;
		case SM_INVALID: // -> Invalid
			nNextState = SM_INVALID;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			while (nState!=nNextState) sleep(0);
			break;
		case SM_RETURN: // -> Return
			nNextState = SM_INVALID;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			while (nState!=nNextState) sleep(0);
			nNextState = SM_RETURN;
			SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);
			pthread_join(hThread,NULL);
			break;
		}
		break;
	}
	return nOldState;
}



void * WorkerThread(void * pParam)
{
	LARGE_INTEGER lDummyInt;				// sample timer ticks
	QueryPerformanceFrequency(&lDummyInt);	// init timer ticks
	lDummyInt.QuadPart /= SAMPLE;			// calculate sample ticks
	dwTickRef = lDummyInt.QuadPart;			// sample timer ticks
	_ASSERT(dwTickRef);						// tick resolution error

loop:
	while (nNextState == SM_INVALID)		// go into invalid state
	{
		//OnToolMacroStop();					// close open keyboard macro handler
		//CommClose();						// close COM port
		bCommInit = FALSE;					// COM port not open
		nState = SM_INVALID;				// in invalid state
		
		WaitForCondition(_shutdnCondition, &_shutdnConditionPredicate);
		
		if (nNextState == SM_RETURN)		// go into return state
		{
			nState = SM_RETURN;				// in return state
			return 0;						// kill thread
		}
		CheckSerial();						// test if UART on
	}
	while (nNextState == SM_RUN)
	{
		if (nState != SM_RUN)
		{
			nState = SM_RUN;
			// clear port2 status bits
			Chipset.cards_status &= ~(PORT2_PRESENT | PORT2_WRITE);
			if (pbyPort2 || Chipset.Port2)	// card plugged in port2
			{
				Chipset.cards_status |= PORT2_PRESENT;

				if (bPort2Writeable)		// is card writeable
					Chipset.cards_status |= PORT2_WRITE;
			}
			// card detection off and timer running
			if ((Chipset.IORam[CARDCTL] & ECDT) == 0 && (Chipset.IORam[TIMER2_CTRL] & RUN) != 0)
			{
				BOOL bNINT2 = Chipset.IORam[SRQ1] == 0 && (Chipset.IORam[SRQ2] & LSRQ) == 0;
				BOOL bNINT  = (Chipset.IORam[CARDCTL] & SMP) == 0;

				// state of CDT2
				bNINT2 = bNINT2 && (Chipset.cards_status & (P2W|P2C)) != P2C;
				// state of CDT1
				bNINT  = bNINT  && (Chipset.cards_status & (P1W|P1C)) != P1C;

				IOBit(SRQ2,NINT2,bNINT2);
				IOBit(SRQ2,NINT,bNINT);
			}
			RomSwitch(Chipset.Bank_FF);		// select HP49G ROM bank and update memory mapping
			UpdateContrast(Chipset.contrast);
			UpdateAnnunciators();
			// init speed reference
			dwOldCyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF);
			QueryPerformanceCounter(&lDummyInt);
			dwSpeedRef = lDummyInt.LowPart;
			SetHP48Time();					// update HP48 time & date
			StartBatMeasure();				// start battery measurement
			StartTimers();
			// start display counter/update engine
			StartDisplay((BYTE)(((Chipset.IORam[LINECOUNT+1]<<4)|Chipset.IORam[LINECOUNT])&0x3F));
		}
		PCHANGED;

		while (!bInterrupt)
		{
			EvalOpcode(FASTPTR(Chipset.pc)); // execute opcode
			AdjustSpeed();					// adjust emulation speed
		}
		bInterrupt = FALSE;					// be sure to reenter opcode loop
		
		contentChanged = TRUE;				// Something was done -> lets suspect the display content changed as well;
		
		// enter SHUTDN handler only in RUN mode
		if (Chipset.Shutdn)
		{
			if (!Chipset.SoftInt)			// ignore SHUTDN on interrupt request
				WaitForCondition(_shutdnCondition, &_shutdnConditionPredicate);
			else
				Chipset.bShutdnWake = TRUE;	// waked by interrupt

			if (Chipset.bShutdnWake)		// waked up by timer, keyboard or serial
			{
				Chipset.bShutdnWake = FALSE;
				Chipset.Shutdn = FALSE;
				// init speed reference
				dwOldCyc = (DWORD) (Chipset.cycles & 0xFFFFFFFF);
				QueryPerformanceCounter(&lDummyInt);
				dwSpeedRef = lDummyInt.LowPart;
			}
		}
		if (Chipset.SoftInt)
		{
			Chipset.SoftInt = FALSE;
			if (Chipset.inte)
			{
				Chipset.inte = FALSE;
				rstkpush(Chipset.pc);
				Chipset.pc = 0xf;
			}
		}
	}
	_ASSERT(nNextState != SM_RUN);

	StopDisplay();							// stop display counter/update
	StopBatMeasure();						// stop battery measurement
	StopTimers();

	while (nNextState == SM_SLEEP)			// go into sleep state
	{
		nState = SM_SLEEP;					// in sleep state
		WaitForCondition(_shutdnCondition, &_shutdnConditionPredicate);
	}
	goto loop;
	UNREFERENCED_PARAMETER(pParam);
}


