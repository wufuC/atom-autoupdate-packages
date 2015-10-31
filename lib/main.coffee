# Debug mode
# If true, enforce CHECK_DELAY = 0, reset lastUpdateTimestamp and
#   trigger @checkTimestamp when window is (re-)drawn
debug = false


# Postpone update checking after a new window is drawn (in millisecond)
# Default: 30 seconds
CHECK_DELAY = if debug then 0 else 30*1000


# Presets of user-selectable options
option =
  preset:
    mode0:
      key: 'Update automatically and notify me (default)'
      autoUpdate: true, notifyMe: true, confirmAction: false
    mode1:
      key: 'Update automatically and silently'
      autoUpdate: true, notifyMe: false, confirmAction: false
    mode2:
      key: 'Notify me and let me choose what to do'
      autoUpdate: false, notifyMe: true, confirmAction: true
    mode3:
      key: 'Notify me only'
      autoUpdate: false, notifyMe: true, confirmAction: false
  suppressStatusbarUpdateIcon:
    disabled: 'Disabled (default)'
    enabled: 'Enabled'
  verboseModes:
    disabled: 'Disabled (default)'
    enabled: 'Enabled'


# for deferred assignment
mainScope = null
updateHandler = null
notificationHandler = null


#
# Package core
#
module.exports =
  config:
    frequency:
      title: 'Check frequency'
      description: 'Check for update every ___ hour(s).'
      type: 'integer'
      default: 6
      minimum: 1
      order: 1
    handling:
      title: 'Update handling'
      description: 'Action to be taken when update(s) is/are available.'
      type: 'string'
      enum: (mode.key for modeID, mode of option.preset)
      default: option.preset.mode0.key
      order: 2
    suppressStatusbarUpdateIcon:
      title: 'Suppress status bar icon'
      description: 'If enabled, automatically dismiss the blue "X update(s)"
                    icon/button at the lower right corner of your Atom window.
                    WARNING: May conflict with other packages or be broken by
                    Atom upgrades. Please set to "Disabled" and file an issue
                    if this throws any error.'
      type: 'string'
      enum:
        for mode, description of option.suppressStatusbarUpdateIcon
          description
      default: option.suppressStatusbarUpdateIcon.disabled
      order: 3
    verbose:
      title: 'Verbose log'
      description: 'If enabled, log action to console.'
      type: 'string'
      enum: (description for mode, description of option.verboseModes)
      default: option.verboseModes.disabled
      order: 4
    lastUpdateTimestamp:
      title: 'LASTUPDATE_TIMESTAMP'
      description: 'For internal use. Do *NOT* modify.
                    If a forced check for update is desired, set to zero, then
                    create a new window or reload the current one.'
      type: 'integer'
      default: 0
      minimum: 0
      order: 9


  # Cached user-selected options
  # Set by calling @cacheUserPreferences
  userChosen:
    checkInterval: null
    autoUpdate: null
    notifyMe: null
    confirmAction: null
    suppressStatusbarUpdateIcon: null
    verbose: true


  # Wrapper function for retrieving user settings from Atom's keypath
  getConfig: (configName) ->
    {BufferedProcess} = require 'atom'
    configValue = atom.config.get("autoupdate-packages.#{configName}")


  # Wrapper function for logging message to console
  # It tags the message by prepending `autoupdate-packages: `
  verboseMsg: (msg, forced = false) ->
    return unless @userChosen.verbose or forced
    console.log "autoupdate-packages: #{msg}"


  # Retrieves user settings and set the `userChosen` object defined above
  cacheUserPreferences: ->
    #
    @userChosen.checkInterval = @getConfig('frequency') * 1000*60*60
    #
    for _mode, mode of option.preset when mode.key is @getConfig('handling')
      @userChosen.autoUpdate = mode.autoUpdate
      @userChosen.notifyMe = mode.notifyMe
      @userChosen.confirmAction = mode.confirmAction
    #
    @userChosen.suppressStatusbarUpdateIcon =
      (@getConfig('suppressStatusbarUpdateIcon') is
        option.suppressStatusbarUpdateIcon.enabled)
    #
    @userChosen.verbose =
      (@getConfig('verbose') is option.verboseModes.enabled) or debug
    #
    @verboseMsg "Running mode ->
                 autoUpdate = #{@userChosen.autoUpdate},
                 notifyMe = #{@userChosen.notifyMe},
                 confirmAction = #{@userChosen.confirmAction},
                 suppressStatusbarUpdateIcon =
                   #{@userChosen.suppressStatusbarUpdateIcon},
                 verbose = #{@userChosen.verbose}"
                 , forced = true


  # Upon package activation run:
  activate: ->
    mainScope = this
    # Hack: suppress status bar icon
    if (atom.config.get "suppressStatusbarUpdateIcon" is
          option.suppressStatusbarUpdateIcon.enabled)
      notificationHandler ?= require './notification-handler'
      notificationHandler.suppressStatusbarUpdateIcon()
    # Defer to reduce load on Atom
    @verboseMsg "Deferring initial check: will launch in
                  #{CHECK_DELAY/1000} seconds"
    @scheduledCheck = setTimeout(@checkTimestamp.bind(mainScope), CHECK_DELAY)


  # Upon package deactivation run:
  deactivate: ->
    clearTimeOut @scheduledCheck if @scheduledCheck?


  # Specify the content of the notification bubble. Called by
  #   `@setPendingUpdates` if `@userChosen.notifyMe` is true
  summonNotifier: (pendingUpdates) ->
    @verboseMsg 'Posting notification'
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpdates(
      updatables = pendingUpdates,
      saySomething = (@userChosen.autoUpdate or @userChosen.confirmAction),
      actionRequired = @userChosen.confirmAction,
      confirmMsg = if @userChosen.confirmAction then notificationHandler.
        generateConfirmMsg(pendingUpdates) else null)


  # Wrapper function that trigger updating of the listed packages
  summonUpdater: (pendingUpdates) ->
    @verboseMsg 'Processing pending updates'
    updateHandler ?= require './update-handler'
    updateHandler.processPendingUpdates(pendingUpdates)


  # Intended to be used as a callback for `update-handler.getOutdated`.
  #   It catches the output of `update-handler.getOutdated`, then, if needed,
  #   redirects it to `@summonNotifier` and/or `@summonUpdater` to trigger
  #   notifications and package-update
  setPendingUpdates: (pendingUpdates) ->
    if pendingUpdates? and (pendingUpdates.length > 0)
      @verboseMsg "#{pendingUpdates.length}
                    update#{if pendingUpdates.length > 1 then 's' else ''}
                    found"
      @summonNotifier(pendingUpdates) if @userChosen.notifyMe
      @summonUpdater(pendingUpdates) if @userChosen.autoUpdate
    else
      @verboseMsg "No update(s) found"


  # Get/set lastUpdateTimestamp and, if the timestamp is expired, ask
  #   `update-handler` to find updates
  checkTimestamp: ->
    @cacheUserPreferences()
    @verboseMsg 'Checking timestamp'
    nextCheck =
      @getConfig('lastUpdateTimestamp') + @userChosen.checkInterval
    timeToNextCheck = nextCheck - Date.now()
    # If timestamp expired, invoke APM
    if timeToNextCheck < 0 or debug
      @verboseMsg 'Timestamp expired -> Checking for updates'
      updateHandler ?= require './update-handler'
      updateHandler.getOutdated(@setPendingUpdates.bind(this))
      @verboseMsg 'Overwriting timestamp'
      atom.config.set('autoupdate-packages.lastUpdateTimestamp', Date.now())
      timeToNextCheck = @userChosen.checkInterval
    # Schedule next check
    @scheduledCheck = setTimeout(@checkTimestamp.bind(mainScope),
                                 timeToNextCheck)
    @verboseMsg "Next check: in
                  #{timeToNextCheck / 1000 / 60}
                  minute#{if timeToNextCheck > 1000*60 then 's' else ''}"
