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
      contentText += "  #{updatable.packageName} #{updatable.fromVersion} ->
                      #{updatable.toVersion}\n"
    messageObj =
      title: titleText
      content: contentText
    return messageObj


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


  announceUpgradeOutcome: (apmInstallMsg, updateTicket) ->
    if apmInstallMsg.indexOf('✓')
      if main.userChosen.notifyMe
        atom.notifications.addSuccess(
          "Package has been updated successfully"
          {'detail': "APM output:\n#{apmInstallMsg}", dimissable: false}
        )
      updateTicket.addToHistory()
    else
      atom.notifications.addWarning(
        "Update failed"
        {'detail': "APM output:\n#{apmInstallMsg}\n
          This could be due to network problem. Please submit a bug report if
          this problem persists.", dimissable: true}
      )
    main.verboseMsg "APM output: #{apmInstallMsg}"
