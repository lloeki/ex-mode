class CommandError
  constructor: (@message) ->
    @name = 'Command Error'

module.exports = CommandError
