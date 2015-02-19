ExCommandModeInputView = require './ex-command-mode-input-view'

class ViewModel
  constructor: (@command, opts={}) ->
    {@editor, @exState} = @command

    @view = new ExCommandModeInputView(@, opts)
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
