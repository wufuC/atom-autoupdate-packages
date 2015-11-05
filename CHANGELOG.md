## 1.2.2
* Change: When settings are modified, new settings apply immediately
* Change: `Suppress status bar icon/button` is enabled by default again
* Change: `Suppress status bar icon/button` now hides the button/icon instead of
            removing it (can be showed again by toggling the option in settings)
* Change: Warnings of `Suppress status bar icon/button` in the setting page has
            been removed as this function should now fail silently


## 1.2.1
* Fix: `Suppress status bar icon` now defaults to be 'Disabled' as this function
         does not utilize Atom's API and may conflicts with other packages or be
         completely broken in future Atom versions
* Fix: `Suppress status bar icon` should now handle multiple bottom panels properly
* Fix: CHANGELOG link in README


## 1.2.0
* New: Find and kill the blue 'X updates(s)' icon/button at the lower right
         corner of Atom window (enabled by default; can be turned off).
         Because updates are managed by this package
* New: Notifications and dialogues are now aware of single/multiple update(s)
         and pluralize if necessary
* Fix: Trigger check-for-update 30 seconds after package activation,
         giving way to Atom to draw the editor window and launch other
         UI-related packages


## 1.1.2
* Fix: minimum interval between check-for-update should not be < 1 hour


## 1.1.1
* Fix: Correct a few typos in README and notification messages


## 1.1.0
* Initial release as a rewrite of yujinakayama's auto-update-packages