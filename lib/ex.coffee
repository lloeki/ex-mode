class Ex
  write: ->
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      atom.workspace.getActiveEditor().save()
    else
      atom.workspace.getActivePane().saveActiveItemAs()

  w: => @write()
  wa: ->
    atom.workspace.saveAll()

  split: (filePaths) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitUp()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitUp(copyActiveItem: true)

  sp: (filePaths) => @split(filePaths)

  vsplit: (filePaths) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitLeft()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitLeft(copyActiveItem: true)

  vsp: (filePaths) => @vsplit(filePaths)

module.exports = Ex
