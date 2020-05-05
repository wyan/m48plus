/*
 *  m48EmulatorEAGLView.h
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
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

typedef enum _m48EmulatorEAGLViewZoom {
	m48EmulatorEAGLViewZoomNone,
	m48EmulatorEAGLViewZoomBest,
	m48EmulatorEAGLViewZoomSingle,
	m48EmulatorEAGLViewZoomDouble,
	m48EmulatorEAGLViewZoomFullscreen,
    m48EmulatorEAGLViewZoomFullscreenStretch
} m48EmulatorEAGLViewZoom;

/*
 This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
 The view content is basically an EAGL surface you render your OpenGL scene into.
 Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
 */
@interface m48EmulatorEAGLView : UIView {
    
@private
    /* The pixel dimensions of the backbuffer */
    GLint _viewWidth;
    GLint _viewHeight;
    
    EAGLContext * _context;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint _viewRenderbuffer, _viewFramebuffer;
    
    NSTimer * _animationTimer;
    NSTimeInterval _animationInterval;
	
	UIImage * _textureImage;
	
	/* OpenGL name for the sprite texture */
	GLint _textureWidth;
	GLint _textureHeight;
	GLuint _texture;
	
	/* Variante C Using a texture */
	GLuint _lcdTexture;
	/* Variante C: Rescaling */
    GLuint _lcdLargeTexturebuffer, _lcdLargeFramebuffer;
	GLuint _lcdLargeTexturebufferMagnification;
	
	/* Additional framebuffers for skin rescale */
	GLuint _viewportTexturebuffer, _viewportFramebuffer;
	GLint _viewportWidth, _viewportHeight;
	BOOL _usesViewportBuffer;
	GLuint _viewportMagTexturebuffer, _viewportMagFramebuffer;
	GLint _viewportMagWidth, _viewportMagHeight;
	BOOL _usesViewportMagBuffer;
	
	BOOL _sharpInterpolationMethod;
	m48EmulatorEAGLViewZoom _zoomSetting;
	CGRect _srcViewport;
	CGRect _trgViewport;
	CGFloat _magnificationX;
	CGFloat _magnificationY;
    
	GLuint _lcdBufferHeight;
	
	// Device capabilities
	GLint _maxTextureSize;
	GLint _maxTextureUnits;
}

@property (nonatomic, assign) NSTimeInterval animationInterval;
@property (nonatomic, retain) UIImage * textureImage;

- (void)loadSettings;

- (void)startAnimation;
- (void)stopAnimation;
- (BOOL)loadTextureImage:(NSString *)filename error:(NSError **)error;
- (void)drawView;
- (void)setupView;
- (void)updateContrast;

- (CGPoint)zoomPoint:(CGPoint)point;
- (CGPoint)reverseZoomPoint:(CGPoint)point;

-(UIImage *) makeScreenshot;


@end
