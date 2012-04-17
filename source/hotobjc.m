#if __has_feature(objc_arc)
#error Apply -fobjc-no-arc to hotobjc.m
#endif

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <mach-o/nlist.h>

// hotobjc wrapper executable
// Licensed under the WTFPL: http://sam.zoy.org/wtfpl/

typedef int (*hot_main_t)(int, char**, char**, char**);


#include <sys/stat.h>
static inline NSTimeInterval HLTimespecToTimeInterval(struct timespec ts) {
    return (ts.tv_sec - NSTimeIntervalSince1970) + (ts.tv_nsec / 1000000000);
}
static NSDate* HLModificationDate(NSString* path) {
    
    struct stat s;
    int statworked = [path fileSystemRepresentation] ? lstat([path fileSystemRepresentation], &s) : -1;
    if (statworked == 0) {
        
        double fileTimestampDoubleStat = HLTimespecToTimeInterval(s.st_mtimespec);
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

@property (retain) NSDictionary* nmtable;

// A list of classes which were there _before_ we loaded anything in
@property (retain) NSSet* baseClasses;

+ (NSSet*)allClasses;
+ (NSSet*)allMethodsForClass:(Class)cl;

- (NSString*)targetBundle;
- (NSString*)targetPath;

- (void)start;
- (void)startBackground;
- (void)reload:(BOOL)isInitial;
- (void)swizzle;
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr;

+ (void)enumerateMethodsForClass:(Class)cl with:(void(^)(Method))f;

@end

@implementation HotLoader

@synthesize handle;
@synthesize nmtable;
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
    Method* methods = class_copyMethodList(cl, &n);
    
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
            return;
        
        [methodNames addObject:NSStringFromSelector(sel)];
    }];
    
    return methodNames;        
}

- (NSString*)targetBundle {
    return [[[[self targetPath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
}
- (NSString*)targetPath {
    static NSString* targetPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        targetPath = [[[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:HOTLOADER_APP_PATH] stringByStandardizingPath];
    });
    return targetPath;
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
            lastChangeDate = newChangeDate;
        }
        
        sleep(1);
    }
}
- (void)copyResources {
    // Make a backup of ourself
    NSString* me = [[NSBundle mainBundle] executablePath];
    NSString* me_backup = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"hotloader_%d", random()]];
    
    NSLog(@"1. Copy\n- %@\n- %@", me, me_backup);
    [[NSFileManager defaultManager] removeItemAtPath:me_backup error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:me toPath:me_backup error:NULL];
    
    NSFileManager* fm = [[NSFileManager alloc] init];
    [fm setDelegate:self];
    
    NSString* targetcontents = [[self targetBundle] stringByAppendingPathComponent:@"Contents"];
    NSString* mycontents = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"];
    NSLog(@"2. Remove\n- %@", mycontents);
    [fm removeItemAtPath:mycontents error:NULL];
    NSLog(@"3. Copy\n- %@\n- %@", targetcontents, mycontents);
    [fm copyItemAtPath:targetcontents toPath:mycontents error:NULL];
    
    NSLog(@"4. Copy\n- %@\n- %@", me_backup, me);
    [[NSFileManager defaultManager] removeItemAtPath:me error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:me_backup toPath:me error:NULL];
}
- (void)reload:(BOOL)isInitial {
    
    if (isInitial)
        [self copyResources];
    
//    void *existingHandle = handle;
    NSLog(@"[self targetBundle] = %@", [self targetBundle]);
    NSLog(@"[self targetPath] = %@", [self targetPath]);
    if (handle)
        dlclose(handle);
    handle = dlopen([[self targetPath] UTF8String], isInitial ? RTLD_LOCAL : RTLD_LOCAL);
    self.nmtable = nil;
    NSLog(@"handle = %lu / '%s'", handle, dlerror());
    if (!isInitial) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self swizzle];
        });
    }
//    if (existingHandle) {
//        dlclose(existingHandle);
//        existingHandle = NULL;
//    }
}
- (void)swizzle {
    
    NSMutableSet* classes = [[[self class] allClasses] mutableCopy];
    [classes minusSet:baseClasses];
    
    for (NSString* classname in classes) {
        NSLog(@"  class %@", classname);
        Class cl = NSClassFromString(classname);
        [[self class] enumerateMethodsForClass:cl with:^(Method meth) {
            SEL sel = method_getName(meth);
            if (!sel)
                return;
            
            NSString* methodname = NSStringFromSelector(sel);
            NSString* symname = [NSString stringWithFormat:@"-[%@ %@]", classname, methodname];
            NSString* errstr = nil;
            IMP imp = (IMP)[self symbolNamed:symname errorString:&errstr];
            NSLog(@"errstr = %@", errstr);
            NSLog(@"    method %@: %ul", symname, imp);
            if (imp)
                method_setImplementation(meth, imp);
            
//            void (*pb)(id, SEL) = [self symbolNamed:@"-[GDDotView printBoo]" errorString:NULL];
//            pb(nil, NULL);
        }];
    }
}
- (void*)symbolNamed:(NSString*)name errorString:(NSString**)errstr {
    if (![name isEqual:@"main"]) {
        [self nm];
        NSLog(@"nmtable = %@", nmtable);
        if ([nmtable objectForKey:name]) {
            
            long long main_addr = (long long)[[nmtable objectForKey:@"main"] unsignedLongLongValue];
            long long sym_addr = (long long)[[nmtable objectForKey:name] unsignedLongLongValue];
            
            long long main_sym_addr = (long long)[self symbolNamed:@"main" errorString:NULL];
            long long delta = sym_addr - main_addr;
            NSLog(@"delta = %lld", delta);
            return (void*)(main_sym_addr + delta);
        }
    }
    
    NSLog(@"handle = %lu", handle);
    void* sym = dlsym(handle, [name UTF8String]);
    if (errstr)
        *errstr = nil;
    if (sym)
        return sym;
    
    if (errstr) {
        char* c_errstr = dlerror();
        *errstr = c_errstr ? [NSString stringWithUTF8String:c_errstr] : [NSString stringWithFormat:@"Unknown error resolving symbol '%@'", name];
    }
    return nil;
}
- (NSDictionary*)nm {
    if (nmtable)
        return nmtable;
//    struct nlist64 names;
//    int x = nlist([[self targetPath] fileSystemRepresentation], &names);
    nmtable = [[NSMutableDictionary alloc] init];
#define mm(idx, unused, name) [nmtable setObject:[NSNumber numberWithUnsignedLongLong:idx] forKey:name];
    /*
    mm(0x0000000000001140, T, @"main")
    mm(0x00000000000011c0, t, @"-[GDAppDelegate applicationDidFinishLaunching:]")
    mm(0x0000000000001180, t, @"-[GDAppDelegate dealloc]")
    mm(0x0000000000001200, t, @"-[GDAppDelegate setWindow:]")
    mm(0x00000000000011e0, t, @"-[GDAppDelegate window]")
    mm(0x0000000000001230, t, @"-[GDDotView awakeFromNib]")
    mm(0x00000000000012e0, t, @"-[GDDotView drawRect:]")
    mm(0x00000000000012b0, t, @"-[GDDotView printBoo]")
    mm(0x0000000000001270, t, @"-[GDDotView redraw]")
    */
    
    NSString* nmoutput_path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hotloader_nm"];
//    NSFileHandle* outhandle = [NSFileHandle fileHandleForWritingAtPath:nmoutput_path];
    
    NSPipe* pipe = [[NSPipe alloc] init];
    
    NSTask* nm = [[NSTask alloc] init];
    [nm setLaunchPath:@"/usr/bin/nm"];
    [nm setArguments:[NSArray arrayWithObject:[self targetPath]]];
    [nm setStandardOutput:pipe];
    [nm launch];
    [nm waitUntilExit];
//    NSLog(@"nmoutput_path = %@", nmoutput_path);
//    return nmtable;
    
//    NSString* nmoutput = [NSString stringWithContentsOfFile:nmoutput_path encoding:NSUTF8StringEncoding error:NULL];
    NSString* nmoutput = [[NSString alloc] initWithData:[[pipe fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
//    NSLog(@"ouuput %@", nmoutput);
//    return nmtable;
    [nmoutput enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        BOOL isMain = [line rangeOfString:@" T _main"].location != NSNotFound;
        if ([line rangeOfString:@" t -["].location != NSNotFound || isMain) {
            NSArray* components = [line componentsSeparatedByString:@" "];
            NSString* addr = [components objectAtIndex:0];
            unsigned long addrValue = strtoul([addr UTF8String], NULL, 16);
            NSString* symname = isMain ? @"main" : [NSString stringWithFormat:@"%@ %@", [components objectAtIndex:2], [components objectAtIndex:3]];
            
            mm(addrValue, t, symname);
        }
    }];
    NSLog(@"nmtable = %@", nmtable);
    return nmtable;
}

@end

int main(int argc, char** argv, char** envp, char** apple) {
//    return 0;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [NSRunLoop currentRunLoop];
    
    HotLoader* loader = [[HotLoader alloc] init];
//    NSLog(@"1 HANDLE: %lu", loader.handle);
    loader.baseClasses = [HotLoader allClasses];
    
    // Perform an initial load of the .app
//    NSLog(@"2 HANDLE: %lu", loader.handle);
    [loader reload:YES];
    
//    NSLog(@"3 HANDLE: %lu", loader.handle);
    // Create and run hotobjc's thread
    [loader start];
//    NSLog(@"4 HANDLE: %lu", loader.handle);
    
    // Get the main function from the loaded dylib and run it
//    hot_main_t existing_start = (hot_main_t)[loader symbolNamed:@"m2" errorString:NULL];
    hot_main_t existing_main = (hot_main_t)[loader symbolNamed:@"main" errorString:NULL];
    NSLog(@"existing_main = %lu", existing_main);
//    NSLog(@"existing_start = %lu", existing_start);
//    NSLog(@"diff = %ld", ((long)existing_start) - (long)existing_main);
    
//    return 0;
    int status = existing_main(argc, argv, envp, apple);
    
    [pool drain];
    return status;
}
