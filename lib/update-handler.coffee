main = require './main'
notificationHandler = null
UpdateTicket = null


module.exports =
  getOutdated: ->
    args = ['outdated', '--json', '--no-color']
    @runCommand args, (outdatedPkgsJSON) =>
      pendingUpdates = @parseAPMOutputJSON(outdatedPkgsJSON)
      @processPendingUpdates(pendingUpdates) if pendingUpdates?


  parseAPMOutputJSON: (apmOutputJSON) ->
    try
      availableUpdates = JSON.parse(apmOutputJSON)
    catch error
      main.verboseMsg "Error parsing APM output.\n #{apmOutputJSON}"
      return
    for availableUpdate in availableUpdates
      # 'name': availableUpdate.name
      # 'installedVersion': availableUpdate.version
      # 'latestVersion': availableUpdate.latestVersion
      UpdateTicket ?= require './update-ticket'
      new UpdateTicket availableUpdate


  processPendingUpdates: (pendingUpdates) ->
    if pendingUpdates? and (pendingUpdates.length > 0)
      main.verboseMsg "#{pendingUpdates.length}
                    update#{if pendingUpdates.length > 1 then 's' else ''}
                    found"
      @summonNotifier(pendingUpdates) if main.userChosen.notifyMe
      @startUpdating(pendingUpdates) if main.userChosen.autoUpdate
    else
      main.verboseMsg "No update(s) found"


  # Specify the content of the notification bubble. Called by
  #   `@processPendingUpdates` if `main.userChosen.notifyMe` is true
  summonNotifier: (pendingUpdates) ->
    main.verboseMsg 'Posting notification'
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpdates(
      updatables = pendingUpdates
      saySomething = main.userChosen.autoUpdate or main.userChosen.confirmAction
      actionRequired = main.userChosen.confirmAction
      confirmMsg = if main.userChosen.confirmAction then notificationHandler.
        generateConfirmMsg(pendingUpdates) else null
    )


  startUpdating: (pendingUpdates) ->
    for updateTicket in pendingUpdates
      updateTicket.update()


  handleAPMOutcome: (apmInstallMsg, updateTicket) ->
    main.verboseMsg "APM output: #{apmInstallMsg}"
    if apmInstallMsg.indexOf('✓')
      updateTicket.addToHistory()
      if main.userChosen.notifyMe
        notificationHandler ?= require './notification-handler'
        notificationHandler.announceSuccessfulUpdate(apmInstallMsg)
    else
      notificationHandler ?= require './notification-handler'
      notificationHandler.announceFailedUpdate(apmInstallMsg)


  runCommand: (args, callback, callbackOptions) ->
    command = atom.packages.getApmPath()
    outputs = []
    stdout = (output) ->
      outputs.push(output)
    exit = ->
      callback(outputs, callbackOptions)
    {BufferedProcess} = require 'atom'
    new BufferedProcess({command, args, stdout, exit})
