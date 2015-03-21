module.exports = {
  findLines: (lines, pattern) ->
    # TODO: There's gotta be a better way to do this. Can we use vim-mode's
    # search or find-and-replace maybe?
    return (i for line, i in lines when line.match(pattern))

  findNext: (lines, pattern, curLine) ->
    lines = @findLines(lines, pattern)
    if lines.length == 0
      return null
    more = (i for i in lines when i > curLine)
    if more.length > 0
      return more[0]
    else
      return lines[0]

  findPrevious: (lines, pattern, curLine) ->
    lines = @findLines(lines, pattern)
    if lines.length == 0
      return null
    less = (i for i in lines when i < curLine)
    if less.length > 0
      return less[0]
    else
      return lines[lines.length - 1]
}
