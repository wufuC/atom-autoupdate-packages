{BufferedProcess} = require 'atom'

module.exports =
  generateMsg: (updatables, saySomething, actionRequired) ->
    header = "New #{if updatables.length == 1 then 'version' else 'versions'} available"
    if saySomething
      details = if actionRequired then 'Would you like to update the following package(s)?\n(Dimiss to proceed)\n' else 'Now updating...\n'
    else
      details = ''
    for updatable in updatables
      details += "  #{updatable.name} #{updatable.installedVersion} -> #{updatable.latestVersion}\n"
    return [header, details]


  announceUpdates: (updatables, saySomething, actionRequired, confirmMsg) ->
    message = {}
    [message.header, message.detail] = @generateMsg(updatables, saySomething, actionRequired)
    if message.header? and message.detail?
      heading = message.header
      options = {'detail': message.detail, 'dismissable': actionRequired}
      updateNotification = atom.notifications.addInfo(heading, options)
    if actionRequired and confirmMsg?
      updateNotification.onDidDismiss( -> atom.confirm(confirmMsg) )
