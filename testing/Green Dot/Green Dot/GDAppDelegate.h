//
//  GDAppDelegate.h
//  Green Dot
//
//  Created by Alex Gordon on 16/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GDAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@end

@interface GDDotView : NSView

- (void)redraw;

@end