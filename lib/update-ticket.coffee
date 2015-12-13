main = require './main'
updateHandler = null
# notificationHandler = null

module.exports =

class UpdateTicket
  constructor: (apmJSONRecord) ->
    @packageName = apmJSONRecord.name
    @fromVersion = apmJSONRecord.version
    @toVersion = apmJSONRecord.latestVersion


  update: ->
    args = ['install'
            '--no-color'
            "#{@packageName}@#{@toVersion}"]
    updateHandler = require './update-handler'
    updateHandler.runCommand(
      args = args,
      callback = updateHandler.handleAPMOutcome,
      callbackOptions = this
      )


  restore: ->
    args = ['install'
            '--no-color'
            "#{@packageName}@#{@fromVersion}"]
    updateHandler = require './update-handler'
    updateHandler.runCommand(
      args = args,
      callback = updateHandler.handleAPMOutcome,
      callbackOptions = this
      )


  addToHistory: ->
    updateHistory = JSON.parse(main.getConfig 'updateHistory')
    updateHistory[Date.now()] = this
    main.setConfig 'updateHistory', JSON.stringify(updateHistory)
