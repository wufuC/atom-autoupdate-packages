main = require './main'
notificationHandler = null


class UpdateTicket
  constructor: (apmJSONRecord) ->
    @packageName = apmJSONRecord.name
    @fromVersion = apmJSONRecord.version
    @toVersion = apmJSONRecord.latestVersion


  addToHistory: ->
    updateHistory = JSON.parse(main.getConfig 'updateHistory')
    updateHistory[Date.now()] = this
    updateHistory = @pruneUpdateHistory(updateHistory)
    updateHistory = JSON.stringify(updateHistory)
    atom.config.set 'autoupdate-packages.updateHistory', updateHistory


  pruneUpdateHistory: (updateHistoryObject) ->
    d = new Date()
    d.setDate(d.getDate() - 30)
    for entryDate in Object.keys(updateHistoryObject)
      if entryDate < d
        delete updateHistoryObject[entryDate]
    return updateHistoryObject



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
      args = ['install'
              '--no-color'
              "#{updateTicket.packageName}@#{updateTicket.toVersion}"]
      @runCommand(
        args=args,
        callback=@handleAPMOutcome,
        callbackOptions=updateTicket
        )


  handleAPMOutcome: (apmInstallMsg, updateTicket) ->
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpgradeOutcome(apmInstallMsg, updateTicket)


  runCommand: (args, callback, callbackOptions) ->
    command = atom.packages.getApmPath()
    outputs = []
    stdout = (output) ->
      outputs.push(output)
    exit = ->
      callback(outputs, callbackOptions)
    {BufferedProcess} = require 'atom'
    new BufferedProcess({command, args, stdout, exit})
