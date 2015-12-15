main = require './main'
notificationHandler = null
UpdateTicket = null


module.exports =
  getOutdated: ->
    args = ['outdated', '--json', '--no-color']
    @runAPM args, (apmOutdatedJSON) =>
      pendingUpdates = @parseAPMOutdatedJSON(apmOutdatedJSON)
      if pendingUpdates?.length > 0
        main.verboseMsg "#{pendingUpdates.length}
                      update#{if pendingUpdates.length > 1 then 's' else ''}
                      found"
        @summonNotifier(pendingUpdates) if main.userChosen.notifyMe
        @startUpdating(pendingUpdates) if main.userChosen.autoUpdate
      else
        main.verboseMsg "No update(s) found"


  parseAPMOutdatedJSON: (apmOutdatedJSON) ->
    try
      availableUpdates = JSON.parse(apmOutdatedJSON)
      for availableUpdate in availableUpdates
        if availableUpdate.name in main.userChosen.blacklistedPackages
          main.verboseMsg "Newer version of `#{availableUpdate.name}` has been
                            found but ignored. See `Settings`."
        else
          UpdateTicket ?= require './update-ticket'
          return new UpdateTicket availableUpdate
    catch error
      main.verboseMsg "Error parsing APM output.\n #{apmOutdatedJSON}"


  # specify the content of the notification bubble
  summonNotifier: (pendingUpdates) ->
    main.verboseMsg 'Posting notification'
    notificationHandler ?= require './notification-handler'
    notificationHandler.announceUpdates(
      updatables = pendingUpdates
      saySomething = main.userChosen.autoUpdate or main.userChosen.confirmAction
      actionRequired = main.userChosen.confirmAction
    )


  startUpdating: (pendingUpdates) ->
    for updateTicket in pendingUpdates
      updateTicket.update()


  runAPM: (args, callback, callbackOptions) ->
    command = atom.packages.getApmPath()
    outputs = []
    stdout = (output) ->
      outputs.push(output)
    exit = ->
      callback(outputs, callbackOptions)
    {BufferedProcess} = require 'atom'
    new BufferedProcess({command, args, stdout, exit})
