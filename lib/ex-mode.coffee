GlobalExState = require './global-ex-state'
ExState = require './ex-state'
Ex = require './ex'
{Disposable, CompositeDisposable} = require 'event-kit'

module.exports = ExMode =
  activate: (state) ->
    @globalExState = new GlobalExState
    @disposables = new CompositeDisposable
    @exStates = new WeakMap

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      return if editor.mini

      element = atom.views.getView(editor)

      if not @exStates.get(editor)
        exState = new ExState(
          element,
          @globalExState
        )

        @exStates.set(editor, exState)

        @disposables.add new Disposable =>
          exState.destroy()

  deactivate: ->
    @disposables.dispose()

  provideEx: ->
    registerCommand: Ex.registerCommand.bind(Ex)
    registerAlias: Ex.registerAlias.bind(Ex)

  consumeVim: (vim) ->
    @vim = vim
    @globalExState.setVim(vim)

  consumeVimModePlus: (vim) ->
    this.consumeVim(vim)

  config:
    splitbelow:
      title: 'Split below'
      description: 'when splitting, split from below'
      type: 'boolean'
      default: 'false'
    splitright:
      title: 'Split right'
      description: 'when splitting, split from right'
      type: 'boolean'
      default: 'false'
    gdefault:
      title: 'Gdefault'
      description: 'When on, the ":substitute" flag \'g\' is default on'
      type: 'boolean'
      default: 'false'
