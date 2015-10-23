{BufferedProcess} = require 'atom'

module.exports =
  generateMsg: (updatables, saySomething, actionRequired) ->
    titleText = "New #{if updatables.length == 1 then 'version' else 'versions'} available"
    if saySomething
      contentText = if actionRequired then '
        Would you like to update the following package(s)?\n
        (Dimiss to proceed)\n
        ' else '
        Now updating...\n
        '
    else
      contentText = ''
    for updatable in updatables
      contentText += "  #{updatable.name} #{updatable.installedVersion} -> 
                      #{updatable.latestVersion}\n"
    messageObj =
      title: titleText
      content: contentText
    return messageObj


  announceUpdates: (updatables, saySomething, actionRequired, confirmMsg) ->
    message = @generateMsg(updatables, saySomething, actionRequired)
    _heading = message.title
    _options = {'detail': message.content, 'dismissable': actionRequired}
    updateNotification = atom.notifications.addInfo(_heading, _options)
    if actionRequired and confirmMsg?
      updateNotification.onDidDismiss( -> atom.confirm(confirmMsg) )
