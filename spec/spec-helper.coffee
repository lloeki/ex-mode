ExState = require '../lib/ex-state'
GlobalExState = require '../lib/global-ex-state'

beforeEach ->
  atom.workspace ||= {}

activateExMode = ->
  atom.workspace.open().then ->
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'ex-mode:open')
    keydown('escape')
    atom.workspace.getActivePane().destroyActiveItem()


getEditorElement = (callback) ->
  textEditor = null

  waitsForPromise ->
    atom.workspace.open().then (e) ->
      textEditor = e

  runs ->
    # element = document.createElement("atom-text-editor")
    # element.setModel(textEditor)
    # element.classList.add('vim-mode')
    # element.exState = new ExState(element, new GlobalExState)
    #
    # element.addEventListener "keydown", (e) ->
    #   atom.keymaps.handleKeyboardEvent(e)

    element = atom.views.getView(textEditor)

    callback(element)

dispatchKeyboardEvent = (target, eventArgs...) ->
  e = document.createEvent('KeyboardEvent')
  e.initKeyboardEvent(eventArgs...)
  # 0 is the default, and it's valid ASCII, but it's wrong.
  Object.defineProperty(e, 'keyCode', get: -> undefined) if e.keyCode is 0
  target.dispatchEvent e

dispatchTextEvent = (target, eventArgs...) ->
  e = document.createEvent('TextEvent')
  e.initTextEvent(eventArgs...)
  target.dispatchEvent e

keydown = (key, {element, ctrl, shift, alt, meta, raw}={}) ->
  key = "U+#{key.charCodeAt(0).toString(16)}" unless key is 'escape' or raw?
  element ||= document.activeElement
  eventArgs = [
    true, # bubbles
    true, # cancelable
    null, # view
    key,  # key
    0,    # location
    ctrl, alt, shift, meta
  ]

  canceled = not dispatchKeyboardEvent(element, 'keydown', eventArgs...)
  dispatchKeyboardEvent(element, 'keypress', eventArgs...)
  if not canceled
    if dispatchTextEvent(element, 'textInput', eventArgs...)
      element.value += key
  dispatchKeyboardEvent(element, 'keyup', eventArgs...)

module.exports = {keydown, getEditorElement, activateExMode}
