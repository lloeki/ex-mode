ExModeView = require './ex-mode-view'
{CompositeDisposable} = require 'atom'

module.exports = ExMode =
  exModeView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @exModeView = new ExModeView(state.exModeViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @exModeView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'ex-mode:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @exModeView.destroy()

  serialize: ->
    exModeViewState: @exModeView.serialize()

  toggle: ->
    console.log 'ExMode was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
