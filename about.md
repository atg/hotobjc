# ObjC Hotloading

## Immediate Goals

* Reload ObjC method implementations at runtime
* Support iOS

## Implementation

We can't implement hotloading the "usual" way (by modifying the code in memory), since iOS doesn't allow it. So we're going to go for a dylib based approach instead:

1. Compile the app as a Mach-O dylib/bundle instead of an executable.
2. A wrapper executable[1] will handle the meat of the operation:
  1. Watch for changes in the _real_ .app[2].
  2. Copy over resources from the real app to the wrapper[3].
  3. When the real app is recompiled, dlopen it.
  4. Use the objc runtime to replace the IMPs with the new functions.
  5. dlclose the existing library, now that it's no longer needed[4].

[1]: The wrapper should be a separate target in Xcode, and specify the app target as a dependency.
[2]: We could get it to recompile automatically (using `xcodebuild`), then reload on a successful recompile[3]: Copy rather than symlink, to make it appear as realistic as possible.
[4]: I'm not sure if this necessarily breaks function pointers. If it does, we may have to leak this memory (configurable).
