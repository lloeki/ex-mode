path = require 'path'
CommandError = require './command-error'
fs = require 'fs-plus'
VimOption = require './vim-option'

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

saveAs = (filePath) ->
  editor = atom.workspace.getActiveTextEditor()
  fs.writeFileSync(filePath, editor.getText())

getFullPath = (filePath) ->
  filePath = fs.normalize(filePath)

  if path.isAbsolute(filePath)
    filePath
  else if atom.project.getPaths().length == 0
    path.join(fs.normalize('~'), filePath)
  else
    path.join(atom.project.getPaths()[0], filePath)

replaceGroups = (groups, string) ->
  replaced = ''
  escaped = false
  while (char = string[0])?
    string = string[1..]
    if char is '\\' and not escaped
      escaped = true
    else if /\d/.test(char) and escaped
      escaped = false
      group = groups[parseInt(char)]
      group ?= ''
      replaced += group
    else
      escaped = false
      replaced += char

  replaced

class Ex
  @singleton: =>
    @ex ||= new Ex

  @registerCommand: (name, func) =>
    @singleton()[name] = func

  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  q: => @quit()

  tabedit: (range, args) =>
    if args.trim() isnt ''
      @edit(range, args)
    else
      @tabnew(range, args)

  tabe: (args...) => @tabedit(args...)

  tabnew: (range, args) =>
    if args.trim() is ''
      atom.workspace.open()
    else
      @tabedit(range, args)

  tabclose: (args...) => @quit(args...)

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
    if filePath[0] is '!'
      force = true
      filePath = filePath[1..].trim()
    else
      force = false

    editor = atom.workspace.getActiveTextEditor()
    if editor.isModified() and not force
      throw new CommandError('No write since last change (add ! to override)')
    if filePath.indexOf(' ') isnt -1
      throw new CommandError('Only one file name allowed')

    if filePath.length isnt 0
      fullPath = getFullPath(filePath)
      if fullPath is editor.getPath()
        editor.getBuffer().reload()
      else
        atom.workspace.open(fullPath)
    else
      if editor.getPath()?
        editor.getBuffer().reload()
      else
        throw new CommandError('No file name')

  e: (args...) => @edit(args...)

  enew: ->
    buffer = atom.workspace.getActiveTextEditor().buffer
    buffer.setPath(undefined)
    buffer.load()

  write: (range, filePath) ->
    if filePath[0] is '!'
      force = true
      filePath = filePath[1..]
    else
      force = false

    filePath = filePath.trim()
    if filePath.indexOf(' ') isnt -1
      throw new CommandError('Only one file name allowed')

    deferred = Promise.defer()

    editor = atom.workspace.getActiveTextEditor()
    saved = false
    if filePath.length isnt 0
      fullPath = getFullPath(filePath)
    if editor.getPath()? and (not fullPath? or editor.getPath() == fullPath)
      # Use editor.save when no path is given or the path to the file is given
      trySave(-> editor.save()).then(deferred.resolve)
      saved = true
    else if not fullPath?
      fullPath = atom.showSaveDialogSync()

    if not saved and fullPath?
      if not force and fs.existsSync(fullPath)
        throw new CommandError("File exists (add ! to override)")
      trySave(-> saveAs(fullPath)).then(deferred.resolve)

    deferred.promise

  w: (args...) =>
    @write(args...)

  wq: (args...) =>
    @write(args...).then => @quit()

  xit: (args...) => @wq(args...)

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
    notDelimRE = new RegExp("\\\\#{delim}", 'g')
    spl[0] = spl[0].replace(notDelimRE, delim)
    spl[1] = spl[1].replace(notDelimRE, delim)

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
    atom.workspace.getActiveTextEditor().transact ->
      for line in [range[0]..range[1]]
        buffer.scanInRange(pattern,
          [[line, 0], [line, buffer.lines[line].length]],
          ({match, matchText, range, stop, replace}) ->
            replace(replaceGroups(match[..], spl[1]))
        )

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

  set: (range, args) ->
    args = args.trim()
    if args == ""
      throw new CommandError("No option specified")
    options = args.split(' ')
    for option in options
      do ->
        if option.includes("=")
          nameValPair = option.split("=")
          if (nameValPair.length != 2)
            throw new CommandError("Wrong option format. [name]=[value] format is expected")
          optionName = nameValPair[0]
          optionValue = nameValPair[1]
          optionProcessor = VimOption.singleton()[optionName]
          if not optionProcessor?
            throw new CommandError("No such option: #{optionName}")
          optionProcessor(optionValue)
        else
          optionProcessor = VimOption.singleton()[option]
          if not optionProcessor?
            throw new CommandError("No such option: #{option}")
          optionProcessor()

module.exports = Ex
