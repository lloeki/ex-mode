path = require 'path'
CommandError = require './command-error'
fs = require 'fs-plus'
VimOption = require './vim-option'
_ = require 'underscore-plus'

defer = () ->
  deferred = {}
  deferred.promise = new Promise((resolve, reject) ->
    deferred.resolve = resolve
    deferred.reject = reject
  )
  return deferred


trySave = (func) ->
  deferred = defer()

  try
    response = func()

    if response instanceof Promise
      response.then ->
        deferred.resolve()
    else
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

saveAs = (filePath, editor) ->
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

getSearchTerm = (term, modifiers = {'g': true}) ->

  escaped = false
  hasc = false
  hasC = false
  term_ = term
  term = ''
  for char in term_
    if char is '\\' and not escaped
      escaped = true
      term += char
    else
      if char is 'c' and escaped
        hasc = true
        term = term[...-1]
      else if char is 'C' and escaped
        hasC = true
        term = term[...-1]
      else if char isnt '\\'
        term += char
      escaped = false

  if hasC
    modifiers['i'] = false
  if (not hasC and not term.match('[A-Z]') and \
      atom.config.get('vim-mode.useSmartcaseForSearch')) or hasc
    modifiers['i'] = true

  modFlags = Object.keys(modifiers).filter((key) -> modifiers[key]).join('')

  try
    new RegExp(term, modFlags)
  catch
    new RegExp(_.escapeRegExp(term), modFlags)

class Ex
  @singleton: =>
    @ex ||= new Ex

  @registerCommand: (name, func) =>
    @singleton()[name] = func

  @registerAlias: (alias, name) =>
    @singleton()[alias] = (args) => @singleton()[name](args)

  @getCommands: () =>
    Object.keys(Ex.singleton()).concat(Object.keys(Ex.prototype)).filter((cmd, index, list) ->
      list.indexOf(cmd) == index
    )

  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  quitall: ->
    atom.close()

  q: => @quit()

  qall: => @quitall()

  tabedit: (args) =>
    if args.args.trim() isnt ''
      @edit(args)
    else
      @tabnew(args)

  tabe: (args) => @tabedit(args)

  tabnew: (args) =>
    if args.args.trim() is ''
      atom.workspace.open()
    else
      @tabedit(args)

  tabclose: (args) => @quit(args)

  tabc: => @tabclose()

  tabnext: ->
    pane = atom.workspace.getActivePane()
    pane.activateNextItem()

  tabn: => @tabnext()

  tabprevious: ->
    pane = atom.workspace.getActivePane()
    pane.activatePreviousItem()

  tabp: => @tabprevious()

  tabonly: ->
    tabBar = atom.workspace.getPanes()[0]
    tabBarElement = atom.views.getView(tabBar).querySelector(".tab-bar")
    tabBarElement.querySelector(".right-clicked") && tabBarElement.querySelector(".right-clicked").classList.remove("right-clicked")
    tabBarElement.querySelector(".active").classList.add("right-clicked")
    atom.commands.dispatch(tabBarElement, 'tabs:close-other-tabs')
    tabBarElement.querySelector(".active").classList.remove("right-clicked")

  tabo: => @tabonly()

  edit: ({ range, args, editor }) ->
    filePath = args.trim()
    if filePath[0] is '!'
      force = true
      filePath = filePath[1..].trim()
    else
      force = false

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

  e: (args) => @edit(args)

  enew: ->
    buffer = atom.workspace.getActiveTextEditor().buffer
    buffer.setPath(undefined)
    buffer.load()

  write: ({ range, args, editor, saveas }) ->
    saveas ?= false
    filePath = args
    if filePath[0] is '!'
      force = true
      filePath = filePath[1..]
    else
      force = false

    filePath = filePath.trim()
    if filePath.indexOf(' ') isnt -1
      throw new CommandError('Only one file name allowed')

    deferred = defer()

    editor = atom.workspace.getActiveTextEditor()
    saved = false
    if filePath.length isnt 0
      fullPath = getFullPath(filePath)
    if editor.getPath()? and (not fullPath? or editor.getPath() == fullPath)
      if saveas
        throw new CommandError("Argument required")
      else
        # Use editor.save when no path is given or the path to the file is given
        trySave(-> editor.save()).then(deferred.resolve)
        saved = true
    else if not fullPath?
      fullPath = atom.showSaveDialogSync()

    if not saved and fullPath?
      if not force and fs.existsSync(fullPath)
        throw new CommandError("File exists (add ! to override)")
      if saveas or editor.getFileName() == null
        editor = atom.workspace.getActiveTextEditor()
        trySave(-> editor.saveAs(fullPath, editor)).then(deferred.resolve)
      else
        trySave(-> saveAs(fullPath, editor)).then(deferred.resolve)

    deferred.promise

  wall: ->
    atom.workspace.saveAll()

  w: (args) =>
    @write(args)

  wq: (args) =>
    @write(args).then(=> @quit())

  wa: =>
    @wall()

  wqall: =>
    @wall()
    @quitall()

  wqa: =>
    @wqall()

  xall: =>
    @wqall()

  xa: =>
    @wqall()

  saveas: (args) =>
    args.saveas = true
    @write(args)

  xit: (args) => @wq(args)

  x: (args) => @xit(args)

  split: ({ range, args }) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    pane = atom.workspace.getActivePane()
    if atom.config.get('ex-mode.splitbelow')
      if filePaths? and filePaths.length > 0
        newPane = pane.splitDown()
        for file in filePaths
          do ->
            atom.workspace.openURIInPane file, newPane
      else
        pane.splitDown(copyActiveItem: true)
    else
      if filePaths? and filePaths.length > 0
        newPane = pane.splitUp()
        for file in filePaths
          do ->
            atom.workspace.openURIInPane file, newPane
      else
        pane.splitUp(copyActiveItem: true)


  sp: (args) => @split(args)

  substitute: ({ range, args, editor, vimState }) ->
    args_ = args.trimLeft()
    delim = args_[0]
    if /[a-z1-9\\"|]/i.test(delim)
      throw new CommandError(
        "Regular expressions can't be delimited by alphanumeric characters, '\\', '\"' or '|'")
    args_ = args_[1..]
    escapeChars = {t: '\t', n: '\n', r: '\r'}
    parsed = ['', '', '']
    parsing = 0
    escaped = false
    while (char = args_[0])?
      args_ = args_[1..]
      if char is delim
        if not escaped
          parsing++
          if parsing > 2
            throw new CommandError('Trailing characters')
        else
          parsed[parsing] = parsed[parsing][...-1]
      else if char is '\\' and not escaped
        parsed[parsing] += char
        escaped = true
      else if parsing == 1 and escaped and escapeChars[char]?
        parsed[parsing] += escapeChars[char]
        escaped = false
      else
        escaped = false
        parsed[parsing] += char

    [pattern, substition, flags] = parsed
    if pattern is ''
      if vimState.getSearchHistoryItem?
        # vim-mode
        pattern = vimState.getSearchHistoryItem()
      else if vimState.searchHistory?
        # vim-mode-plus
        pattern = vimState.searchHistory.get('prev')

      if not pattern?
        atom.beep()
        throw new CommandError('No previous regular expression')
    else
      if vimState.pushSearchHistory?
        # vim-mode
        vimState.pushSearchHistory(pattern)
      else if vimState.searchHistory?
        # vim-mode-plus
        vimState.searchHistory.save(pattern)

    try
      flagsObj = {}
      flags.split('').forEach((flag) -> flagsObj[flag] = true)
      # gdefault option
      if atom.config.get('ex-mode.gdefault')
        flagsObj.g = !flagsObj.g
      patternRE = getSearchTerm(pattern, flagsObj)
    catch e
      if e.message.indexOf('Invalid flags supplied to RegExp constructor') is 0
        throw new CommandError("Invalid flags: #{e.message[45..]}")
      else if e.message.indexOf('Invalid regular expression: ') is 0
        throw new CommandError("Invalid RegEx: #{e.message[27..]}")
      else
        throw e

    editor.transact ->
      for line in [range[0]..range[1]]
        editor.scanInBufferRange(
          patternRE,
          [[line, 0], [line + 1, 0]],
          ({match, replace}) ->
            replace(replaceGroups(match[..], substition))
        )

  s: (args) => @substitute(args)

  vsplit: ({ range, args }) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    pane = atom.workspace.getActivePane()
    if atom.config.get('ex-mode.splitright')
      if filePaths? and filePaths.length > 0
        newPane = pane.splitRight()
        for file in filePaths
          do ->
            atom.workspace.openURIInPane file, newPane
      else
        pane.splitRight(copyActiveItem: true)
    else
      if filePaths? and filePaths.length > 0
        newPane = pane.splitLeft()
        for file in filePaths
          do ->
            atom.workspace.openURIInPane file, newPane
      else
        pane.splitLeft(copyActiveItem: true)

  vsp: (args) => @vsplit(args)

  delete: ({ range }) ->
    range = [[range[0], 0], [range[1] + 1, 0]]
    editor = atom.workspace.getActiveTextEditor()

    text = editor.getTextInBufferRange(range)
    atom.clipboard.write(text)

    editor.buffer.setTextInRange(range, '')

  yank: ({ range }) ->
    range = [[range[0], 0], [range[1] + 1, 0]]
    txt = atom.workspace.getActiveTextEditor().getTextInBufferRange(range)
    atom.clipboard.write(txt);

  set: ({ range, args }) ->
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

  sort: ({ range }) =>
    editor = atom.workspace.getActiveTextEditor()
    sortingRange = [[]]

    # If no range is provided, the entire file should be sorted.
    isMultiLine = range[1] - range[0] > 1
    if isMultiLine
      sortingRange = [[range[0], 0], [range[1] + 1, 0]]
    else
      sortingRange = [[0, 0], [editor.getLastBufferRow(), 0]]

    # Store every bufferedRow string in an array.
    textLines = []
    for lineIndex in [sortingRange[0][0]..sortingRange[1][0] - 1]
      textLines.push(editor.lineTextForBufferRow(lineIndex))

    # Sort the array and join them together with newlines for writing back to the file.
    sortedText = _.sortBy(textLines).join('\n') + '\n'
    editor.buffer.setTextInRange(sortingRange, sortedText)

  move: ({range, args, editor}) ->
    args = args.trimLeft()
    lastLine = editor.getLastBufferRow()
    argsPattern = /^[$.]|[+-]\d+|\d+|[+-]/g
    args = args.match(argsPattern)

    if args?
      firstArgIsOffset = /[+-]/.test(args[0])
      address = if firstArgIsOffset then range[0] else 0

      # Caluculate address from args.
      for arg in args
        if arg == '$'
          address = lastLine
        else if arg == '.'
          address = editor.getCursorBufferPosition().row + 1
        else if arg == '+'
          address++
        else if arg == '-'
          address--
        else
          address += parseInt(arg)

    movingUp = address < range[0]
    if movingUp
      address++
    if not firstArgIsOffset
      address--

    if isNaN(address) or address < 0 or address > lastLine
      throw new CommandError("E14: Invalid address")
    if address > range[0] and address < range[1]
      throw new CommandError("E134: Move lines into themselves")
    if editor.getSelections().length > 1
      throw new CommandError("Multiple selections present")

    if address == range[0] or address == range[1]
      editor.setCursorBufferPosition([range[1], 0])
    else
      # Batch move operations as a single undo/redo action.
      move = ->
        numOfLinesToMove = range[1] - range[0]
        bufferRange = [[range[0], 0], [range[1] + 1, 0]]
        textToMove = editor.getTextInBufferRange(bufferRange)
        editor.setTextInBufferRange(bufferRange, '')

        if movingUp
          editor.setTextInBufferRange([[address, 0], [address, 0]], textToMove)
          editor.setCursorBufferPosition([address + numOfLinesToMove, 0])
        else
          editor.setTextInBufferRange([[address - numOfLinesToMove, 0],
          [address - numOfLinesToMove, 0]], textToMove)
          editor.setCursorBufferPosition([address, 0])
      editor.transact(300, move)

  m: (args) => @move(args)

module.exports = Ex
