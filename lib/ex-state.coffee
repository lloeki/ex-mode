{Emitter, Disposable, CompositeDisposable} = require 'event-kit'

Command = require './command'
CommandError = require './command-error'

class ExState
  constructor: (@editorElement, @globalExState) ->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @editor = @editorElement.getModel()
    @opStack = []
    @history = []

    @registerOperationCommands
      open: (e) => new Command(@editor, @)

  destroy: ->
    @subscriptions.dispose()

  getExHistoryItem: (index) ->
    @globalExState.commandHistory[index]

  pushExHistory: (command) ->
    @globalExState.commandHistory.unshift command

  registerOperationCommands: (commands) ->
    for commandName, fn of commands
      do (fn) =>
        pushFn = (e) => @pushOperations(fn(e))
        @subscriptions.add(
          atom.commands.add(@editorElement, "ex-mode:#{commandName}", pushFn)
        )

  onDidFailToExecute: (fn) ->
    @emitter.on('failed-to-execute', fn)

  onDidProcessOpStack: (fn) ->
    @emitter.on('processed-op-stack', fn)

  pushOperations: (operations) ->
    @opStack.push operations

    @processOpStack() if @opStack.length == 2

  clearOpStack: ->
    @opStack = []

  processOpStack: ->
    [command, input] = @opStack
    if input.characters.length > 0
      @history.unshift command
      try
        command.execute(input)
      catch e
        if (e instanceof CommandError)
          atom.notifications.addError("Command error: #{e.message}")
          @emitter.emit('failed-to-execute')
        else
          throw e
    @clearOpStack()
    @emitter.emit('processed-op-stack')

  # Returns all non-empty selections
  getSelections: ->
    filtered = {}
    for id, selection of @editor.getSelections()
      unless selection.isEmpty()
        filtered[id] = selection

    return filtered

module.exports = ExState
