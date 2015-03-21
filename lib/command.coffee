ExViewModel = require './ex-view-model'
Ex = require './ex'
Find = require './find'

class CommandError
  constructor: (@message) ->
    @name = 'Command Error'

class Command
  constructor: (@editor, @exState) ->
    @viewModel = new ExViewModel(@)

  parseAddr: (str, curLine) ->
    if str == '.'
      addr = curLine
    else if str == '$'
      # Lines are 0-indexed in Atom, but 1-indexed in vim.
      addr = @editor.getBuffer().lines.length - 1
    else if str[0] in ["+", "-"]
      addr = curLine + @parseOffset(str)
    else if not isNaN(str)
      addr = parseInt(str) - 1
    else if str[0] == "'" # Parse Mark...
      unless @vimState?
        throw new CommandError("Couldn't get access to vim-mode.")
      mark = @vimState.marks[str[1]]
      unless mark?
        throw new CommandError('Mark ' + str + ' not set.')
      addr = mark.bufferMarker.range.end.row
    else if str[0] == "/" # TODO: Parse forward search
      addr = Find.findNext(@editor.buffer.lines, str[1...-1], curLine)
      unless addr?
        throw new CommandError('Pattern not found: ' + str[1...-1])
    else if str[0] == "?" # TODO: Parse backwards search
      addr = Find.findPrevious(@editor.buffer.lines, str[1...-1], curLine)
      unless addr?
        throw new CommandError('Pattern not found: ' + str[1...-1])

    return addr

  parseOffset: (str) ->
    if str.length == 0
      return 0
    if str.length == 1
      o = 1
    else
      o = parseInt(str[1..])
    if str[0] == '+'
      return o
    else
      return -o

  execute: (input) ->
    @vimState = @exState.globalExState.vim?.getEditorState(@editor)
    # Command line parsing (mostly) following the rules at
    # http://pubs.opengroup.org/onlinepubs/9699919799/utilities/ex.html#tag_20_40_13_03
    # Steps 1/2: Leading blanks and colons are ignored.
    cl = input.characters
    cl = cl.replace(/^(:|\s)*/, '')
    return unless cl.length > 0
    # Step 3: If the first character is a ", ignore the rest of the line
    if cl[0] == '"'
      return
    # Step 4: Address parsing
    lastLine = @editor.getBuffer().lines.length - 1
    if cl[0] == '%'
      range = [0, lastLine]
      cl = cl[1..]
    else
      addrPattern = ///^
        (?:                               # First address
        (
        \.|                               # Current line
        \$|                               # Last line
        \d+|                              # n-th line
        '[\[\]<>'`"^.(){}a-zA-Z]|         # Marks
        /.*?[^\\]/|                       # Regex
        \?.*?[^\\]\?|                     # Backwards search
        [+-]\d*                           # Current line +/- a number of lines
        )((?:\s*[+-]\d*)*)                # Line offset
        )?
        (?:,                              # Second address
        (                                 # Same as first address
        \.|
        \$|
        \d+|
        '[\[\]<>'`"^.(){}a-zA-Z]|
        /.*?[^\\]/|
        \?.*?[^\\]\?|
        [+-]\d*
        )((?:\s*[+-]\d*)*)
        )?
      ///

      [match, addr1, off1, addr2, off2] = cl.match(addrPattern)

      curLine = @editor.getCursorBufferPosition().row

      if addr1?
        address1 = @parseAddr(addr1, curLine)
      else
        # If no addr1 is given (,+3), assume it is '.'
        address1 = curLine
      if off1?
        address1 += @parseOffset(off1)

      if address1 < 0 or address1 > lastLine
        throw new CommandError('Invalid range')

      if addr2?
        address2 = @parseAddr(addr2, curLine)
      if off2?
        address2 += @parseOffset(off2)

      if address2 < 0 or address2 > lastLine
        throw new CommandError('Invalid range')

      if address2 < address1
        throw new CommandError('Backwards range given')

      range = [address1, if address2? then address2 else address1]
      cl = cl[match?.length..]

    # Step 5: Leading blanks are ignored
    cl = cl.trimLeft()

    # Vim behavior: If no command is specified, go to the specified length
    if cl.length == 0
      @editor.setCursorBufferPosition([range[1], 0])
      return

    func = Ex.singleton()[command]
    if func?
      func(args...)
    else
      throw new CommandError("#{input.characters}")

module.exports = {Command, CommandError}
