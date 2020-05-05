/*
 *  xml.h
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

typedef struct xmlColor {
	CGFloat red;
	CGFloat green;
	CGFloat blue;
	CGFloat alpha;
} XmlColor;

typedef struct xmlLogic {
	DWORD	dontCareVec;
	DWORD	logicVec;
} XmlLogic;

typedef enum xmlAnimationControlState {
	XmlAnimationControlStateIdle,
	XmlAnimationControlStateReady,
	XmlAnimationControlStateAnimating
} XmlAnimationControlState;

typedef struct xmlAnimationControl {
	BOOL	repeats;
	BOOL	noGate;
	UINT	holdoffval;
	UINT	currentholdoffval;
	UINT	fadeinval;
	UINT	currentfadeinval;
	UINT	holdonval;
	UINT	currentholdonval;
	UINT	fadeoutval;
	UINT	currentfadeoutval;
	CGFloat currentAlpha;
	BOOL	previousPredicate;
	XmlAnimationControlState state;
} XmlAnimationControl;

typedef enum xmlOrientationType {
	XmlOrientationTypeUnknown,
	XmlOrientationTypePortrait,
	XmlOrientationTypePortraitUpsideDown,
	XmlOrientationTypeLandscape,
	XmlOrientationTypeLandscapeLeft,
	XmlOrientationTypeLandscapeRight,
	XmlOrientationTypeVertical
} XmlOrientationType;

typedef struct xmlDrawable {
	XmlColor				color;
	BOOL					isTextured;
	XmlOrientationType		textureOrientation;
	CGRect					texture;
	CGRect					screen;
	XmlAnimationControl *	animationControl;
} XmlDrawable;

typedef struct xmlLcd {
	CGFloat			zorder;
	UINT			nLogics;
	XmlLogic *		logics;
	XmlDrawable *	onDrawable;
	XmlDrawable *	offDrawable;
} XmlLcd;

typedef struct xmlSoundFX {
	UINT	soundIDOnDown;
	UINT	soundIDOnHold;
	UINT	soundIDOnUp;
	float	volume;
	BOOL	repeat;
	unsigned long currentSessionID;
} XmlSoundFX;

typedef struct xmlFace
{
	CGFloat					zorder;
	UINT					nLogics;
	XmlLogic *	logics;
	XmlDrawable *			onDrawable;
	XmlDrawable *			offDrawable;
	XmlSoundFX *			soundfx;
} XmlFace;

typedef enum xmlButtonType {
	XmlButtonTypeNormal,
	XmlButtonTypeMenu,
	XmlButtonTypeVirtual,
	XmlButtonTypeCopy,
	XmlButtonTypePaste,
	XmlButtonTypeInit
} XmlButtonType;

#define SENSORMINSWIPEDIST 24
#define SENSORMAXSWIPEDEV 18
#define SENSORMINHOLDTIME 0.5
#define SENSORDOUBLETAPTIME 0.3


typedef enum xmlSensorType {
	XmlSensorTypeNone,
	XmlSensorTypeTouch,
	XmlSensorTypeTouchUp,
	XmlSensorTypeTouchInside,
	XmlSensorTypeTouchInsideDelayed, 
	XmlSensorTypeTouchInsideDelayedFocused, 
	XmlSensorTypeTouchInsideUp,	
	XmlSensorTypeTouchInsideUpFast,
	XmlSensorTypeTouchInsideUpFocused,
	XmlSensorTypeTouchInsideUpFastFocused,	
	XmlSensorTypeTouchDown,
	XmlSensorTypeTouchInsideDown, 
	XmlSensorTypeTouchInsideDownDelayed, 
	XmlSensorTypeTouchInsideDownDelayedFocused,
	XmlSensorTypeTap,		
	XmlSensorTypeDoubleTap, 
	XmlSensorTypeSwipeInsideRight, 
	XmlSensorTypeSwipeInsideLeft, 
	XmlSensorTypeSwipeInsideUp, 
	XmlSensorTypeSwipeInsideDown, 
	XmlSensorTypeSwipeInsideUpperRight,
	XmlSensorTypeSwipeInsideUpperLeft,
	XmlSensorTypeSwipeInsideLowerRight,
	XmlSensorTypeSwipeInsideLowerLeft,
	XmlSensorTypeSwipeInsideRightFast,
	XmlSensorTypeSwipeInsideLeftFast,
	XmlSensorTypeSwipeInsideUpFast,
	XmlSensorTypeSwipeInsideDownFast,
	XmlSensorTypeSwipeInsideUpperRightFast,
	XmlSensorTypeSwipeInsideUpperLeftFast,
	XmlSensorTypeSwipeInsideLowerRightFast,
	XmlSensorTypeSwipeInsideLowerLeftFast
} XmlSensorType;

typedef enum xmlButtonMode {
	XmlButtonModeNormal,
	XmlButtonModeToggle
} XmlButtonMode;

typedef enum xmlActionTriggerMode {
	XmlActionTriggerModeTrigger, 
	XmlActionTriggerModeOn,
	XmlActionTriggerModeOff, 
	XmlActionTriggerModeToggle	
} XmlActionTriggerMode;

typedef struct xmlAction {
	UINT					buttonId;
	float					delay;
	XmlActionTriggerMode	triggerMode;
} XmlAction;

#define BUTTON_HOLDCYCLES 1
typedef struct xmlButton
{
	UINT					nId;
	BOOL					bDown;
	UINT					nOut, nIn;
	XmlButtonType			type;
	UINT					nSensorTypes;
	XmlSensorType *			sensorTypes;
	XmlButtonMode			mode;
	BOOL					isGhost;
	CGFloat					zorder;
	UINT					nLogics;
	XmlLogic *				logics;
	UINT					logicId;
	CGRect					toucharea;
	XmlDrawable *			onDrawable;
	XmlDrawable *			offDrawable;
	XmlSoundFX *			soundfx;
	UINT					nActions;
	XmlAction *				actions;
} XmlButton;

typedef enum xmlOrientationElementType {
	XmlOrientationElementTypeButton,
	XmlOrientationElementTypeFace,
	XmlOrientationElementTypeLcd
} XmlOrientationElementType;

typedef struct xmlOrientation {
	XmlOrientationType				orientationType;
	NSString *						textureFilename;
	XmlColor						backgroundColor;
	BOOL							hasStatusBar;
	UIStatusBarStyle				statusBarStyle;
	UINT							nLcds;
	XmlLcd *						lcds;
	UINT							nFaces;
	XmlFace	*						faces;
	UINT							nButtons;
	XmlButton *						buttons;
	CGRect							viewport;
	CGFloat							zoomX;
	CGFloat							zoomY;
	CGFloat							textureZoomX;
	CGFloat							textureZoomY;
	UINT							nDrawingOrder;
	XmlOrientationElementType *		drawingOrderElementTypes;
	UINT *							drawingOrderElementIndices;
} XmlOrientation;

typedef struct xmlSound {
	NSString *		filename;
	UINT			xmlSoundId;
	float			volume;
} XmlSound;

typedef enum xmlBeepType {
	XmlBeepTypeSquare,
	XmlBeepTypeSawtooth,
	XmlBeepTypeTriangle,
	XmlBeepTypeSine 
} XmlBeepType;

typedef enum xmlLcdInterpolationMethod {
	XmlLcdInterpolationMethodSharp,
	XmlLcdInterpolationMethodFuzzy
} XmlLcdInterpolationMethod;

#define FRAMERATEDEFAULT 24
#define FRAMERATEMIN 5
#define FRAMERATEMAX 24
typedef struct xmlGlobal {
	NSString *					title;
	NSString *					author;
	NSString *					copyright;
	NSString *					message;
	NSString *					hardware;
	char						model;
	UINT						class;
	NSString *					romFilename;
	NSString *					patchFilename;
	UINT						nLcdColors;
	XmlColor *					lcdColors;
	BOOL						lcdInterpolationEnabled;
	XmlLcdInterpolationMethod	lcdInterpolationMethod;
	UINT						nSounds;
	XmlSound *					sounds;
	XmlBeepType					beepType;
	float						framerate;
	BOOL						requiresSGX;
} XmlGlobal;

typedef struct xmlRoot {
	NSString *			filename;
	NSString *			directory;
	XmlGlobal *			global;
	UINT				nOrientations;
	XmlOrientation *	orientations;
	XmlOrientation *	currentOrientation;
	UINT				currentOrientationIndex; // Required for serialization
	XmlOrientation *	previousOrientation;
	UINT				previousOrientationIndex; // Required for serialization
	DWORD				logicStateVec;
} XmlRoot;


extern XmlRoot * xml;

BOOL InitXML(NSString * filename, NSError ** error);
void KillXML(void);
void killXmlRoot(XmlRoot * elem);
BOOL PeekXML(NSString * filename, NSString ** title);
BOOL TryGetXmlCacheFile(void);
BOOL DeleteXmlCacheFile(void);
BOOL WriteXmlCacheFile(void);

// Orientation
BOOL FindProperOrientation(UIDeviceOrientation deviceOrientation, XmlOrientation ** properOrientation);
void ChangeToOrientation(XmlOrientation * newOrientation);
void PrepareAvailableOrientations(void);
BOOL IsAllowedOrientation(UIInterfaceOrientation interfaceOrientation);
void SetOrientation(UIInterfaceOrientation interfaceOrientation);


// Buttons
void ReloadButtons(BYTE *Keyboard_Row, UINT nSize);

// Animation
void resetAnimation(XmlAnimationControl * animationControl, BOOL isInverse, BOOL isArmed);
BOOL calcAnimation(XmlAnimationControl * animationControl, BOOL predicate, BOOL isInverse);