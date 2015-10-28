## 1.2.0
* New: Option to dismiss the blue 'package(s) available' icon at the lower right
         corner of Atom window automatically when the update process is triggered
* New: Notifications and dialogues are now aware of single/multiple update(s).
         Pluralize if necessary
* Fix: Trigger check-for-update 30 seconds after package activation,
         giving way to Atom to draw the editor window and launch other
         UI-related packages

## 1.1.2
* Fix: minimum interval between check-for-update should not be < 1 hour

## 1.1.1
* Fix: Correct a few typos in README and notification messages

## 1.1.0
* Initial release as a rewrite of yujinakayama's auto-update-packages