{BufferedProcess} = require 'atom'


module.exports =
  generateNotificationMsg: (listOfUpdates, saySomething, actionRequired) ->
    multipleUpdates = listOfUpdates.length > 1
    titleText = "New version#{if multipleUpdates then 's' else ''} available"
    if saySomething
      contentText = if actionRequired then "
        Would you like to update the following package#{if multipleUpdates then 's' else ''}?\n
        (Dimiss to proceed)\n
        " else '
        Now updating:\n
        '
    else
      contentText = ''
    for updatable in listOfUpdates
      contentText += "  #{updatable.name} #{updatable.installedVersion} -> 
                      #{updatable.latestVersion}\n"
    messageObj =
      title: titleText
      content: contentText
    return messageObj


  # Compose the content of the confirmation diaglogue. Called by
  #   `main/summonNotifier`
  generateConfirmMsg: (listOfUpdates) ->
    multipleUpdates = listOfUpdates.length > 1
    confimMsgObj = 
      message: "Update the package#{if multipleUpdates then 's' else ''} now?"
      buttons:
        'Yes': ->
          require('./main').summonUpdater(listOfUpdates)
        'Not now': ->
          return
    if multipleUpdates
      confimMsgObj.buttons['Let me choose what to update'] = ->
        atom.commands.dispatch(
          atom.views.getView(atom.workspace),
          'settings-view:check-for-package-updates'
          )
    return confimMsgObj


  announceUpdates: (listOfUpdates, saySomething, actionRequired, confirmMsg) ->
    message = @generateNotificationMsg(listOfUpdates, saySomething, actionRequired)
    bubbleHeading = message.title
    bubbleOptions = {'detail': message.content, 'dismissable': actionRequired}
    updateNotification = atom.notifications.addInfo(bubbleHeading, bubbleOptions)
    if actionRequired and confirmMsg?
      updateNotification.onDidDismiss -> atom.confirm(confirmMsg)


  # HACK
  # Remove the blue package icon at the bottom-righthand corner of the window
  #   It would be better to retrieve the `PackageUpdatesStatusView` (a `Tile` object)
  #   from the status-bar service and `dispose()` it cleanly.
  #   But I have yet to identify how to do so. Note: This object is not
  #   immediately available when consumestatusBar() is being executed.
  #   The activating `setting-view` module launch APM and waits for its
  #   output, then generates this object if update(s) is/are found.
  removeStatusbarUpdateIcon: ->
    for bottomPanel in window.atom.workspace.panelContainers.bottom.panels
      for tile in bottomPanel.item.rightTiles
        if tile.item.constructor.name is 'PackageUpdatesStatusView'
          tile.destroy() 
          return true


  suppressStatusbarUpdateIcon: ->
    TIMEOUT = 2 * 60 * 1000
    invokeTime = Date.now()
    monitorID = setInterval (->
      removed = @removeStatusbarUpdateIcon()
      if removed or (Date.now() - invokeTime > TIMEOUT)
        clearInterval(monitorID)
      ).bind(this), 100
