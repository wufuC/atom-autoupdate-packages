# Debug mode
# If true, enforce CHECK_DELAY = 0, reset lastUpdateTimestamp and
#   trigger @checkTimestamp when window is (re-)drawn
debugMode = false


# Postpone update checking after a new window is drawn (in millisecond)
# Default: 30 seconds
CHECK_DELAY = if debugMode then 0 else 30*1000


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
    disabled: 'Disabled'
    enabled: 'Enabled (default)'
  verboseModes:
    disabled: 'Disabled (default)'
    enabled: 'Enabled'


class CachedUserPreferences
  # Instance contains
  #   * checkInterval [integer]
  #   * autoUpdate [bool]
  #   * notifyMe [bool]
  #   * confirmAction [bool]
  #   * suppressStatusbarUpdateIcon [bool]
  #   * verbose [bool]
  constructor: (configObj) ->
    @checkInterval = configObj.frequency * 1000*60*60
  #
    for _mode, mode of option.preset when mode.key is configObj.handling
      @autoUpdate = mode.autoUpdate
      @notifyMe = mode.notifyMe
      @confirmAction = mode.confirmAction
  #
    @suppressStatusbarUpdateIcon =
      (configObj.suppressStatusbarUpdateIcon is
        option.suppressStatusbarUpdateIcon.enabled)
  #
    @verbose = configObj.verbose is option.verboseModes.enabled


mainScope = null
updateHandler = null
notificationHandler = null


module.exports =
  config:
    frequency:
      title: 'Check frequency'
      description: "Check for update every ___ hour(s)\nMinimum: 1 hour"
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
      title: 'Suppress status bar icon/button'
      description: 'If enabled, automatically dismiss the blue "X update(s)"
                    icon/button at the lower right corner of your Atom window.'
      type: 'string'
      enum:
        for mode, description of option.suppressStatusbarUpdateIcon
          description
      default: option.suppressStatusbarUpdateIcon.enabled
      order: 3
    verbose:
      title: 'Verbose log'
      description: 'If enabled, log action to console.'
      type: 'string'
      enum: (description for mode, description of option.verboseModes)
      default: option.verboseModes.disabled
      order: 4
    lastUpdateTimestamp:
      title: 'Lastupdate timestamp'
      description: 'For internal use. Do *NOT* modify.
                    If a forced check-for-update is needed, set to zero, then
                    create a new window or reload the current one.'
      type: 'integer'
      default: 0
      minimum: 0
      order: 9


  activate: ->
    mainScope = this
    @init()
    @monitorConfig =  # Re-initialize when settings are modified
      atom.config.onDidChange 'autoupdate-packages', (contrastedValues) ->
        for item, oldSetting of contrastedValues.oldValue
          newSetting = contrastedValues.newValue[item]
          if (item isnt 'lastUpdateTimestamp') and (oldSetting isnt newSetting)
            @init(contrastedValues.newValue).bind(mainScope)


  deactivate: ->
    clearTimeout @scheduledCheck if @scheduledCheck?
    clearInterval @knockingStatusbar if @knockingStatusbar?
    @monitorConfig.dispose() if @monitorConfig?


  init: (configObj = @getConfig()) ->
    clearTimeout @scheduledCheck if @scheduledCheck?
    clearInterval @knockingStatusbar if @knockingStatusbar?
    @userChosen = new CachedUserPreferences configObj
    @verboseMsg "Running mode ->
                  autoUpdate = #{@userChosen.autoUpdate},
                  notifyMe = #{@userChosen.notifyMe},
                  confirmAction = #{@userChosen.confirmAction},
                  suppressStatusbarUpdateIcon =
                    #{@userChosen.suppressStatusbarUpdateIcon},
                  verbose = #{@userChosen.verbose}"
    # schedule initial timestamp check
    #   The check is delayed to reduce burden on Atom's startup process,
    #   which is already slow
    @verboseMsg "Timestamp inspection will commence in #{CHECK_DELAY/1000} s"
    @scheduledCheck = setTimeout(@checkTimestamp.bind(mainScope), CHECK_DELAY)
    # Hack
    @suppressStatusbarUpdateIcon()


  # Wait for `PackageUpdatesStatusView` element. Kill itself once the
  #  it is found or specific ammount (`TIMEOUT`) of time has past
  suppressStatusbarUpdateIcon: ->
    invokeTime = Date.now()
    TIMEOUT = 2 * 60 * 1000
    @verboseMsg 'looking for "PackageUpdatesStatusView"'
    @knockingStatusbar = setInterval (->
      toggled = @hidePackageUpdatesStatusView(hide =
                    @userChosen.suppressStatusbarUpdateIcon)
      if toggled?
        clearInterval(@knockingStatusbar)
        if @userChosen.suppressStatusbarUpdateIcon
          @verboseMsg '"PackageUpdatesStatusView" off'
        else if not @userChosen.suppressStatusbarUpdateIcon
          @verboseMsg '"PackageUpdatesStatusView" on'
      else if  Date.now() - invokeTime > TIMEOUT
        @verboseMsg '"PackageUpdatesStatusView" not found'
        clearInterval(@knockingStatusbar)
      ).bind(mainScope), 1000


  # HACK
  # Remove the blue package icon at the bottom-righthand corner of the window
  # TODO: find a way to retrieve the `PackageUpdatesStatusView` object directly
  #  through `status-bar` service
  # getPackageUpdatesStatusView: ->
  #   for bottomPanel in atom.workspace.getBottomPanels()
  #     if bottomPanel.item.constructor.name is 'status-bar'
  #       for tile in bottomPanel.item.rightTiles
  #         if tile.item.constructor.name is 'PackageUpdatesStatusView'
  #           return tile


  hidePackageUpdatesStatusView: (hide = true) ->
    buttons = document.getElementsByClassName(
      'package-updates-status-view inline-block text text-info'
    )
    if buttons.length > 0
      for button in buttons
        button.style.display = if hide then "None" else ""
      return true


  checkTimestamp: ->
    @verboseMsg 'Inspecting timestamp'
    nextCheck =
      @getConfig('lastUpdateTimestamp') + @userChosen.checkInterval
    timeToNextCheck = nextCheck - Date.now()
    if timeToNextCheck < 0 or debugMode
      @verboseMsg 'Timestamp expired -> Checking for updates...'
      updateHandler ?= require './update-handler'
      updateHandler.getOutdated()
      @verboseMsg 'Overwriting timestamp'
      atom.config.set('autoupdate-packages.lastUpdateTimestamp', Date.now())
      timeToNextCheck = @userChosen.checkInterval
    # Schedule next check
    @scheduledCheck = setTimeout(@checkTimestamp.bind(mainScope),
                                 timeToNextCheck + 1)
    @verboseMsg "Will check for updates again in
                  #{timeToNextCheck / 1000 / 60}
                  minute#{if timeToNextCheck > 1000*60 then 's' else ''}"


  getConfig: (configName) ->
    if configName?
      atom.config.get("autoupdate-packages.#{configName}")
    else
      atom.config.get("autoupdate-packages")


  verboseMsg: (msg, forced = debugMode) ->
    return unless @userChosen.verbose or forced
    console.log "autoupdate-packages: #{msg}"
