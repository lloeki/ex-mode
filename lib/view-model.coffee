ExCommandModeInputElement = require './ex-command-mode-input-element'

class ViewModel
  constructor: (@command, opts={}) ->
    {@editor, @exState} = @command

    @view = new ExCommandModeInputElement().initialize(@, opts)
    @editor.commandModeInputView = @view
    @exState.onDidFailToExecute => @view.remove()

  confirm: (view) ->
    @exState.pushOperations(new Input(@view.value))

  cancel: (view) ->
    @exState.pushOperations(new Input(''))

class Input
  constructor: (@characters) ->

module.exports = {
  ViewModel, Input
}
