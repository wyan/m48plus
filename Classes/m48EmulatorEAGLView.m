/*
 *  m48EmulatorEAGLView.m
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

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "m48EmulatorEAGLView.h"
#import "m48EmulatorAudioEngine.h"

#import "patchwince.h"
#import "patchwinpch.h"
#import "emu48.h"
#import "xml.h"
#import "io.h"

#import "m48Errors.h"

extern LARGE_INTEGER lLcdRef;

// A class extension to declare private methods
@interface m48EmulatorEAGLView ()

@property (nonatomic, retain) EAGLContext * context;
@property (nonatomic, assign) NSTimer *animationTimer;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

@end


@implementation m48EmulatorEAGLView

@synthesize context = _context;
@synthesize animationTimer = _animationTimer;
@synthesize animationInterval = _animationInterval;
@synthesize textureImage = _textureImage;

// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


//Init the GL view:
- (id)initWithFrame:(CGRect)aRect {	
    
    if ((self = [super initWithFrame:aRect])) {
		// Read the settings
		[self loadSettings];
		
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		// iPhone 4 compatibility
		float viewScale = 0.0;
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			viewScale = [[UIScreen mainScreen] scale];
		}
		if (viewScale == 0.0) viewScale = 1;
		if ([self respondsToSelector:@selector(setContentScaleFactor:)] == YES) {
			self.contentScaleFactor = viewScale;
		}
		
        NSString * tempString = [[UIDevice currentDevice] systemVersion];
        if ([tempString characterAtIndex:0] != '5') {
            _sharpInterpolationMethod = YES;
        }
        else {
            if (cCurrentRomType=='Q') {
                _sharpInterpolationMethod = NO;
            }
            else {
                _sharpInterpolationMethod = YES;
            }
        }
        
        
        _lcdBufferHeight = 128;
        
        if(!_context || ![EAGLContext setCurrentContext:_context] || ![self createFramebuffer]) {
            [self release];
            return nil;
        }
        // Check the max texture size and store it in defaults (some skins can only loaded with sgx hardware
		glGetIntegerv(GL_MAX_TEXTURE_SIZE, &_maxTextureSize);
		if (_maxTextureSize > 1024) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"internalIsSGXHW"];
		}
		else {
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"internalIsSGXHW"];
		}
		
		
		_texture = 0;
		_lcdTexture = 0;
        
		lcdTextureBuffer1 = malloc(_lcdBufferHeight*256*4);
		lcdTextureBuffer2 = malloc(_lcdBufferHeight*256*4);
		lcdTextureBuffer = lcdTextureBuffer1;
		timesNewTextureBufferDiffers = 1000;
		
		
        
		holdDelayStartVal = 2;
		
		
		[self setMultipleTouchEnabled:YES];
    }
    return self;
}


// [self setupView hinzugefügt]
- (void)layoutSubviews {
	//static int i = 0; // Trying to do this anyway, as some people experiece problems under iOS 5.1.1 with black screen. Does it come here from?
	//if ((++i) == 2) return; // Second time at startup this is not necessary and we can save some time
	
	//DEBUG NSLog(@"EAGL: Start layout subviews");
    [EAGLContext setCurrentContext:_context];
    [self destroyFramebuffer];
	//NSLog(@"EAGL: Create framebuffer");
    [self createFramebuffer];
	//DEBUG NSLog(@"EAGL: Setup views");
	[self setupView];
	//DEBUG NSLog(@"EAGL: Draw one view");
    //[self drawView];
	
	//DEBUG NSLog(@"EAGL: Set statusbar");
	
	UIApplication * application = [UIApplication sharedApplication];
	if (xml->currentOrientation->hasStatusBar) {
		[application setStatusBarStyle:xml->currentOrientation->statusBarStyle animated:YES];
		[application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
	}
	else {
		[application setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
	}
	
	//DEBUG NSLog(@"EAGL: End layout subviews");
}

- (void)loadSettings {
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	bStaticsFilterEnabled = [defaults boolForKey:@"graphicsStaticsFilterEnabled"];
	NSString * temp = [defaults objectForKey:@"graphicsZoom"];
	if ([temp isEqual:@"best"]) {
		_zoomSetting = m48EmulatorEAGLViewZoomBest;
	}
	else if ([temp isEqual:@"fullscreen"]) {
		_zoomSetting = m48EmulatorEAGLViewZoomFullscreen;
	}
	else if ([temp isEqual:@"1x"]) {
		_zoomSetting = m48EmulatorEAGLViewZoomSingle;
	}
	else if ([temp isEqual:@"2x"]) {
		_zoomSetting = m48EmulatorEAGLViewZoomDouble;
	}
	else if ([temp isEqual:@"fullstretch"]) {
		_zoomSetting = m48EmulatorEAGLViewZoomFullscreenStretch;
	}
	else {
		_zoomSetting = m48EmulatorEAGLViewZoomNone;
	}
}

- (BOOL)loadTextureImage:(NSString *)filename error:(NSError **)error {
	if (filename != nil) {
		self.textureImage = [UIImage imageWithContentsOfFile:getFullDocumentsPathForFile(filename)];
	}
	else {
		self.textureImage = nil;
		return YES;
	}
	if (_textureImage == nil) {
		if (error != NULL) {
			*error = [NSError errorWithDomain:ERROR_DOMAIN code:EFIO userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not load file.", NSLocalizedDescriptionKey, nil]];
		}
		return NO;
	}
	return YES;	
}

- (void)updateContrast {
	UpdateContrast(Chipset.contrast);
}

- (CGPoint)zoomPoint:(CGPoint)point {
	// Translates a given point from the coordinates in _src
	CGPoint trg;
	trg.x = (point.x - _srcViewport.origin.x)*_magnificationX + _trgViewport.origin.x;
	trg.y = (point.y - _srcViewport.origin.y)*_magnificationY + _trgViewport.origin.y;
	return trg;
}

- (CGPoint)reverseZoomPoint:(CGPoint)point {
	// Translates a given point from the coordinates in _src
	CGPoint trg;
	trg.x = (point.x - _trgViewport.origin.x)/_magnificationX + _srcViewport.origin.x;
	trg.y = (point.y - _trgViewport.origin.y)/_magnificationY + _srcViewport.origin.y;
	return trg;
}

- (BOOL)createFramebuffer {
    //NSLog(@"EAGL: Create Framebuffers");    
	// Determine Open GL capabilities
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &_maxTextureSize);
	glGetIntegerv(GL_MAX_TEXTURE_UNITS, &_maxTextureUnits);
	
    glGenFramebuffersOES(1, &_viewFramebuffer);
    glGenRenderbuffersOES(1, &_viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, _viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &_viewWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &_viewHeight);
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        //DEBUG NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    // Sets up matrices and transforms for OpenGL ES
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    // Set the model view matrix
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
	
    glGenFramebuffersOES(1, &_lcdLargeFramebuffer);
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, _lcdLargeFramebuffer);
	
	glGenTextures(1, &_lcdLargeTexturebuffer);
	glBindTexture(GL_TEXTURE_2D, _lcdLargeTexturebuffer);
	
	// Determine size for _lcdLargeTexturebuffer dependent on the current viewport (assuming we need to magnify no more
	_lcdLargeTexturebufferMagnification = 1;
	if (xml != NULL) {
		while (((xml->currentOrientation->viewport.size.width)/(131.0*_lcdLargeTexturebufferMagnification) > 1.0) &&
			   (_lcdLargeTexturebufferMagnification < _maxTextureSize/256)) {
			_lcdLargeTexturebufferMagnification *= 2;
		}
	}
    
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256*_lcdLargeTexturebufferMagnification, _lcdBufferHeight*_lcdLargeTexturebufferMagnification, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, _lcdLargeTexturebuffer, 0);
	GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
	if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
		//DEBUG NSLog(@"failed to make complete framebuffer object %x", status);
		return NO;
	}
	
	
	// Adding zoom support: additional layers have to be used
	// Determine the src and trg viewport
	_usesViewportBuffer = NO;
	_usesViewportMagBuffer = NO;
	
	if (xml && xml->currentOrientation) {
		_srcViewport = xml->currentOrientation->viewport;
	
		// Determine the target Viewport
		if (_zoomSetting == m48EmulatorEAGLViewZoomSingle) {
			// Just center the src viewport
			_magnificationX = 1;
            _magnificationY = _magnificationX;
			_trgViewport.size = _srcViewport.size;
			_trgViewport.origin.x = (_viewWidth-_trgViewport.size.width)/2;
			_trgViewport.origin.y = (_viewHeight-_trgViewport.size.height)/2;
		}
		else if (_zoomSetting == m48EmulatorEAGLViewZoomDouble) {
			// Just center the src viewport
			_magnificationX = 2;
            _magnificationY = _magnificationX;
			_trgViewport.size.width = _magnificationX*_srcViewport.size.width;
			_trgViewport.size.height = _magnificationY*_srcViewport.size.height;
			_trgViewport.origin.x = (_viewWidth-_trgViewport.size.width)/2;
			_trgViewport.origin.y = (_viewHeight-_trgViewport.size.height)/2;
		}
		else if (_zoomSetting == m48EmulatorEAGLViewZoomFullscreen) {
			// Just center the src viewport
			CGFloat maxX = fabsf(_viewWidth/_srcViewport.size.width);
			CGFloat maxY = fabsf(_viewHeight/_srcViewport.size.height);
			_magnificationX = (maxX < maxY)?maxX:maxY;
            _magnificationY = _magnificationX;
			_trgViewport.size.width = _magnificationX*_srcViewport.size.width;
			_trgViewport.size.height = _magnificationY*_srcViewport.size.height;
			_trgViewport.origin.x = (_viewWidth-_trgViewport.size.width)/2;
			_trgViewport.origin.y = (_viewHeight-_trgViewport.size.height)/2;
		}
		else if (_zoomSetting == m48EmulatorEAGLViewZoomFullscreenStretch) {
			// Just center the src viewport
			CGFloat maxX = fabsf(_viewWidth/_srcViewport.size.width);
			CGFloat maxY = fabsf(_viewHeight/_srcViewport.size.height);
			_magnificationX = maxX;
            _magnificationY = maxY;
			_trgViewport.size.width = _magnificationX*_srcViewport.size.width;
			_trgViewport.size.height = _magnificationY*_srcViewport.size.height;
			_trgViewport.origin.x = (_viewWidth-_trgViewport.size.width)/2;
			_trgViewport.origin.y = (_viewHeight-_trgViewport.size.height)/2;
		}
		else if (_zoomSetting == m48EmulatorEAGLViewZoomBest) {
			// Snaps magnification to 0.5, 1 or 2
			// Just center the src viewport
			CGFloat maxX = fabsf(_viewWidth/_srcViewport.size.width);
			CGFloat maxY = fabsf(_viewHeight/_srcViewport.size.height);
			_magnificationX = (maxX < maxY)?maxX:maxY;
			
			if ((_magnificationX >= 1.0) && (_magnificationX < 2.0)) {
				_magnificationX = 1.0;
			}
			else if ((_magnificationX >= 2.0) && (_magnificationX < 3.0)) {
				_magnificationX = 2.0;
			}
			/*
			else if ((_magnificationX >= 0.5) && (_magnificationX < 1.0)) {
				_magnificationX = 0.5;
			}
			 */
			// for all other cases we leave it to fullscreen.
            _magnificationY = _magnificationX;
			_trgViewport.size.width = _magnificationX*_srcViewport.size.width;
			_trgViewport.size.height = _magnificationY*_srcViewport.size.height;
			_trgViewport.origin.x = (_viewWidth-_trgViewport.size.width)/2;
			_trgViewport.origin.y = (_viewHeight-_trgViewport.size.height)/2;
		}
		else {
			_magnificationX = 1;
            _magnificationY = _magnificationX;
			_trgViewport = _srcViewport;
		}
		
		//_magnification = 1.0;
		// We now know how much we need to magnify and can implement the additional framebuffers	
		if (_maxTextureUnits >= 4) {
            //_magnification = 1.0;
            
			if ((_magnificationX > 1.0) || (_magnificationY > 1.0)) {
				_usesViewportBuffer = YES;
				
				// Generate the viewport texturBuffer
				glGenFramebuffersOES(1, &_viewportFramebuffer);
				glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewportFramebuffer);
				
				glGenTextures(1, &_viewportTexturebuffer);
				glBindTexture(GL_TEXTURE_2D, _viewportTexturebuffer);
				// Texture size must be powers of 2
				_viewportWidth = exp2(ceil(log2(_srcViewport.size.width)));
				_viewportHeight = exp2(ceil(log2(_srcViewport.size.height)));
                if (_viewportWidth > _viewportHeight) {
                    _viewportHeight = _viewportWidth;
                }
                else {
                    _viewportWidth = _viewportHeight;
                }
                if (_viewportHeight > _maxTextureSize) {
                    _viewportHeight = _maxTextureSize;
                    _viewportWidth = _maxTextureSize;
                }
				
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _viewportWidth, _viewportHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
				glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, _viewportTexturebuffer, 0);
				GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) ;
				if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
					//DEBUG NSLog(@"failed to make complete framebuffer object %x", status);
					return NO;
				}
				
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
				
				glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                glEnable(GL_BLEND);
			}
			
			if ((fabs(round(_magnificationX) - _magnificationX) > 0.0) || (fabs(round(_magnificationY) - _magnificationY) > 0.0)) {
				_usesViewportMagBuffer = YES;
		
				// Generate the magnification buffer;
				glGenFramebuffersOES(1, &_viewportMagFramebuffer);
				glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewportMagFramebuffer);
				glGenTextures(1, &_viewportMagTexturebuffer);
				glBindTexture(GL_TEXTURE_2D, _viewportMagTexturebuffer);
                if (ceil(_magnificationX) > ceil(_magnificationY)) {
                    _viewportMagWidth = exp2(ceil(log2(ceil(_magnificationX)*_srcViewport.size.width)));
                    _viewportMagHeight = exp2(ceil(log2(ceil(_magnificationX)*_srcViewport.size.height)));
                }
                else {
                    _viewportMagWidth = exp2(ceil(log2(ceil(_magnificationY)*_srcViewport.size.width)));
                    _viewportMagHeight = exp2(ceil(log2(ceil(_magnificationY)*_srcViewport.size.height)));
                }
                if (_viewportMagWidth > _viewportMagHeight) {
                    _viewportMagHeight = _viewportMagWidth;
                }
                else {
                    _viewportMagWidth = _viewportMagHeight;
                }
                if (_viewportMagHeight > _maxTextureSize) {
                    _viewportMagHeight = _maxTextureSize;
                    _viewportMagWidth = _maxTextureSize;
                }
                _viewportMagHeight = _maxTextureSize;
                _viewportMagWidth = _maxTextureSize;
                
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _viewportMagWidth, _viewportMagHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
				glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, _viewportMagTexturebuffer, 0);
				GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) ;
				if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
					//DEBUG NSLog(@"failed to make complete framebuffer object %x", status);
					return NO;
				}
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
				
				glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
                glEnable(GL_BLEND);
			}
            
		}
		 
	}
    
    return YES;
}

// Diese Methode entstammt der SDK und keine Veränderungen wurden gemacht
- (void)destroyFramebuffer {
    glDeleteFramebuffersOES(1, &_viewFramebuffer);
    _viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &_viewRenderbuffer);
    _viewRenderbuffer = 0;
	
	glDeleteTextures(1, &_lcdLargeFramebuffer);
	glDeleteFramebuffersOES(1,&_lcdLargeFramebuffer);
	_lcdLargeFramebuffer = 0;
	// muss der Speicher des color-buffers freigegeben werden? wie wird das bei einer texture gemacht?
	
	if (_usesViewportBuffer) {
		glDeleteTextures(1, &_viewportTexturebuffer);
		glDeleteFramebuffersOES(1,&_viewportFramebuffer);
		_viewportFramebuffer = 0;
    }
	
	if (_usesViewportMagBuffer) {
		glDeleteTextures(1, &_viewportMagTexturebuffer);
		glDeleteFramebuffersOES(1,&_viewportMagFramebuffer);
		_viewportMagFramebuffer = 0;
	}
}

- (void)setupView
{
	CGImageRef multiSkinTexImage;
	CGContextRef multiSkinTexImageContext;
	GLubyte *multiSkinTexImageData;
	
	XmlOrientation * myOrientation = xml->currentOrientation;
	[self loadSettings];
	
	
	BOOL textureFileChanged = (xml->previousOrientation != NULL) && ([myOrientation->textureFilename isEqual:xml->previousOrientation->textureFilename] == NO);
	if ((_textureImage == nil) || textureFileChanged) {
		[self loadTextureImage:myOrientation->textureFilename error:NULL];
	}
	
	multiSkinTexImage = [_textureImage CGImage];
	
	if(multiSkinTexImage) {
		// Get the width and height of the image
		_textureWidth = CGImageGetWidth(multiSkinTexImage);
		_textureHeight = CGImageGetHeight(multiSkinTexImage);
		
		// Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
		// you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.

		// Allocated memory needed for the bitmap context
		multiSkinTexImageData = (GLubyte *) malloc(_textureWidth * _textureHeight * 4);
		// Uses the bitmatp creation function provided by the Core Graphics framework. 
		multiSkinTexImageContext = CGBitmapContextCreate(multiSkinTexImageData, _textureWidth, _textureHeight, 8, _textureWidth * 4, CGImageGetColorSpace(multiSkinTexImage), kCGImageAlphaPremultipliedLast);//kCGImageAlphaPremultipliedLast
		// After you create the context, you can draw the sprite image to the context.
		//CGContextScaleCTM(multiSkinTexImageContext, 1.0f, 1.0f);
        CGRect myRect = CGRectMake(0.0, 0.0, (CGFloat)_textureWidth, (CGFloat)_textureHeight);
        CGContextClearRect(multiSkinTexImageContext, myRect);
        CGContextDrawImage(multiSkinTexImageContext,myRect, multiSkinTexImage);

		// You don't need the context at this point, so you need to release it to avoid memory leaks.
		CGContextRelease(multiSkinTexImageContext);

		// Use OpenGL ES to generate a name for the texture.
		glDeleteTextures(1, &_texture);
		_texture = 0;
		glGenTextures(1, &_texture);
        printf("\ntexture=%d\n", _texture);
		// Bind the texture name. 
		glBindTexture(GL_TEXTURE_2D, _texture);
		// Speidfy a 2D texture image, provideing the a pointer to the image data in memory
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _textureWidth, _textureHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, multiSkinTexImageData);
		
		// Release the image data
		free(multiSkinTexImageData);		
		
		// Set the texture parameters to use a minifying filter and a linear filer (weighted average)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}
	
	_sharpInterpolationMethod = (xml->global->lcdInterpolationMethod == XmlLcdInterpolationMethodSharp);
	/* Variante C Using a texture */	
	// Use OpenGL ES to generate a name for the texture.
	glDeleteTextures(1, &_lcdTexture);
	_lcdTexture = 0;
	glGenTextures(1, &_lcdTexture);
	// Bind the texture name. 
	glBindTexture(GL_TEXTURE_2D, _lcdTexture);
	// Specify a 2D texture image, provideing the a pointer to the image data in memory
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, _lcdBufferHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, lcdTextureBuffer);
	// Set the texture parameters to use a minifying filter and a linear filter (weighted average)
	if ((!_sharpInterpolationMethod) && (xml->global->lcdInterpolationEnabled)) {
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}
	else {
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	// Setup the _lcdLargeFramebuffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, _lcdLargeFramebuffer);
	glBindTexture(GL_TEXTURE_2D, _lcdLargeTexturebuffer);
	if (xml->global->lcdInterpolationEnabled) {
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}
	else {
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

static GLfloat textureCoords[8];
static GLfloat screenCoords[8];

static void inline drawDrawable(XmlDrawable * myDrawable) {
	static GLfloat myAlpha;
	static CGRect myRect;
	static XmlColor myCol;

	if (myDrawable->isTextured) {
		myRect = myDrawable->texture;
		// Orientation
		if (myDrawable->textureOrientation == XmlOrientationTypePortrait) {
			textureCoords[0] = myRect.origin.x; // 0.0f*320.0f/1024.0f;
			textureCoords[1] = myRect.origin.y; //1.0f*480.0f/1024.0f;
			textureCoords[2] = textureCoords[0]; //0.0f*320.0f/1024.0f;
			textureCoords[3] = myRect.origin.y + myRect.size.height; //0.0f*480.0f/1024.0f;
			textureCoords[4] = myRect.origin.x + myRect.size.width; //1.0f*320.0f/1024.0f;
			textureCoords[5] = textureCoords[3]; //0.0f*480.0f/1024.0f;
			textureCoords[6] = textureCoords[4]; //1.0f*320.0f/1024.0f;
			textureCoords[7] = textureCoords[1]; //1.0f*480.0f/1024.0f;	
		}
		else if (myDrawable->textureOrientation == XmlOrientationTypeLandscapeLeft) {
			textureCoords[0] = myRect.origin.x + myRect.size.width;
			textureCoords[1] = myRect.origin.y;
			textureCoords[2] = myRect.origin.x;
			textureCoords[3] = textureCoords[1];
			textureCoords[4] = textureCoords[2]; 
			textureCoords[5] = myRect.origin.y + myRect.size.height; 
			textureCoords[6] = textureCoords[0];
			textureCoords[7] = textureCoords[5]; 
		}
		else if (myDrawable->textureOrientation == XmlOrientationTypeLandscapeRight) {
			textureCoords[0] = myRect.origin.x;
			textureCoords[1] = myRect.origin.y + myRect.size.height;
			textureCoords[2] = myRect.origin.x + myRect.size.width;
			textureCoords[3] = textureCoords[1];
			textureCoords[4] = textureCoords[2];
			textureCoords[5] = myRect.origin.y;
			textureCoords[6] = textureCoords[0];
			textureCoords[7] = textureCoords[5];
		}
		else if (myDrawable->textureOrientation == XmlOrientationTypePortraitUpsideDown) {
			textureCoords[0] = myRect.origin.x + myRect.size.width;
			textureCoords[1] = myRect.origin.y + myRect.size.height;
			textureCoords[2] = textureCoords[0];
			textureCoords[3] = myRect.origin.y;
			textureCoords[4] = myRect.origin.x;
			textureCoords[5] = textureCoords[3];
			textureCoords[6] = textureCoords[4];
			textureCoords[7] = textureCoords[1];
		}
		glEnable(GL_TEXTURE_2D);
		glTexCoordPointer(2, GL_FLOAT, 0, textureCoords);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	}
	else {
		glDisable(GL_TEXTURE_2D);
	}
		
	myRect = myDrawable->screen;
	screenCoords[0] = myRect.origin.x; //0.0f;
	screenCoords[1] = myRect.origin.y; //0.0f;
	screenCoords[2] = screenCoords[0]; //0.0f;
	screenCoords[3] = myRect.origin.y + myRect.size.height; //1.0f;
	screenCoords[4] = myRect.origin.x + myRect.size.width; //1.0f;
	screenCoords[5] = screenCoords[3]; //1.0f;
	screenCoords[6] = screenCoords[4]; //1.0f;
	screenCoords[7] = screenCoords[1]; //0.0f;	
		
	myCol = myDrawable->color;
	if (myDrawable->animationControl) {
		myAlpha = myDrawable->animationControl->currentAlpha;
		glColor4f(myAlpha*myCol.red, myAlpha*myCol.green, myAlpha*myCol.blue, myAlpha*myCol.alpha);
	}
	else {
		glColor4f(myCol.red, myCol.green, myCol.blue, myCol.alpha);
	}
		
	glVertexPointer(2, GL_FLOAT, 0, screenCoords);
	glEnableClientState(GL_VERTEX_ARRAY);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	
	return;
}	

- (void)drawView {
	// Watch always if we even need to fraw something;
	static int holdDelay = 0;
	static BOOL animationInProgress = YES;
	static DWORD prevLogicVec = 0;
	DWORD curLogicVec = xml->logicStateVec;
	if ((animationInProgress == NO) && (Chipset.Shutdn == YES) && (contentChanged == NO)) {
		if (holdDelay == 0) {
			holdDelay = 0;
			return;
		}
		else {
			holdDelay--;
		}
	}
	else {
		contentChanged = NO;
		animationInProgress = NO;
		holdDelay = holdDelayStartVal + holdDelayStartVal;
	}
	
    // DRAW A FRAME
    [EAGLContext setCurrentContext:_context];
	
	XmlFace * myFaces = xml->currentOrientation->faces;
	static XmlFace * myFace;
	static XmlColor myCol;
	static BOOL needToBeDrawn, needToBeDrawn2;
	static XmlLogic * myLogic;
	XmlLcd * myLcds = xml->currentOrientation->lcds;
	static XmlLcd * myLcd;
	XmlButton * myButtons = xml->currentOrientation->buttons;
	static XmlButton * myButton;
	static XmlDrawable * myDrawable;
	
	// Update display
	// if (_lcdLargeTexturebuffer != NULL)  //if ( (Chipset.IORam[BITOFFSET] & DON) != 0) { // Inzwischen wird der Kontrast auf 0 gesetzt
	// Auslesen des Emulators
	if ( (Chipset.IORam[BITOFFSET] & DON) != 0) {
		UpdateDisplay();					// update display
		QueryPerformanceCounter(&lLcdRef);
	}
	/* Variante D Using a texture */
	glBindTexture(GL_TEXTURE_2D, _lcdTexture);
	// Erzeugtes Bild in OpenGL übersetzen
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, _lcdBufferHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, lcdTextureBuffer);
	
	if (_sharpInterpolationMethod) {
		screenCoords[0] = -1.0f;
		screenCoords[1] = -1.0f;
		screenCoords[2] = -1.0f;
		screenCoords[3] =  1.0f;
		screenCoords[4] =  1.0f;
		screenCoords[5] =  1.0f;
		screenCoords[6] =  1.0f;
		screenCoords[7] = -1.0f;	
		
		textureCoords[0] = 0.0f;
		textureCoords[1] = 0.0f;
		textureCoords[2] = 0.0f;
		textureCoords[3] = 1.0f;
		textureCoords[4] = 1.0f;
		textureCoords[5] = 1.0f;
		textureCoords[6] = 1.0f;
		textureCoords[7] = 0.0f;
		
		
		// Enable lcd framebuffer and draw texture
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, _lcdLargeFramebuffer);
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		//glViewport(0, 0, 256*_lcdLargeTexturebufferMagnification, SCREENHEIGHT*_lcdLargeTexturebufferMagnification);
		//glMatrixMode(GL_MODELVIEW);
		//glLoadIdentity();
		
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, _lcdLargeFramebuffer);
		glViewport(0, 0, 256*_lcdLargeTexturebufferMagnification, _lcdBufferHeight*_lcdLargeTexturebufferMagnification);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glMatrixMode(GL_TEXTURE);
		glLoadIdentity();
		
		glVertexPointer(2, GL_FLOAT, 0, screenCoords);
		glEnableClientState(GL_VERTEX_ARRAY);
		glTexCoordPointer(2, GL_FLOAT, 0, textureCoords);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glEnable(GL_TEXTURE_2D);
		glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}
	
	glBindTexture(GL_TEXTURE_2D, _texture);
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glScalef(1.0f/_textureWidth, 1.0f/_textureHeight, 1.0f);
	
	// Main picture
	if (_usesViewportBuffer) {
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewportFramebuffer);
		glViewport(0, 0, _viewportWidth, _viewportHeight);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrthof(0.0f, _viewportWidth, _viewportHeight, 0.0f, -1.0f, 1.0f);	
	}
	else {
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
		glViewport(0, 0, _viewWidth, _viewHeight);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrthof(0.0f, _viewWidth, _viewHeight, 0.0f, -1.0f, 1.0f);
		// This is only the case if no additional texture units are available and the zoom of the skin has to be performed like this. 
		// Will only occur for _magnification < 1 on iPhone and for very weird skins.
		if (_zoomSetting != m48EmulatorEAGLViewZoomNone) {
			// Center picture:
			glTranslatef((_viewWidth - _trgViewport.size.width)/2, (_viewHeight - _trgViewport.size.height)/2, 0.0f);
			glScalef(_magnificationX, _magnificationY, 1.0f);
		}
	}
	

	
	// Clear color buffer
	myCol = xml->currentOrientation->backgroundColor;
    glClearColor(myCol.red, myCol.green, myCol.blue, myCol.alpha);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Alle Elemente in der richtigen Reihenfolge zeichnen
	UINT							nDrawingOrder = xml->currentOrientation->nDrawingOrder;
	XmlOrientationElementType *		drawingOrderElementTypes = xml->currentOrientation->drawingOrderElementTypes;
	UINT *							drawingOrderElementIndices = xml->currentOrientation->drawingOrderElementIndices;
	for (int i=0; i < nDrawingOrder; i++) {
		if ( *drawingOrderElementTypes == XmlOrientationElementTypeButton) {
			myButton = (myButtons + *drawingOrderElementIndices);
			// annunciatorlogik!!!!
			if (myButton->logics) {
				needToBeDrawn = NO;
				myLogic = myButton->logics;
				for (int j = 0; j < myButton->nLogics; j++) {
					if (  myLogic->logicVec == ((curLogicVec) &  ~myLogic->dontCareVec) ) {
						needToBeDrawn = YES;
						break;
					}
					myLogic = myLogic + 1;
				}
			}
			else {
				needToBeDrawn = YES;
			}
			
			// Off-drawable
			myDrawable = myButton->offDrawable;
			if (needToBeDrawn && myDrawable) {
				if (myDrawable->animationControl) {
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, myButton->bDown, YES);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = !(myButton->bDown);
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}
			
			// On Drawable
			myDrawable = myButton->onDrawable;
			if (needToBeDrawn && myDrawable) {
				if (myDrawable->animationControl) {
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, myButton->bDown, NO);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = myButton->bDown;
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}
			
				
		}
		else if ( *drawingOrderElementTypes == XmlOrientationElementTypeFace) {
			myFace = (myFaces + *drawingOrderElementIndices);
			// Annunciatorlogik!!!!
			if (myFace->logics) {
				needToBeDrawn = NO;
				myLogic = myFace->logics;
				for (int j = 0; j < myFace->nLogics; j++) {
					if (  myLogic->logicVec == ((curLogicVec) &  ~myLogic->dontCareVec) ) {
						needToBeDrawn = YES;
						break;
					}
					myLogic = myLogic + 1;
				}
				if (myFace->soundfx) {
					// Eval previous logicVec
					needToBeDrawn2 = NO;
					myLogic = myFace->logics;
					for (int j = 0; j < myFace->nLogics; j++) {
						if (  myLogic->logicVec == ((prevLogicVec) &  ~myLogic->dontCareVec) ) {
							// True detected
							needToBeDrawn2 = YES;
							break;
						}
						myLogic = myLogic + 1;
					}
					if (needToBeDrawn2 != needToBeDrawn) {
						playXmlSoundFX(myFace->soundfx, needToBeDrawn);
					}
				}
			}
			else {
				needToBeDrawn = YES;
			}
			// Off-drawable
			myDrawable = myFace->offDrawable;
			if (myDrawable) {
				if (myDrawable->animationControl) {
					if (needToBeDrawn && !(myDrawable->animationControl->previousPredicate)) {
						resetAnimation(myDrawable->animationControl, NO, YES);
					}
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, needToBeDrawn, YES);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = !(needToBeDrawn);
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}
			
			// On Drawable
			myDrawable = myFace->onDrawable;
			if (myDrawable) {
				if (myDrawable->animationControl) {
					if (needToBeDrawn && !(myDrawable->animationControl->previousPredicate)) {
							resetAnimation(myDrawable->animationControl, NO, YES);
					}
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, needToBeDrawn, NO);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = needToBeDrawn;
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}	
						
		}
		else if ( *drawingOrderElementTypes == XmlOrientationElementTypeLcd) {
			/* Variante C Using a texture */
			if (_sharpInterpolationMethod) {
				glBindTexture(GL_TEXTURE_2D, _lcdLargeTexturebuffer);
			} else {
				glBindTexture(GL_TEXTURE_2D, _lcdTexture);
			}
			glMatrixMode(GL_TEXTURE);
			glLoadIdentity();
			glScalef(1.0f/256.0f, 1.0f/_lcdBufferHeight, 1.0f);
			
			myLcd = (myLcds + *drawingOrderElementIndices);
			// annunciatorlogik!!!!
			if (myLcd->logics) {
				needToBeDrawn = NO;
				myLogic = myLcd->logics;
				for (int j = 0; j < myLcd->nLogics; j++) {
					if (  myLogic->logicVec == ((curLogicVec) &  ~myLogic->dontCareVec) ) {
						needToBeDrawn = YES;
						break;
					}
					myLogic = myLogic + 1;
				}
			}
			else {
				needToBeDrawn = YES;
			}
			
			// Off-drawable
			myDrawable = myLcd->offDrawable;
			if (needToBeDrawn && myDrawable) {
				if (myDrawable->animationControl) {
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, ((Chipset.IORam[BITOFFSET] & DON) != 0), YES);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = !((Chipset.IORam[BITOFFSET] & DON) != 0);
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}
			
			// On Drawable
			myDrawable = myLcd->onDrawable;
			if (needToBeDrawn && myDrawable) {
				if (myDrawable->animationControl) {
					needToBeDrawn2 = calcAnimation(myDrawable->animationControl, ((Chipset.IORam[BITOFFSET] & DON) != 0), NO);
					animationInProgress |= (myDrawable->animationControl->state != XmlAnimationControlStateIdle);
				}
				else {
					needToBeDrawn2 = ((Chipset.IORam[BITOFFSET] & DON) != 0);
				}
				if (needToBeDrawn2) {
					drawDrawable(myDrawable);
				}
			}
			
			glBindTexture(GL_TEXTURE_2D, _texture);
			glMatrixMode(GL_TEXTURE);
			glLoadIdentity();
			glScalef(1.0f/_textureWidth, 1.0f/_textureHeight, 1.0f);
		}
		
		drawingOrderElementTypes++;
		drawingOrderElementIndices++;
	}
	
	// Store the ucrrent logicVec
	prevLogicVec = curLogicVec;
	
	
	// Post processing for magnification
	if (_usesViewportBuffer) {
		if (_usesViewportMagBuffer == NO) {
			// Must be some integer ratio of magnification and we can just paint directly to the main area
			glBindTexture(GL_TEXTURE_2D, _viewportTexturebuffer);
			glMatrixMode(GL_TEXTURE);
			glLoadIdentity();
			glScalef(1.0f/_viewportWidth, 1.0f/_viewportHeight, 1.0f);			
			
			glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
			glViewport(0, 0, _viewWidth, _viewHeight);
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glOrthof(0.0f, _viewWidth, 0.0f, _viewHeight, -1.0f, 1.0f);		
			
			textureCoords[0] = 0.0f;
			textureCoords[1] = _viewportHeight - _srcViewport.size.height;
			textureCoords[2] = 0.0f;
			textureCoords[3] = _viewportHeight;
			textureCoords[4] = _srcViewport.size.width;
			textureCoords[5] = _viewportHeight;
			textureCoords[6] = textureCoords[4];
			textureCoords[7] = textureCoords[1];

			screenCoords[0] = _trgViewport.origin.x; //0.0f;
			screenCoords[1] = _trgViewport.origin.y; //0.0f;
			screenCoords[2] = screenCoords[0]; //0.0f;
			screenCoords[3] = _trgViewport.origin.y + _trgViewport.size.height; //1.0f;
			screenCoords[4] = _trgViewport.origin.x + _trgViewport.size.width; //1.0f;
			screenCoords[5] = screenCoords[3]; //1.0f;
			screenCoords[6] = screenCoords[4]; //1.0f;
			screenCoords[7] = screenCoords[1]; //0.0f;	
			
			// Clear color buffer
			myCol = xml->currentOrientation->backgroundColor;
            
            glClearColor(myCol.red, myCol.green, myCol.blue, myCol.alpha);
			
            glClear(GL_COLOR_BUFFER_BIT);
			glVertexPointer(2, GL_FLOAT, 0, screenCoords);
			glEnableClientState(GL_VERTEX_ARRAY);
			glTexCoordPointer(2, GL_FLOAT, 0, textureCoords);
			glEnableClientState(GL_TEXTURE_COORD_ARRAY);
			glEnable(GL_TEXTURE_2D);
			glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
			glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
		}
		else {
			// This is the most complicated case - requires two times drawing
			glBindTexture(GL_TEXTURE_2D, _viewportTexturebuffer);
			glMatrixMode(GL_TEXTURE);
			glLoadIdentity();
			glScalef(1.0f/_viewportWidth, 1.0f/_viewportHeight, 1.0f);			
			
			glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewportMagFramebuffer);
			glViewport(0, 0, _viewportMagWidth, _viewportMagHeight);
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glOrthof(0.0f, _viewportMagWidth, 0.0f, _viewportMagHeight, -1.0f, 1.0f);		
			
			textureCoords[0] = 0.0f;
			textureCoords[1] = _viewportHeight - _srcViewport.size.height;
			textureCoords[2] = 0.0f;
			textureCoords[3] = _viewportHeight;
			textureCoords[4] = _srcViewport.size.width;
			textureCoords[5] = _viewportHeight;
			textureCoords[6] = textureCoords[4];
			textureCoords[7] = textureCoords[1];
			
			screenCoords[0] = 0.0f;
			screenCoords[1] = 0.0f;
			screenCoords[2] = screenCoords[0]; //0.0f;
			screenCoords[3] = ceil(_magnificationX)*_srcViewport.size.height;
            screenCoords[4] = ceil(_magnificationY)*_srcViewport.size.width;
			screenCoords[5] = screenCoords[3]; //1.0f;
			screenCoords[6] = screenCoords[4]; //1.0f;
			screenCoords[7] = screenCoords[1]; //0.0f;	
			
			// Clear color buffer
			myCol = xml->currentOrientation->backgroundColor;
            glClearColor(myCol.red, myCol.green, myCol.blue, myCol.alpha);
			glClear(GL_COLOR_BUFFER_BIT);
			glVertexPointer(2, GL_FLOAT, 0, screenCoords);
			glEnableClientState(GL_VERTEX_ARRAY);
			glTexCoordPointer(2, GL_FLOAT, 0, textureCoords);
			glEnableClientState(GL_TEXTURE_COORD_ARRAY);
			glEnable(GL_TEXTURE_2D);
			glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
			glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
			
			// Second step: draw to the actual screen:
			glBindTexture(GL_TEXTURE_2D, _viewportMagTexturebuffer);
			glMatrixMode(GL_TEXTURE);
			glLoadIdentity();
			glScalef(1.0f/_viewportMagWidth, 1.0f/_viewportMagHeight, 1.0f);			
			
			glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
			glViewport(0, 0, _viewWidth, _viewHeight);
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glOrthof(0.0f, _viewWidth, 0.0f, _viewHeight, -1.0f, 1.0f);		
			
			
			textureCoords[0] = _trgViewport.origin.x; //0.0f;
			textureCoords[1] = _trgViewport.origin.y; //0.0f;
			textureCoords[2] = textureCoords[0]; //0.0f;
			textureCoords[3] = _trgViewport.origin.y + _trgViewport.size.height; //1.0f;
			textureCoords[4] = _trgViewport.origin.x + _trgViewport.size.width; //1.0f;
			textureCoords[5] = textureCoords[3]; //1.0f;
			textureCoords[6] = textureCoords[4]; //1.0f;
			textureCoords[7] = textureCoords[1]; //0.0f;	
			
			// Clear color buffer
            glClearColor(myCol.red, myCol.green, myCol.blue, myCol.alpha);
			glClear(GL_COLOR_BUFFER_BIT);
			glVertexPointer(2, GL_FLOAT, 0, textureCoords); // Exchanged!
			glEnableClientState(GL_VERTEX_ARRAY);
			glTexCoordPointer(2, GL_FLOAT, 0, screenCoords); // Exchanged!
			glEnableClientState(GL_TEXTURE_COORD_ARRAY);
			glEnable(GL_TEXTURE_2D);
			glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
			glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
		}
		
	}
	
	// This is not to be modified
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER_OES];
	// Make sure that you are drawing to the current context
	[EAGLContext setCurrentContext:_context];
}

- (void)startAnimation {
	if (xml)
		_animationInterval = 1.0f/(xml->global->framerate);
	else
		_animationInterval = 1.0f/24;

	// Affects static filter and delay for drawing enginge -> set 100ms
	holdDelayStartVal = 0.15f/_animationInterval;
	self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:_animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation {
	self.animationTimer = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer {
	if ((_animationTimer != nil) && [_animationTimer isValid]) {
		[_animationTimer invalidate];
	}
	[newTimer retain];
	[_animationTimer release];
    _animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
    _animationInterval = interval;
    if (_animationTimer) {
        [self stopAnimation];
        [self startAnimation];
    }
}

- (void)dealloc {
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    if (lcdTextureBuffer1 != NULL) {
        free(lcdTextureBuffer1);
        lcdTextureBuffer1 = NULL;
    }
    if (lcdTextureBuffer2 != NULL) {
        free(lcdTextureBuffer2);
        lcdTextureBuffer2 = NULL;
    }
	
	[self destroyFramebuffer];
	[_textureImage release];
    [_context release];  
    [super dealloc];
}

#pragma mark -
#pragma mark Screenhot
-(UIImage *) makeScreenshot {
    NSInteger myDataLength = _viewWidth * _viewHeight * 4;
    GLubyte swapBuffer;
	// allocate array and read pixels into it.
    GLubyte *buffer = (GLubyte *) malloc(myDataLength);
	glReadPixels(0, 0, _viewWidth, _viewHeight, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    for(int y = 0; y < (_viewHeight/2); y++)
    {
        for(int x = 0; x <_viewWidth * 4; x++)
        {
			swapBuffer = buffer[y*_viewWidth*4 + x];
			buffer[y*_viewWidth*4 + x] = buffer[(_viewHeight-1-y)*_viewWidth*4 + x];
			buffer[(_viewHeight-1-y)*_viewWidth*4 + x] = swapBuffer;
        }  
    }
    // make data provider with data.
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, myDataLength, NULL);
    // prep the ingredients
    int bitsPerComponent = 8;
    int bitsPerPixel = 32;
    int bytesPerRow = 4 * _viewWidth;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
	
    // make the cgimage
    CGImageRef imageRef = CGImageCreate(_viewWidth, _viewHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
	CFRelease(colorSpaceRef);
	CGDataProviderRelease(provider);
	
    // then make the uiimage from that
    UIImage *myImage = [UIImage imageWithCGImage:imageRef];
	NSData * data = UIImagePNGRepresentation(myImage);	
	CFRelease(imageRef);
	free(buffer);
	
    return [UIImage imageWithData:data];
}

@end

