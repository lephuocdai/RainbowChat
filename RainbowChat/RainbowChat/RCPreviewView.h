//
//  RCPreviewView.h
//  RainbowChat
//
//  Created by レー フックダイ on 5/20/14.
//  Copyright (c) 2014 lephuocdai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>

@interface RCPreviewView : UIView {
    int renderBufferWidth;
	int renderBufferHeight;
    
	CVOpenGLESTextureCacheRef videoTextureCache;
    
	EAGLContext* oglContext;
	GLuint frameBufferHandle;
	GLuint colorBufferHandle;
    GLuint passThroughProgram;
}

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer;

@end
