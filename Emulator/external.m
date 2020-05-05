/*
 *   external.c
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2005 Christoph Gießelink
 *
 */

#import "patchwinpch.h"
#import "emu48.h"
#import "ops.h"


#define MUSIC_FREQ 11025					// this can be adjusted for quality

//| 38G  | 39G  | 40G  | 48SX | 48GX | 49G  | Name
//#F0E4F #80F0F #80F0F #706D2 #80850 #80F0F =SFLAG53_56

// memory address for flags -53 to -56
#define SFLAG53_56	(  (cCurrentRomType=='6')								\
	                 ? 0xE0E4F												\
					 : (  (cCurrentRomType=='A')							\
					    ? 0xF0E4F											\
					    : (  (cCurrentRomType!='E' && cCurrentRomType!='X' && cCurrentRomType!='Q')	\
					       ? (  (cCurrentRomType=='S')						\
					          ? 0x706D2										\
						      : 0x80850										\
						     )												\
						   : 0x80F0F										\
					      )													\
					   )													\
					)

DWORD dwWaveVol = 64;						// wave sound volume

//static __inline VOID BeepWave(DWORD dwFrequency,DWORD dwDuration)
//{
//	HWAVEOUT     hSoundDevice;
//	WAVEFORMATEX wf;
//	WAVEHDR      wh;
//	HANDLE       hEventSound;
//	DWORD        i;
//	
//	if (dwFrequency == 0)					// this is just a delay
//	{
//		Sleep(dwDuration);
//		return;
//	}
//	
//	hEventSound = CreateEvent(NULL,FALSE,FALSE,NULL);
//	
//	wf.wFormatTag      = WAVE_FORMAT_PCM;
//	wf.nChannels       = 1;
//	wf.nSamplesPerSec  = MUSIC_FREQ;
//	wf.nAvgBytesPerSec = MUSIC_FREQ;
//	wf.nBlockAlign     = 1;
//	wf.wBitsPerSample  = 8;
//	wf.cbSize          = 0;
//	
//	if (waveOutOpen(&hSoundDevice,WAVE_MAPPER,&wf,(DWORD)hEventSound,0,CALLBACK_EVENT) != 0)
//	{
//		CloseHandle(hEventSound);			// no sound available
//		return;
//	}
//	
//	// (samp/sec) * msecs * (secs/msec) = samps
//	wh.dwBufferLength = (DWORD) ((QWORD) MUSIC_FREQ * dwDuration / 1000);
//	VERIFY(wh.lpData = HeapAlloc(hHeap,0,wh.dwBufferLength));
//	wh.dwBytesRecorded = 0;
//	wh.dwUser = 0;
//	wh.dwFlags = 0;
//	wh.dwLoops = 0;
//	
//	for (i = 0; i < wh.dwBufferLength; ++i)	// generate square wave
//	{
//		wh.lpData[i] = (BYTE) ((((QWORD) 2 * dwFrequency * i / MUSIC_FREQ) & 1) * dwWaveVol);
//	}
//	
//	VERIFY(waveOutPrepareHeader(hSoundDevice,&wh,sizeof(wh)) == MMSYSERR_NOERROR);
//	
//	ResetEvent(hEventSound);				// prepare event for finishing
//	VERIFY(waveOutWrite(hSoundDevice,&wh,sizeof(wh)) == MMSYSERR_NOERROR);
//	WaitForSingleObject(hEventSound,INFINITE); // wait for finishing
//	
//	VERIFY(waveOutUnprepareHeader(hSoundDevice,&wh,sizeof(wh)) == MMSYSERR_NOERROR);
//	VERIFY(waveOutClose(hSoundDevice) == MMSYSERR_NOERROR);
//	
//	HeapFree(hHeap,0,wh.lpData);
//	CloseHandle(hEventSound);
//	return;
//}
#import "m48EmulatorAudioEngine.h"

static inline VOID BeepWave(DWORD dwFrequency,DWORD dwDuration)
{
	playBeep(dwFrequency, dwDuration);
	
	// Easy version
	//[NSThread sleepForTimeInterval:(0.001*dwDuration)];

	double a, b;
	a = CFAbsoluteTimeGetCurrent();
	b = a + 0.001*dwDuration;
	// Check for ON-Key the hard way:
	while ((!((Chipset.IR15X)&0x8000)) && (a < b)) {
		[NSThread sleepForTimeInterval:0.02];
		a = CFAbsoluteTimeGetCurrent();
	}
	stopBeep();

	return;
}

VOID External(CHIPSET* w)					// Beep patch
{
	BYTE  fbeep;
	DWORD freq,dur;

	freq = Npack(w->D,5);					// frequency in Hz
	dur = Npack(w->C,5);					// duration in ms
	Nread(&fbeep,SFLAG53_56,1);				// fetch system flags -53 to -56

	w->carry = TRUE;						// setting of no beep
	if (!(fbeep & 0x8) && freq)				// bit -56 clear and frequency > 0 Hz
	{
		if (freq < 37)   freq = 37;			// low limit of freqency (NT)
		if (freq > 4400) freq = 4400;		// high limit of HP (SX)

		if (dur > 1048575)					// high limit of HP (SX)
			dur = 1048575;

		BeepWave(freq, dur);				// do it on the hard way

		// estimate cpu cycles for beeping time (2MHz / 4MHz)
		w->cycles += dur * ((cCurrentRomType=='S') ? 2000 : 4000);           

		// original routine return with...
		w->P = 0;							// P=0
		w->intk = TRUE;						// INTON
		w->carry = FALSE;					// RTNCC
	}
	w->pc = rstkpop();
	return;
}

VOID RCKBp(CHIPSET* w)						// ROM Check Beep patch
{
	DWORD dw2F,dwCpuFreq;
	DWORD freq,dur;
	BYTE f,d;

	f = w->C[1];							// f = freq ctl
	d = w->C[0];							// d = duration ctl
	
	if (cCurrentRomType == 'S')				// Clarke chip with 48S ROM
	{	
		// CPU strobe frequency @ RATE 14 = 1.97MHz
		dwCpuFreq = ((14 + 1) * 524288) >> 2;

		dw2F = f * 126 + 262;				// F=f*63+131
	}
	else									// York chip with 48G and later ROM
	{
		// CPU strobe frequency @ RATE 27 = 3.67MHz
		// CPU strobe frequency @ RATE 29 = 3.93MHz
		dwCpuFreq = ((27 + 1) * 524288) >> 2;

		dw2F = f * 180 + 367;				// F=f*90+183.5
	}

	freq = dwCpuFreq / dw2F;
	dur = (dw2F * (256 - 16 * d)) * 1000 / 2 / dwCpuFreq;

	if (freq > 4400) freq = 4400;			// high limit of HP

	BeepWave(freq, dur);					// do it on the hard way

	// estimate cpu cycles for beeping time (2MHz / 4MHz)
	w->cycles += dur * ((cCurrentRomType=='S') ? 2000 : 4000);           

	w->P = 0;								// P=0
	w->carry = FALSE;						// RTNCC
	w->pc = rstkpop();
	return;
}
