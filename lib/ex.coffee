class Ex
  write: -> atom.workspace.getActiveEditor().save()
  w: => @write()

module.exports = Ex
