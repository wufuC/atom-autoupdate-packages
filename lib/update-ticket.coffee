main = require './main'
updateHandler = null
notificationHandler = null

module.exports =

class UpdateTicket
  constructor: (obj) ->
    # construct from `apm --oudated --json` output
    if obj.name? and obj.version and obj.latestVersion
      @packageName = obj.name
      @fromVersion = obj.version
      @toVersion = obj.latestVersion
    # construct from deserialized UpdateTicket object
    else if obj.packageName? and obj.fromVersion and obj.toVersion
      @packageName = obj.packageName
      @fromVersion = obj.fromVersion
      @toVersion = obj.toVersion


  update: ->
    args = ['install'
            '--no-color'
            "#{@packageName}@#{@toVersion}"]
    updateHandler = require './update-handler'
    updateHandler.runAPM(
      args = args,
      callback = @parseUpdateOutcome,
      callbackOptions = this
      )


  # stub of rollback function
  # need to implement blacklist first
  # restore: ->
  #   args = ['install'
  #           '--no-color'
  #           "#{@packageName}@#{@fromVersion}"]
  #   updateHandler = require './update-handler'
  #   updateHandler.runAPM(
  #     args = args,
  #     callback = @parseUpdateOutcome,
  #     callbackOptions = this
  #     )


  parseUpdateOutcome: (apmInstallMsg, updateTicket) ->
    main.verboseMsg "APM output: #{apmInstallMsg}"
    if apmInstallMsg.indexOf('✓')
      updateTicket.addToHistory()
      if main.userChosen.notifyMe
        notificationHandler ?= require './notification-handler'
        notificationHandler.announceSuccessfulUpdate(apmInstallMsg)
    else
      notificationHandler ?= require './notification-handler'
      notificationHandler.announceFailedUpdate(apmInstallMsg)


  addToHistory: ->
    updateHistory = main.parseUpdateHistory()
    updateHistory[Date.now()] = this
    main.setConfig 'updateHistory', JSON.stringify(updateHistory)
