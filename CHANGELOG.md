## 1.3.0
* Detect change in settings. New settings are applied immediately.
* `Suppress status bar icon/button` is enabled by default again.
* `Suppress status bar icon/button` now hides the button/icon instead of removing it completely (can be revealed again by toggling this option).
* Reduce package loading time.
* Fix broken silent mode. Now runs truly silently unless error occurs.


## 1.2.1
* `Suppress status bar icon` now defaults to be 'Disabled' as this function does not utilize Atom's API and may conflicts with other packages or be completely broken in future Atom versions.
* `Suppress status bar icon` should now handle multiple bottom panels properly.
* Fix CHANGELOG link in README.


## 1.2.0
* Find and kill the blue 'X updates(s)' icon/button at the lower right corner of Atom window (enabled by default; can be turned off). Because updates are managed by this package
* Notifications and dialogues are now aware of single/multiple update(s) and pluralize if necessary
* Trigger check-for-update 30 seconds after package activation, giving way to Atom to draw the editor window and launch other UI-related packages.


## 1.1.2
* Fix minimum interval between check-for-update should not be < 1 hour.


## 1.1.1
* Correct a few typos in README and notification messages.


## 1.1.0
* Initial release as a rewrite of yujinakayama's auto-update-packages
