path = require 'path'

class Ex
  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()
  q: =>
    @quit()
  tabedit: (filePaths...) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      for file in filePaths
        do -> atom.workspace.openURIInPane file, pane
    else
      atom.workspace.openURIInPane('', pane)
  tabe: (filePaths...) =>
    @tabedit(filePaths...)
  write: (filePath) =>
    projectPath = atom.project.getPath()
    pane = atom.workspace.getActivePane()
    editor = atom.workspace.getActiveEditor()
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      if filePath?
        editorPath = editor.getPath()
        editor.saveAs(path.join(projectPath, filePath))
        editor.buffer.setPath(editorPath)
      else
        editor.save()
    else
      if filePath?
        editor.saveAs(path.join(projectPath, filePath))
      else
        pane.saveActiveItemAs()
  w: (filePath) => @write(filePath)

module.exports = Ex
