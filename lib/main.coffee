# Debug mode
# If true, enforce CHECK_DELAY = 0, ignore lastUpdateTimestamp and
#   trigger @checkTimestamp when window is (re-)drawn
debug = true


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
  autoDimissStatusbarIcon:
    disabled: 'Disabled (default)'
    enabled: 'Enabled'
  verboseModes:
    disabled: 'Disabled (default)'
    enabled: 'Enabled'


# User selected options
# Set by calling @setUserChoice upon package activation
userChosen = 
  checkInterval: null
  autoUpdate: null
  notifyMe: null
  confirmAction: null
  autoDimissStatusbarIcon: null
  verbose: null


# dummy variable for deferred `require`
updateHandler = null
notificationHandler = null


#
# Package core
#
module.exports =
  config:
    frequency:
      title: 'Update-check frequency'
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
    autoDimissStatusbarIcon:
      title: 'Auto dimiss status bar icon'
      description: 'If enabled, automatically remove the "blue package
                    icon" at the bottom-righthand-corner of Atom window when
                    the update is being commenced.'
      type: 'string'
      enum: (description for mode, description of option.autoDimissStatusbarIcon)
      default: option.autoDimissStatusbarIcon.disabled
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
                    If a forced check for update is desired, set to zero,
                    then create a new window or reload the current one.'
      type: 'integer'
      default: 0
      minimum: 0
      order: 9


  # Wrapper function for retrieving user settings from Atom's keypath
  getConfig: (configName) ->
    {BufferedProcess} = require 'atom'
    configValue = atom.config.get("autoupdate-packages.#{configName}")


  # Wrapper function for logging message to console
  # It tags the message by prepending `autoupdate-packages: `
  verboseMsg: (msg) ->
    return unless userChosen.verbose
    console.log "autoupdate-packages: #{msg}"


  # Retrieves the relevant user settings and set the `userChosen` object
  #   defined above. Intended to be called during package activation.
  #
  # TODO: Re-trigger this function when user setting is modified
  setUserChoice: ->
    @verboseMsg "Setting options"
    #
    userChosen.checkInterval = @getConfig('frequency') * 1000*60*60
    #
    selectedMode = mode for modeID, mode of option.preset when mode.key is @getConfig('handling')
    userChosen.autoUpdate = selectedMode.autoUpdate
    userChosen.notifyMe = selectedMode.notifyMe
    userChosen.confirmAction = selectedMode.confirmAction
    #
    userChosen.autoDimissStatusbarIcon = @getConfig('autoDimissStatusbarIcon') is option.autoDimissStatusbarIcon.enabled
    #
    userChosen.verbose = @getConfig('verbose') is option.verboseModes.enabled
    @verboseMsg "Running mode ->
                 autoUpdate = #{userChosen.autoUpdate},
                 notifyMe = #{userChosen.notifyMe},
                 confirmAction = #{userChosen.confirmAction},
                 autoDimissStatusbarIcon = #{userChosen.autoDimissStatusbarIcon},
                 verbose = #{userChosen.verbose}"


  # Upon package activation run:
  activate: ->
    @setUserChoice()
    @verboseMsg "Deferring initial check: will launch in #{CHECK_DELAY/1000} seconds"
    @initialCheck = setTimeout(@checkTimestamp.bind(this), CHECK_DELAY)
    @verboseMsg 'Scheduling check'
    @scheduledCheck = setInterval(@checkTimestamp.bind(this), userChosen.checkInterval)


  # Upon package deactivation run:
  deactivate: ->  
    clearTimeOut @initialCheck
    clearInterval @scheduledCheck


  # Specify the content of the notification bubble. Called by
  #   `@setPendingUpdates` if `userChosen.notifyMe` is true
  summonNotifier: (pendingUpdates) ->
    @verboseMsg 'Posting notification'
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpdates(
      updatables = pendingUpdates,
      saySomething = (userChosen.autoUpdate or userChosen.confirmAction),
      actionRequired = userChosen.confirmAction,
      confirmMsg = if userChosen.confirmAction then notificationHandler.generateConfirmMsg(pendingUpdates) else null
      )


  # Wrapper function that trigger the update of the specified packages
  summonUpdater: (pendingUpdates) ->
    @verboseMsg 'Processing pending updates'
    updateHandler ?= require './update-handler'
    updateHandler.processPendingUpdates(pendingUpdates)
    if userChosen.autoDimissStatusbarIcon
      notificationHandler ?= require './notification-handler'
      notificationHandler.suppressStatusbarUpdateIcon()


  # Intended to be used as a callback for `update-handler.getOutdated`.
  #   It catches the output of `update-handler.getOutdated`, then, if needed,
  #   redirects it to `@summonNotifier` and/or `@summonUpdater` to trigger
  #   notifications and package-update
  setPendingUpdates: (pendingUpdates) ->
    if pendingUpdates? and (pendingUpdates.length > 0)
      @verboseMsg "#{pendingUpdates.length} update#{if pendingUpdates.length > 1 then 's' else ''} found"
      @summonNotifier(pendingUpdates) if userChosen.notifyMe
      @summonUpdater(pendingUpdates) if userChosen.autoUpdate
    else
      @verboseMsg "No update(s) found"


  # Get/set lastUpdateTimestamp and, if the timestamp is expired, ask
  #   `update-handler` to find updates 
  checkTimestamp: ->
    @verboseMsg 'Checking timestamp'
    lastCheck = @getConfig('lastUpdateTimestamp')
    nextCheck = lastCheck + userChosen.checkInterval
    if (Date.now() > nextCheck) or debug
      @verboseMsg 'Timestamp expired -> Checking for updates'
      updateHandler ?= require './update-handler'
      updateHandler.getOutdated(@setPendingUpdates.bind(this))
      @verboseMsg 'Overwriting timestamp'
      atom.config.set('autoupdate-packages.lastUpdateTimestamp', Date.now())
    else
      timeToNextCheck = (nextCheck - Date.now()) / 1000 / 60
      timeUnit = "minute#{if timeToNextCheck > 1 then 's' else ''}"
      @verboseMsg "Next check in #{timeToNextCheck} #{timeUnit}"
