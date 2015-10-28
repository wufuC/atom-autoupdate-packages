autoupdate-packages
===

[Changelog here](CHANGELOG.md)

---

A rewrite of [yujinakayama](https://github.com/yujinakayama/)'s excellent [auto-update-packages](https://github.com/yujinakayama/atom-auto-update-packages)

---

Why a rewrite?

yujinakayama's auto-update-packages works, although I would like have an option for disabling notification (i.e. keeping my packages up-to-date automatically and silently). The same feature has already been requested by other users months ago, too. Unfortunately, yujinakayama might be too busy to add new codes. The package's Github issue page also lists a number of longstanding feature requests. I guess I can help making everyone's life slightly better;) 

This started off as a series of hacks that attempt to provide the desired features/options. After a few hours of polishing, it turns into something that is difficult to be merged back into to yujinakayama's source. Therefore, I rewrote (with a few lines of codes *borrowed* from yujinakayama) and renamed it as a standalone package. The differences (feature-wise) between these two packages are trivial, though. See below.


|                                       | This package | yujinakayama's<br>package |
|---------------------------------------|:------------:|:-------------------------:|
| Keep packages update-to-date          | ✓            | ✓                         |
| Confirm before updating               | ✓            |                           |
| Send notification                     | ✓#           | ✓$<br> (OS X 10.8+ only)  |
| Can mute notification                 | ✓            |                           |
| Minimum interval between update-check | 1 hour^      | 15 mins                   |

\# Uses Atom's notification system, should be platform-independent. Require the bundled `notification` package.

$ Use `terminal-notifer`. Messages are sent to the Notification Center on Mac OS X 10.8 or higher.

^ Who needs shorter than this?

---

*Tested on OS X 10.11 (El Capitan). Please report back if it fails on your system.*