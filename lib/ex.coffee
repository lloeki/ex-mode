class Ex
  write: ->
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      atom.workspace.getActiveEditor().save()
    else
      atom.workspace.getActivePane().saveActiveItemAs()
  w: => @write()
  wa: ->
    atom.workspace.saveAll()

module.exports = Ex
