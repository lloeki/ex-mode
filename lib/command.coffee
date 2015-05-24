ExViewModel = require './ex-view-model'
Ex = require './ex'
Find = require './find'
CommandError = require './command-error'

class Command
  constructor: (@editor, @exState) ->
    @viewModel = new ExViewModel(@)

  parseAddr: (str, curPos) ->
    if str is '.'
      addr = curPos.row
    else if str is '$'
      # Lines are 0-indexed in Atom, but 1-indexed in vim.
      addr = @editor.getBuffer().lines.length - 1
    else if str[0] in ["+", "-"]
      addr = curPos.row + @parseOffset(str)
    else if not isNaN(str)
      addr = parseInt(str) - 1
    else if str[0] is "'" # Parse Mark...
      unless @vimState?
        throw new CommandError("Couldn't get access to vim-mode.")
      mark = @vimState.marks[str[1]]
      unless mark?
        throw new CommandError("Mark #{str} not set.")
      addr = mark.bufferMarker.range.end.row
    else if str[0] is "/"
      addr = Find.findNextInBuffer(@editor.buffer, curPos, str[1...-1])
      unless addr?
        throw new CommandError("Pattern not found: #{str[1...-1]}")
    else if str[0] is "?"
      addr = Find.findPreviousInBuffer(@editor.buffer, curPos, str[1...-1])
      unless addr?
        throw new CommandError("Pattern not found: #{str[1...-1]}")

    return addr

  parseOffset: (str) ->
    if str.length is 0
      return 0
    if str.length is 1
      o = 1
    else
      o = parseInt(str[1..])
    if str[0] is '+'
      return o
    else
      return -o

  execute: (input) ->
    @vimState = @exState.globalExState.vim?.getEditorState(@editor)
    # Command line parsing (mostly) following the rules at
    # http://pubs.opengroup.org/onlinepubs/9699919799/utilities
    # /ex.html#tag_20_40_13_03

    # Steps 1/2: Leading blanks and colons are ignored.
    cl = input.characters
    cl = cl.replace(/^(:|\s)*/, '')
    return unless cl.length > 0

    # Step 3: If the first character is a ", ignore the rest of the line
    if cl[0] is '"'
      return

    # Step 4: Address parsing
    lastLine = @editor.getBuffer().lines.length - 1
    if cl[0] is '%'
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

      curPos = @editor.getCursorBufferPosition()

      if addr1?
        address1 = @parseAddr(addr1, curPos)
      else
        # If no addr1 is given (,+3), assume it is '.'
        address1 = curPos.row
      if off1?
        address1 += @parseOffset(off1)

      address1 = 0 if address1 is -1

      if address1 < 0 or address1 > lastLine
        throw new CommandError('Invalid range')

      if addr2?
        address2 = @parseAddr(addr2, curPos)
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

    # Step 6a: If no command is specified, go to the last specified address
    if cl.length is 0
      @editor.setCursorBufferPosition([range[1], 0])
      return

    # Ignore steps 6b and 6c since they only make sense for print commands and
    # print doesn't make sense

    # Ignore step 7a since flags are only useful for print

    # Step 7b: :k<valid mark> is equal to :mark <valid mark> - only a-zA-Z is
    # in vim-mode for now
    if cl.length is 2 and cl[0] is 'k' and /[a-z]/i.test(cl[1])
      command = 'mark'
      args = cl[1]
    else if not /[a-z]/i.test(cl[0])
      command = cl[0]
      args = cl[1..]
    else
      [m, command, args] = cl.match(/^(\w+)(.*)/)

    # If the command matches an existing one exactly, execute that one
    if (func = Ex.singleton()[command])?
      func(range, args)
    else
      # Step 8: Match command against existing commands
      matching = (name for name, val of Ex.singleton() when \
        name.indexOf(command) is 0)

      matching.sort()

      command = matching[0]

      func = Ex.singleton()[command]
      if func?
        func(range, args)
      else
        throw new CommandError("Not an editor command: #{input.characters}")

module.exports = Command
