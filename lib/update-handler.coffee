{BufferedProcess} = require 'atom'


module.exports =
  runCommand: (args, callback) ->
    command = atom.packages.getApmPath()
    outputs = []
    stdout = (output) ->
      outputs.push(output)
    exit = ->
      callback(outputs)
    new BufferedProcess({command, args, stdout, exit})


  parseAPMOutputJSON: (apmOutputJSON) ->
    try
      availableUpdates = JSON.parse(apmOutputJSON)
    catch error
      availableUpdates = null
      console.log "autoupdate-packages: Error parsing APM output.\n
                   #{apmOutputJSON}"
      return
    for availableUpdate in availableUpdates
      'name': availableUpdate.name
      'installedVersion': availableUpdate.version
      'latestVersion': availableUpdate.latestVersion


  getOutdated: (callback) ->
    args = ['outdated', '--json', '--no-color']
    updatables = null
    @runCommand args, (outdatedPkgsJSON) =>
      updatables = @parseAPMOutputJSON(outdatedPkgsJSON)
      callback(updatables)


  processPendingUpdates: (pendingUpdates) ->
    for pendingUpdate in pendingUpdates
      args = ['install'
              '--no-color'
              "#{pendingUpdate.name}@#{pendingUpdate.latestVersion}"]
      @runCommand args, (apmInstallMsg) =>
        if apmInstallMsg.indexOf('✓')
          atom.notifications.addSuccess(
            "Package has been updated successfully",
            {'detail': "APM output:\n  #{apmInstallMsg}", dimissable: false}
            )
        else
          atom.notifications.addWarning(
            "Update failed",
            {'detail': "APM output:\n  #{apmInstallMsg}", dimissable: true}
            )
        console.log("autoupdate-packages: APM output: #{apmInstallMsg}")
