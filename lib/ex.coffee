class Ex
  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()
  q: =>
    @quit()
  tabedit: (filenames) ->
    if filenames? and filenames.length > 0
      atom.open(pathsToOpen: filenames)
    else
      atom.open()
  tabe: (filenames) =>
    @tabedit(filenames)
  write: (close=false) =>
    if close
      nextAction = ->
        atom.notifications.addSuccess("Saved and closed")
        atom.workspace.getActivePane().destroyActiveItem()
    else
      nextAction = ->
        atom.notifications.addSuccess("Saved")

    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      atom.workspace.getActivePane().saveItem(atom.workspace.getActivePane().getActiveItem(), nextAction)
    else
      atom.workspace.getActivePane().saveActiveItemAs(nextAction)
  w: => @write()
  wq: =>
    @write(close=true)

module.exports = Ex
