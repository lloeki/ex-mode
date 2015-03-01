path = require 'path'

trySave = (func) ->
  deferred = Promise.defer()

  try
    func()
    deferred.resolve()
  catch error
    if error.message.endsWith('is a directory')
      atom.notifications.addWarning("Unable to save file: #{error.message}")
    else if error.code is 'EACCES' and error.path?
      atom.notifications.addWarning("Unable to save file: Permission denied '#{error.path}'")
    else if error.code in ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST'] and error.path?
      atom.notifications.addWarning("Unable to save file '#{error.path}'", detail: error.message)
    else if error.code is 'EROFS' and error.path?
      atom.notifications.addWarning("Unable to save file: Read-only file system '#{error.path}'")
    else if errorMatch = /ENOTDIR, not a directory '([^']+)'/.exec(error.message)
      fileName = errorMatch[1]
      atom.notifications.addWarning("Unable to save file: A directory in the path '#{fileName}' could not be written to")
    else
      throw error

  deferred.promise

class Ex
  @singleton: =>
    @ex ||= new Ex

  @registerCommand: (name, func) =>
    @singleton()[name] = func

  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  q: => @quit()

  tabedit: (filePaths...) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      for file in filePaths
        do -> atom.workspace.openURIInPane file, pane
    else
      atom.workspace.openURIInPane('', pane)

  tabe: (filePaths...) => @tabedit(filePaths...)

  tabnew: (filePaths...) => @tabedit(filePaths...)

  tabclose: => @quit()

  tabc: => @tabclose()

  tabnext: ->
    pane = atom.workspace.getActivePane()
    pane.activateNextItem()

  tabn: => @tabnext()

  tabprevious: ->
    pane = atom.workspace.getActivePane()
    pane.activatePreviousItem()

  tabp: => @tabprevious()

  edit: (filePath) => @tabedit(filePath) if filePath?

  e: (filePath) => @edit(filePath)

  enew: => @edit()

  write: (filePath) ->
    deferred = Promise.defer()

    projectPath = atom.project.getPath()
    pane = atom.workspace.getActivePane()
    editor = atom.workspace.getActiveEditor()
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      if filePath?
        editorPath = editor.getPath()
        fullPath = if path.isAbsolute(filePath)
          filePath
        else
          path.join(projectPath, filePath)
        trySave(-> editor.saveAs(fullPath))
          .then ->
            deferred.resolve()
        editor.buffer.setPath(editorPath)
      else
        trySave(-> editor.save())
          .then deferred.resolve
    else
      if filePath?
        fullPath = if path.isAbsolute(filePath)
          filePath
        else
          path.join(projectPath, filePath)
        trySave(-> editor.saveAs(fullPath))
          .then deferred.resolve
      else
        fullPath = atom.showSaveDialogSync()
        if fullPath?
          trySave(-> editor.saveAs(fullPath))
            .then deferred.resolve

    deferred.promise

  w: (filePath) =>
    @write(filePath)

  wq: (filePath) =>
    @write(filePath).then => @quit()
  
  x: => @wq()

  wa: ->
    atom.workspace.saveAll()

  split: (filePaths...) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitUp()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitUp(copyActiveItem: true)

  sp: (filePaths...) => @split(filePaths...)

  vsplit: (filePaths...) ->
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitLeft()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitLeft(copyActiveItem: true)

  vsp: (filePaths...) => @vsplit(filePaths...)

module.exports = Ex
