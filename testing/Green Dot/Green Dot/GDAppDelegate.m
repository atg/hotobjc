#import "GDAppDelegate.h"

@implementation GDAppDelegate
@synthesize window = _window;
- (void)dealloc {
    [super dealloc];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}
@end


@implementation GDDotView

- (void)awakeFromNib {
//    [self redraw];
    [self setNeedsDisplay:YES];
    [self performSelector:@selector(awakeFromNib) withObject:nil afterDelay:0.5];
}
- (void)printBoo {
    NSLog(@"BOO!");
}

- (void)drawRect:(NSRect)dirtyRect {
    
    NSLog(@"Redrawing");
    SEL colorsel = NSSelectorFromString(@"redColor");
    
    [(NSColor*)[NSColor performSelector:colorsel] set];
    NSRect r = [self bounds];
    r.size.width = 1.0 * MIN([self bounds].size.width, [self bounds].size.height);
    r.size.height = r.size.width;
    r.origin.x = ([self bounds].size.width - r.size.width) / 2.0;
    r.origin.y = ([self bounds].size.height - r.size.height) / 2.0;
    [[NSBezierPath bezierPathWithOvalInRect:r] fill];
}

@end