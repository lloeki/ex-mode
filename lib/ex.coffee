path = require 'path'
CommandError = require './command-error'

trySave = (func) ->
  deferred = Promise.defer()

  try
    func()
    deferred.resolve()
  catch error
    if error.message.endsWith('is a directory')
      atom.notifications.addWarning("Unable to save file: #{error.message}")
    else if error.path?
      if error.code is 'EACCES'
        atom.notifications
          .addWarning("Unable to save file: Permission denied '#{error.path}'")
      else if error.code in ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST']
        atom.notifications.addWarning("Unable to save file '#{error.path}'",
          detail: error.message)
      else if error.code is 'EROFS'
        atom.notifications.addWarning(
          "Unable to save file: Read-only file system '#{error.path}'")
    else if (errorMatch =
        /ENOTDIR, not a directory '([^']+)'/.exec(error.message))
      fileName = errorMatch[1]
      atom.notifications.addWarning("Unable to save file: A directory in the "+
        "path '#{fileName}' could not be written to")
    else
      throw error

  deferred.promise

getFullPath = (filePath) ->
  return filePath if path.isAbsolute(filePath)
  return path.join(atom.project.getPath(), filePath)

replaceGroups = (groups, replString) ->
  arr = replString.split('')
  offset = 0
  cdiff = 0

  while (m = replString.match(/(?:[^\\]|^)\\(\d)/))?
    group = groups[m[1]] or ''
    i = replString.indexOf(m[0])
    l = m[0].length
    replString = replString.slice(i + l)
    arr[i + offset...i + offset + l] = (if l is 2 then '' else m[0][0]) +
      group
    arr = arr.join('').split ''
    offset += i + l - group.length

  return arr.join('').replace(/\\\\(\d)/, '\\$1')

class Ex
  @singleton: =>
    @ex ||= new Ex

  @registerCommand: (name, func) =>
    @singleton()[name] = func

  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  q: => @quit()

  tabedit: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      for file in filePaths
        do -> atom.workspace.openURIInPane file, pane
    else
      atom.workspace.openURIInPane('', pane)

  tabe: (args...) => @tabedit(args...)

  tabnew: (args...) => @tabedit(args...)

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

  edit: (range, filePath) ->
    filePath = filePath.trim()
    if filePath.indexOf(' ') isnt -1
      throw new CommandError('Only one file name allowed')
    buffer = atom.workspace.getActiveTextEditor().buffer
    filePath = buffer.getPath() if filePath is ''
    buffer.setPath(getFullPath(filePath))
    buffer.load()

  e: (args...) => @edit(args...)

  enew: ->
    buffer = atom.workspace.getActiveTextEditor().buffer
    buffer.setPath(undefined)
    buffer.load()

  write: (range, filePath) ->
    filePath = filePath.trim()
    deferred = Promise.defer()

    pane = atom.workspace.getActivePane()
    editor = atom.workspace.getActiveTextEditor()
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      if filePath.length > 0
        editorPath = editor.getPath()
        fullPath = getFullPath(filePath)
        trySave(-> editor.saveAs(fullPath))
          .then ->
            deferred.resolve()
        editor.buffer.setPath(editorPath)
      else
        trySave(-> editor.save())
          .then deferred.resolve
    else
      if filePath.length > 0
        fullPath = getFullPath(filePath)
        trySave(-> editor.saveAs(fullPath))
          .then deferred.resolve
      else
        fullPath = atom.showSaveDialogSync()
        if fullPath?
          trySave(-> editor.saveAs(fullPath))
            .then deferred.resolve

    deferred.promise

  w: (args...) =>
    @write(args...)

  wq: (args...) =>
    @write(args...).then => @quit()

  x: (args...) => @wq(args...)

  wa: ->
    atom.workspace.saveAll()

  split: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitUp()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitUp(copyActiveItem: true)

  sp: (args...) => @split(args...)

  substitute: (range, args) ->
    args = args.trimLeft()
    delim = args[0]
    if /[a-z]/i.test(delim)
      throw new CommandError(
        "Regular expressions can't be delimited by letters")
    delimRE = new RegExp("[^\\\\]#{delim}")
    spl = []
    args_ = args[1..]
    while (i = args_.search(delimRE)) isnt -1
      spl.push args_[..i]
      args_ = args_[i + 2..]
    if args_.length is 0 and spl.length is 3
      throw new CommandError('Trailing characters')
    else if args_.length isnt 0
      spl.push args_
    if spl.length > 3
      throw new CommandError('Trailing characters')
    spl[1] ?= ''
    spl[2] ?= ''

    try
      pattern = new RegExp(spl[0], spl[2])
    catch e
      if e.message.indexOf('Invalid flags supplied to RegExp constructor') is 0
        # vim only says 'Trailing characters', but let's be more descriptive
        throw new CommandError("Invalid flags: #{e.message[45..]}")
      else if e.message.indexOf('Invalid regular expression: ') is 0
        throw new CommandError("Invalid RegEx: #{e.message[27..]}")
      else
        throw e

    buffer = atom.workspace.getActiveTextEditor().buffer
    cp = buffer.history.createCheckpoint()
    for line in [range[0]..range[1]]
      buffer.scanInRange(pattern,
        [[line, 0], [line, buffer.lines[line].length]],
        ({match, matchText, range, stop, replace}) ->
          replace(replaceGroups(match[..], spl[1]))
      )
    buffer.history.groupChangesSinceCheckpoint(cp)

  s: (args...) => @substitute(args...)

  vsplit: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitLeft()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitLeft(copyActiveItem: true)

  vsp: (args...) => @vsplit(args...)

  delete: (range) ->
    range = [[range[0], 0], [range[1] + 1, 0]]
    atom.workspace.getActiveTextEditor().buffer.setTextInRange(range, '')

module.exports = Ex
