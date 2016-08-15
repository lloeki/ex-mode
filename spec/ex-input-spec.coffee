helpers = require './spec-helper'
describe "the input element", ->
  [editor, editorElement, vimState, exState] = []
  beforeEach ->
    vimMode = atom.packages.loadPackage('vim-mode')
    exMode = atom.packages.loadPackage('ex-mode')
    waitsForPromise ->
      activationPromise = exMode.activate()
      helpers.activateExMode()
      activationPromise

    runs ->
      spyOn(exMode.mainModule.globalExState, 'setVim').andCallThrough()

    waitsForPromise ->
      vimMode.activate()

    waitsFor ->
      exMode.mainModule.globalExState.setVim.calls.length > 0

    runs ->
      helpers.getEditorElement (element) ->
        atom.commands.dispatch(element, "ex-mode:open")
        editorElement = element
        editor = editorElement.getModel()
        atom.commands.dispatch(getCommandEditor(), "core:cancel")
        vimState = vimMode.mainModule.getEditorState(editor)
        exState = exMode.mainModule.exStates.get(editor)
        vimState.activateNormalMode()
        vimState.resetNormalMode()
        editor.setText("abc\ndef\nabc\ndef")

  afterEach ->
    atom.commands.dispatch(getCommandEditor(), "core:cancel")

  getVisibility = () ->
    editor.normalModeInputView.panel.visible

  getCommandEditor = () ->
    editor.normalModeInputView.editorElement

  it "opens with 'ex-mode:open'", ->
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getVisibility()).toBe true

  it "closes with 'core:cancel'", ->
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getVisibility()).toBe true
    atom.commands.dispatch(getCommandEditor(), "core:cancel")
    expect(getVisibility()).toBe false

  it "closes when opening and then pressing backspace", ->
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getVisibility()).toBe true
    atom.commands.dispatch(getCommandEditor(), "core:backspace")
    expect(getVisibility()).toBe false

  it "doesn't close when there is text and pressing backspace", ->
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getVisibility()).toBe true
    commandEditor = getCommandEditor()
    model = commandEditor.getModel()
    model.setText('abc')
    atom.commands.dispatch(commandEditor, "core:backspace")
    expect(getVisibility()).toBe true
    expect(model.getText()).toBe 'ab'

  it "closes when there is text and pressing backspace multiple times", ->
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getVisibility()).toBe true
    commandEditor = getCommandEditor()
    model = commandEditor.getModel()
    expect(model.getText()).toBe ''
    model.setText('abc')
    atom.commands.dispatch(commandEditor, "core:backspace")
    expect(getVisibility()).toBe true
    expect(model.getText()).toBe 'ab'
    atom.commands.dispatch(commandEditor, "core:backspace")
    expect(getVisibility()).toBe true
    expect(model.getText()).toBe 'a'
    atom.commands.dispatch(commandEditor, "core:backspace")
    expect(getVisibility()).toBe true
    expect(model.getText()).toBe ''
    atom.commands.dispatch(commandEditor, "core:backspace")
    expect(getVisibility()).toBe false

  it "contains '<,'> when opened while there are selections", ->
    editor.setCursorBufferPosition([0, 0])
    editor.selectToBufferPosition([0, 1])
    editor.addCursorAtBufferPosition([2, 0])
    editor.selectToBufferPosition([2, 1])
    atom.commands.dispatch(editorElement, "ex-mode:open")
    expect(getCommandEditor().getModel().getText()).toBe "'<,'>"
