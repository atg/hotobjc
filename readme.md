# hotobjc: Objective-C Hotloading

Inspired by [Notch's](http://www.twitch.tv/notch) merciless development pace (in *Java*). One of the most noticeable things is how he uses hotloading to instantly see changes while coding. I want this for Objective-C.

### Getting Started

1. Add a new build configuration called "Hotloading" that is a duplicate of "Debug".
2. Change the "Mach-O" type of your app *in the "Hotloading" configuration* from "Executable" to **"Dynamic Library"**
3. Add "-ObjC" to the "Linker Flags" of your app's target *in the "Hotloading" configuration*
3. Add a new Application target called "Hotloader"
4. Add your target as a dependency of the "Hotloader" target (Project -> Hotloader target -> Build Phrases -> Target Dependencies -> Click the `+` button)
5. Copy hotobjc.m to your project, assign it to the "Hotloader" target (and no others!)
6. Remove the file `main.m` that Xcode created when it made the target 
7. Add the following user defines: as a user define. The easiest place to put theme is in the Hotloader.bundle `Hotloader-Prefix.pch` prefix header that Xcode created when you made the target.

    #define HOTLOADER_TARGET @"<name-of-your-app-target>"
    #define HOTLOADER_APP_PATH @"<relative-path-to-your-app>"
    
    for example
    #define HOTLOADER_TARGET @"Green Dot"
    #define HOTLOADER_APP_PATH @"../Green Dot"
8. Change the current build configuration to "Hotloading"
9. Build and run Hotloader.

[[ This could be turned into a script of some sort ]]

### Requirements

Hotobjc works on Mac OS X and iOS. It requires the "new" 64-bit runtime. That's not to say that your app must drop 32-bit support.

### License

Hotobjc is available under the [WTFPL](http://sam.zoy.org/wtfpl/).