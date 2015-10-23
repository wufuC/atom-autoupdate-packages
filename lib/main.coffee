# Debug mode
# If true, enforce CHECK_DELAY = 0 and ignore lastUpdateTimestamp
#   i.e. always trigger @launchUpdater when window is (re-)drawn
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
  verbose: null


# dummy variable for deferred `require`
updateHander = null
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
    verbose:
      title: 'Verbose log'
      description: 'If enabled, log action to console.'
      type: 'string'
      enum: (description for mode, description of option.verboseModes)
      default: option.verboseModes.disabled
      order: 3
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
  #  it tags output message by prepending `autoupdate-packages: `
  verboseMsg: (msg) ->
    return unless userChosen.verbose
    console.log "autoupdate-packages: #{msg}"


  # This retrieves the relevant user settings and set the `userChosen` object
  #   defined above. Intended to be called during package activation.
  # TODO: trigger this function when user setting is modified
  setUserChoice: ->
    @verboseMsg "Setting options"
    userChosen.checkInterval = @getConfig('frequency') * 1000*60*60
    selectedMode = mode for modeID, mode of option.preset when mode.key is @getConfig('handling')
    userChosen.autoUpdate = selectedMode.autoUpdate
    userChosen.notifyMe = selectedMode.notifyMe
    userChosen.confirmAction = selectedMode.confirmAction
    userChosen.verbose = @getConfig('verbose') is option.verboseModes.enabled
    @verboseMsg "Running mode ->
                 autoUpdate = #{userChosen.autoUpdate},
                 notifyMe = #{userChosen.notifyMe},
                 confirmAction = #{userChosen.confirmAction},
                 verbose = #{userChosen.verbose}"


  # Stuffs to be run upon package activation:
  # The userChoice object is set by calling @setUserChoice.
  #   `setTimeout` defers the initial check of timestamp (and updates, if
  #   timestamp is expired. `setInterval` registers recurrent check.
  activate: ->
    @setUserChoice()
    @verboseMsg "Deferring initial check: will launch in #{CHECK_DELAY/1000} seconds"
    initialCheck = setTimeout(@launchUpdater.bind(this), CHECK_DELAY)
    @verboseMsg 'Scheduling check'
    scheduledCheck = setInterval(@launchUpdater.bind(this), userChosen.checkInterval)


  # # Stuffs to be run upon package deactivation
  # deactivate: ->
  #   # Stop all timed check. Currently disabled as it seems like Atom clears
  #   #   these processes automatically when the editor window is killed.    
  #   clearTimeOut @initialCheck
  #   clearInterval @scheduledCheck


  # Get and set lastUpdateTimestamp and ask `update-handler` to launch `apm`
  #   to find updates if the timestamp is expired
  launchUpdater: ->
    @verboseMsg 'Checking timestamp'
    lastCheck = @getConfig('lastUpdateTimestamp')
    nextCheck = lastCheck + userChosen.checkInterval
    if (Date.now() > nextCheck) or debug
      @verboseMsg 'Timestamp expired -> Checking for updates'
      updateHander ?= require './update-handler'
      updateHander.getOutdated(@setPendingUpdates.bind(this))
      @verboseMsg 'Overwriting timestamp'
      atom.config.set('autoupdate-packages.lastUpdateTimestamp', Date.now())
    else
      @verboseMsg "Next check in #{(nextCheck - Date.now()) / 1000 / 60} mins"


  # A Glue function intended to be used as a callback of `update-handler.getOutdated`.
  #   It takes the output of `update-handler.getOutdated`, then, if required, summon
  #   `notification-handler` to post notification and/or
  #   `update-handler` to launch `apm` to update packages.
  setPendingUpdates: (pendingUpdates) ->
    if pendingUpdates? and (pendingUpdates.length > 0)
      @verboseMsg "#{pendingUpdates.length} pending update(s) found"
      if userChosen.notifyMe
        @verboseMsg 'Posting notification'
        notificationHandler ?= require './notification-handler'
        if userChosen.confirmAction
          confirmMsg =
            message: 'Update(s) available'
            detailedMessage: 'Would you like to update the package(s)?'
            buttons:
              'Update all': -> updateHander.processPendingUpdates(pendingUpdates)
              'Let me choose what to update': ->
                atom.commands.dispatch(
                  atom.views.getView(atom.workspace),
                  'settings-view:check-for-package-updates'
                  )
              'Not now': -> return
          notificationHandler.announceUpdates(
            updatables = pendingUpdates,
            saySomething = (userChosen.autoUpdate or userChosen.confirmAction),
            actionRequired = userChosen.confirmAction,
            confirmMsg = confirmMsg
            )
        else
          notificationHandler.announceUpdates(
            updatables = pendingUpdates,
            saySomething = (userChosen.autoUpdate or userChosen.confirmAction),
            actionRequired = userChosen.confirmAction
            )
      if userChosen.autoUpdate
        @verboseMsg 'Processing pending updates'
        updateHander.processPendingUpdates(pendingUpdates)
    else
      @verboseMsg "No update(s) found"
