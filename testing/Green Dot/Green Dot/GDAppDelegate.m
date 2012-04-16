//
//  GDAppDelegate.m
//  Green Dot
//
//  Created by Alex Gordon on 16/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GDAppDelegate.h"

@implementation GDAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

@end

@implementation GDDotView

- (void)awakeFromNib {
    [self redraw];
}
- (void)redraw {
    [self setNeedsDisplay:YES];
    [self performSelector:@selector(redraw) withObject:nil afterDelay:0.5];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSLog(@"Redrawing");
    [[NSColor greenColor] set]; // [[NSColor redColor] set];
    
    NSRect r = [self bounds];
    r.size.width = 0.75 * MIN([self bounds].size.width, [self bounds].size.height);
    r.size.height = r.size.width;
    r.origin.x = ([self bounds].size.width - r.size.width) / 2.0;
    r.origin.y = ([self bounds].size.height - r.size.height) / 2.0;
    [[NSBezierPath bezierPathWithOvalInRect:r] fill];
}

@end