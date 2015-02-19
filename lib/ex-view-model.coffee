{ViewModel, Input} = require './view-model'

module.exports =
class ExViewModel extends ViewModel
  constructor: (@exCommand) ->
    super(@exCommand, class: 'command')
    @historyIndex = -1

    @view.editor.on('core:move-up', @increaseHistoryEx)
    @view.editor.on('core:move-down', @decreaseHistoryEx)

  restoreHistory: (index) ->
    @view.editor.setText(@history(index).value)

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
      @view.editor.setText('')
    else
      @historyIndex -= 1
      @restoreHistory(@historyIndex)

  confirm: (view) =>
    @value = @view.value
    @exState.pushExHistory(@)
    super(view)
