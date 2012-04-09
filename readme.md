# hotobjc: Objective-C Hotloading

Inspired by [Notch's](http://www.twitch.tv/notch) merciless development pace (in *Java*). One of the most noticeable things is how he uses hotloading to instantly see changes while coding. I want this for Objective-C.

### Getting Started

1. Add a new build configuration called "Hotloading" that is a duplicate of your usual Debug configuration.
2. Change the "Mach-O" type to "Dynamic Library"
3. Add a new target called "Hotloader"
4. Copy hotobjc.m to your project, assign it to the "Hotloader" target (and no others!)
5. Add the name of your app's target as a user define. e.g. `HOTLOADER_TARGET: Chocolat`
6. Build and run Hotloader.

[[ This could be turned into a script of some sort ]]

### Requirements

Hotobjc works on Mac OS X and iOS. It requires the "new" 64-bit runtime. That's not to say that your app must drop 32-bit support.

### License

Hotobjc is available under the [WTFPL](http://sam.zoy.org/wtfpl/).