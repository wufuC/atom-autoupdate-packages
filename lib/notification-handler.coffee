main = require './main'
updateHandler = null


module.exports =
  generateNotificationMsg: (listOfUpdates, saySomething, actionRequired) ->
    multipleUpdates = listOfUpdates.length > 1
    titleText = "New version#{if multipleUpdates then 's' else ''} available"
    if saySomething
      contentText = if actionRequired then "
        Would you like to update the following
        package#{if multipleUpdates then 's' else ''}?\n
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
          main.verboseMsg 'confirm prompt -> proceed'
          updateHandler ?= require './update-handler'
          updateHandler.processPendingUpdates(listOfUpdates)
        'Not now': ->
          main.verboseMsg 'confirm prompt -> pass'
    if multipleUpdates
      confimMsgObj.buttons['Let me choose what to update'] = ->
        atom.commands.dispatch(
          atom.views.getView(atom.workspace),
          'settings-view:check-for-package-updates'
          )
        main.verboseMsg 'confirm prompt -> opening settings-view'
    return confimMsgObj


  announceUpdates: (listOfUpdates, saySomething, actionRequired, confirmMsg) ->
    message =
      @generateNotificationMsg(listOfUpdates, saySomething, actionRequired)
    bubbleHeading = message.title
    bubbleOptions = {'detail': message.content, 'dismissable': actionRequired}
    updateNotification =
      atom.notifications.addInfo(bubbleHeading, bubbleOptions)
    if actionRequired and confirmMsg?
      updateNotification.onDidDismiss -> atom.confirm(confirmMsg)
