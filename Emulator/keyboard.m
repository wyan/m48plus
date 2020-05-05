/*
 *   keyboard.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gießelink
 *
 */
#import "patchwinpch.h"
#import "emu48.h"
#import "io.h"								// I/O definitions
#import "xml.h"

UINT buttonHistory[BTNHISTMAX][2];
int buttonHistoryNext;
//extern WORD currentAnnunciators;

static WORD Keyboard_GetIR(VOID)
{
	WORD r = 0;

	// OR[0:8] are wired on Clarke/Yorke chip
	if (Chipset.out==0) return 0;
	if (Chipset.out&0x001) r|=Chipset.Keyboard_Row[0];
	if (Chipset.out&0x002) r|=Chipset.Keyboard_Row[1];
	if (Chipset.out&0x004) r|=Chipset.Keyboard_Row[2];
	if (Chipset.out&0x008) r|=Chipset.Keyboard_Row[3];
	if (Chipset.out&0x010) r|=Chipset.Keyboard_Row[4];
	if (Chipset.out&0x020) r|=Chipset.Keyboard_Row[5];
	if (Chipset.out&0x040) r|=Chipset.Keyboard_Row[6];
	if (Chipset.out&0x080) r|=Chipset.Keyboard_Row[7];
	if (Chipset.out&0x100) r|=Chipset.Keyboard_Row[8];
	return r;
}

VOID ScanKeyboard(BOOL bActive, BOOL bReset)
{
	// bActive = TRUE  -> function called by direct read (A=IN, C=IN, RSI)
	//           FALSE -> function called by 1ms keyboard poll simulation
	// bReset  = TRUE  -> Reset Chipset.in interrupt state register
	//           FALSE -> generate interrupt only for new pressed keys

	// keyboard read not active?
	if (!(   bActive || Chipset.Shutdn || Chipset.IR15X
		  || (Chipset.intk && (Chipset.IORam[TIMER2_CTRL]&RUN) != 0)))
	{
		[_csKeyLock lock];
		{
			Chipset.in &= ~0x8000;			// remove ON key
		}
		[_csKeyLock unlock];
		return;
	}

	[_csKeyLock lock];						// synchronize
	{
		BOOL bKbdInt;

		WORD wOldIn = Chipset.in;			// save old Chipset.in state

		UpdateKdnBit();						// update KDN bit
		Chipset.dwKdnCycles = (DWORD) (Chipset.cycles & 0xFFFFFFFF);

		Chipset.in = Keyboard_GetIR();		// update Chipset.in register
		Chipset.in |= Chipset.IR15X;		// add ON key

		// interrupt for any new pressed keys?
		bKbdInt = (Chipset.in && (wOldIn & 0x1FF) == 0) || Chipset.IR15X || bReset;

		// update keyboard interrupt pending flag when 1ms keyboard scan is disabled
		Chipset.intd = Chipset.intd || (bKbdInt && !Chipset.intk);

		// keyboard interrupt enabled?
		bKbdInt = bKbdInt && Chipset.intk;

		// interrupt at ON key pressed
		bKbdInt = bKbdInt || Chipset.IR15X != 0;

		// no interrupt if still inside interrupt service routine
		bKbdInt = bKbdInt && Chipset.inte;

		if (Chipset.in != 0)				// any key pressed
		{
			if (bKbdInt)					// interrupt enabled
			{
				Chipset.SoftInt = TRUE;		// interrupt request
				bInterrupt = TRUE;			// exit emulation loop
			}

			if (Chipset.Shutdn)				// cpu sleeping
			{
				Chipset.bShutdnWake = TRUE;	// wake up from SHUTDN mode
				
				SignalCondition(_shutdnCondition, &_shutdnConditionPredicate);		// wake up emulation thread
			}
		}
		else
		{
			Chipset.intd = FALSE;			// no keyboard interrupt pending
		}
	}
	[_csKeyLock unlock];
	return;
}

VOID KeyboardEvent(BOOL bPress, UINT out, UINT in)
{
	if (nState != SM_RUN)					// not in running state
		return;								// ignore key

	//mksg KeyMacroRecord(bPress,out,in);			// save all keyboard events
	if (bPress) {
		buttonHistory[buttonHistoryNext][0] = out;
		buttonHistory[buttonHistoryNext][1] = in;
		if ((++buttonHistoryNext)>=BTNHISTMAX) buttonHistoryNext=0;	
	
		// Find AlphaLock
		int ind1 = buttonHistoryNext-1;
		if (ind1<0) ind1 = BTNHISTMAX-1;
		int ind2 = ind1-1;
		if (ind2<0) ind2 = BTNHISTMAX-1;
		if (   (buttonHistory[ind1][0] ==  3) 
			&& (buttonHistory[ind1][1] == 32) 
			&& (buttonHistory[ind2][0] ==  3) 
			&& (buttonHistory[ind2][1] == 32)
			&& (xml->logicStateVec & LA3)) {
			xml->logicStateVec = (xml->logicStateVec) | LALPHALOCK;
		}
		// Find small/big
		if (   (buttonHistory[ind1][0] ==  3) 
			&& (buttonHistory[ind1][1] == 32) 
			&& (buttonHistory[ind2][0] ==  2) 
			&& (buttonHistory[ind2][1] == 32)
			&& (xml->logicStateVec & LALPHALOCK)) {
			xml->logicStateVec = ((xml->logicStateVec) &(~LALPHASMALL)) | (~((xml->logicStateVec)&LALPHASMALL) & LALPHASMALL);
		}
		
		if (!((xml->logicStateVec) & LA3)) {
			(xml->logicStateVec) &= ~LALPHALOCK;
			(xml->logicStateVec) &= ~LALPHASMALL;
		}
	}
	else {
		if (!((xml->logicStateVec) & LA3)) {
			(xml->logicStateVec) &= ~LALPHALOCK;
			(xml->logicStateVec) &= ~LALPHASMALL;
		}
	}
	

	if (in == 0x8000)						// ON key ?
	{
		Chipset.IR15X = bPress?0x8000:0x0000; // refresh special ON key flag
	}
	else
	{
		// "out" is outside Keyboard_Row 
		if (out >= ARRAYSIZEOF(Chipset.Keyboard_Row)) return;

		// in &= 0x1FF;						// only IR[0:8] are wired on Clarke/Yorke chip

		_ASSERT(out < ARRAYSIZEOF(Chipset.Keyboard_Row));
		if (bPress)							// key pressed
			Chipset.Keyboard_Row[out] |= in; // set key marker in keyboard row
		else
			Chipset.Keyboard_Row[out] &= (~in); // clear key marker in keyboard row
	}
	AdjKeySpeed();							// adjust key repeat speed
	ScanKeyboard(FALSE,FALSE);				// update Chipset.in register by 1ms keyboard poll
	
	//[NSThread sleepForTimeInterval:0.050];  // Wichtig!!! Sonst werde manche Eingaben einfach verschluckt!; // Nur wenn keine KeyboardEventQueue im emulator verwendet wird!
	
	return;
}
