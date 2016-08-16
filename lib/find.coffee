_ = require 'underscore-plus'

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
      atom.config.get("vim-mode:useSmartcaseForSearch")) or hasc
    modifiers['i'] = true

  modFlags = Object.keys(modifiers).filter((key) -> modifiers[key]).join('')

  try
    new RegExp(term, modFlags)
  catch
    new RegExp(_.escapeRegExp(term), modFlags)

module.exports = {
  findInBuffer : (buffer, pattern) ->
    found = []
    buffer.scan(new RegExp(pattern, 'g'), (obj) -> found.push obj.range)
    return found

  findNextInBuffer : (buffer, curPos, pattern) ->
    found = @findInBuffer(buffer, pattern)
    more = (i for i in found when i.compare([curPos, curPos]) is 1)
    if more.length > 0
      return more[0].start.row
    else if found.length > 0
      return found[0].start.row
    else
      return null

  findPreviousInBuffer : (buffer, curPos, pattern) ->
    found = @findInBuffer(buffer, pattern)
    less = (i for i in found when i.compare([curPos, curPos]) is -1)
    if less.length > 0
      return less[less.length - 1].start.row
    else if found.length > 0
      return found[found.length - 1].start.row
    else
      return null

  # Returns an array of ranges of all occurences of `term` in `editor`.
  #  The array is sorted so that the first occurences after the cursor come
  #  first (and the search wraps around). If `reverse` is true, the array is
  #  reversed so that the first occurence before the cursor comes first.
  scanEditor: (term, editor, position, reverse = false) ->
    [rangesBefore, rangesAfter] = [[], []]
    editor.scan getSearchTerm(term), ({range}) ->
      if reverse
        isBefore = range.start.compare(position) < 0
      else
        isBefore = range.start.compare(position) <= 0

      if isBefore
        rangesBefore.push(range)
      else
        rangesAfter.push(range)

    if reverse
      rangesAfter.concat(rangesBefore).reverse()
    else
      rangesAfter.concat(rangesBefore)
}
