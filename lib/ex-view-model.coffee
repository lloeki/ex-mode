{ViewModel, Input} = require './view-model'

module.exports =
class ExViewModel extends ViewModel
  constructor: (@exCommand) ->
    super(@exCommand, class: 'command')
    @historyIndex = -1

    atom.commands.add(@view.editorElement, 'core:move-up', @increaseHistoryEx)
    atom.commands.add(@view.editorElement, 'core:move-down', @decreaseHistoryEx)

  restoreHistory: (index) ->
    @view.editorElement.getModel().setText(@history(index).value)

  history: (index) ->
    @exState.getExHistoryItem(index)

  increaseHistoryEx: =>
    if @history(@historyIndex + 1)?
      @historyIndex += 1
      @restoreHistory(@historyIndex)

  decreaseHistoryEx: =>
    if @historyIndex <= 0
      # get us back to a clean slate
      @historyIndex = -1
      @view.editorElement.getModel().setText('')
    else
      @historyIndex -= 1
      @restoreHistory(@historyIndex)

  confirm: (view) =>
    @value = @view.value
    @exState.pushExHistory(@)
    super(view)
