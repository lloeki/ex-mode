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
}
