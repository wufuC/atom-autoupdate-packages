main = require './main'

notificationHandler = null


module.exports =
  getOutdated: ->
    args = ['outdated', '--json', '--no-color']
    @runCommand args, (outdatedPkgsJSON) =>
      updatables = @parseAPMOutputJSON(outdatedPkgsJSON)
      @setPendingUpdates(updatables) if updatables?


  parseAPMOutputJSON: (apmOutputJSON) ->
    try
      availableUpdates = JSON.parse(apmOutputJSON)
    catch error
      @verboseMsg " Error parsing APM output.\n #{apmOutputJSON}"
      return
    for availableUpdate in availableUpdates
      'name': availableUpdate.name
      'installedVersion': availableUpdate.version
      'latestVersion': availableUpdate.latestVersion


  setPendingUpdates: (pendingUpdates) ->
    if pendingUpdates? and (pendingUpdates.length > 0)
      @verboseMsg "#{pendingUpdates.length}
                    update#{if pendingUpdates.length > 1 then 's' else ''}
                    found"
      @summonNotifier(pendingUpdates) if main.userChosen.notifyMe
      @processPendingUpdates(pendingUpdates) if main.userChosen.autoUpdate
    else
      @verboseMsg "No update(s) found"


  # Specify the content of the notification bubble. Called by
  #   `@setPendingUpdates` if `main.userChosen.notifyMe` is true
  summonNotifier: (pendingUpdates) ->
    @verboseMsg 'Posting notification'
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpdates(
      updatables = pendingUpdates
      saySomething = main.userChosen.autoUpdate or main.userChosen.confirmAction
      actionRequired = main.userChosen.confirmAction
      confirmMsg = if main.userChosen.confirmAction then notificationHandler.
        generateConfirmMsg(pendingUpdates) else null
    )


  processPendingUpdates: (pendingUpdates) ->
    for pendingUpdate in pendingUpdates
      args = ['install'
              '--no-color'
              "#{pendingUpdate.name}@#{pendingUpdate.latestVersion}"]
      @runCommand args, (apmInstallMsg) =>
        if apmInstallMsg.indexOf('✓') and main.userChosen.notifyMe
          atom.notifications.addSuccess(
            "Package has been updated successfully",
            {'detail': "APM output:\n#{apmInstallMsg}", dimissable: false}
            )
        else if not apmInstallMsg.indexOf('✓')
          atom.notifications.addWarning(
            "Update failed",
            {'detail': "APM output:\n#{apmInstallMsg}", dimissable: true}
            )
        @verboseMsg "APM output: #{apmInstallMsg}"


  runCommand: (args, callback) ->
    command = atom.packages.getApmPath()
    outputs = []
    stdout = (output) ->
      outputs.push(output)
    exit = ->
      callback(outputs)
    {BufferedProcess} = require 'atom'
    new BufferedProcess({command, args, stdout, exit})


  verboseMsg: (msg, forced = false) ->
    main.verboseMsg msg, forced
