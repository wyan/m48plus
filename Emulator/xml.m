/*
 *  xml.m
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
#import "emu48.h"
#import "xml.h"
#import "m48Errors.h"

#import <libxml/parser.h>
#import <libxml/tree.h>

XmlRoot * xml = NULL;
static NSMutableString * xmlParserLog = nil;

#pragma mark -
#pragma mark paths
static NSString * resolveXmlFilename(NSString * filename) {
	NSString * resolvedFilename;
	if ([filename isAbsolutePath]) {
		resolvedFilename = filename;
	}
	else {
		resolvedFilename = [xml->directory stringByAppendingPathComponent:filename];	
		resolvedFilename = [resolvedFilename stringByStandardizingPath];
	}
	return resolvedFilename;	
}

#pragma mark -
#pragma mark logging
static void initXmlParserLog(void) {
	[xmlParserLog release];
	xmlParserLog = [[NSMutableString alloc] initWithCapacity:0];
}

static void addToXmlParserLog(NSString * message) {
	[xmlParserLog appendString:message];
	[xmlParserLog appendString:@"\n"];
}

static void killXmlParserLog(void) {
	[xmlParserLog release];
	xmlParserLog = nil;
}

static void printTreeToConsole(xmlNode * node, int depth) {
	do {
		if ( strcmp((const char *) node->name, "text" ) == 0) {
			if (strcmp((const char *) node->content, "\n" ) != 0 ) {
				printf(" textelementWithContent:%s\n",node->content);
			}
		}
		else
		{
			for (int i=0; i<depth; i++) {
				printf(" ");
			}
			printf("elementWithName:%s", node->name);
			if (node->children) {
				printTreeToConsole(node->children,depth+1);
			}
		}
	} while ((node = node->next));
	return;
}

#pragma mark -
#pragma mark static functions declarations
static void initXmlRoot(XmlRoot * elem);
static void initXmlGlobal(XmlGlobal * elem);
static void initXmlOrientation(XmlOrientation * elem);
static void initXmlDrawable(XmlDrawable * elem);
static void initXmlFace(XmlFace * elem);
static void initXmlAction(XmlAction * elem);
static void initXmlButton(XmlButton * elem);
static void initXmlSensorType(XmlSensorType * elem);
static void initXmlColor(XmlColor * elem, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
static void initXmlLogic(XmlLogic * elem);
static void initXmlAnimationControl(XmlAnimationControl * elem);
static void initXmlSound(XmlSound * elem);
static void initXmlSoundFX(XmlSoundFX * elem);

static BOOL searchNodeList(xmlNode * node, const char * name, xmlNode ** result);

static BOOL parseXmlRoot(xmlNode * node, XmlRoot * elem);
static BOOL parseXmlGlobal(xmlNode * node, XmlGlobal ** pelem);
static BOOL parseXmlOrientations(xmlNode * node, XmlOrientation ** pelems, UINT * pnElems);
static BOOL parseXmlOrientation(xmlNode * node, XmlOrientation * elem);
static BOOL parseXmlLcds(xmlNode * node, XmlLcd ** pelems, UINT * pnElems);
static BOOL parseXmlLcd(xmlNode * node, XmlLcd * elem);
static BOOL parseXmlDrawable(xmlNode * node, XmlDrawable * elem);
static BOOL parseXmlFaces(xmlNode * node, XmlFace ** pelems, UINT * pnElems);
static BOOL parseXmlFace(xmlNode * node, XmlFace * elem);
static BOOL parseXmlActions(xmlNode * node, XmlAction ** pelems, UINT * pnElems);
static BOOL parseXmlAction(xmlNode * node, XmlAction * elem);
static BOOL parseXmlButtons(xmlNode * node, XmlButton ** pelems, UINT * pnElems);
static BOOL parseXmlButton(xmlNode * node, XmlButton * elem);
static BOOL parseXmlSensorTypes(xmlNode * node, XmlSensorType ** pelems, UINT * pnElems);
static BOOL parseXmlSensorType(xmlNode * node, XmlSensorType * elem);
static BOOL parseXmlColors(xmlNode * node, XmlColor ** pelems, UINT *pnElems);
static BOOL parseXmlColor(xmlNode * node, XmlColor * elem);
static BOOL parseXmlLogics(xmlNode * node, XmlLogic ** pelems, UINT *pnElems);
static BOOL parseXmlLogic(xmlNode * node, XmlLogic * elem);
static BOOL parseXmlSounds(xmlNode * node, XmlSound ** pelems, UINT * pnElems);
static BOOL parseXmlSound(xmlNode * node, XmlSound * elem);
static BOOL parseXmlSoundFX(xmlNode * node, XmlSoundFX * elem);
static BOOL parseXmlAnimationControl(xmlNode * node, XmlAnimationControl * elem);
static BOOL parseXmlCGRect(xmlNode * node, CGRect * result);
static BOOL parseXmlFloat(xmlNode * node, float * result);
static BOOL parseXmlCGFloat(xmlNode * node, CGFloat * result);
static BOOL parseXmlUINT(xmlNode * node, UINT * result);
static BOOL parseXmlTextContent(xmlNode * node, const xmlChar ** result);

static void killXmlGlobal(XmlGlobal ** pelem);
static void killXmlOrientations(XmlOrientation ** pelems, UINT * pnElems);
static void killXmlOrientation(XmlOrientation * elem);
static void killXmlLcds(XmlLcd ** pelems, UINT * pnElems);
static void killXmlLcd(XmlLcd * elem);
static void killXmlDrawable(XmlDrawable * elem);
static void killXmlFaces(XmlFace ** pelems, UINT * pnElems);
static void killXmlFace(XmlFace * elem);
static void killXmlActions(XmlAction ** pelems, UINT * pnElems);
static void killXmlButtons(XmlButton ** pelems, UINT * pnElems);
static void killXmlButton(XmlButton * elem);
static void killXmlSensorTypes(XmlSensorType ** pelems, UINT * pnElems);
static void killXmlColors(XmlColor ** pelems, UINT *pnElems);
static void killXmlLogics(XmlLogic ** pelems, UINT *pnElems);
static void killXmlSounds(XmlSound ** pelems, UINT *pnElems);
static void killXmlSound(XmlSound * elem);
static void killXmlSoundFX(XmlSoundFX * elem);

#pragma mark -
#pragma mark Serialization
void serializeXmlRoot(NSFileHandle * file, XmlRoot * elem);
void deserializeXmlRoot(NSFileHandle * file, XmlRoot ** pelem);
static void serializeXmlGlobal(NSFileHandle * file, XmlGlobal * elem);
static void deserializeXmlGlobal(NSFileHandle * file, XmlGlobal ** pelem);
static void serializeXmlOrientations(NSFileHandle * file, XmlOrientation * elems, UINT nElems);
static void deserializeXmlOrientations(NSFileHandle * file, XmlOrientation ** pelems, UINT nElems);
static void serializeXmlLcds(NSFileHandle * file, XmlLcd * elems, UINT nElems);
static void deserializeXmlLcds(NSFileHandle * file, XmlLcd ** pelems, UINT nElems);
static void serializeXmlDrawable(NSFileHandle * file, XmlDrawable * elem);
static void deserializeXmlDrawable(NSFileHandle * file, XmlDrawable ** pelem);
static void serializeXmlFaces(NSFileHandle * file, XmlFace * elems, UINT nElems);
static void deserializeXmlFaces(NSFileHandle * file, XmlFace ** pelems, UINT nElems);
static void serializeXmlActions(NSFileHandle * file, XmlAction * elems, UINT nElems);
static void deserializeXmlActions(NSFileHandle * file, XmlAction ** pelems, UINT nElems);
static void serializeXmlButtons(NSFileHandle * file, XmlButton * elems, UINT nElems);
static void deserializeXmlButtons(NSFileHandle * file, XmlButton ** pelems, UINT nElems);
static void serializeXmlSensorTypes(NSFileHandle * file, XmlSensorType * elems, UINT nElems);
static void deserializeXmlSensorTypes(NSFileHandle * file, XmlSensorType ** pelems, UINT nElems);
static void serializeXmlColors(NSFileHandle * file, XmlColor * elems, UINT nElems);
static void deserializeXmlColors(NSFileHandle * file, XmlColor ** pelems, UINT nElems);
static void serializeXmlLogics(NSFileHandle * file, XmlLogic * elems, UINT nElems);
static void deserializeXmlLogics(NSFileHandle * file, XmlLogic ** pelems, UINT nElems);
static void serializeXmlLogic(NSFileHandle * file, XmlLogic * elem);
static void deserializeXmlLogic(NSFileHandle * file, XmlLogic ** pelem);
static void serializeXmlSounds(NSFileHandle * file, XmlSound * elems, UINT nElems);
static void deserializeXmlSounds(NSFileHandle * file, XmlSound ** pelems, UINT nElems);
static void serializeXmlSoundFX(NSFileHandle * file, XmlSoundFX * elem);
static void deserializeXmlSoundFX(NSFileHandle * file, XmlSoundFX ** pelem);
static void serializeXmlAnimationControl(NSFileHandle * file, XmlAnimationControl * elem);
static void deserializeXmlAnimationControl(NSFileHandle * file, XmlAnimationControl ** pelem);
static void serializeXmlDrawingOrderElementTypes(NSFileHandle * file, XmlOrientationElementType * elems, UINT nElems);
static void serializeXmlDrawingOrderElementIndices(NSFileHandle * file, UINT * elems, UINT nElems);
static void deserializeXmlDrawingOrderElementTypes(NSFileHandle * file, XmlOrientationElementType ** pelems, UINT nElems);
static void deserializeXmlDrawingOrderElementIndices(NSFileHandle * file, UINT ** pelems, UINT nElems);
static void serializeXmlNSString(NSFileHandle * file, NSString * string);
static void deserializeXmlNSString(NSFileHandle * file, NSString ** pstring);
static void setOrientationIndicesFromPointers(void);
static void setOrientationPointersFromIndices(void);

#pragma mark -
#pragma mark static helper functions
static void shiftSkinToViewportOriginAndApplyZoomAndTextureZoom(void);

#pragma mark -
#pragma mark static init functions

static void initXmlRoot(XmlRoot * elem) {
	elem->filename = nil;
	elem->directory = nil;
	elem->global = NULL;
	elem->nOrientations = 0;
	elem->orientations = NULL;
	elem->currentOrientation = NULL;
	elem->previousOrientation = NULL;
	elem->logicStateVec = 0;
	return;
}

static void initXmlGlobal(XmlGlobal * elem) {
	elem->title = nil;
	elem->author = nil;
	elem->message = nil;
	elem->copyright = nil;
	elem->hardware = nil;
	elem->model = '\0';
	elem->class = 0;
	elem->romFilename = nil;
	elem->patchFilename = nil;
	elem->nLcdColors = 0;
	elem->lcdColors = NULL;
	elem->lcdInterpolationEnabled = YES;
	elem->lcdInterpolationMethod = XmlLcdInterpolationMethodSharp;
	elem->sounds = NULL;
	elem->nSounds = 0;
	elem->beepType = XmlBeepTypeSquare;
	elem->framerate = FRAMERATEDEFAULT;
	elem->requiresSGX = FALSE;
	return;
}

static void initXmlOrientation(XmlOrientation * elem) {
	elem->orientationType = XmlOrientationTypePortrait;
	elem->textureFilename = nil;
	elem->backgroundColor.red = 0;
	elem->backgroundColor.green = 0;
	elem->backgroundColor.blue = 0;
	elem->backgroundColor.alpha = 1;
	elem->hasStatusBar = FALSE;
	elem->statusBarStyle = UIStatusBarStyleDefault;
	elem->nLcds = 0;
	elem->lcds = NULL;
	elem->nFaces = 0;
	elem->faces = NULL;
	elem->nButtons = 0;
	elem->buttons = NULL;
	elem->viewport = CGRectMake(0, 0, 0, 0);
	elem->zoomX = 1.0;
	elem->zoomY = 1.0;
	elem->textureZoomX = 1.0;
	elem->textureZoomY = 1.0;
	elem->nDrawingOrder = 0;
	elem->drawingOrderElementTypes = NULL;
	elem->drawingOrderElementIndices = NULL;
	return;
}

static void initXmlDrawable(XmlDrawable * elem) {
	initXmlColor(&(elem->color), 1, 1, 1, 1);
	elem->isTextured = FALSE;
	elem->textureOrientation = XmlOrientationTypePortrait;
	elem->texture = CGRectMake(0, 0, 0, 0);
	elem->screen = CGRectMake(0, 0, 0, 0);
	elem->animationControl = NULL;
}

static void initXmlFace(XmlFace * elem) {
	elem->zorder = 0;
	elem->nLogics = 0;
	elem->logics = NULL;
	elem->onDrawable = NULL;
	elem->offDrawable = NULL;
	elem->soundfx = NULL;
	return;
}

static void initXmlAction(XmlAction * elem) {
	elem->buttonId = 0;
	elem->delay = 0.0f;
	elem->triggerMode = XmlActionTriggerModeTrigger;
	return;
}

static void initXmlButton(XmlButton * elem) {
	elem->nId = 0;
	elem->bDown = FALSE;
	elem->type = XmlButtonTypeNormal;
	elem->nSensorTypes = 0;
	elem->sensorTypes = NULL;
	elem->mode = XmlButtonModeNormal;
	elem->nOut = 0;
	elem->nIn = 0;
	elem->zorder = 0;
	elem->nLogics = 0;
	elem->logics = NULL;
	elem->logicId = 0;
	elem->toucharea = CGRectMake(0, 0, 0, 0);
	elem->onDrawable = NULL;
	elem->offDrawable = NULL;
	elem->soundfx = NULL;
	elem->nActions = 0;
	elem->actions = NULL;
	elem->isGhost = NO;
	return;
}

static void initXmlSensorType(XmlSensorType * elem) {
	*elem = XmlSensorTypeTouchInside;
}

static void initXmlLcd(XmlLcd * elem) {
	elem->zorder = 0;
	elem->nLogics = 0;
	elem->logics = NULL;
	elem->onDrawable = NULL;
	elem->offDrawable = NULL;
	return;
}

static void initXmlColor(XmlColor * elem, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
	elem->red = red;
	elem->green = green;
	elem->blue = blue;
	elem->alpha = alpha;
	return;
}

static void initXmlLogic(XmlLogic * elem) {
	elem->dontCareVec = 0xFFFF;
	elem->logicVec = 0x0000;
	return;
}

static void initXmlAnimationControl(XmlAnimationControl * elem) {
	elem->repeats = NO;
	elem->noGate = NO;
	elem->fadeinval = 0;
	elem->holdonval = 0;
	elem->fadeoutval = 0;
	elem->holdoffval = 0;
	elem->currentfadeinval = 0;
	elem->currentholdonval = 0;
	elem->currentfadeoutval = 0;
	elem->currentholdoffval = 0;
	elem->currentAlpha = 0;
	elem->previousPredicate = NO;
	elem->state = XmlAnimationControlStateIdle;
	return;
}

static void initXmlSound(XmlSound * elem) {
	elem->filename = nil;
	elem->xmlSoundId = 0;
	elem->volume = 1.0;
	return;
}

static void initXmlSoundFX(XmlSoundFX * elem) {
	elem->soundIDOnDown = 0;
	elem->soundIDOnHold = 0;
	elem->soundIDOnUp = 0;
	elem->repeat = NO;
	elem->volume = 1.0;
	elem->currentSessionID = 0;
	return;
}

#pragma mark -
#pragma mark static helper functions
static BOOL searchNodeList(xmlNode * node, const char * name, xmlNode ** result) {
	xmlNode * current = node;
	do {
		if (!current) 
			return FALSE;
		if (strcmp((const char *) current->name, name) == 0) {
			if (result != NULL) {
				*result = current;
			}
			return TRUE;
		}
	} while ((current = current->next));
	return FALSE;
}

#pragma mark -
#pragma mark static parser functions

static BOOL parseXmlRoot(xmlNode * node, XmlRoot * elem) {
	do { 
		if (strcmp((char *) node->name,"global") == 0) {
			if (!parseXmlGlobal(node, &(elem->global))) {
				addToXmlParserLog(@"Error parsing <global>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"orientations") == 0) {
			if (!parseXmlOrientations(node, &(elem->orientations), &(elem->nOrientations))) {
				addToXmlParserLog(@"Error parsing <orientations>.");
				goto kill;
			}
		}
	} while ((node=node->next));
	
	// Was everything found?
	if (!elem->global) {
		addToXmlParserLog(@"No <global> found.");
		goto kill;
	}
	if (!elem->orientations) {
		addToXmlParserLog(@"No <orientations> found.");
	}
	
	return TRUE;
kill:
	killXmlRoot(elem);
	return FALSE;
}

static BOOL parseXmlGlobal(xmlNode * node, XmlGlobal ** pelem) {
	// Debug
	//printTreeToConsole(node, 0);
	
	XmlGlobal * elem =  malloc(sizeof(XmlGlobal));
	if (!elem) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	
	initXmlGlobal(elem);
	*pelem = elem;
	node = node->children;
	xmlNode * tempNode;
	const xmlChar * tempXmlChar;
	do { 
		if (strcmp((char *) node->name,"title") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<title> does contain more than just text.");
				goto kill;
			}
			elem->title = [[NSString stringWithUTF8String:(char *) tempXmlChar] retain];
		}
		else if (strcmp((char *) node->name,"author") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<author> does contain more than just text.");
				goto kill;
			}
			elem->author = [[NSString stringWithUTF8String:(char *) tempXmlChar] retain];
			
		}
		else if (strcmp((char *) node->name,"copyright") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<copyright> does contain more than just text.");
				goto kill;
			}
			elem->copyright = [[NSString stringWithUTF8String:(char *) tempXmlChar] retain];
			
		}
		else if (strcmp((char *) node->name,"message") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<message> does contain more than just text.");
				goto kill;
			}
			elem->message = [[NSString stringWithUTF8String:(char *) tempXmlChar] retain];
			
		}
		else if (strcmp((char *) node->name,"hardware") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<hardware> does contain more than just text.");
				goto kill;
			}
			elem->hardware = [[NSString stringWithUTF8String:(char *) tempXmlChar] retain];
		}
		else if (strcmp((char *) node->name,"rom") == 0) {
			if (!searchNodeList(node->children, "filename", &tempNode)) {
				addToXmlParserLog(@"No <filename> for <rom> given.");
				goto kill;
			}
			if (!parseXmlTextContent(tempNode, &tempXmlChar)) {
				addToXmlParserLog(@"Error parsing <filename>.");
				goto kill;
			}
			if (strlen((const char *) tempXmlChar) < 4) {
				addToXmlParserLog(@"<filename> of <rom> is too short.");
				goto kill;
			}
			elem->romFilename = [NSString stringWithUTF8String:(char *) tempXmlChar];
			elem->romFilename = [resolveXmlFilename(elem->romFilename) retain];
			
			if (searchNodeList(node->children, "patch", &tempNode)) {
				if (!searchNodeList(tempNode->children, "filename", &tempNode)) {
					addToXmlParserLog(@"No <filename> for <patch> in <rom> given.");
					goto kill;
				}
				if (!parseXmlTextContent(tempNode, &tempXmlChar)) {
					addToXmlParserLog(@"Error parsing <filename>.");
					goto kill;
				}
				if (strlen((const char *) tempXmlChar) < 4) {
					addToXmlParserLog(@"<filename> of <rom> is too short.");
					goto kill;
				}
				elem->patchFilename = [NSString stringWithUTF8String:(char *) tempXmlChar];
				elem->patchFilename = [resolveXmlFilename(elem->patchFilename) retain];
			}
			
		}
		else if (strcmp((char *) node->name,"model") == 0) {
			if ((node->children) && (strcmp((char *) node->children->name,"text") == 0))
				elem->model = *( BAD_CAST node->children->content );
			else {
				addToXmlParserLog(@"<model> does contain more than just text.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"class") == 0) {
			if (!parseXmlUINT(node, &(elem->class))) {
				addToXmlParserLog(@"Error parsing <class>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"lcdsettings") == 0) {
			if (searchNodeList(node->children, "colors", &tempNode)) {
				if (!parseXmlColors(tempNode, &(elem->lcdColors), &(elem->nLcdColors))) {
					addToXmlParserLog(@"Error parsing <lcdsettings><colors>.");
					goto kill;
				}
			}
			if (searchNodeList(node->children, "interpolation", &tempNode)) {
				if  (searchNodeList(tempNode, "disabled", NULL)) {
					elem->lcdInterpolationEnabled = FALSE;
				}
				else if (searchNodeList(tempNode, "method", &tempNode)) {
					elem->lcdInterpolationEnabled = TRUE;
					const xmlChar * tempString = NULL;
					searchNodeList(tempNode, "text", &tempNode);
					if (tempNode) {
						parseXmlTextContent(node->children, &tempString);
						if (tempString && (strcmp((char *) tempString, "sharp") == 0)) {
							elem->lcdInterpolationMethod = XmlLcdInterpolationMethodSharp;
						}
						else if (tempString && (strcmp((char *) tempString, "fuzzy") == 0)) {
							elem->lcdInterpolationMethod = XmlLcdInterpolationMethodFuzzy;
						}
						else {
							addToXmlParserLog(@"Unknown <lcdsettings><interpolation><method>.");
							goto kill;
						}	
					}
					else {
						addToXmlParserLog(@"Error parsing <lcdsettings><interpolation><method>.");
						goto kill;
					}
				}	
			}			
		}
		else if (strcmp((char *) node->name,"soundfiles") == 0) {
			if (!parseXmlSounds(node, &(elem->sounds), &(elem->nSounds))) {
				addToXmlParserLog(@"Error parsing <soundfiles>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"framerate") == 0) {
			if (!parseXmlFloat(node, &(elem->framerate))) {
				addToXmlParserLog(@"Error parsing <framerate>.");
				goto kill;
			}
			if ((elem->framerate < FRAMERATEMIN) || (elem->framerate > FRAMERATEMAX)) {
				addToXmlParserLog(@"Value of <framerate> not within range.");
				goto kill;
			}				
		}
		else if (strcmp((char *) node->name,"beeptype") == 0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"<beeptype> does contain more than just text.");
				goto kill;
			}
			if (strcmp((char *) tempXmlChar, "square") == 0) {
				elem->beepType = XmlBeepTypeSquare;
			}
			else if (strcmp((char *) tempXmlChar, "sawtooth") == 0) {
				elem->beepType = XmlBeepTypeSawtooth;
			}
			else if (strcmp((char *) tempXmlChar, "triangle") == 0) {
				elem->beepType = XmlBeepTypeTriangle;
			}
			else if (strcmp((char *) tempXmlChar, "sine") == 0) {
				elem->beepType = XmlBeepTypeSine;
			}
			else {
				addToXmlParserLog(@"The waveform in <beeptype> is not supported.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"requiressgx") == 0) {
			elem->requiresSGX = TRUE;
		}
	} while ((node=node->next));
	
	// Was everyting found ?
	if (!elem->title) {
		addToXmlParserLog(@"No <title> found.");
		goto kill;
	}
	/*
	if (!elem->author) {
		addToXmlParserLog(@"No <author> found.");
		goto kill;
	}
	*/
	if (!elem->hardware) {
		addToXmlParserLog(@"No <hardware> found.");
		goto kill;
	}
	if (!elem->model) {
		addToXmlParserLog(@"No <model> found.");
		goto kill;
	}
	if (!elem->romFilename) {
		addToXmlParserLog(@"No rom <filename> found.");
		goto kill;
	}

	if (strcmp([elem->hardware UTF8String], "Yorke")) {
		addToXmlParserLog(@"This <hardware> is not supported.");
		goto kill;
	}
	
#ifndef VERSIONPLUS
	if (elem->model != 'G') {
		addToXmlParserLog(@"This <model> is not supported.");
		goto kill;
	}		
#endif
    
	return TRUE;
kill:
	killXmlGlobal(pelem);
	return FALSE;
}

static BOOL parseXmlOrientations(xmlNode * node, XmlOrientation ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count how many orientations are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"orientation")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <orientation> found.");
		return FALSE;
	}
	
	// Allocate memory
	XmlOrientation * elems = malloc(ctr*sizeof(XmlOrientation));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlOrientation(elems + i); // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"orientation")==0) {
			if (!parseXmlOrientation(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <orientation>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
		
	return TRUE;
kill:
	killXmlOrientations(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlOrientation(xmlNode * node, XmlOrientation * elem) {	
	xmlNode * tempNode;
    xmlNode * tempNode2;
	const xmlChar * tempXmlChar;
	BOOL foundViewport = FALSE;
	node = node->children;

	do {	
		if (strcmp((char *) node->name,"texturefile")==0) {
			if (!searchNodeList(node->children, "filename", &tempNode)) {
				addToXmlParserLog(@"No <filename> for <texture> given.");
				goto kill;
			}
			if (!parseXmlTextContent(tempNode, &tempXmlChar)) {
				addToXmlParserLog(@"Error finding <filename>.");
				goto kill;
			}
			if (strlen((const char *) tempXmlChar) < 4) {
				addToXmlParserLog(@"<filename> too short.");
				goto kill;
			}
			elem->textureFilename = [NSString stringWithUTF8String:(char *) tempXmlChar];
			elem->textureFilename = [resolveXmlFilename(elem->textureFilename) retain];
			if (searchNodeList(node->children, "zoom", &tempNode)) {
				tempNode2 = NULL;
				if (searchNodeList(tempNode->children, "xzoom", &tempNode2)) {
                    if (!parseXmlCGFloat(tempNode2, &(elem->textureZoomX))) {
                        addToXmlParserLog(@"Error parsing <texture><zoom><xzoom>.");
                        goto kill;
                    }
                    if (searchNodeList(tempNode->children, "yzoom", &tempNode2)) {
                        if (!parseXmlCGFloat(tempNode2, &(elem->textureZoomY))) {
                            addToXmlParserLog(@"Error parsing <texture><zoom><yzoom>.");
                            goto kill;
                        }
                    }
                    else {
                        addToXmlParserLog(@"Error parsing <texture><zoom><yzoom>.");
                        goto kill;
                    }
                }
                if (tempNode2 == NULL) {
                    if (!parseXmlCGFloat(tempNode, &(elem->textureZoomX))) {
                        addToXmlParserLog(@"Error parsing <texture><zoom>.");
                        goto kill;
                    }
                    elem->textureZoomY = elem->textureZoomX;
                }
                NSLog(@"elem->textureZoomX = %f", elem->textureZoomX);
                NSLog(@"elem->textureZoomY = %f", elem->textureZoomY);
			}
		}
		else if (strcmp((char *) node->name,"viewport") == 0) {
			if (!parseXmlCGRect(node, &(elem->viewport)) ) {
				addToXmlParserLog(@"Error parsing <viewport>.");
				goto kill;
			}
			foundViewport = TRUE;
			if (searchNodeList(node->children, "zoom", &tempNode)) {
                tempNode2 = NULL;
				if (searchNodeList(tempNode->children, "xzoom", &tempNode2)) {
                    if (!parseXmlCGFloat(tempNode2, &(elem->zoomX))) {
                        addToXmlParserLog(@"Error parsing <viewport><zoom><xzoom>.");
                        goto kill;
                    }
                    if (searchNodeList(tempNode->children, "yzoom", &tempNode2)) {
                        if (!parseXmlCGFloat(tempNode2, &(elem->zoomY))) {
                            addToXmlParserLog(@"Error parsing <viewport><zoom><yzoom>.");
                            goto kill;
                        }
                    }
                    else {
                        addToXmlParserLog(@"Error parsing <viewport><zoom><yzoom>.");
                        goto kill;
                    }
                }
                if (tempNode2 == NULL) {
                    if (!parseXmlCGFloat(tempNode, &(elem->zoomX))) {
                        addToXmlParserLog(@"Error parsing <viewport><zoom>.");
                        goto kill;
                    }
                    elem->zoomY = elem->zoomX;
                }
			}
		}
		else if (strcmp((char *) node->name,"statusbar")==0) {
			elem->hasStatusBar = true;
			if (!searchNodeList(node->children, "style", &tempNode)) {
				addToXmlParserLog(@"No <style> for <statusbar> given");
				goto kill;
			}
			if (!parseXmlTextContent(tempNode, &tempXmlChar)) {
				addToXmlParserLog(@"Error finding value for <style> of <statusbar>.");
				goto kill;
			}
			if (strcmp((char *) tempXmlChar, "default") == 0)
				elem->statusBarStyle = UIStatusBarStyleDefault;
			else if (strcmp((char *) tempXmlChar, "blackOpaque") == 0)
				elem->statusBarStyle = UIStatusBarStyleLightContent;
			else if (strcmp((char *) tempXmlChar, "blackTranslucent") == 0)
                elem->statusBarStyle = UIStatusBarStyleLightContent;
            else if (strcmp((char *) tempXmlChar, "lightContent") == 0)
                elem->statusBarStyle = UIStatusBarStyleLightContent;
			else {
				addToXmlParserLog(@"<style> of <statusbar> not recognized.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"background")==0) {
			if (!searchNodeList(node->children, "color", &tempNode) ) {
				addToXmlParserLog(@"Error parsing <color> of <background>.");
				goto kill;
			}					
			if (!parseXmlColor(tempNode, &(elem->backgroundColor)) ) {
				addToXmlParserLog(@"Error parsing <color> of <background>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"lcds")==0) {
			if (!parseXmlLcds(node, &(elem->lcds), &(elem->nLcds))) {
				addToXmlParserLog(@"Error parsing <lcds>");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"faces")==0) {
			if (!parseXmlFaces(node, &(elem->faces), &(elem->nFaces))) {
				addToXmlParserLog(@"Error parsing <faces>");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"buttons")==0) {
			if (!parseXmlButtons(node, &(elem->buttons), &(elem->nButtons))) {
				addToXmlParserLog(@"Error parsing <buttons>");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"portrait")==0) {
			elem->orientationType = XmlOrientationTypePortrait;
		}
		else if (strcmp((char *) node->name,"landscape")==0) {
			elem->orientationType = XmlOrientationTypeLandscape;
		}
		else if (strcmp((char *) node->name,"landscapeleft")==0) {
			elem->orientationType = XmlOrientationTypeLandscapeLeft;
		}
		else if (strcmp((char *) node->name,"landscaperight")==0) {
			elem->orientationType = XmlOrientationTypeLandscapeRight;
		}
		else if (strcmp((char *) node->name,"portraitupsidedown")==0) {
			elem->orientationType = XmlOrientationTypePortraitUpsideDown;
		}
		else if (strcmp((char *) node->name,"vertical")==0) {
			elem->orientationType = XmlOrientationTypeVertical;
		}
		else if (strcmp((char *) node->name,"horizontal")==0) {
			elem->orientationType = XmlOrientationTypeLandscape;
		}
		
	} while ((node = node->next));
	
	if (foundViewport == FALSE) {
		if ((elem->orientationType == XmlOrientationTypePortrait) ||
			(elem->orientationType == XmlOrientationTypeVertical) ||
			(elem->orientationType == XmlOrientationTypePortraitUpsideDown)) {
			elem->viewport = CGRectMake(0.0, 0.0, 320.0, 480.0);
		}
		else {
			elem->viewport = CGRectMake(0.0, 0.0, 480.0, 320.0);
		}
		
		//addToXmlParserLog(@"No <viewport> given.");
		//goto kill;
	}
	
	// Was everything found?
	XmlDrawable * tempDrawable;
	if (!elem->textureFilename) {
		for (int i=0; i < elem->nFaces; i++) {
			tempDrawable = (elem->faces+i)->onDrawable;
			if (tempDrawable && tempDrawable->isTextured) {
				addToXmlParserLog(@"No <texture> given.");
				goto kill;
			}
			tempDrawable = (elem->faces+i)->offDrawable;
			if (tempDrawable && tempDrawable->isTextured) {
				addToXmlParserLog(@"No <texture> given.");
				goto kill;
			}
		}
		for (int i=0; i < elem->nButtons; i++) {
			tempDrawable = (elem->buttons+i)->onDrawable;
			if (tempDrawable && tempDrawable->isTextured) {
				addToXmlParserLog(@"No <texture> given.");
				goto kill;
			}
			tempDrawable = (elem->buttons+i)->offDrawable;
			if (tempDrawable && tempDrawable->isTextured) {
				addToXmlParserLog(@"No <texture> given.");
				goto kill;
			}
		}
	}
	/*
	if (!elem->lcd) {
		addToXmlParserLog(@"No <lcd> given.");
		goto kill;
	}
	if (!elem->faces) {
		addToXmlParserLog(@"No <faces> given.");
		goto kill;
	}		
	if (!elem->buttons) {
		addToXmlParserLog(@"No <buttons> given.");
		goto kill;
	}
	*/
	if ((elem->orientationType != XmlOrientationTypePortrait) &&
	    (elem->orientationType != XmlOrientationTypePortraitUpsideDown) &&
		(elem->orientationType != XmlOrientationTypeLandscape) &&
		(elem->orientationType != XmlOrientationTypeLandscapeLeft) &&
		(elem->orientationType != XmlOrientationTypeLandscapeRight) &&
		(elem->orientationType != XmlOrientationTypeVertical)) {
		addToXmlParserLog(@"No valid orientation-tag for <orientation> given.");
		goto kill;
	}	
	
	// Die Reihenfolge zum Zeichnen rausfinden
	// Wieviel Speicher brauchen wir?
	int ctr = 0;
	XmlButton * myButton = elem->buttons;
	for (int i=0; i < elem->nButtons; i++) {
		if (myButton->isGhost == NO) {
			ctr++;
		}
		myButton++;
	}
	ctr += elem->nFaces + elem->nLcds;
	
	elem->nDrawingOrder = ctr;
	XmlOrientationElementType * drawingOrderElementTypes = malloc(ctr * sizeof(XmlOrientationElementType));
	if (!drawingOrderElementTypes) {
		addToXmlParserLog(@"Error allocating memory.");
		goto kill;
	}
	
	elem->drawingOrderElementTypes = drawingOrderElementTypes;
	UINT * drawingOrderElementIndices = malloc(ctr * sizeof(UINT));
	if (!drawingOrderElementIndices) {
		addToXmlParserLog(@"Error allocating memory.");
		goto kill;
	}	
	
	elem->drawingOrderElementIndices = drawingOrderElementIndices;
	CGFloat * tempDrawingOrderElementZorders = malloc(ctr * sizeof(CGFloat));
	if (!tempDrawingOrderElementZorders) {
		addToXmlParserLog(@"Error allocating memory.");
		goto kill;
	}	
	
	ctr = 0;
	int i;
	int j;
	myButton = elem->buttons;
	for (i=0; i < elem->nButtons; i++) {
		if (myButton->isGhost == NO) {
			*(drawingOrderElementTypes + ctr) = XmlOrientationElementTypeButton;
			*(drawingOrderElementIndices + ctr) = i;
			*(tempDrawingOrderElementZorders + ctr) = myButton->zorder;
			ctr++;
		}
		myButton++;
	}
	for (i=0; i < elem->nFaces; i++) {
		*(drawingOrderElementTypes + ctr) = XmlOrientationElementTypeFace;
		*(drawingOrderElementIndices + ctr) = i;
		*(tempDrawingOrderElementZorders + ctr) = ((elem->faces) + i)->zorder;
		ctr++;
	}
	for (i=0; i < elem->nLcds; i++) {
		*(drawingOrderElementTypes + ctr) = XmlOrientationElementTypeLcd;
		*(drawingOrderElementIndices + ctr) = i;
		*(tempDrawingOrderElementZorders + ctr) = ((elem->lcds) + i)->zorder;
		ctr++;
	}
	
	// Sortieren
	XmlOrientationElementType tempDrawingOrderElementType;
	UINT tempDrawingOrderElementIndex;
	CGFloat tempDrawingOrderElementZorder;
	for(i=0; i < (ctr-1); i++) {
		for(j=(i+1); j < ctr; j++) {
			if ( *(tempDrawingOrderElementZorders + i) > *(tempDrawingOrderElementZorders + j) ) {
				tempDrawingOrderElementType = *(drawingOrderElementTypes + i);
				tempDrawingOrderElementIndex = *(drawingOrderElementIndices + i);
				tempDrawingOrderElementZorder = *(tempDrawingOrderElementZorders + i);
				*(drawingOrderElementTypes + i) = *(drawingOrderElementTypes + j);
				*(drawingOrderElementIndices + i) = *(drawingOrderElementIndices + j);
				*(tempDrawingOrderElementZorders + i) = *(tempDrawingOrderElementZorders + j);
				*(drawingOrderElementTypes + j) = tempDrawingOrderElementType;
				*(drawingOrderElementIndices + j) = tempDrawingOrderElementIndex;
				*(tempDrawingOrderElementZorders + j) = tempDrawingOrderElementZorder;
			}
		}
	}
	free(tempDrawingOrderElementZorders);
	//tempDrawingOrderElementZorders = NULL;
	
	return TRUE;
kill:
	killXmlOrientation(elem);
	return FALSE;
}

static BOOL parseXmlLcds(xmlNode * node, XmlLcd ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count how many orientations are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"lcd")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		return TRUE;
		//addToXmlParserLog(@"No <lcds> given.");
		//return FALSE;
	}
	
	// Allocate memory
	XmlLcd * elems = malloc(ctr*sizeof(XmlLcd));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlLcd(elems+i);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"lcd")==0) {
			if (!parseXmlLcd(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <lcd>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlLcds(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlLcd(xmlNode * node, XmlLcd * elem) {
	xmlNode * current = node->children;
    float tempFloat;
	do {	
		if (strcmp((char *) current->name,"zorder")==0) {
			if (!parseXmlFloat(current, &tempFloat) ) {
				addToXmlParserLog(@"Error parsing <zorder>.");
				goto kill;
            }
            elem->zorder = tempFloat;
		}
		else if (strcmp((char *) current->name,"logics")==0) {
			if (!parseXmlLogics(current, &(elem->logics), &(elem->nLogics)) ) {
				addToXmlParserLog(@"Error parsing <logics>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"on")==0) {
			// Allocate memory
			elem->onDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->onDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->onDrawable);
			if (!parseXmlDrawable(current, elem->onDrawable)) {
				addToXmlParserLog(@"Error parsing <on>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"off")==0) {
			// Allocate memory
			elem->offDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->offDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->offDrawable);
			if (!parseXmlDrawable(current, elem->offDrawable)) {
				addToXmlParserLog(@"Error parsing <off>.");
				goto kill;
			}
		}
	} while ((current = current->next));
	
	// Found at least an on-drawable?
	if (!(elem->onDrawable)) {
		elem->onDrawable = malloc(sizeof(XmlDrawable));
		if (!(elem->onDrawable)) {
			addToXmlParserLog(@"Error allocating memory.");
			goto kill;
		}
		initXmlDrawable(elem->onDrawable);
		if (!parseXmlDrawable(node, elem->onDrawable)) {
			// Nothing found ... give up
			killXmlDrawable(elem->onDrawable);
			free(elem->onDrawable);
			elem->onDrawable = NULL;
		}
	}
	
	if (!(elem->onDrawable) && !(elem->offDrawable)) {
		addToXmlParserLog(@"Could not resolve drawable information.");
		goto kill;
	}
	
	// Special for LCD: if no texture is given, use the whole texture
	if (elem->onDrawable && elem->onDrawable->isTextured == false) {
		elem->onDrawable->isTextured = true;
		elem->onDrawable->texture = CGRectMake(0, 0, 131, 64);
	}
	if (elem->offDrawable && elem->offDrawable->isTextured == false) {
		elem->offDrawable->isTextured = true;
		elem->offDrawable->texture = CGRectMake(0, 0, 131, 64);
	}
	
	if ((elem->offDrawable) && (elem->offDrawable->animationControl)) {
		/* Old version, does confuse more than being effective
		elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->fadeoutval;
		elem->offDrawable->animationControl->fadeoutval = elem->offDrawable->animationControl->fadeinval;
		elem->offDrawable->animationControl->fadeinval = elem->offDrawable->animationControl->currentfadeinval;
		elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->holdonval;
		elem->offDrawable->animationControl->holdonval = elem->offDrawable->animationControl->holdoffval;
		elem->offDrawable->animationControl->holdoffval = elem->offDrawable->animationControl->currentfadeinval;
		elem->offDrawable->animationControl->currentfadeinval = 0;
		*/
		resetAnimation(elem->offDrawable->animationControl, YES, NO);
	}
	if ((elem->onDrawable) && (elem->onDrawable->animationControl))
		resetAnimation(elem->onDrawable->animationControl, NO, NO);
	
	return TRUE;
kill:
	killXmlLcd(elem);
	return FALSE;
}

static BOOL parseXmlDrawable(xmlNode * node, XmlDrawable * elem) {
	const xmlChar * tempXmlChar;
	node = node->children;
	BOOL foundColor = FALSE;
	BOOL foundDrawable = FALSE;
	do {	
		if (strcmp((char *) node->name,"color")==0) {
			if (!parseXmlColor(node, &(elem->color)) ) {
				addToXmlParserLog(@"Error parsing <color>.");
				goto kill;
			}
			foundColor = TRUE;
		}
		else if (strcmp((char *) node->name,"texture")==0) {
			elem->isTextured = true;
			if (!parseXmlCGRect(node, &(elem->texture)) ) {
				addToXmlParserLog(@"Error parsing <texture>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"screen")==0) {
			if (!parseXmlCGRect(node, &(elem->screen)) ) {
				addToXmlParserLog(@"Error parsing <screen>.");
				goto kill;
			}
			foundDrawable = TRUE;
		}
		else if (strcmp((char *) node->name,"animation")==0) {
			// Allocate memory
			elem->animationControl = malloc(sizeof(XmlAnimationControl));
			if (!(elem->animationControl)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlAnimationControl(elem->animationControl);
			if (!parseXmlAnimationControl(node, elem->animationControl) ) {
				addToXmlParserLog(@"Error parsing <animation>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"orientation")==0) {
			if (!parseXmlTextContent(node->children, &tempXmlChar)) {
				addToXmlParserLog(@"Error parsing <orientation>.");
				goto kill;
			}		
			if (strcmp((char *) tempXmlChar,"portrait")==0) {
				elem->textureOrientation = XmlOrientationTypePortrait;
			}
			else if (strcmp((char *) tempXmlChar,"landscapeLeft")==0) {
				elem->textureOrientation = XmlOrientationTypeLandscapeLeft;
			}
			else if (strcmp((char *) tempXmlChar,"landscapeRight")==0) {
				elem->textureOrientation = XmlOrientationTypeLandscapeRight;
			}
			else if (strcmp((char *) tempXmlChar,"portraitUpsideDown")==0) {
				elem->textureOrientation = XmlOrientationTypePortraitUpsideDown;
			}
			else {
				addToXmlParserLog(@"Error parsing value of <orientation>.");
				goto kill;
			}
		}
	} while ((node = node->next));
	
	if (!foundColor && elem->isTextured) {
		initXmlColor(&(elem->color), 1, 1, 1, 1);
	}
	
	return foundDrawable;
kill:
	killXmlDrawable(elem);
	return FALSE;
}

static BOOL parseXmlFaces(xmlNode * node, XmlFace ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count how many orientations are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"face")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		return TRUE;
		//addToXmlParserLog(@"No <faces> given.");
		//return FALSE;
	}
	
	// Allocate memory
	XmlFace * elems = malloc(ctr*sizeof(XmlFace));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlFace(elems+i);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;

	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"face")==0) {
			if (!parseXmlFace(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <face>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlFaces(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlFace(xmlNode * node, XmlFace * elem) {
	xmlNode * current = node->children;
    float tempFloat;
	do {	
		if (strcmp((char *) current->name,"zorder")==0) {
			if (!parseXmlFloat(current, &tempFloat) ) {
				addToXmlParserLog(@"Error parsing <zorder>.");
				goto kill;
            }
            elem->zorder = tempFloat;
		}
		else if (strcmp((char *) current->name,"logics")==0) {
			if (!parseXmlLogics(current, &(elem->logics), &(elem->nLogics)) ) {
				addToXmlParserLog(@"Error parsing <logics>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"on")==0) {
			// Allocate memory
			elem->onDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->onDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->onDrawable);
			if (!parseXmlDrawable(current, elem->onDrawable)) {
				addToXmlParserLog(@"Error parsing <on>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"off")==0) {
			// Allocate memory
			elem->offDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->offDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->offDrawable);
			if (!parseXmlDrawable(current, elem->offDrawable)) {
				addToXmlParserLog(@"Error parsing <off>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"sound")==0) {
			elem->soundfx = malloc(sizeof(XmlSoundFX));
			if (!(elem->soundfx)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlSoundFX(elem->soundfx);
			if (!parseXmlSoundFX(current, elem->soundfx) ) {
				addToXmlParserLog(@"Error parsing <sound>.");
				goto kill;
			}
		}
	} while ((current = current->next));
	
	// Found at least an on-drawable?
	if (!(elem->onDrawable)) {
		elem->onDrawable = malloc(sizeof(XmlDrawable));
		if (!(elem->onDrawable)) {
			addToXmlParserLog(@"Error allocating memory.");
			goto kill;
		}
		initXmlDrawable(elem->onDrawable);
		if (!parseXmlDrawable(node, elem->onDrawable)) {
			// Nothing found ... give up
			killXmlDrawable(elem->onDrawable);
			free(elem->onDrawable);
			elem->onDrawable = NULL;
		}
	}

	if (!(elem->onDrawable) && !(elem->offDrawable)) {
		addToXmlParserLog(@"Could not resolve drawable information.");
		goto kill;
	}
	
	if ((elem->offDrawable) && (elem->offDrawable->animationControl)) {
		/* Old version, does confuse more than being effective
		 elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->fadeoutval;
		 elem->offDrawable->animationControl->fadeoutval = elem->offDrawable->animationControl->fadeinval;
		 elem->offDrawable->animationControl->fadeinval = elem->offDrawable->animationControl->currentfadeinval;
		 elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->holdonval;
		 elem->offDrawable->animationControl->holdonval = elem->offDrawable->animationControl->holdoffval;
		 elem->offDrawable->animationControl->holdoffval = elem->offDrawable->animationControl->currentfadeinval;
		 elem->offDrawable->animationControl->currentfadeinval = 0;
		 */
		resetAnimation(elem->offDrawable->animationControl, YES, NO);
	}
	if ((elem->onDrawable) && (elem->onDrawable->animationControl))
		resetAnimation(elem->onDrawable->animationControl, NO, NO);
	
	return TRUE;
kill:
	killXmlFace(elem);
	return FALSE;
}

static BOOL parseXmlActions(xmlNode * node, XmlAction ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"action")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <action> given.");
		return FALSE;
	}
	
	// Allocate memory
	XmlAction * elems = malloc(ctr*sizeof(XmlAction));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlAction(elems+i);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"action")==0) {
			if (!parseXmlAction(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <action>.");
				goto kill;
			}

			ctr++;
		}
	} while ((current=current->next));

	return TRUE;
kill:
	killXmlActions(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlAction(xmlNode * node, XmlAction * elem) {
	xmlNode * current = node->children;
	
	do {	
		if (strcmp((char *) current->name,"buttonid")==0) {
			if (!parseXmlUINT(current, &(elem->buttonId)) ) {
				addToXmlParserLog(@"Error parsing <buttonid>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"delay")==0) {
			if (!parseXmlFloat(current, &(elem->delay)) ) {
				addToXmlParserLog(@"Error parsing <delay>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"on")==0) {
			elem->triggerMode = XmlActionTriggerModeOn;
		}
		else if (strcmp((char *) current->name,"off")==0) {
			elem->triggerMode = XmlActionTriggerModeOff;
		}
		else if (strcmp((char *) current->name,"trigger")==0) {
			elem->triggerMode = XmlActionTriggerModeTrigger;
		}
		else if (strcmp((char *) current->name,"toggle")==0) {
			elem->triggerMode = XmlActionTriggerModeToggle;
		}
	} while ((current = current->next));
	
	if (elem->delay > 1.0) {
		addToXmlParserLog(@"delays longer 1sec are not supported.");
		goto kill;
	}
	
	return TRUE;
kill:
	return FALSE;
}

static BOOL parseXmlButtons(xmlNode * node, XmlButton ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"button")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <buttons> given.");
		return FALSE;
	}
	
	// Allocate memory
	XmlButton * elems = malloc(ctr*sizeof(XmlButton));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlButton(elems+i);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	// Check also if at least one menu-button was found:
	BOOL foundMenuButton = NO;
	do { 				
		if (strcmp((char *) current->name,"button")==0) {
			if (!parseXmlButton(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <button>.");
				goto kill;
			}
			if ((elems+ctr)->type == XmlButtonTypeMenu) {
				foundMenuButton = true;
			}
			ctr++;
		}
	} while ((current=current->next));

	if (!foundMenuButton) {
		addToXmlParserLog(@"No <button> of <type>menu</type> given.");
		goto kill;				
	}
	
	return TRUE;
kill:
	killXmlButtons(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlButton(xmlNode * node, XmlButton * elem) {
	xmlNode * current = node->children;
	BOOL foundToucharea = NO;
	xmlNode * tempNode = NULL;
    float tempFloat;
	
	do {	
		if (strcmp((char *) current->name,"id")==0) {
			if (!parseXmlUINT(current, &(elem->nId)) ) {
				addToXmlParserLog(@"Error parsing <id>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"type")==0) {
			const xmlChar * tempText;
			if (!parseXmlTextContent(current, &tempText)) {
				addToXmlParserLog(@"Error parsing <type>.");
				goto kill;
			}
			if (strcmp((char *) tempText, "menu") == 0) {
				elem->type = XmlButtonTypeMenu;
			}
			else if (strcmp((char *) tempText, "normal") == 0) {
				elem->type = XmlButtonTypeNormal;
			}
			else if (strcmp((char *) tempText, "virtual") == 0) {
				elem->type = XmlButtonTypeVirtual;
			}
			else if (strcmp((char *) tempText, "copy") == 0) {
				elem->type = XmlButtonTypeCopy;
			}
			else if (strcmp((char *) tempText, "paste") == 0) {
				elem->type = XmlButtonTypePaste;
			}
			else if (strcmp((char *) tempText, "init") == 0) {
				elem->type = XmlButtonTypeInit;
			}
			else {
				addToXmlParserLog(@"This <type> is unknown.");
				goto kill;
			}
			
		}
		else if (strcmp((char *) current->name,"mode")==0) {
			const xmlChar * tempText;
			if (!parseXmlTextContent(current, &tempText)) {
				addToXmlParserLog(@"Error parsing <mode>.");
				goto kill;
			}
			if (strcmp((char *) tempText, "normal") == 0) {
				elem->mode = XmlButtonModeNormal;
			}
			else if (strcmp((char *) tempText, "toggle") == 0) {
				elem->mode = XmlButtonModeToggle;
			}
			else {
				addToXmlParserLog(@"This <mode> is unknown.");
				goto kill;
			}
			
		}
		else if (strcmp((char *) current->name,"sensors")==0) {
			if (!parseXmlSensorTypes(current, &(elem->sensorTypes), &(elem->nSensorTypes))) {
				addToXmlParserLog(@"Error parsing <sensors>");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"sensortype")==0) {
			tempNode = current;
		}
		else if (strcmp((char *) current->name,"out")==0) {
			if (!parseXmlUINT(current, &(elem->nOut)) ) {
				addToXmlParserLog(@"Error parsing <out>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) current->name,"in")==0) {
			if (!parseXmlUINT(current, &(elem->nIn)) ) {
				addToXmlParserLog(@"Error parsing <in>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) current->name,"zorder")==0) {
			if (!parseXmlFloat(current, &tempFloat) ) {
				addToXmlParserLog(@"Error parsing <zorder>.");
				goto kill;
			}
            elem->zorder = tempFloat;
		}
		else if (strcmp((char *) current->name,"logics")==0) {
			if (!parseXmlLogics(current, &(elem->logics), &(elem->nLogics)) ) {
				addToXmlParserLog(@"Error parsing <logics>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"logicid")==0) {
			if (!parseXmlUINT(current, &(elem->logicId)) ) {
				addToXmlParserLog(@"Error parsing <logicid>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) current->name,"toucharea")==0) {
			if (!parseXmlCGRect(current, &(elem->toucharea)) ) {
				addToXmlParserLog(@"Error parsing <toucharea>.");
				goto kill;
			}
			foundToucharea = YES;
		}
		else if (strcmp((char *) current->name,"sound")==0) {
			elem->soundfx = malloc(sizeof(XmlSoundFX));
			if (!(elem->soundfx)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlSoundFX(elem->soundfx);
			if (!parseXmlSoundFX(current, elem->soundfx) ) {
				addToXmlParserLog(@"Error parsing <sound>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"active")==0) {
			// Allocate memory
			elem->onDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->onDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->onDrawable);
			initXmlColor(&(elem->onDrawable->color),0,0,0,0);
			if (!parseXmlDrawable(current, elem->onDrawable)) {
				addToXmlParserLog(@"Error parsing <active>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"idle")==0) {
			// Allocate memory
			elem->offDrawable = malloc(sizeof(XmlDrawable));
			if (!(elem->offDrawable)) {
				addToXmlParserLog(@"Error allocating memory.");
				goto kill;
			}
			initXmlDrawable(elem->offDrawable);
			initXmlColor(&(elem->offDrawable->color),0,0,0,0);
			if (!parseXmlDrawable(current, elem->offDrawable)) {
				addToXmlParserLog(@"Error parsing <idle>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"actions")==0) {
			if (!parseXmlActions(current, &(elem->actions), &(elem->nActions)) ) {
				addToXmlParserLog(@"Error parsing <actions>.");
				goto kill;
			}
		}
		else if (strcmp((char *) current->name,"ghost")==0) {
			elem->isGhost = TRUE;
		}
	} while ((current = current->next));
	
	// Found on-drawable? => Try parse it directly
	if (!(elem->onDrawable)) {
		elem->onDrawable = malloc(sizeof(XmlDrawable));
		if (!(elem->onDrawable)) {
			addToXmlParserLog(@"Error allocating memory.");
			goto kill;
		}
		initXmlDrawable(elem->onDrawable);
		initXmlColor(&(elem->onDrawable->color),0,0,0,0);
		if (!parseXmlDrawable(node, elem->onDrawable)) {
			// Nothing found ... give up
			killXmlDrawable(elem->onDrawable);
			free(elem->onDrawable);
			elem->onDrawable = NULL;
		}
		else {
		// Put default hold-time (for buttons as a convenience)
			if (!(elem->onDrawable->animationControl)) {
				elem->onDrawable->animationControl = malloc(sizeof(XmlAnimationControl));
				if (!(elem->onDrawable->animationControl)) {
					addToXmlParserLog(@"Error allocating memory.");
					goto kill;
				}
				initXmlAnimationControl(elem->onDrawable->animationControl);
				elem->onDrawable->animationControl->holdonval = BUTTON_HOLDCYCLES;
			}
		}
	}

	if ((elem->offDrawable) && (elem->offDrawable->animationControl)) {
		/* Old version, does confuse more than being effective
		 elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->fadeoutval;
		 elem->offDrawable->animationControl->fadeoutval = elem->offDrawable->animationControl->fadeinval;
		 elem->offDrawable->animationControl->fadeinval = elem->offDrawable->animationControl->currentfadeinval;
		 elem->offDrawable->animationControl->currentfadeinval = elem->offDrawable->animationControl->holdonval;
		 elem->offDrawable->animationControl->holdonval = elem->offDrawable->animationControl->holdoffval;
		 elem->offDrawable->animationControl->holdoffval = elem->offDrawable->animationControl->currentfadeinval;
		 elem->offDrawable->animationControl->currentfadeinval = 0;
		 */
		resetAnimation(elem->offDrawable->animationControl, YES, NO);
	}
	if ((elem->onDrawable) && (elem->onDrawable->animationControl))
		resetAnimation(elem->onDrawable->animationControl, NO, NO);

	if (elem->logicId > 16) {
		addToXmlParserLog(@"<logicid> must not be greater than 16.");
		goto kill;
	}
	
	// Have sensors been found?
	if (elem->sensorTypes == NULL) {
		elem->sensorTypes = malloc(sizeof(XmlSensorType));
		if (elem->sensorTypes == NULL) {
			addToXmlParserLog(@"Error allocating memory.");
			goto kill;
		}
		initXmlSensorType(elem->sensorTypes);
		elem->nSensorTypes = 1;
		
		// Lets try to find it directly
		if (tempNode != NULL) {
			if (!parseXmlSensorType(tempNode->children, elem->sensorTypes)) {
				addToXmlParserLog(@"Error parsing <sensortype>.");
				goto kill;
			}
		}
	}
	
	// Haben wir alles gefunden?
	if (!foundToucharea) {
		if (elem->offDrawable)
			elem->toucharea = elem->offDrawable->screen;
		else if (elem->onDrawable)
			elem->toucharea = elem->onDrawable->screen;
	}

	
	//If a button was explicitly tagged as ghost, it cannot react to input by default
	if (elem->isGhost == YES) { // So that it will not react to any touch input
		*(elem->sensorTypes) = XmlSensorTypeNone;
	}
	
	// If nothing has to be drawn, we dont want to have it in the drawing queue for performance reasons
	if ((elem->onDrawable == NULL) && (elem->offDrawable == NULL)) {
		elem->isGhost = YES;
	}
	
	return TRUE;
kill:
	killXmlButton(elem);
	return FALSE;
}

static BOOL parseXmlSensorTypes(xmlNode * node, XmlSensorType ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"sensorpreset")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <sensorpreset> given.");
		return FALSE;
	}
	
	// Allocate memory
	XmlSensorType * elems = malloc(ctr*sizeof(XmlSensorType));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlSensorType(elems+i);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"sensorpreset")==0) {
			if (!parseXmlSensorType(current->children, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <sensorpreset>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlSensorTypes(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlSensorType(xmlNode * node, XmlSensorType * elem) {
	const xmlChar * tempText;
	if (!parseXmlTextContent(node, &tempText)) {
		addToXmlParserLog(@"Error parsing <sensortype>.");
		goto kill;
	}
	if (strcmp((char *) tempText, "none") == 0) {
		*elem = XmlSensorTypeNone;
	}
	else if (strcmp((char *) tempText, "touch") == 0) {
		*elem = XmlSensorTypeTouch;
	}
	else if (strcmp((char *) tempText, "touchUp") == 0) {
		*elem = XmlSensorTypeTouchUp;
	}
	else if (strcmp((char *) tempText, "touchInside") == 0) {
		*elem = XmlSensorTypeTouchInside;
	}
	else if (strcmp((char *) tempText, "touchInsideDelayed") == 0) {
		*elem = XmlSensorTypeTouchInsideDelayed;
	}
	else if (strcmp((char *) tempText, "touchInsideDelayedFocused") == 0) {
		*elem = XmlSensorTypeTouchInsideDelayedFocused;
	}
	else if (strcmp((char *) tempText, "touchInsideUp") == 0) {
		*elem = XmlSensorTypeTouchInsideUp;
	}
	else if (strcmp((char *) tempText, "touchInsideUpFast") == 0) {
		*elem = XmlSensorTypeTouchInsideUpFast;
	}
	else if (strcmp((char *) tempText, "touchInsideUpFocused") == 0) {
		*elem = XmlSensorTypeTouchInsideUpFocused;
	}
	else if (strcmp((char *) tempText, "touchInsideUpFastFocused") == 0) {
		*elem = XmlSensorTypeTouchInsideUpFastFocused;
	}
	else if (strcmp((char *) tempText, "touchDown") == 0) {
		*elem = XmlSensorTypeTouchDown;
	}
	else if (strcmp((char *) tempText, "touchInsideDown") == 0) {
		*elem = XmlSensorTypeTouchInsideDown;
	}
	else if (strcmp((char *) tempText, "touchInsideDownDelayed") == 0) {
		*elem = XmlSensorTypeTouchInsideDownDelayed;
	}
	else if (strcmp((char *) tempText, "touchInsideDownDelayedFocused") == 0) {
		*elem = XmlSensorTypeTouchInsideDownDelayedFocused;
	}
	else if (strcmp((char *) tempText, "tap") == 0) {
		*elem = XmlSensorTypeTap;
	}
	else if (strcmp((char *) tempText, "doubleTap") == 0) {
		*elem = XmlSensorTypeDoubleTap;
	}
	else if (strcmp((char *) tempText, "swipeInsideRight") == 0) {
		*elem = XmlSensorTypeSwipeInsideRight;
	}
	else if (strcmp((char *) tempText, "swipeInsideLeft") == 0) {
		*elem = XmlSensorTypeSwipeInsideLeft;
	}
	else if (strcmp((char *) tempText, "swipeInsideUp") == 0) {
		*elem = XmlSensorTypeSwipeInsideUp;
	}
	else if (strcmp((char *) tempText, "swipeInsideDown") == 0) {
		*elem = XmlSensorTypeSwipeInsideDown;
	}	
	else if (strcmp((char *) tempText, "swipeInsideUpperRight") == 0) {
		*elem = XmlSensorTypeSwipeInsideUpperRight;
	}
	else if (strcmp((char *) tempText, "swipeInsideUpperLeft") == 0) {
		*elem = XmlSensorTypeSwipeInsideUpperLeft;
	}
	else if (strcmp((char *) tempText, "swipeInsideLowerRight") == 0) {
		*elem = XmlSensorTypeSwipeInsideLowerRight;
	}
	else if (strcmp((char *) tempText, "swipeInsideLowerLeft") == 0) {
		*elem = XmlSensorTypeSwipeInsideLowerLeft;
	}
	else if (strcmp((char *) tempText, "swipeInsideRightFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideRightFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideLeftFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideLeftFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideUpFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideUpFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideDownFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideDownFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideUpperRightFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideUpperRightFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideUpperLeftFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideUpperLeftFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideLowerRightFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideLowerRightFast;
	}
	else if (strcmp((char *) tempText, "swipeInsideLowerLeftFast") == 0) {
		*elem = XmlSensorTypeSwipeInsideLowerLeftFast;
	}
	else {
		addToXmlParserLog(@"This <sensorpreset> is unknown.");
		goto kill;
	}
	
	return TRUE;
kill:
	return FALSE;
}

static BOOL parseXmlColors(xmlNode * node, XmlColor ** pelems, UINT *pnElems) {
	xmlNode * current = node->children;
	
	// First we need to count how many orientations are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"color")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <color> given.");
		return FALSE;
	}
	
	// Allocate memory
	XmlColor * elems = malloc(ctr*sizeof(XmlColor));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlColor(elems + i, 0, 0, 0, 0);  // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"color")==0) {
			if (!parseXmlColor(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <color>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlColors(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlColor(xmlNode * node, XmlColor * elem) {
	node = node->children;
	xmlNode * temp;
	BOOL isPremultiplied = NO;
    float tempFloat;
    
	if (!searchNodeList(node, "red", &temp))
		return FALSE;
	if (!parseXmlFloat(temp, &tempFloat))
		return FALSE;
    elem->red = tempFloat;
	if (!searchNodeList(node, "green", &temp))
		return FALSE;
	if (!parseXmlFloat(temp, &tempFloat))
		return FALSE;
    elem->green = tempFloat;
	if (!searchNodeList(node, "blue", &temp))
		return FALSE;
	if (!parseXmlFloat(temp, &tempFloat))
		return FALSE;
    elem->blue = tempFloat;
	if (!searchNodeList(node, "alpha", &temp))
		return FALSE;
	if (!parseXmlFloat(temp, &tempFloat))
		return FALSE;
    elem->alpha = tempFloat;
	if (searchNodeList(node, "premultiplied", &temp))
		isPremultiplied = YES;
	elem->red = (elem->red)/255;
	elem->green = (elem->green)/255;
	elem->blue = (elem->blue)/255;
	elem->alpha = (elem->alpha)/255;
	// premultiply alpha
	if (!isPremultiplied) {
		elem->red = (elem->red)*(elem->alpha);
		elem->green = (elem->green)*(elem->alpha);
		elem->blue = (elem->blue)*(elem->alpha);
	}
	return TRUE;
}

static BOOL parseXmlLogics(xmlNode * node, XmlLogic ** pelems, UINT *pnElems) {
	xmlNode * current = node->children;
	
	// First we need to count how many orientations are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"logic")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <logic> given.");
		return FALSE;
	}
	
	// Allocate memory
	XmlLogic * elems = malloc(ctr*sizeof(XmlLogic));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlLogic(elems + i);
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"logic")==0) {
			if (!parseXmlLogic(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <logic>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlLogics(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlLogic(xmlNode * node, XmlLogic * elem) {
	const xmlChar * tempXmlChar;
	if (!parseXmlTextContent(node, &tempXmlChar))
		return FALSE;
	int n = strlen((const char *) tempXmlChar);
	int n2 = 0;
	for (int i=0; i < n; i++) {
		if (tempXmlChar[i] != ' ') n2++;
	}		
	if (n2 > (8*sizeof(DWORD)))
		return FALSE;
	elem->logicVec = 0;
	elem->dontCareVec = 0;
	n2 = 0;
	for (int i=0; i < n; i++) {
		if (tempXmlChar[i] == '1') {
			elem->logicVec = elem->logicVec | (0x1 << n2++);
		}
		else if  (tempXmlChar[i] == 'X') {
			elem->dontCareVec = elem->dontCareVec | (0x1 << n2++);
		}
		else if (tempXmlChar[i] == '0') {
				n2++;
		}
		else if (tempXmlChar[i] != ' ') {
			return FALSE;
		}
	}
	for (int i=n2; i < (8*sizeof(DWORD)); i++) {
		elem->dontCareVec = elem->dontCareVec | (0x1 << i);
	}
	return TRUE;
}

static BOOL parseXmlSounds(xmlNode * node, XmlSound ** pelems, UINT * pnElems) {
	xmlNode * current = node->children;
	// First we need to count how many sounds are needed:
	int ctr = 0;
	do { 
		if (strcmp((char *) current->name,"soundfile")==0) 
			ctr++;
	} while ((current=current->next));
	if (ctr==0) {
		addToXmlParserLog(@"No <soundfile> found.");
		return FALSE;
	}
	
	// Allocate memory
	XmlSound * elems = malloc(ctr*sizeof(XmlSound));
	if (!elems) {
		addToXmlParserLog(@"Error allocating memory.");
		return FALSE;
	}
	for (int i = 0; i < ctr; i++) {
		initXmlSound(elems + i); // elems ist Typgebunden und die Addition stimmt so!!!
	}
	*pelems = elems;
	*pnElems = ctr;
	
	//Start over and actually parse
	current = node->children;
	ctr = 0;
	do { 				
		if (strcmp((char *) current->name,"soundfile")==0) {
			if (!parseXmlSound(current, elems + ctr)) {
				addToXmlParserLog(@"Error parsing <soundfile>.");
				goto kill;
			}
			ctr++;
		}
	} while ((current=current->next));
	
	return TRUE;
kill:
	killXmlSounds(pelems, pnElems);
	return FALSE;
}

static BOOL parseXmlSound(xmlNode * node, XmlSound * elem) {	
	const xmlChar * tempXmlChar;
	
	node = node->children;
	
	do {	
		if (strcmp((char *) node->name,"filename")==0) {
			if (!parseXmlTextContent(node, &tempXmlChar)) {
				addToXmlParserLog(@"Error finding <filename>.");
				goto kill;
			}
			if (strlen((const char *) tempXmlChar) < 4) {
				addToXmlParserLog(@"<filename> too short.");
				goto kill;
			}
			elem->filename = [NSString stringWithUTF8String:(char *) tempXmlChar];
			elem->filename = [resolveXmlFilename(elem->filename) retain];
		}
		else if (strcmp((char *) node->name,"id")==0) {
			if (!parseXmlUINT(node, &(elem->xmlSoundId))) {
				addToXmlParserLog(@"Error parsing <id>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"volume")==0) {
			if (!parseXmlFloat(node, &(elem->volume))) {
				addToXmlParserLog(@"Error parsing <volume>.");
				goto kill;
			}
			
		}
	} while ((node = node->next));
	
	// Was everything found?
	if ((elem->filename) == nil) {
		addToXmlParserLog(@"No <filename> given.");
		goto kill;
	}
	if ((elem->xmlSoundId) == 0) {
		addToXmlParserLog(@"No <id> given.");
		goto kill;
	}	

	return TRUE;
kill:
	killXmlSound(elem);
	return FALSE;
}

static BOOL parseXmlSoundFX(xmlNode * node, XmlSoundFX * elem) {	
	
	node = node->children;
	
	do {	
		if (strcmp((char *) node->name,"ondown")==0) {
			if (!parseXmlUINT(node, &(elem->soundIDOnDown))) {
				addToXmlParserLog(@"Error parsing <ondown>.");
				goto kill;
			}
		}
		else if (strcmp((char *) node->name,"onup")==0) {
			if (!parseXmlUINT(node, &(elem->soundIDOnUp))) {
				addToXmlParserLog(@"Error parsing <onup>.");
				goto kill;
			}
				
		}
		else if (strcmp((char *) node->name,"onhold")==0) {
			if (!parseXmlUINT(node, &(elem->soundIDOnHold))) {
				addToXmlParserLog(@"Error parsing <onhold>.");
				goto kill;
			}
			
		}
		else if (strcmp((char *) node->name,"volume")==0) {
			if (!parseXmlFloat(node, &(elem->volume))) {
				addToXmlParserLog(@"Error parsing <volume>.");
				goto kill;
			}
			
		}
		else if (strcmp((char *) node->name,"repeat")==0) {
			elem->repeat = YES;
		}
	} while ((node = node->next));
	
	// Die sound-ids ersetzen
	XmlSound * tempSound;
	int i;
	if (elem->soundIDOnDown) {
		tempSound = xml->global->sounds;
		for (i=0; i < xml->global->nSounds; i++) {
			if (tempSound->xmlSoundId == elem->soundIDOnDown) {
				break;
			}
			tempSound++;
		}
		if (i && (i == xml->global->nSounds)) {
			addToXmlParserLog(@"No soundfile for <sound><ondown> found.");
			goto kill;
		}
	}
	
	if (elem->soundIDOnUp) {
		tempSound = xml->global->sounds;
		for (i=0; i < xml->global->nSounds; i++) {
			if (tempSound->xmlSoundId == elem->soundIDOnUp) {
				break;
				
			}
			tempSound++;
		}
		if (i && (i == xml->global->nSounds)) {
			addToXmlParserLog(@"No soundfile for <sound><onup> found.");
			goto kill;
		}
	}
	
	if (elem->soundIDOnHold) {
		tempSound = xml->global->sounds;
		for (i=0; i < xml->global->nSounds; i++) {
			if (tempSound->xmlSoundId == elem->soundIDOnHold) {
				break;
				
			}
			tempSound++;
		}
		if (i && (i == xml->global->nSounds)) {
			addToXmlParserLog(@"No soundfile for <sound><onhold> found.");
			goto kill;
		}
	}
		
	return TRUE;
kill:
	killXmlSoundFX(elem);
	return FALSE;
}

static BOOL parseXmlAnimationControl(xmlNode * node, XmlAnimationControl * elem) {
	node = node->children;
	
	do {	
		if (strcmp((char *) node->name,"fadein")==0) {
			if (!parseXmlUINT(node, &(elem->fadeinval))) {
				addToXmlParserLog(@"Error parsing <fadein>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"fadeout")==0) {
			if (!parseXmlUINT(node, &(elem->fadeoutval))) {
				addToXmlParserLog(@"Error parsing <fadeout>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"holdon")==0) {
			if (!parseXmlUINT(node, &(elem->holdonval))) {
				addToXmlParserLog(@"Error parsing <holdon>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"holdoff")==0) {
			if (!parseXmlUINT(node, &(elem->holdoffval))) {
				addToXmlParserLog(@"Error parsing <holdoff>.");
				goto kill;
			}
		} 
		else if (strcmp((char *) node->name,"repeat")==0) {
			elem->repeats = YES;
		}
		else if (strcmp((char *) node->name,"triggered")==0) {
			elem->noGate = YES;
		}
	} while ((node = node->next));
	
	if (elem->repeats && elem->noGate) {
		addToXmlParserLog(@"Either <repeat /> or <triggered /> mode is possible.");
		goto kill;
	}
	
	return TRUE;
kill:
	return FALSE;	
}

static BOOL parseXmlCGRect(xmlNode * node, CGRect * result) {
	xmlNode * temp;
	xmlNode * temp2;
    float tempFloat;
	if (!searchNodeList(node->children, "origin", &temp))
		return FALSE;
	if (!searchNodeList(temp->children, "x", &temp2))
		return FALSE;
	if (!parseXmlFloat(temp2, &tempFloat))
		return FALSE;
    result->origin.x = tempFloat;
	if (!searchNodeList(temp->children, "y", &temp2))
		return FALSE;
	if (!parseXmlFloat(temp2, &tempFloat))
		return FALSE;
    result->origin.y = tempFloat;
	if (!searchNodeList(node->children, "size", &temp))
		return FALSE;
	if (!searchNodeList(temp->children, "height", &temp2))
		return FALSE;
	if (!parseXmlFloat(temp2, &tempFloat))
		return FALSE;
    result->size.height = tempFloat;
	if (!searchNodeList(temp->children, "width", &temp2))
		return FALSE;
	if (!parseXmlFloat(temp2, &tempFloat))
		return FALSE;
    result->size.width = tempFloat;
	return TRUE;
}

static BOOL parseXmlFloat(xmlNode * node, float * result) {
	const xmlChar * tempChar;
	if (parseXmlTextContent(node, &tempChar)) {
		if (sscanf((char *) tempChar, "%f", result) != EOF)
			return TRUE;
		else
			return FALSE;
	}
	return FALSE;
}

static BOOL parseXmlCGFloat(xmlNode * node, CGFloat * result) {
    float temp = 1.;
    bool retval;
    retval = parseXmlFloat(node, &temp);
    *result = temp;
    return retval;
}

static BOOL parseXmlUINT(xmlNode * node, UINT * result) {
	const xmlChar * tempChar;
	if (parseXmlTextContent(node, &tempChar)) {
		if (sscanf((char *) tempChar, "%u", result) != EOF)
			return TRUE;
		else
			return FALSE;
	}
	return FALSE;
}

static BOOL parseXmlTextContent(xmlNode * node, const xmlChar ** result) {
	xmlNode * temp = node;
	if (node->children)
		temp = node->children;
	if (strcmp((char *) temp->name, "text") == 0) {
		*result = temp->content;
		return TRUE;
	}
	return FALSE;
}

#pragma mark -
#pragma mark static kill functions

void killXmlRoot(XmlRoot * elem) {
	[elem->filename release];
	elem->filename = nil;
	[elem->directory release];
	elem->directory = nil;
	if (elem) {
		if (elem->global)
			killXmlGlobal(&(elem->global));
		if (elem->orientations)
			killXmlOrientations(&(elem->orientations), &(elem->nOrientations));
	}
	return;
}

static void killXmlGlobal(XmlGlobal ** pelem) {
	XmlGlobal * elem = *pelem;
	[elem->title release];
	[elem->author release];
	[elem->hardware release];
	[elem->copyright release];
	[elem->message release];
	[elem->romFilename release];
	[elem->patchFilename release];
	if (elem->nLcdColors) {
		killXmlColors(&(elem->lcdColors), &(elem->nLcdColors));
	}
	if (elem->sounds) {
		killXmlSounds(&(elem->sounds), &(elem->nSounds));
	}
	free(elem);
	*pelem = NULL;
	return;
}

static void killXmlOrientations(XmlOrientation ** pelems, UINT * pnElems) {
	XmlOrientation * elems = *pelems;
	for (int i = 0; i < *pnElems; i++) {
		killXmlOrientation(elems + i);
	}
	free(elems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlOrientation(XmlOrientation * elem) {
	[elem->textureFilename release];
	elem->textureFilename = nil;
	if (elem->lcds)
		killXmlLcds(&(elem->lcds),&(elem->nLcds));
	if (elem->faces) 
		killXmlFaces(&(elem->faces),&(elem->nFaces));
	if (elem->buttons)
		killXmlButtons(&(elem->buttons),&(elem->nButtons));
	if(elem->drawingOrderElementTypes)
		free(elem->drawingOrderElementTypes);
	if(elem->drawingOrderElementIndices)
		free(elem->drawingOrderElementIndices);
	initXmlOrientation(elem);
	return;
}

static void killXmlLcds(XmlLcd ** pelems, UINT * pnElems) {
	XmlLcd * elems = *pelems;
	for (int i = 0; i < *pnElems; i++) {
		killXmlLcd(elems + i);
	}
	free(elems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlLcd(XmlLcd * elem) {
	if (elem->logics)
		killXmlLogics(&(elem->logics), &(elem->nLogics));
	if (elem->onDrawable) {
		killXmlDrawable(elem->onDrawable);
		free(elem->onDrawable);
		elem->onDrawable = NULL;
	}
	if (elem->offDrawable) {
		killXmlDrawable(elem->offDrawable);
		free(elem->offDrawable);
		elem->offDrawable = NULL;
	}
	return;
}

static void killXmlDrawable(XmlDrawable * elem) {
	if (elem->animationControl) {
		free(elem->animationControl);
		elem->animationControl = NULL;
	}
	return;
}

static void killXmlFaces(XmlFace ** pelems, UINT * pnElems) {
	XmlFace * elems = *pelems;
	for (int i = 0; i < *pnElems; i++) {
		killXmlFace(elems + i);
	}
	free(elems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlFace(XmlFace * elem) {
	if (elem->logics)
		killXmlLogics(&(elem->logics), &(elem->nLogics));
	if (elem->onDrawable) {
		killXmlDrawable(elem->onDrawable);
		free(elem->onDrawable);
		elem->onDrawable = NULL;
	}
	if (elem->offDrawable) {
		killXmlDrawable(elem->offDrawable);
		free(elem->offDrawable);
		elem->offDrawable = NULL;
	}
	if (elem->soundfx) {
		killXmlSoundFX(elem->soundfx);
		free(elem->soundfx);
		elem->soundfx = NULL;
	}
	return;
}

static void killXmlActions(XmlAction ** pelems, UINT * pnElems) {
	free(*pelems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlButtons(XmlButton ** pelems, UINT * pnElems) {
	XmlButton * elems = *pelems;
	for (int i = 0; i < *pnElems; i++) {
		killXmlButton(elems + i);
	}
	free(elems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlButton(XmlButton * elem) {
	if (elem->logics)
		killXmlLogics(&(elem->logics), &(elem->nLogics));
	if (elem->onDrawable) {
		killXmlDrawable(elem->onDrawable);
		free(elem->onDrawable);
		elem->onDrawable = NULL;
	}
	if (elem->offDrawable) {
		killXmlDrawable(elem->offDrawable);
		free(elem->offDrawable);
		elem->offDrawable = NULL;
	}
	if (elem->soundfx) {
		killXmlSoundFX(elem->soundfx);
		free(elem->soundfx);
		elem->soundfx = NULL;
	}
	if (elem->actions) {
		killXmlActions(&(elem->actions), &(elem->nActions));
	}
	if (elem->sensorTypes) {
		killXmlSensorTypes(&(elem->sensorTypes), &(elem->nSensorTypes));
	}
	return;
}

static void killXmlSensorTypes(XmlSensorType ** pelems, UINT * pnElems) {
	free(*pelems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlColors(XmlColor ** pelems, UINT *pnElems) {
	free(*pelems);
	*pelems = NULL;
	*pnElems = 0;
	return;
}

static void killXmlLogics(XmlLogic ** pelems, UINT *pnElems) {
	free(*pelems);
	*pelems = NULL;
	*pnElems = 0;
	return;	
}

static void killXmlSounds(XmlSound ** pelems, UINT *pnElems) {
	XmlSound * elems = *pelems;
	for (int i = 0; i < *pnElems; i++) {
		killXmlSound(elems + i);
	}	
	free(*pelems);
	*pelems = NULL;
	*pnElems = 0;
	return;		
}

static void killXmlSound(XmlSound * elem) {
	[elem->filename release];
	elem->filename = nil;
}

static void killXmlSoundFX(XmlSoundFX * elem) {
	return;
}

#pragma mark -
#pragma mark Serialization
void serializeXmlRoot(NSFileHandle * file, XmlRoot * elem) {
	setOrientationIndicesFromPointers();
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlRoot)]];
	if (elem->filename != nil) {
		serializeXmlNSString(file, elem->filename);
	}
	if (elem->directory != nil) {
		serializeXmlNSString(file, elem->directory);
	}
	if (elem->global) {
		serializeXmlGlobal(file, elem->global);
	}
	if (elem->nOrientations) {
		serializeXmlOrientations(file, elem->orientations, elem->nOrientations);
	}
}

void deserializeXmlRoot(NSFileHandle * file, XmlRoot ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlRoot)];
	*pelem = malloc(sizeof(XmlRoot));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlRoot));
		if ((*pelem)->filename != nil) {
			deserializeXmlNSString(file, &((*pelem)->filename));
		}
		if ((*pelem)->directory != nil) {
			deserializeXmlNSString(file, &((*pelem)->directory));
		}
		if ((*pelem)->global) {
			deserializeXmlGlobal(file, &((*pelem)->global));
		}
		if ((*pelem)->nOrientations) {
			deserializeXmlOrientations(file, &((*pelem)->orientations), (*pelem)->nOrientations);
		}
	}
	setOrientationPointersFromIndices();
}

static void serializeXmlGlobal(NSFileHandle * file, XmlGlobal * elem) {
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlGlobal)]];
	if (elem->title != nil) {
		serializeXmlNSString(file, elem->title);
	}
	if (elem->author != nil) {
		serializeXmlNSString(file, elem->author);
	}
	if (elem->copyright != nil) {
		serializeXmlNSString(file, elem->copyright);
	}
	if (elem->message != nil) {
		serializeXmlNSString(file, elem->message);
	}
	if (elem->hardware != nil) {
		serializeXmlNSString(file, elem->hardware);
	}
	if (elem->romFilename != nil) {
		serializeXmlNSString(file, elem->romFilename);
	}
	if (elem->patchFilename != nil) {
		serializeXmlNSString(file, elem->patchFilename);
	}
	if (elem->nLcdColors) {
		serializeXmlColors(file, elem->lcdColors, elem->nLcdColors);
	}
	if (elem->nSounds) {
		serializeXmlSounds(file, elem->sounds, elem->nSounds);
	}
}

static void deserializeXmlGlobal(NSFileHandle * file, XmlGlobal ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlGlobal)];
	*pelem = malloc(sizeof(XmlGlobal));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlGlobal));
		if ((*pelem)->title != nil) {
			deserializeXmlNSString(file, &((*pelem)->title));
		}
		if ((*pelem)->author != nil) {
			deserializeXmlNSString(file, &((*pelem)->author));
		}
		if ((*pelem)->copyright != nil) {
			deserializeXmlNSString(file, &((*pelem)->copyright));
		}
		if ((*pelem)->message != nil) {
			deserializeXmlNSString(file, &((*pelem)->message));
		}
		if ((*pelem)->hardware != nil) {
			deserializeXmlNSString(file, &((*pelem)->hardware));
		}
		if ((*pelem)->romFilename != nil) {
			deserializeXmlNSString(file, &((*pelem)->romFilename));
		}
		if ((*pelem)->patchFilename != nil) {
			deserializeXmlNSString(file, &((*pelem)->patchFilename));
		}
		if ((*pelem)->nLcdColors) {
			deserializeXmlColors(file, &((*pelem)->lcdColors), (*pelem)->nLcdColors);
		}
		if ((*pelem)->nSounds) {
			deserializeXmlSounds(file, &((*pelem)->sounds), (*pelem)->nSounds);
		}
	}		
}

static void serializeXmlOrientations(NSFileHandle * file, XmlOrientation * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlOrientation))]];
	
	for (int i=0; i < nElems; i++) {
		if (elems->textureFilename != nil) {
			serializeXmlNSString(file, elems->textureFilename);
		}
		if (elems->nLcds) {	
			serializeXmlLcds(file, elems->lcds, elems->nLcds);
		}
		if (elems->nFaces) {
			serializeXmlFaces(file, elems->faces, elems->nFaces);
		}
		if (elems->nButtons) {
			serializeXmlButtons(file, elems->buttons, elems->nButtons);
		}
		
		if (elems->nDrawingOrder) {
			serializeXmlDrawingOrderElementTypes(file, elems->drawingOrderElementTypes, elems->nDrawingOrder);
			serializeXmlDrawingOrderElementIndices(file, elems->drawingOrderElementIndices, elems->nDrawingOrder);
		}
		
		elems++;
	}
}

static void deserializeXmlOrientations(NSFileHandle * file, XmlOrientation ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlOrientation))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlOrientation));
	// Read in
	if (*pelems != NULL) {
		XmlOrientation * elem = *pelems;
		memcpy(elem, [data bytes], (nElems*sizeof(XmlOrientation)));
		for (int i=0; i < nElems; i++) {
			if (elem->textureFilename != nil) {
				deserializeXmlNSString(file, &(elem->textureFilename));
			}
			if (elem->nLcds) {	
				deserializeXmlLcds(file, &(elem->lcds), elem->nLcds);
			}
			if (elem->nFaces) {
				deserializeXmlFaces(file, &(elem->faces), elem->nFaces);
			}
			if (elem->nButtons) {
				deserializeXmlButtons(file, &(elem->buttons), elem->nButtons);
			}
			
			if (elem->nDrawingOrder) {
				deserializeXmlDrawingOrderElementTypes(file, &(elem->drawingOrderElementTypes), elem->nDrawingOrder);
				deserializeXmlDrawingOrderElementIndices(file, &(elem->drawingOrderElementIndices), elem->nDrawingOrder);
			}
			elem++;
		}
		
	}
}

static void serializeXmlLcds(NSFileHandle * file, XmlLcd * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlLcd))]];
	
	for (int i=0; i < nElems; i++) {
		if (elems->nLogics) {
			serializeXmlLogics(file, elems->logics, elems->nLogics);
		}
		if (elems->onDrawable) {	
			serializeXmlDrawable(file, elems->onDrawable);
		}
		if (elems->offDrawable) {	
			serializeXmlDrawable(file, elems->offDrawable);
		}
		elems++;
	}
}

static void deserializeXmlLcds(NSFileHandle * file, XmlLcd ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlLcd))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlLcd));
	// Read in
	if (*pelems != NULL) {
		XmlLcd * elem = *pelems;
		memcpy(elem, [data bytes], (nElems*sizeof(XmlLcd)));
		for (int i=0; i < nElems; i++) {
			if (elem->nLogics) {
				deserializeXmlLogics(file, &(elem->logics), elem->nLogics);
			}
			if (elem->onDrawable) {	
				deserializeXmlDrawable(file, &(elem->onDrawable));
			}
			if (elem->offDrawable) {	
				deserializeXmlDrawable(file, &(elem->offDrawable));
			}
			elem++;
		}
		
	}
}

static void serializeXmlDrawable(NSFileHandle * file, XmlDrawable * elem) {
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlDrawable)]];
	if (elem->animationControl) {
		serializeXmlAnimationControl(file, elem->animationControl);
	}
	
}

static void deserializeXmlDrawable(NSFileHandle * file, XmlDrawable ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlDrawable)];
	*pelem = malloc(sizeof(XmlDrawable));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlDrawable));
		if ((*pelem)->animationControl) {
			deserializeXmlAnimationControl(file, &((*pelem)->animationControl));
		}
	}
}

static void serializeXmlFaces(NSFileHandle * file, XmlFace * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlFace))]];
	
	for (int i=0; i < nElems; i++) {
		if (elems->nLogics) {
			serializeXmlLogics(file, elems->logics, elems->nLogics);
		}
		if (elems->onDrawable) {	
			serializeXmlDrawable(file, elems->onDrawable);
		}
		if (elems->offDrawable) {	
			serializeXmlDrawable(file, elems->offDrawable);
		}
		if (elems->soundfx) {	
			serializeXmlSoundFX(file, elems->soundfx);
		}
		elems++;
	}
}

static void deserializeXmlFaces(NSFileHandle * file, XmlFace ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlFace))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlFace));
	// Read in
	if (*pelems != NULL) {
		XmlFace * elem = *pelems;
		memcpy(elem, [data bytes], (nElems*sizeof(XmlFace)));
		for (int i=0; i < nElems; i++) {
			if (elem->nLogics) {
				deserializeXmlLogics(file, &(elem->logics), elem->nLogics);
			}
			if (elem->onDrawable) {	
				deserializeXmlDrawable(file, &(elem->onDrawable));
			}
			if (elem->offDrawable) {	
				deserializeXmlDrawable(file, &(elem->offDrawable));
			}
			if (elem->soundfx) {	
				deserializeXmlSoundFX(file, &(elem->soundfx));
			}
			elem++;
		}
		
	}
}

static void serializeXmlActions(NSFileHandle * file, XmlAction * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlAction))]];
}

static void deserializeXmlActions(NSFileHandle * file, XmlAction ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlAction))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlAction));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(XmlAction)));
	}
}

static void serializeXmlButtons(NSFileHandle * file, XmlButton * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlButton))]];
	
	for (int i=0; i < nElems; i++) {
		if (elems->nSensorTypes) {
			serializeXmlSensorTypes(file, elems->sensorTypes, elems->nSensorTypes);
		}
		if (elems->nLogics) {
			serializeXmlLogics(file, elems->logics, elems->nLogics);
		}
		if (elems->onDrawable) {	
			serializeXmlDrawable(file, elems->onDrawable);
		}
		if (elems->offDrawable) {	
			serializeXmlDrawable(file, elems->offDrawable);
		}
		if (elems->soundfx) {	
			serializeXmlSoundFX(file, elems->soundfx);
		}
		if (elems->nActions) {
			serializeXmlActions(file, elems->actions, elems->nActions);
		}
		elems++;
	}
}

static void deserializeXmlButtons(NSFileHandle * file, XmlButton ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlButton))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlButton));
	// Read in
	if (*pelems != NULL) {
		XmlButton * elem = *pelems;
		memcpy(elem, [data bytes], (nElems*sizeof(XmlButton)));
		for (int i=0; i < nElems; i++) {
			if (elem->nSensorTypes) {
				deserializeXmlSensorTypes(file, &(elem->sensorTypes), elem->nSensorTypes);
			}
			if (elem->nLogics) {
				deserializeXmlLogics(file, &(elem->logics), elem->nLogics);
			}			
			if (elem->onDrawable) {	
				deserializeXmlDrawable(file, &(elem->onDrawable));
			}
			if (elem->offDrawable) {	
				deserializeXmlDrawable(file, &(elem->offDrawable));
			}
			if (elem->soundfx) {	
				deserializeXmlSoundFX(file, &(elem->soundfx));
			}
			if (elem->nActions) {
				deserializeXmlActions(file, &(elem->actions), elem->nActions);
			}
			elem++;
		}
		
	}
}

static void serializeXmlSensorTypes(NSFileHandle * file, XmlSensorType * elems, UINT nElems)  {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlSensorType))]];
}

static void deserializeXmlSensorTypes(NSFileHandle * file, XmlSensorType ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlSensorType))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlSensorType));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(XmlSensorType)));
	}
}

static void serializeXmlColors(NSFileHandle * file, XmlColor * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlColor))]];
}

static void deserializeXmlColors(NSFileHandle * file, XmlColor ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlColor))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlColor));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(XmlColor)));
	}
}

static void serializeXmlLogics(NSFileHandle * file, XmlLogic * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlLogic))]];
}

static void deserializeXmlLogics(NSFileHandle * file, XmlLogic ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlLogic))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlLogic));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(XmlLogic)));
	}
}

static void serializeXmlLogic(NSFileHandle * file, XmlLogic * elem) {
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlLogic)]];
}

static void deserializeXmlLogic(NSFileHandle * file, XmlLogic ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlLogic)];
	*pelem = malloc(sizeof(XmlLogic));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlLogic));
	}
}

static void serializeXmlSounds(NSFileHandle * file, XmlSound * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlSound))]];
	for (int i=0; i < nElems; i++) {
		if (elems->filename != nil) {
			serializeXmlNSString(file, elems->filename);
		}
		elems++;
	}
}

static void deserializeXmlSounds(NSFileHandle * file, XmlSound ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlSound))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlSound));
	// Read in
	if (*pelems != NULL) {
		XmlSound * elem = *pelems;
		memcpy(elem, [data bytes], (nElems*sizeof(XmlSound)));
		for (int i=0; i < nElems; i++) {
			if (elem->filename != nil) {
				deserializeXmlNSString(file, &(elem->filename));
			}
			elem++;
		}
	}
}
	
static void serializeXmlSoundFX(NSFileHandle * file, XmlSoundFX * elem) {
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlSoundFX)]];
}

static void deserializeXmlSoundFX(NSFileHandle * file, XmlSoundFX ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlSoundFX)];
	*pelem = malloc(sizeof(XmlSoundFX));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlSoundFX));
	}
}

static void serializeXmlAnimationControl(NSFileHandle * file, XmlAnimationControl * elem) {
	[file writeData:[NSData dataWithBytes:elem length:sizeof(XmlAnimationControl)]];
}

static void deserializeXmlAnimationControl(NSFileHandle * file, XmlAnimationControl ** pelem) {
	NSData * data = [file readDataOfLength:sizeof(XmlAnimationControl)];
	*pelem = malloc(sizeof(XmlAnimationControl));
	if (*pelem) {
		memcpy(*pelem, [data bytes], sizeof(XmlAnimationControl));
	}
}

static void serializeXmlDrawingOrderElementTypes(NSFileHandle * file, XmlOrientationElementType * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(XmlOrientationElementType))]];
}

static void serializeXmlDrawingOrderElementIndices(NSFileHandle * file, UINT * elems, UINT nElems) {
	[file writeData:[NSData dataWithBytes:elems length:(nElems*sizeof(UINT))]];
}

static void deserializeXmlDrawingOrderElementTypes(NSFileHandle * file, XmlOrientationElementType ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(XmlOrientationElementType))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(XmlOrientationElementType));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(XmlOrientationElementType)));
	}
}

static void deserializeXmlDrawingOrderElementIndices(NSFileHandle * file, UINT ** pelems, UINT nElems) {
	NSData * data = [file readDataOfLength:(nElems*sizeof(UINT))];
	// Allocate memory
	*pelems = malloc(nElems*sizeof(UINT));
	// Read in
	if (*pelems != NULL) {
		memcpy(*pelems, [data bytes], (nElems*sizeof(UINT)));
	}
}

static void serializeXmlNSString(NSFileHandle * file, NSString * string) {
	NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
	// Write length
	UINT len = [data length];
	[file writeData:[NSData dataWithBytes:&len length:sizeof(UINT)]];
	[file writeData:data];
}

static void deserializeXmlNSString(NSFileHandle * file, NSString ** pstring) {
	NSData * data;
	UINT len;
	data = [file readDataOfLength:sizeof(UINT)];
	memcpy(&len, [data bytes], sizeof(UINT));
	data = [file readDataOfLength:len];
	*pstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

void setOrientationIndicesFromPointers(void) {
	if (xml == NULL) {
		return;
	}
	XmlOrientation * p = xml->orientations;
	for (int i=0; i < xml->nOrientations; i++) {
		if (p == xml->currentOrientation) {
			xml->currentOrientationIndex = i;
		}
		if (p == xml->previousOrientation) {
			xml->previousOrientationIndex = i;
		}
		p++;
	}
}	

void setOrientationPointersFromIndices(void) {
	if (xml == NULL) {
		return;
	}
	if (xml->currentOrientationIndex >= xml->nOrientations) {
		return;
	}
	if (xml->previousOrientationIndex >= xml->nOrientations) {
		return;
	}
	xml->currentOrientation = xml->orientations + xml->currentOrientationIndex;
	xml->previousOrientation = xml->orientations + xml->previousOrientationIndex;
}

#pragma mark -
#pragma mark static helper functions
static void shiftSkinToViewportOriginAndApplyZoomAndTextureZoom(void) {
	if (xml == NULL) {
		return;
	}
	XmlOrientation * myOrientation = xml->orientations;
	for (int i=0; i < xml->nOrientations; i++) {
		CGPoint origin = myOrientation->viewport.origin;
		CGFloat zoomX = myOrientation->zoomX;
        CGFloat zoomY = myOrientation->zoomY;
        //printf("=>zoomX = %f\n", zoomX);
        CGFloat textureZoomInvX = 1.0f/(myOrientation->textureZoomX);
        //printf("=>textureZoomInvX = %f\n", zoomX);
        CGFloat textureZoomInvY = 1.0f/(myOrientation->textureZoomY);
		XmlLcd * myLcd = myOrientation->lcds;
		for (int j=0; j < myOrientation->nLcds; j++) {
			CGRect * rect;
			if (myLcd->onDrawable) {
				rect = &(myLcd->onDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
			}
			if (myLcd->offDrawable) {
				rect = &(myLcd->offDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
			}			
			myLcd++;
		}
		
		XmlFace * myFace = myOrientation->faces;
		for (int j=0; j < myOrientation->nFaces; j++) {
			CGRect * rect;
			if (myFace->onDrawable) {
				rect = &(myFace->onDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
				if (myFace->onDrawable->isTextured) {
					rect = &(myFace->onDrawable->texture);
					(*rect).origin.x *= textureZoomInvX;
					(*rect).origin.y *= textureZoomInvY;
					(*rect).size.width *= textureZoomInvX;
					(*rect).size.height *= textureZoomInvY;
				}
			}
			if (myFace->offDrawable) {
				rect = &(myFace->offDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
				if (myFace->offDrawable->isTextured) {
					rect = &(myFace->offDrawable->texture);
					(*rect).origin.x *= textureZoomInvX;
					(*rect).origin.y *= textureZoomInvY;
					(*rect).size.width *= textureZoomInvX;
					(*rect).size.height *= textureZoomInvY;
				}
			}			
			myFace++;
		}
		
		XmlButton * myButton = myOrientation->buttons;
		for (int j=0; j < myOrientation->nButtons; j++) {
			CGRect * rect;
			if (myButton->onDrawable) {
				rect = &(myButton->onDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
				if (myButton->onDrawable->isTextured) {
					rect = &(myButton->onDrawable->texture);
					(*rect).origin.x *= textureZoomInvX;
					(*rect).origin.y *= textureZoomInvY;
					(*rect).size.width *= textureZoomInvX;
					(*rect).size.height *= textureZoomInvY;
				}
			}
			if (myButton->offDrawable) {
				rect = &(myButton->offDrawable->screen);
				(*rect).origin.x -= origin.x;
				(*rect).origin.y -= origin.y;
				(*rect).origin.x *= zoomX;
				(*rect).origin.y *= zoomY;
				(*rect).size.width *= zoomX;
				(*rect).size.height *= zoomY;
				if (myButton->offDrawable->isTextured) {
					rect = &(myButton->offDrawable->texture);
					(*rect).origin.x *= textureZoomInvX;
					(*rect).origin.y *= textureZoomInvY;
					(*rect).size.width *= textureZoomInvX;
					(*rect).size.height *= textureZoomInvY;
				}
			}
			rect = &(myButton->toucharea);
			(*rect).origin.x -= origin.x;
			(*rect).origin.y -= origin.y;
			(*rect).origin.x *= zoomX;
			(*rect).origin.y *= zoomY;
			(*rect).size.width *= zoomX;
			(*rect).size.height *= zoomY;
			myButton++;
		}
		
		// Save new viewport and zoom
		myOrientation->zoomX = 1.0f;
		myOrientation->zoomY = 1.0f;
		myOrientation->viewport.origin.x = 0.0f;
		myOrientation->viewport.origin.y = 0.0f;
		myOrientation->viewport.size.width = zoomX*myOrientation->viewport.size.width;
		myOrientation->viewport.size.height = zoomY*myOrientation->viewport.size.height;
		
		myOrientation++;
	}
}


BOOL checkAllFiles(XmlRoot * xmlroot) {
	NSFileManager * filemanager = [NSFileManager defaultManager];
	
	if (xmlroot == NULL) {
		return FALSE;
	}
	
	if ([filemanager fileExistsAtPath:getFullDocumentsPathForFile(xmlroot->global->romFilename)] == NO) {
		addToXmlParserLog(@"Specified ROM file not found.");
		return NO;
	}
	
	if ([filemanager fileExistsAtPath:getFullDocumentsPathForFile(xmlroot->global->patchFilename)] == NO) {
		addToXmlParserLog(@"Specified patch file not found.");
		return NO;
	}
	
	for (int i=0; i < xmlroot->global->nSounds; i++) {
		XmlSound * sound = xmlroot->global->sounds + i;
		if ([filemanager fileExistsAtPath:getFullDocumentsPathForFile(sound->filename)] == NO) {
			addToXmlParserLog(@"Specified sound file not found.");
			return NO;
		}
		if ([[sound->filename pathExtension] isEqual:@"wav"] == NO) {
			addToXmlParserLog(@"Currently only wav sound files are supported.");
			return NO;
		}
	}
	
	for (int i=0; i < xmlroot->nOrientations; i++) {
		XmlOrientation * orientation = xmlroot->orientations + i;
		if ([filemanager fileExistsAtPath:getFullDocumentsPathForFile(orientation->textureFilename)] == NO) {
			addToXmlParserLog(@"Specified texture file not found.");
			return NO;
		}
		if (orientation->textureFilename != nil) {
			if (([[[orientation->textureFilename pathExtension] lowercaseString] isEqual:@"png"] == NO) &&
				([[[orientation->textureFilename pathExtension] lowercaseString] isEqual:@"jpg"] == NO)) {
				addToXmlParserLog(@"Currently only png and jpg texture files are supported.");
				return NO;
			}
		}
	}
	
	return YES;
}


#pragma mark -
#pragma mark public functions

BOOL InitXML(NSString * filename, NSError ** error) {
	// Recreate the path of the given xml-file with regards to the documents folder.
	NSString * path = [filename stringByDeletingLastPathComponent];
	NSString * tempPath = getFullDocumentsPathForFile(@"");
	path = [path stringByReplacingOccurrencesOfString:tempPath withString:@""];
	if ([path hasPrefix:@"/"] == YES) {
		//path = [@"/" stringByAppendingString:path];
		path = [path stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
	}
	if ([path hasSuffix:@"/"] == NO) {
		path = [path stringByAppendingString:@"/"];
	}
	
	// Start the XML-Parsing
    xmlDoc *doc = NULL;
    xmlNode *root_element = NULL;
	doc = xmlParseFile([filename UTF8String]);
	if (doc == NULL ) {
		// Create an error-report and return FALSE
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EXML userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not open xml-file", NSLocalizedDescriptionKey, nil]];
		}
		return FALSE;
	}
	
	// Init the log
	initXmlParserLog();
	
	root_element = xmlDocGetRootElement(doc);
	
	if (root_element == NULL) {
		addToXmlParserLog(@"XML file is empty.");
		goto kill;
	}
	
	if (xmlStrcmp(root_element->name, (const xmlChar *) "m48SkinFile")) {
		addToXmlParserLog(@"XML file must have root element <m48SkinFile>. Make sure you do not try to open an old <m48XMLScriptingFile>.");
		goto kill;
	}
	
	if (!(root_element->children)) {
		addToXmlParserLog(@"XML file does not contain any element.");
		goto kill;
	}
	
	
	// Allocate memory
	KillXML();
	xml = malloc(sizeof(XmlRoot));
	if (!xml) {
		addToXmlParserLog(@"Error allocating memory.");
		goto kill;
	}
	initXmlRoot(xml);

	// Lets put the filenames
	xml->filename = [[filename lastPathComponent] retain];
	xml->directory =  [path retain];
	
	//printTreeToConsole(root_element, 0);
	if (!parseXmlRoot(root_element->children, xml)) {
		free(xml);
		xml = NULL;
		addToXmlParserLog(@"Error parsing XML file.");
		goto kill;
	}
	
	// Lets check the existence of all files
	if (checkAllFiles(xml) == FALSE) {
		free(xml);
		xml = NULL;
		goto kill;
	}
	
	// Use Viewport
	shiftSkinToViewportOriginAndApplyZoomAndTextureZoom();
	
	// Orientierung setzen:
	xml->currentOrientation = xml->orientations;
	xml->previousOrientation = xml->currentOrientation;
	
	PrepareAvailableOrientations();
	
	if (error != NULL) {
		*error = nil;
	}
	xmlFreeDoc(doc);
	killXmlParserLog();
	
	// Save in NSUserDefaults
	[[NSUserDefaults standardUserDefaults] setObject:xml->filename forKey:@"internalCurrentXmlFilename"];
	[[NSUserDefaults standardUserDefaults] setObject:xml->directory forKey:@"internalCurrentXmlDirectory"];
	
	return TRUE;
	
kill:
	// Create NSError-Object
	if (error != NULL) {	
		*error = [NSError errorWithDomain:ERROR_DOMAIN code:EXML userInfo:[NSDictionary dictionaryWithObjectsAndKeys:xmlParserLog, NSLocalizedDescriptionKey, nil]];
	}
	xmlFreeDoc(doc);
	killXmlParserLog();
	return FALSE;
}


void KillXML(void) {
	if (xml) {
		killXmlRoot(xml);
		free(xml);
		xml = NULL;
	}
}

// Orientation
BOOL FindProperOrientation(UIDeviceOrientation deviceOrientation, XmlOrientation ** properOrientation) {
	XmlOrientation * myOrientation;
	BOOL foundProperOrientation = NO;
	if (!xml) {
		return NO;
	}
	if (deviceOrientation == UIDeviceOrientationPortrait) {
		myOrientation = xml->orientations;
		for(int i=0; i < xml->nOrientations; i++) {
			if (myOrientation->orientationType == XmlOrientationTypePortrait) {
				foundProperOrientation = YES;
				break;
			}
			myOrientation++;
		}
		if (foundProperOrientation == NO) {
			myOrientation = xml->orientations;
			for(int i=0; i < xml->nOrientations; i++) {
				if (myOrientation->orientationType == XmlOrientationTypeVertical) {
					foundProperOrientation = YES;
					break;
				}
				myOrientation++;
			}
		}
	}
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
		myOrientation = xml->orientations;
		for(int i=0; i < xml->nOrientations; i++) {
			if (myOrientation->orientationType == XmlOrientationTypeLandscapeLeft) {
				foundProperOrientation = YES;
				break;
			}
			myOrientation++;
		}
		if (foundProperOrientation == NO) {
			myOrientation = xml->orientations;
			for(int i=0; i < xml->nOrientations; i++) {
				if (myOrientation->orientationType == XmlOrientationTypeLandscape) {
					foundProperOrientation = YES;
					break;
				}
				myOrientation++;
			}
		}
	}
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
		myOrientation = xml->orientations;
		for(int i=0; i < xml->nOrientations; i++) {
			if (myOrientation->orientationType == XmlOrientationTypeLandscapeRight) {
				foundProperOrientation = YES;
				break;
			}
			myOrientation++;
		}
		if (foundProperOrientation == NO) {
			myOrientation = xml->orientations;
			for(int i=0; i < xml->nOrientations; i++) {
				if (myOrientation->orientationType == XmlOrientationTypeLandscape) {
					foundProperOrientation = YES;
					break;
				}
				myOrientation++;
			}
		}
	}
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
		myOrientation = xml->orientations;
		for(int i=0; i < xml->nOrientations; i++) {
			if (myOrientation->orientationType == XmlOrientationTypePortraitUpsideDown) {
				foundProperOrientation = YES;
				break;
			}
		}
		if (foundProperOrientation == NO) {
			myOrientation = xml->orientations;
			for(int i=0; i < xml->nOrientations; i++) {
				if (myOrientation->orientationType == XmlOrientationTypeVertical) {
					foundProperOrientation = YES;
					break;
				}
				myOrientation++;
			}
		}
	}
	if (foundProperOrientation) {
		if (properOrientation != NULL) {
			*properOrientation = myOrientation;
		}
		return YES;
	}
	else {
		if (properOrientation != NULL) {
			*properOrientation = XmlOrientationTypeUnknown;
		}
		return NO;
	}
}

void ChangeToOrientation(XmlOrientation * newOrientation) {
	if (xml && newOrientation) {
		xml->previousOrientation = xml->currentOrientation;
		xml->currentOrientation = newOrientation;
	}
}


XmlOrientationType assignedOrientationType[4]; // order: UIDeviceOrientation

XmlOrientationType searchForXmlOrientation(XmlOrientationType orientationType, XmlOrientation ** orientation) {
	if (xml == NULL) {
		return XmlOrientationTypeUnknown;
	}
	for (int i=0; i < xml->nOrientations; i++) {
		if ((xml->orientations + i)->orientationType == orientationType) {
			if (orientation != NULL) {
				*orientation = xml->orientations + i;
			}
			return orientationType;
		}
	}
	if (orientation != NULL) {
		*orientation = NULL;
	}
	return XmlOrientationTypeUnknown;
}


void PrepareAvailableOrientations(void) {
	if (xml == NULL) {
		return;
	}
	
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	
	// Check if we are locked
	BOOL lock = FALSE;
	if ([defaults boolForKey:@"graphicsOrientationLockEnabled"]) {
		NSString * prefOrientation = [defaults objectForKey:@"graphicsOrientationPreferred"];
		assignedOrientationType[0] = XmlOrientationTypeUnknown;
		assignedOrientationType[1] = XmlOrientationTypeUnknown;
		assignedOrientationType[2] = XmlOrientationTypeUnknown;
		assignedOrientationType[3] = XmlOrientationTypeUnknown;
		if ([prefOrientation isEqual:@"portrait"] == YES) {
			assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypePortrait, NULL);
			if (assignedOrientationType[0] == XmlOrientationTypeUnknown) {
				assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
			if (assignedOrientationType[0] == XmlOrientationTypeUnknown) {
				assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypePortraitUpsideDown, NULL);
			}
			if (assignedOrientationType[0] != XmlOrientationTypeUnknown) {
				lock = TRUE;
			}
		}
		else if ([prefOrientation isEqual:@"landscapeLeft"] == YES) {
			assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscapeLeft, NULL);
			if (assignedOrientationType[1] == XmlOrientationTypeUnknown) {
				assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			if (assignedOrientationType[1] == XmlOrientationTypeUnknown) {
				assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscapeRight, NULL);
			}
			if (assignedOrientationType[1] != XmlOrientationTypeUnknown) {
				lock = TRUE;
			}
		}
		else if ([prefOrientation isEqual:@"landscapeRight"] == YES) {
			assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscapeRight, NULL);
			if (assignedOrientationType[2] == XmlOrientationTypeUnknown) {
				assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			if (assignedOrientationType[2] == XmlOrientationTypeUnknown) {
				assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscapeLeft, NULL);
			}
			if (assignedOrientationType[2] != XmlOrientationTypeUnknown) {
				lock = TRUE;
			}
		}
		else if ([prefOrientation isEqual:@"portraitUpsideDown"] == YES) {
			assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypePortraitUpsideDown, NULL);
			if (assignedOrientationType[3] == XmlOrientationTypeUnknown) {
				assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
			if (assignedOrientationType[3] == XmlOrientationTypeUnknown) {
				assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypePortrait, NULL);
			}
			if (assignedOrientationType[3] != XmlOrientationTypeUnknown) {
				lock = TRUE;
			}
		}

		
	}
	
	if (lock == NO) {
		if ([defaults boolForKey:@"internalIsIPad"] == NO) {
			// iPhone:
			// Normal mode: assign only what is available
			assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypePortrait, NULL);
			if (assignedOrientationType[0] == XmlOrientationTypeUnknown) {
				assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
			assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscapeLeft, NULL);
			if (assignedOrientationType[1] == XmlOrientationTypeUnknown) {
				assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscapeRight, NULL);
			if (assignedOrientationType[2] == XmlOrientationTypeUnknown) {
				assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypePortraitUpsideDown, NULL);
			if (assignedOrientationType[3] == XmlOrientationTypeUnknown) {
				assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
		}
		else {
			assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypePortrait, NULL);
			if (assignedOrientationType[0] == XmlOrientationTypeUnknown) {
				assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
			if (assignedOrientationType[0] == XmlOrientationTypeUnknown) {
				assignedOrientationType[0] = searchForXmlOrientation(XmlOrientationTypePortraitUpsideDown, NULL);
			}
			assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscapeLeft, NULL);
			if (assignedOrientationType[1] == XmlOrientationTypeUnknown) {
				assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			if (assignedOrientationType[1] == XmlOrientationTypeUnknown) {
				assignedOrientationType[1] = searchForXmlOrientation(XmlOrientationTypeLandscapeRight, NULL);
			}
			assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscapeRight, NULL);
			if (assignedOrientationType[2] == XmlOrientationTypeUnknown) {
				assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscape, NULL);
			}
			if (assignedOrientationType[2] == XmlOrientationTypeUnknown) {
				assignedOrientationType[2] = searchForXmlOrientation(XmlOrientationTypeLandscapeLeft, NULL);
			}
			assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypePortraitUpsideDown, NULL);
			if (assignedOrientationType[3] == XmlOrientationTypeUnknown) {
				assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypeVertical, NULL);
			}
			if (assignedOrientationType[3] == XmlOrientationTypeUnknown) {
				assignedOrientationType[3] = searchForXmlOrientation(XmlOrientationTypePortrait, NULL);
			}
		}

	}
}

BOOL IsAllowedOrientation(UIInterfaceOrientation interfaceOrientation) {
	if (xml == NULL) {
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		
        NSString * test = [defaults stringForKey:@"internalCurrentDocumentFilename"];
        if ((test != nil) && ([test length] > 0) && ([defaults boolForKey:@"graphicsOrientationLockEnabled"])) {
            return (interfaceOrientation == [defaults integerForKey:@"internalCurrentXmlUIInterfaceOrientation"]);
        }
        else {
            return YES;
        }
	}
	switch (interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			return (assignedOrientationType[0] != XmlOrientationTypeUnknown);
		case UIInterfaceOrientationLandscapeRight:
			return (assignedOrientationType[1] != XmlOrientationTypeUnknown);
		case UIInterfaceOrientationLandscapeLeft:
			return (assignedOrientationType[2] != XmlOrientationTypeUnknown);
		case UIInterfaceOrientationPortraitUpsideDown:
			return (assignedOrientationType[3] != XmlOrientationTypeUnknown);
		default:
			return NO;
	}
}

void SetOrientation(UIInterfaceOrientation interfaceOrientation) {
	if (xml == NULL) {
		return;
	}
	XmlOrientation * newOrientation;
	switch (interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			searchForXmlOrientation(assignedOrientationType[0], &newOrientation);
			break;
		case UIInterfaceOrientationLandscapeRight:
			searchForXmlOrientation(assignedOrientationType[1], &newOrientation);
			break;
		case UIInterfaceOrientationLandscapeLeft:
			searchForXmlOrientation(assignedOrientationType[2], &newOrientation);
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			searchForXmlOrientation(assignedOrientationType[3], &newOrientation);
			break;
		default:
			newOrientation = NULL;
			break;
	}	
	if (newOrientation != NULL) {
		xml->previousOrientation = xml->currentOrientation;
		xml->currentOrientation = newOrientation;
	}
}


// Funktionen um die Buttons zu setzen
void ReloadButtons(BYTE *Keyboard_Row, UINT nSize)
{
	XmlOrientation * tempOrientation = xml->orientations;
	for (int i=0; i < xml->nOrientations; i++) {
		XmlButton * tempButton = tempOrientation->buttons;
		for (int j=0; j < tempOrientation->nButtons; j++) {  // scan all buttons
			if ((tempButton->type == XmlButtonTypeNormal) && (tempButton->nOut < nSize))  // valid out code
			{
				// get state of button from keyboard matrix
				tempButton->bDown = ((Keyboard_Row[tempButton->nOut] & tempButton->nIn) != 0);
			}
			tempButton++;
		}
		tempOrientation++;
	}
}

// Animation
void resetAnimation(XmlAnimationControl * animationControl, BOOL isInverse, BOOL isArmed) {
	animationControl->currentfadeinval = animationControl->fadeinval;
	animationControl->currentholdonval = animationControl->holdonval;
	animationControl->currentfadeoutval = animationControl->fadeoutval;
	animationControl->currentholdoffval = animationControl->holdoffval;
	animationControl->previousPredicate = NO;
	if (!isInverse)
		animationControl->currentAlpha = 0.0f;
	else
		animationControl->currentAlpha = 1.0f;
	if (isArmed)
		animationControl->state = XmlAnimationControlStateReady;
	else
		animationControl->state = XmlAnimationControlStateIdle;
	return;
}
	
/* Version I */
inline BOOL calcAnimation(XmlAnimationControl * animationControl, BOOL predicate, BOOL isInverse) {
	float x1, x2;
	animationControl->previousPredicate = predicate;
	if (!(animationControl->state == XmlAnimationControlStateAnimating)) {
		if (animationControl->state == XmlAnimationControlStateReady) {
			if ((animationControl->holdoffval == 0) && (animationControl->fadeinval == 0)) {
				animationControl->currentAlpha = 1.0f - animationControl->currentAlpha;
				animationControl->state = XmlAnimationControlStateAnimating;
			}
			else if (predicate || animationControl->noGate) {
				animationControl->state = XmlAnimationControlStateAnimating;
			}
		}
		else if (predicate && animationControl->repeats) {
			if ((animationControl->holdoffval == 0) && (animationControl->fadeinval == 0))
				animationControl->currentAlpha = 1.0f - animationControl->currentAlpha;
			animationControl->state = XmlAnimationControlStateAnimating;
		}
	}
	if (animationControl->state == XmlAnimationControlStateAnimating) {
		if (predicate || animationControl->noGate) {
			if (animationControl->currentholdoffval > 0) {
				(animationControl->currentholdoffval)--;
				if (!isInverse)
					animationControl->currentAlpha = 0.0f;
				else
					animationControl->currentAlpha = 1.0f;
				if ((animationControl->currentholdoffval == 0) && (animationControl->currentfadeinval == 0)) {
					animationControl->currentAlpha = 1.0f - animationControl->currentAlpha;
				}	
			}
			else if (animationControl->currentfadeinval > 0) {
				(animationControl->currentfadeinval)--;
				x1 = animationControl->fadeinval;
				x2 = animationControl->currentfadeinval;
				if (!isInverse)
					animationControl->currentAlpha = 1.0f - x2/x1;
				else
					animationControl->currentAlpha = x2/x1;
			}
			else if (animationControl->currentholdonval > 0) {
				(animationControl->currentholdonval)--;
			}
			else if ((animationControl->repeats) || (animationControl->noGate)) {
				if (animationControl->currentfadeoutval > 0) {
					(animationControl->currentfadeoutval)--;
					x1 = animationControl->fadeoutval;
					x2 = animationControl->currentfadeoutval;
					if (!isInverse)
						animationControl->currentAlpha = x2/x1;
					else
						animationControl->currentAlpha = 1 - x2/x1;	
				}
				else if (animationControl->repeats) {
					resetAnimation(animationControl, isInverse, YES);
				}
				else {
					resetAnimation(animationControl, isInverse, NO);
				}
			}
			
		}
		else {
			if (animationControl->repeats) {
				// Reset immediatly
				resetAnimation(animationControl, isInverse, NO);
			}
			else if (animationControl->currentholdoffval == 0) {
				// Overcame holdoffphase
				if (animationControl->currentfadeinval > 0) {
					// Fadein war noch angefangen -> alpha halten
					// Calculate appropriate fadeoutval
					if (!isInverse)
						animationControl->currentfadeoutval = round((animationControl->fadeoutval)*(animationControl->currentAlpha));
					else
						animationControl->currentfadeoutval = round((animationControl->fadeoutval)*(1.0f - animationControl->currentAlpha));				
					animationControl->currentfadeinval = 0;
				}
				else if (animationControl->currentholdonval > 0) {
					(animationControl->currentholdonval)--;
				}
				else if (animationControl->currentfadeoutval > 0) {
					(animationControl->currentfadeoutval)--;
					x1 = animationControl->fadeoutval;
					x2 = animationControl->currentfadeoutval;
					if (!isInverse)
						animationControl->currentAlpha = x2/x1;
					else
						animationControl->currentAlpha = 1 - x2/x1;
				}
				else {
					resetAnimation(animationControl, isInverse, NO);
				}
			}
			else {
				resetAnimation(animationControl, isInverse, NO);
			}
		}
	}
	if (animationControl->currentAlpha > 0.0f) 
		return YES;
	else
		return NO;
}

/* Version II
 inline BOOL calcAnimation(XmlAnimationControl * animationControl, BOOL predicate, BOOL isInverse) {
 float x1, x2;
 
 if (animationControl->repeats) {
 if (predicate) {
 animationControl->state = XmlAnimationControlStateAnimating;
 // Normal repeat workflow
 if (animationControl->currentfadeinval > 0) {
 (animationControl->currentfadeinval)--;
 x1 = animationControl->fadeinval;
 x2 = animationControl->currentfadeinval;
 if (!isInverse)
 animationControl->currentAlpha = 1.0f - x2/x1;
 else
 animationControl->currentAlpha = x2/x1;
 }
 else if (animationControl->currentholdonval > 0) {
 (animationControl->currentholdonval)--;
 }
 else if (animationControl->currentfadeoutval > 0) {
 (animationControl->currentfadeoutval)--;
 x1 = animationControl->fadeoutval;
 x2 = animationControl->currentfadeoutval;
 if (!isInverse)
 animationControl->currentAlpha = x2/x1;
 else
 animationControl->currentAlpha = 1 - x2/x1;	
 }
 else if (animationControl->currentholdoffval > 0) {
 (animationControl->currentholdoffval)--;
 }
 else {
 resetAnimation(animationControl, isInverse, YES);
 }
 }
 else {
 // Reset immediatly
 resetAnimation(animationControl, isInverse, NO);
 }
 }
 else {
 if (predicate && (animationControl->state == XmlAnimationControlStateReady)) {
 if (!(animationControl->fadeinval))
 animationControl->currentAlpha = 1.0f - animationControl->currentAlpha;
 // Start animation
 animationControl->state = XmlAnimationControlStateAnimating;
 }
 if (animationControl->state == XmlAnimationControlStateAnimating) {
 if (predicate || animationControl->noGate) {
 if (animationControl->currentfadeinval > 0) {
 (animationControl->currentfadeinval)--;
 x1 = animationControl->fadeinval;
 x2 = animationControl->currentfadeinval;
 if (!isInverse)
 animationControl->currentAlpha = 1.0f - x2/x1;
 else
 animationControl->currentAlpha = x2/x1;
 }
 else if (animationControl->currentholdonval > 0) {
 (animationControl->currentholdonval)--;
 }
 else if (animationControl->noGate) {
 if (animationControl->currentfadeoutval > 0) {
 (animationControl->currentfadeoutval)--;
 x1 = animationControl->fadeoutval;
 x2 = animationControl->currentfadeoutval;
 if (!isInverse)
 animationControl->currentAlpha = x2/x1;
 else
 animationControl->currentAlpha = 1 - x2/x1;	
 }
 else if (animationControl->currentholdoffval > 0) {
 (animationControl->currentholdoffval)--;
 }
 else {
 animationControl->state = XmlAnimationControlStateIdle;
 }
 }
 
 }
 else {
 // Fadein war noch angefangen -> alpha halten
 if (animationControl->currentfadeinval > 0) {
 // Calculate appropriate fadeoutval
 if (!isInverse)
 animationControl->currentfadeoutval = round((animationControl->fadeoutval)*(animationControl->currentAlpha));
 else
 animationControl->currentfadeoutval = round((animationControl->fadeoutval)*(1.0f - animationControl->currentAlpha));				
 animationControl->currentfadeinval = 0;
 }
 else if (animationControl->currentholdonval > 0) {
 (animationControl->currentholdonval)--;
 }
 else if (animationControl->currentfadeoutval > 0) {
 (animationControl->currentfadeoutval)--;
 x1 = animationControl->fadeoutval;
 x2 = animationControl->currentfadeoutval;
 if (!isInverse)
 animationControl->currentAlpha = x2/x1;
 else
 animationControl->currentAlpha = 1 - x2/x1;
 }
 else if (animationControl->currentholdoffval > 0) {
 (animationControl->currentholdoffval)--;
 }
 else {
 animationControl->state = XmlAnimationControlStateIdle;
 }
 }
 }
 }
 if (animationControl->currentAlpha > 0.0f) 
 return YES;
 else
 return NO;
 }
 */

BOOL PeekXML(NSString * filename, NSString ** title) {
	NSString * tempString = nil;
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	
	NSFileHandle * fileHandle = [NSFileHandle fileHandleForReadingAtPath:filename];
	if (fileHandle == nil) goto kill;
	
	NSData * someData = [fileHandle readDataOfLength:2000];
	//[fileHandle closeFile];
	if (someData == nil) goto kill;
	
	tempString = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];

	if (someData == nil) goto kill;
	
	
	// Search for the keywords
	NSRange openTag;
	NSRange closeTag;
	NSRange targetRange;
	
	// <title>;
	openTag = [tempString rangeOfString:@"<title>"];
	if (openTag.location == NSNotFound) goto kill;
	closeTag = [tempString rangeOfString:@"</title>"];
	if (closeTag.location == NSNotFound) goto kill;
	
	targetRange.location = openTag.location + openTag.length;
	targetRange.length = closeTag.location - targetRange.location;
	*title = [tempString substringWithRange:targetRange];
	
	
	if (xml != NULL) {
	
		// <hardware>;
		openTag = [tempString rangeOfString:@"<hardware>"];
		if (openTag.location == NSNotFound) goto kill;
		closeTag = [tempString rangeOfString:@"</hardware>"];
		if (closeTag.location == NSNotFound) goto kill;
		
		targetRange.location = openTag.location + openTag.length;
		targetRange.length = closeTag.location - targetRange.location;
		NSString * hardware = [tempString substringWithRange:targetRange];
		
		
		if(![xml->global->hardware isEqual:hardware]) goto kill;
		
		// <model>;
		openTag = [tempString rangeOfString:@"<model>"];
		if (openTag.location == NSNotFound) goto kill;
		closeTag = [tempString rangeOfString:@"</model>"];
		if (closeTag.location == NSNotFound) goto kill;
		
		targetRange.location = openTag.location + openTag.length;
		targetRange.length = closeTag.location - targetRange.location;
		NSString * model = [tempString substringWithRange:targetRange];	
		const char * modelchar = [model UTF8String];
		
		if (*modelchar != xml->global->model) goto kill;
	}
	
	// <requiressgx />;
	openTag = [tempString rangeOfString:@"<requiressgx />"];
	closeTag = [tempString rangeOfString:@"<requiressgx/>"];
	if ((openTag.location != NSNotFound) || (closeTag.location != NSNotFound)) {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"internalIsSGXHW"] == NO) {
			goto kill;
		}
	}
	
	[*title retain];
	[tempString release];
	[pool release];
	return TRUE;
	
kill:
	*title = nil;
	[tempString release];
	[pool release];
	return FALSE;
}

BOOL TryGetXmlCacheFile(void) {
	NSString * filename = getFullDocumentsPathForFile(@".cached_skin");
	if ([[NSFileManager defaultManager] fileExistsAtPath:filename] == NO) {
		return NO;
	}
	NSFileHandle * file = [NSFileHandle fileHandleForReadingAtPath:filename];
	if (file == nil) {
		return NO;
	}
	KillXML();
	deserializeXmlRoot(file, &xml);
	[file closeFile];

	PrepareAvailableOrientations();
	return YES;
}

BOOL DeleteXmlCacheFile(void) {
	NSString * filename = getFullDocumentsPathForFile(@".cached_skin");
	NSFileManager * filemanager = [NSFileManager defaultManager];
	if ([filemanager fileExistsAtPath:filename] == NO) {
		return NO;
	}
	if (![filemanager removeItemAtPath:filename error:NULL]) {
		return NO;
	}
	return YES;
}

BOOL WriteXmlCacheFile(void) {
	NSString * filename = getFullDocumentsPathForFile(@".cached_skin");
	NSFileManager * filemanager = [NSFileManager defaultManager];
	if ([filemanager fileExistsAtPath:filename] == YES) {
		if (![filemanager removeItemAtPath:filename error:NULL]) {
			return NO;
		}
	}
	if (![filemanager createFileAtPath:filename contents:nil attributes:0]) {
		return NO;
	}
	NSFileHandle * file = [NSFileHandle fileHandleForWritingAtPath:filename];
	if (file == nil) {
		return NO;
	}
	
	serializeXmlRoot(file, xml);
	[file closeFile];
	return YES;
}


