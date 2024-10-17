# ScrollableGui
The current code is in the beta phase.  
It has not yet undergone comprehensive testing.
### Version 0.0.0 (2024-07-09)
- Code release.  
For more details, refer to the following thread.  
[How to show the scrollbar on a Gui Window?](https://www.autohotkey.com/boards/viewtopic.php?f=82&t=131307)  
[Gui Scroll Window v2](https://www.autohotkey.com/boards/viewtopic.php?f=82&t=133676)
### Version 0.1.0 (2024-07-10)
- Added the `updateSize()` method.  
It can be called when the window size changes without going through a callback.
### Version 0.2.0 (2024-07-16)
- Added the `getInnerControlsSize()`, `getBoundary()` and `updateBoundary()` methods.
- The translation for version 1 has not been completed yet.
### Version 0.2.1 (2024-07-20)
 - Added `visibleControlsOnly` parameter to `getInnerControlsSize()` method.
- Added `innerScrollWithFocus` parameter to `register()` method.
- Added new method `setInnerScrollWithFocus()`.
