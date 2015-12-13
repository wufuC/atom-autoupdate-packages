main = require './main'
updateHandler = null


module.exports =

  announceUpdates: (pendingUpdates, saySomething, actionRequired) ->
    # generate a message object
    message =
      @generateNotificationMsg pendingUpdates, saySomething, actionRequired
    # populate content of notification bubble
    bubbleHeading = message.title
    bubbleOptions = {'detail': message.content, 'dismissable': actionRequired}
    # post notification bubble
    updateNotification = atom.notifications.addInfo bubbleHeading, bubbleOptions
    # trigger confirmation dialog if required
    if actionRequired
      confirmMsg = @generateConfirmMsg(pendingUpdates)
      updateNotification.onDidDismiss -> atom.confirm(confirmMsg)


  generateNotificationMsg: (pendingUpdates, saySomething, actionRequired) ->
    multipleUpdates = pendingUpdates.length > 1
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
    for updatable in pendingUpdates
      contentText += "  #{updatable.packageName} #{updatable.fromVersion} ->
                      #{updatable.toVersion}\n"
    messageObj =
      title: titleText
      content: contentText
    return messageObj


  generateConfirmMsg: (pendingUpdates) ->
    multipleUpdates = pendingUpdates.length > 1
    confimMsgObj =
      message: "Update the package#{if multipleUpdates then 's' else ''} now?"
      buttons:
        'Yes': ->
          main.verboseMsg 'confirm prompt -> proceed'
          updateHandler ?= require './update-handler'
          updateHandler.startUpdating(pendingUpdates)
        'Not now': ->
          main.verboseMsg 'confirm prompt -> pass'
    # if multiple updates are available generate an extra button that open
    #   the `Updates pane` of `settings-view`
    if multipleUpdates
      confimMsgObj.buttons['Let me choose what to update'] = ->
        main.verboseMsg 'confirm prompt -> opening settings-view'
        atom.commands.dispatch(
          atom.views.getView(atom.workspace),
          'settings-view:check-for-package-updates'
        )
    return confimMsgObj


  announceSuccessfulUpdate: (apmInstallMsg) ->
    atom.notifications.addSuccess(
      "Package has been updated successfully"
      {'detail': "APM output:\n#{apmInstallMsg}", dimissable: false}
    )


  announceFailedUpdate: (apmInstallMsg) ->
    atom.notifications.addWarning(
      "Update failed"
      {'detail': "APM output:\n#{apmInstallMsg}\n
        This could be due to network problem. Please submit a bug report if
        this problem persists.", dimissable: true}
    )
