{ViewModel, Input} = require './view-model'
AutoComplete = require './autocomplete'
Ex = require './ex'

module.exports =
class ExViewModel extends ViewModel
  constructor: (@exCommand, withSelection) ->
    super(@exCommand, class: 'command')
    @historyIndex = -1

    if withSelection
      @view.editorElement.getModel().setText("'<,'>")

    @view.editorElement.addEventListener('keydown', @tabAutocomplete)
    atom.commands.add(@view.editorElement, 'core:move-up', @increaseHistoryEx)
    atom.commands.add(@view.editorElement, 'core:move-down', @decreaseHistoryEx)

    @autoComplete = new AutoComplete(Ex.getCommands())

  restoreHistory: (index) ->
    @view.editorElement.getModel().setText(@history(index).value)

  history: (index) ->
    @exState.getExHistoryItem(index)

  tabAutocomplete: (event) =>
    if event.keyCode == 9
      event.stopPropagation()
      event.preventDefault()

      completed = @autoComplete.getAutocomplete(@view.editorElement.getModel().getText())
      if completed
        @view.editorElement.getModel().setText(completed)

      return false
    else
      @autoComplete.resetCompletion()

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
