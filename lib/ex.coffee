class Ex
  write: ->
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      atom.workspace.getActiveEditor().save()
    else
      atom.workspace.getActivePane().saveActiveItemAs()
  w: => @write()

module.exports = Ex
