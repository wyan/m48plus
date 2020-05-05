/*
 *   Emu48.h
 *
 *   This file is part of Emu48
 *
 *   Copyright (C) 2004 Christoph Gieﬂelink
 *
 */
#import "types.h"

#define	ARRAYSIZEOF(a)	(sizeof(a) / sizeof(a[0]))

#define	_KB(a)			((a)*2*1024)

#define HARDWARE		"Yorke"				// emulator hardware (Yorke)
//#define HARDWARE		"Clarke"				// emulator hardware (Clarke)
#define MODELS			"26AEGPSXQ"			// valid calculator models

// cards status
#define PORT1_PRESENT	((cCurrentRomType=='S')?P1C:P2C)
#define PORT1_WRITE		((cCurrentRomType=='S')?P1W:P2W)
#define PORT2_PRESENT	((cCurrentRomType=='S')?P2C:P1C)
#define PORT2_WRITE		((cCurrentRomType=='S')?P2W:P1W)

#define BINARYHEADER48	"HPHP48-W"
#define BINARYHEADER49	"HPHP49-W"

#define HP_FILTER		"HP Binary Object (*.HP;*.LIB)\0*.HP;*.LIB\0All Files (*.*)\0*.*\0"

// CPU cycles in 16384 Hz time frame
#define T2CYCLES		((cCurrentRomType=='S')?dwSXCycles:dwGXCycles)

#define SM_RUN			0					// states of cpu emulation thread
#define SM_INVALID		1
#define SM_RETURN		2
#define SM_SLEEP		3

#define S_ERR_NO        0					// stack errorcodes
#define S_ERR_OBJECT	1
#define S_ERR_BINARY    2
#define S_ERR_ASCII     3

#define BAD_OB			(0xFFFFFFFF)		// bad object

#define NO_SERIAL       "disabled"			// port not open

#define MACRO_OFF		0					// macro recorder off
#define MACRO_NEW		1
#define MACRO_PLAY		2

#define TOPBAR_OFF		0x1					// top bar off
#define MENUBAR_OFF		0x2					// menu bar off

#define ROMPAGESIZE		(1<<12)				// ROM dirty page size in nibbles

// macro to check for valid calculator model
#define isModelValid(m)	(m != 0 && strchr(MODELS,m) != NULL)

// values for mapping area
enum MMUMAP { M_IO, M_ROM, M_RAM, M_P1, M_P2, M_BS };

# pragma mark -
# pragma mark emu48.m
extern NSLock *			_csLCDLock;
extern NSLock *			_csKeyLock;
extern NSLock *			_csIOLock;
extern NSLock *			_csT1Lock;
extern NSLock *			_csT2Lock;
//extern NSLock *			_csSlowLock;
extern OSSpinLock		_slSlowLock;
extern NSCondition *	_shutdnCondition;
extern BOOL				_shutdnConditionPredicate;

extern LARGE_INTEGER	lFreq;
extern LARGE_INTEGER	lAppStart;

extern pthread_t		hThread;

extern DWORD			dwWakeupDelay;

# pragma mark -
# pragma mark mru.m

# pragma mark -
# pragma mark settings.m

# pragma mark -
# pragma mark display.m
extern BYTE	  * lcdTextureBuffer;
extern BYTE	  * lcdTextureBuffer1;
extern BYTE	  * lcdTextureBuffer2;
extern int		timesNewTextureBufferDiffers;
extern int		holdDelayStartVal;
extern BOOL		bStaticsFilterEnabled;
//extern WORD		currentAnnunciators;
extern VOID   UpdateContrast(BYTE byContrast);
extern VOID   UpdateAnnunciators(VOID);
extern BYTE   GetLineCounter(VOID);
extern VOID   StartDisplay(BYTE byInitial);
extern VOID   StopDisplay(VOID);
extern VOID   UpdateDisplay(VOID);

# pragma mark -
# pragma mark engine.m
extern BOOL    bInterrupt;
extern UINT    nState;
extern UINT    nNextState;
extern BOOL    bRealSpeed;
extern BOOL    bKeySlow;
extern BOOL    bCommInit;
extern CHIPSET Chipset;

extern DWORD   dwSXCycles;
extern DWORD   dwGXCycles;

extern BOOL	   contentChanged;

extern VOID    CheckSerial(VOID);
extern VOID    AdjKeySpeed(VOID);
extern VOID    SetSpeed(BOOL bAdjust);
extern VOID    UpdateKdnBit(VOID);
extern BOOL    WaitForSleepState(VOID);
extern UINT    SwitchToState(UINT nNewState);
extern void *  WorkerThread(void * pParam);

# pragma mark -
# pragma mark fetch.m
extern VOID    EvalOpcode(LPBYTE I);

# pragma mark -
# pragma mark files.m
extern BYTE    cCurrentRomType;
extern UINT    nCurrentClass;
extern LPBYTE  pbyRom;
extern BOOL    bRomWriteable;
extern DWORD   dwRomSize;
extern LPBYTE  pbyRomDirtyPage;
extern DWORD   dwRomDirtyPageSize;
extern WORD    wRomCrc;
extern LPBYTE  pbyPort2;
extern BOOL    bPort2Writeable;
extern BOOL    bPort2IsShared;
extern DWORD   dwPort2Size;
extern DWORD   dwPort2Mask;
extern WORD    wPort2Crc;
extern BOOL    bBackup;

extern VOID    UpdatePatches(BOOL bPatch);
extern BOOL    PatchRom(NSString * filename);
extern BOOL    CrcRom(WORD *pwChk);
extern BOOL    MapRom(NSString * filename);
extern VOID    UnmapRom(VOID);
/*
extern BOOL    CrcPort2(WORD *pwCrc);
 */
extern BOOL    MapPort2(NSString * filename);
/*
extern VOID    UnmapPort2(VOID);
*/
extern VOID    ResetDocument(VOID);
extern BOOL    NewDocument(NSString * xmlFilename, NSError ** error);
extern BOOL	   OpenDocument(NSString * documentFilename, NSError ** error);
extern BOOL	   WriteDocument(NSString * documentFilename, NSError ** error);

extern WORD    WriteStack(UINT nStkLevel,LPBYTE lpBuf,DWORD dwSize);
#ifdef VERSIONPLUS
extern BOOL    LoadObject(NSString * filename, NSError ** error);
extern BOOL    SaveObject(NSString * filename, NSError ** error);
#endif

# pragma mark -
# pragma mark timer.m
extern VOID  SetHP48Time(VOID);
extern VOID  StartTimers(VOID);
extern VOID  StopTimers(VOID);
extern DWORD ReadT2(VOID);
extern VOID  SetT2(DWORD dwValue);
extern BYTE  ReadT1(VOID);
extern VOID  SetT1(BYTE byValue);

# pragma mark -
# pragma mark mops.m
extern BOOL        bFlashRomArray;
extern LPBYTE      RMap[256];
extern LPBYTE      WMap[256];
extern DWORD       FlashROMAddr(DWORD d);
extern VOID        Map(BYTE a, BYTE b);
extern VOID        RomSwitch(DWORD adr);
extern VOID        Config(VOID);
extern VOID        Uncnfg(VOID);
extern VOID        Reset(VOID);
extern VOID        C_Eq_Id(VOID);
extern enum MMUMAP MapData(DWORD d);
extern VOID        CpuReset(VOID);
extern VOID        Npeek(BYTE *a, DWORD d, UINT s);
extern VOID        Nread(BYTE *a, DWORD d, UINT s);
extern VOID        Nwrite(BYTE *a, DWORD d, UINT s);
extern BYTE        Read2(DWORD d);
extern DWORD       Read5(DWORD d);
extern VOID        Write5(DWORD d, DWORD n);
extern VOID        Write2(DWORD d, BYTE n);
extern VOID        IOBit(DWORD d, BYTE b, BOOL s);
extern VOID        ReadIO(BYTE *a, DWORD b, DWORD s, BOOL bUpdate);
extern VOID        WriteIO(BYTE *a, DWORD b, DWORD s);

# pragma mark -
# pragma mark lowbat.m
extern BOOL bLowBatDisable;
extern VOID StartBatMeasure(VOID);
extern VOID StopBatMeasure(VOID);
extern VOID GetBatteryState(BOOL *pbLBI, BOOL *pbVLBI);

# pragma mark -
# pragma mark keyboard.m
extern VOID ScanKeyboard(BOOL bActive, BOOL bReset);
extern VOID KeyboardEvent(BOOL bPress, UINT out, UINT in);
#define BTNHISTMAX 5
extern UINT buttonHistory[BTNHISTMAX][2];
extern int buttonHistoryNext;
extern BOOL alphaLock;
extern BOOL alphaSmall;
# pragma mark -
# pragma mark keymacro.m

# pragma mark -
# pragma mark stack.m
// Stack.c
extern BOOL bDetectClpObject;
#ifdef VERSIONPLUS
extern BOOL OnStackCopy(NSError ** error);
extern BOOL OnStackPaste(NSError ** error);
#endif

# pragma mark -
# pragma mark RPL.m
// RPL.c
extern BOOL    RPL_GetSystemFlag(INT nFlag);
extern DWORD   RPL_SkipOb(DWORD d);
extern DWORD   RPL_ObjectSize(BYTE *o,DWORD s);
extern DWORD   RPL_CreateTemp(DWORD l);
extern UINT    RPL_Depth(VOID);
extern DWORD   RPL_Pick(UINT l);
extern VOID    RPL_Replace(DWORD n);
extern VOID    RPL_Push(UINT l,DWORD n);

# pragma mark -
# pragma mark external.m
extern DWORD dwWaveVol;
extern VOID  External(CHIPSET* w);
extern VOID  RCKBp(CHIPSET* w);

# pragma mark -
# pragma mark serial.m
//extern BOOL CommOpen(LPTSTR strWirePort,LPTSTR strIrPort);
//extern VOID CommClose(VOID);
//extern VOID CommSetBaud(VOID);
extern BOOL UpdateUSRQ(VOID);
//extern VOID CommTxBRK(VOID);
//extern VOID CommTransmit(VOID);
//extern VOID CommReceive(VOID);

#define SCREENHEIGHT (cCurrentRomType=='Q' ? 80 : 64)   // CdB for HP: add apples display management
