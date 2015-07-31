GlobalExState = require './global-ex-state'
ExState = require './ex-state'
ExCommands = require './ex-commands'
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

        @disposables.add new Disposable ->
          exState.destroy()

  deactivate: ->
    @disposables.dispose()

  provideEx_0_20: ->
    registerCommand: (name, callback) ->
      ExCommands.registerCommand({name, callback, priority: 1})

  provideEx_0_30: ->
    registerCommand: ExCommands.registerCommand

  consumeVim: (vim) ->
    @vim = vim
    @globalExState.setVim(vim)
