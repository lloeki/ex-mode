ExViewModel = require './ex-view-model'
ExCommands = require './ex-commands'
Find = require './find'
CommandError = require './command-error'
{getSearchTerm} = require './utils'

cmp = (x, y) -> if x > y then 1 else if x < y then -1 else 0

class Command
  constructor: (@editor, @exState) ->
    @viewModel = new ExViewModel(@)
    @vimState = @exState.globalExState.vim?.getEditorState(@editor)

  scanEditor: (term, position, reverse = false) ->
    return if term is ""

    [rangesBefore, rangesAfter] = [[], []]
    @editor.scan getSearchTerm(term), ({range}) ->
      isBefore = if reverse
        range.start.compare(position) < 0
      else
        range.start.compare(position) <= 0

      if isBefore
        rangesBefore.push(range)
      else
        rangesAfter.push(range)

    if reverse
      rangesAfter.concat(rangesBefore).reverse()[0]
    else
      rangesAfter.concat(rangesBefore)[0]

  checkForRepeatSearch: (term, reversed = false) ->
    if term is '' or reversed and term is '?' or not reversed and term is '/'
      @vimState.getSearchHistoryItem(0)
    else
      term

  parseAddr: (str, curPos) ->
    if str in ['.', '']
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
      mark = @vimState.getMark(str[1])
      unless mark?
        throw new CommandError("Mark #{str} not set.")
      addr = mark.row
    else if (first = str[0]) in ['/', '?']
      reversed = first is '?'
      str = @checkForRepeatSearch(str[1..], reversed)
      throw new CommandError('No previous regular expression') if not str?
      str = str[...-1] if str[str.length - 1] is first
      @regex = str
      lineRange = @editor.getLastCursor().getCurrentLineBufferRange()
      pos = if reversed then lineRange.start else lineRange.end
      addr = @scanEditor(str, pos, reversed)
      unless addr?
        throw new CommandError("Pattern not found: #{str[1...-1]}")
      addr = addr.start.row

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

  parseLine: (commandLine) ->
    # Command line parsing (mostly) following the rules at
    # http://pubs.opengroup.org/onlinepubs/9699919799/utilities
    # /ex.html#tag_20_40_13_03
    _commandLine = commandLine

    # Steps 1/2: Leading blanks and colons are ignored.
    commandLine = commandLine.replace(/^(:|\s)*/, '')
    return unless commandLine.length > 0

    # Step 3: If the first character is a ", ignore the rest of the line
    if commandLine[0] is '"'
      return

    # Step 4: Address parsing
    lastLine = @editor.getBuffer().lines.length - 1
    if commandLine[0] is '%'
      range = [0, lastLine]
      commandLine = commandLine[1..]
    else
      addrPattern = ///^
        (?:                               # First address
        (
        \.|                               # Current line
        \$|                               # Last line
        \d+|                              # n-th line
        '[\[\]<>'`"^.(){}a-zA-Z]|         # Marks
        /(?:.*?[^\\]|)(?:/|$)|            # Regex
        \?(?:.*?[^\\]|)(?:\?|$)|          # Backwards search
        [+-]\d*                           # Current line +/- a number of lines
        )((?:\s*[+-]\d*)*)                # Line offset
        )?
        (?:,                              # Second address
        (                                 # Same as first address
        \.|
        \$|
        \d+|
        '[\[\]<>'`"^.(){}a-zA-Z]|
        /(?:.*?[^\\]|)(?:/|$)|
        \?(?:.*?[^\\]|)(?:\?|$)|
        [+-]\d*|
                                          # Empty second address
        )((?:\s*[+-]\d*)*)|
        )?
      ///

      [match, addr1, off1, addr2, off2] = commandLine.match(addrPattern)

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

      if @regex?
        @vimState.pushSearchHistory(@regex)

      if address2 < 0 or address2 > lastLine
        throw new CommandError('Invalid range')

      if address2 < address1
        throw new CommandError('Backwards range given')

      range = [address1, if address2? then address2 else address1]
      commandLine = commandLine[match?.length..]

    # Step 5: Leading blanks are ignored
    commandLine = commandLine.trimLeft()

    # Step 6a: If no command is specified, go to the last specified address
    if commandLine.length is 0
      @editor.setCursorBufferPosition([range[1], 0])
      return {range, command: undefined, args: undefined}

    # Ignore steps 6b and 6c since they only make sense for print commands and
    # print doesn't make sense

    # Ignore step 7a since flags are only useful for print

    # Step 7b: :k<valid mark> is equal to :mark <valid mark> - only a-zA-Z is
    # in vim-mode for now
    if commandLine.length is 2 and commandLine[0] is 'k' \
        and /[a-z]/i.test(commandLine[1])
      command = 'mark'
      args = commandLine[1]
    else if not /[a-z]/i.test(commandLine[0])
      command = commandLine[0]
      args = commandLine[1..]
    else
      [m, command, args] = commandLine.match(/^(\w+)(.*)/)

    commandLineRE = new RegExp("^" + command)
    matching = []

    for name in Object.keys(ExCommands.commands)
      if commandLineRE.test(name)
        command = ExCommands.commands[name]
        if matching.length is 0
          matching = [command]
        else
          switch cmp(command.priority, matching[0].priority)
            when 1 then matching = [command]
            when 0 then matching.push(command)

    command = matching.sort()[0]
    unless command?
      throw new CommandError("Not an editor command: #{_commandLine}")

    return {command: command.callback, range, args: args.trimLeft()}


  execute: (input) ->
    {command, range, args} = @parseLine(input.characters)

    command?({args, range, @editor, @exState, @vimState})

module.exports = Command
