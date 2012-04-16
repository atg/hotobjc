#ifdef __has_feature(objc_arc)
#error Apply -fobjc-no-arc to hotobjc.m
#endif

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>

// hotobjc wrapper executable
// Licensed under the WTFPL: http://sam.zoy.org/wtfpl/

typedef (int)(*hot_main_t)(int, char**, char**, char**);


#include <sys/stat.h>
static inline NSTimeInterval HLTimespecToTimeInterval(struct timespec ts) {
    return (ts.tv_sec - NSTimeIntervalSince1970) + (ts.tv_nsec / 1000000000);
}
static NSDate* HLModificationDate(NSString* path) {
    
    struct stat s;
    int statworked = [self fileSystemRepresentation] ? lstat([self fileSystemRepresentation], &s) : -1;
    if (statworked == 0) {
        
        double fileTimestampDoubleStat = CHTimespecToTimeInterval(s.st_mtimespec);
        return [NSDate dateWithTimeIntervalSinceReferenceDate:fileTimestampDoubleStat];
    }
    return nil;
}

static void hot_raise(NSString* err) {
    [NSException raise:@"hotobjc exception" format:err];
}

@interface HotLoader : NSObject

// dlopen handle
@property (assign) void* handle;

// A list of classes which were there _before_ we loaded anything in
@property (retain) NSSet* baseClasses;

+ (NSSet*)allClasses;
+ (NSSet*)allMethodsForClass:(Class)cl;

- (void)start;
- (void)startBackground;
- (void)reload:(BOOL)isInitial;
- (void)swizzle;
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr;

@end

@implementation HotLoader

@synthesize handle;
@synthesize baseClasses;

static BOOL hot_classIsOfKind(Class cl, Class other) {
    Class superclass = cl;
    while (superclass) {
        if (superclass == other)
            return YES;
        superclass = class_getSuperclass(superclass);
    }
    return NO;
}

+ (NSSet*)allClasses {
    int n = objc_getClassList(NULL, 0);
    Class* classes = calloc(sizeof(Class), n);
    if (!classes)
        hot_raise(@"Not enough space to allocate class list.");
    
    int m = objc_getClassList(classes, n);
    
    NSMutableSet* classNames = [NSMutableSet set];
    for (int i = 0; i < m; i++) {
        
        if (!hot_classIsOfKind(classes[i], [NSObject class]))
            continue;
        
        [classNames addObject:NSStringFromClass(classes[i])];
    }
    
    free(classes);
    return classNames;
}
+ (void)enumerateMethodsForClass:(Class)cl with:(void(^)(Method))f {
    unsigned n = 0;
    Method* methods = class_copyMethodList(classes, &n);
    
    for (unsigned i = 0; i < n; i++) {
        f(methods[i]);
    }
    
    free(methods);
}

+ (NSSet*)allMethodsForClass:(Class)cl {
    
    NSMutableSet* methodNames = [NSMutableSet set];
    
    [self enumerateMethodsForClass:cl with:^(Method meth) {
        SEL sel = method_getName(meth);
        if (!sel)
            continue;
        
        [methodNames addObject:NSStringFromSelector(sel)];
    }];
    
    return methodNames;        
}

- (NSString*)targetPath {
    // TODO: get the path to the real app
}
- (void)start {
    [NSThread detachNewThreadSelector:@selector(startBackground) toTarget:self withObject:nil];
}
- (void)startBackground {
    
    NSTimeInterval lastChangeDate = [NSDate timeIntervalSinceReferenceDate];
    while (1) {
        
        NSTimeInterval newChangeDate = [HLModificationDate([self targetPath]) timeIntervalSinceReferenceDate];
        if (fabs(newChangeDate - lastChangeDate) > 0.001) {
            // ...
            
            [self reload:NO];
        }
        
        sleep(1);
    }
}
- (void)reload:(BOOL)isInitial {
    
    void *existingHandle = handle;
    
    handle = dlopen([[self targetPath] UTF8String], isInitial ? RTLD_GLOBAL : RTLD_LOCAL);
    if (!isInitial)
        [self swizzle];
    
    if (existingHandle) {
        dlclose(existingHandle);
        existingHandle = NULL;
    }
}
- (void)swizzle {
    
    NSSet* classes = [[[[self class] allClasses] mutableCopy] minusSet:baseClasses];
    
    for (NSString* classname in classes) {
        Class cl = NSClassFromString(classname);
        [self enumerateMethodsForClass:cl with:^(Method meth) {
            SEL sel = method_getName(meth);
            if (!sel)
                continue;
            
            NSString* methodname = NSStringFromSelector(sel);
            
            IMP imp = (IMP)[self symbolNamed:[NSString stringWithFormat:@"_%@__%@", classname, methodname] errorString:NULL];
            method_setImplementation(meth, imp);
        }];
    }
}
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr {
    void* sym = dlsym(handle, [name UTF8String]);
    if (sym)
        return sym;
    
    if (errstr) {
        char* c_errstr = dlerror();
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
    hot_main_t existing_main = (hot_main_t)[loader symbolNamed:@"_main" error:NULL];
    int status = existing_main(argc, argv, envp, apple);
    
    [pool drain];
    return status;
}
