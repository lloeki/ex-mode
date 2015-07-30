ExNormalModeInputElement = require './ex-normal-mode-input-element'

class ViewModel
  constructor: (@command, opts={}) ->
    {@editor, @exState} = @command

    @view = new ExNormalModeInputElement().initialize(@, opts)
    @editor.normalModeInputView = @view
    @exState.onDidFailToExecute => @view.remove()
    @done = false

  confirm: (view) ->
    @exState.pushOperations(new Input(@view.value))
    @done = true

  cancel: (view) ->
    unless @done
      @exState.pushOperations(new Input(''))
      @done = true

class Input
  constructor: (@characters) ->

module.exports = {
  ViewModel, Input
}
