#ifdef __has_feature(objc_arc)
#error Apply -fobjc-no-arc to hotobjc.m
#endif

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>

// hotobjc wrapper executable
// Licensed under the WTFPL: http://sam.zoy.org/wtfpl/

typedef (int)(*hot_main_t)(int, char**, char**, char**);

@interface HotLoader : NSObject

// dlopen handle
@property (assign) void* handle;

// A list of classes which were there _before_ we loaded anything in
@property (retain) NSSet* baseClasses;

+ (NSSet*)allClasses;

- (void)start;
- (void)startBackground;
- (void)reload:(BOOL)isInitial;
- (void)swizzle;
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr;

@end

@implementation HotLoader

@synthesize handle;
@synthesize baseClasses;

+ (NSSet*)allClasses {
    const size_t n = 75000;
    Class* classes = calloc(sizeof(Class), n);
    if (!classes)
        hot_raise(@"Not enough space to allocate class list.");
    
    @try {
        const size_t m = objc_getClassList(classes, n);
        if (n > m)
            hot_raise(@"The user has too many classes and should perhaps be shot.");
        
        return [NSSet setWithObjects:classes count:m];
    }
    @finally {
        free(classes);
    }
}

- (void)start {
    [NSThread detachNewThreadSelector:@selector(startBackground) toTarget:self withObject:nil];
}
- (void)startBackground {
    
    
    
}
- (void)reload:(BOOL)isInitial {
    
    void *existingHandle = handle;
    
    handle = dlopen([[self targetPath] UTF8String], RTLD_LOCAL);
    if (!isInitial)
        [self swizzle];
    
    if (existingHandle) {
        dlclose(existingHandle);
        existingHandle = NULL;
    }
}
- (void)swizzle {
    
    for (NSString* classname in [[self class] allClasses]) {
        
    }
}
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr {
    void* sym = dlsym(handle, [name UTF8String]);
    if (sym)
        return sym;
    
    if (errstr) {
        char c_errstr = dlerror();
        *errstr = c_errstr ? [NSString stringWithUTF8String:dlerror()] : [NSString stringWithFormat:@"Unknown error resolving symbol '%@'", name];
    }
    return nil;
}

@end

int main(int argc, char** argv, char** envp, char** apple) {
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [NSRunLoop currentRunLoop];
    
    HotLoader* loader = [[HotLoader alloc] init];
    loader.baseClasses = [HotLoader allClasses];
    
    // Perform an initial load of the .app
    [loader reload:YES];
    
    // Create and run hotobjc's thread
    [loader start];
    
    // Get the main function from the loaded dylib and run it
    hot_main_t existing_main = (hot_main_t)[loader symbolNamed:@"main" error:NULL];
    int status = existing_main(argc, argv, envp, apple);
    
    [pool drain];
    return status;
}
