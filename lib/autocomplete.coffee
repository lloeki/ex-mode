fs = require 'fs'
path = require 'path'
os = require 'os'
Ex = require './ex'

module.exports =
class AutoComplete
  constructor: (commands) ->
    @commands = commands
    @resetCompletion()

  resetCompletion: () ->
    @autoCompleteIndex = 0
    @autoCompleteText = null
    @completions = []

  expandTilde: (filePath) ->
    if filePath.charAt(0) == '~'
      return os.homedir() + filePath.slice(1)
    else
      return filePath

  getAutocomplete: (text) ->
    if !@autoCompleteText
      @autoCompleteText = text

    parts = @autoCompleteText.split(' ')
    cmd = parts[0]

    if parts.length > 1
      filePath = parts.slice(1).join(' ')
      return @getCompletion(() => @getFilePathCompletion(cmd, filePath))
    else
      return @getCompletion(() => @getCommandCompletion(cmd))

  filterByPrefix: (commands, prefix) ->
    commands.sort().filter((f) => f.startsWith(prefix))

  getCompletion: (completeFunc) ->
    if @completions.length == 0
      @completions = completeFunc()

    complete = ''
    if @completions.length
      complete = @completions[@autoCompleteIndex % @completions.length]
      @autoCompleteIndex++

      # Only one result so lets return this directory
      if complete.endsWith('/') && @completions.length == 1
        @resetCompletion()

    return complete

  getCommandCompletion: (command) ->
    return @filterByPrefix(@commands, command)

  getFilePathCompletion: (command, filePath) ->
      filePath = @expandTilde(filePath)

      if filePath.endsWith(path.sep)
        basePath = path.dirname(filePath + '.')
        baseName = ''
      else
        basePath = path.dirname(filePath)
        baseName = path.basename(filePath)

      try
        basePathStat = fs.statSync(basePath)
        if basePathStat.isDirectory()
          files = fs.readdirSync(basePath)
          return @filterByPrefix(files, baseName).map((f) =>
            filePath = path.join(basePath, f)
            if fs.lstatSync(filePath).isDirectory()
              return command + ' ' + filePath  + path.sep
            else
              return command + ' ' + filePath
          )
        return []
      catch err
        return []
