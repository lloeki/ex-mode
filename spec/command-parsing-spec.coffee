helpers = require './spec-helper'
Command = require '../lib/command'
ExCommands = require('../lib/ex-commands')

describe "command parsing", ->
  [editor, editorElement, vimState, exState, command, lines] = []
  beforeEach ->
    vimMode = atom.packages.loadPackage('vim-mode')
    exMode = atom.packages.loadPackage('ex-mode')
    exMode.activate()

    waitsForPromise ->
      vimMode.activate().then ->
        helpers.activateExMode().then ->
          helpers.getEditorElement (element) ->
            editorElement = element
            editor = editorElement.getModel()
            atom.commands.dispatch(element, 'ex-mode:open')
            atom.commands.dispatch(editor.normalModeInputView.editorElement,
              'core:cancel')
            vimState = vimMode.mainModule.getEditorState(editor)
            exState = exMode.mainModule.exStates.get(editor)
            command = new Command(editor, exState)
            vimState.activateNormalMode()
            vimState.resetNormalMode()
            editor.setText(
              'abc\nabc\nabc\nabc\nabc\nabc\nabc\nabc\nabc\nabc\nabc\nabc'
              '\nabc\nabc\n')
            lines = editor.getBuffer().getLines()
            editor.setCursorBufferPosition([0, 0])

  it "parses a simple command (e.g. `:quit`)", ->
    expect(command.parseLine('quit')).toEqual
      command: ExCommands.commands.quit.callback
      args: ''
      range: [0, 0]

  it "matches sub-commands (e.g. `:q`)", ->
    expect(command.parseLine('q')).toEqual
      command: ExCommands.commands.quit.callback
      args: ''
      range: [0, 0]

  it "uses the command with the highest priority if multiple match an input", ->
    expect(command.parseLine('s').command)
      .toEqual(ExCommands.commands.substitute.callback)

  it "ignores leading blanks and spaces", ->
    expect(command.parseLine(':::: :::: : : : ')).toBeUndefined
    expect(command.parseLine('::  :::::: :quit')).toEqual
      command: ExCommands.commands.quit.callback
      args: ''
      range: [0, 0]
    expect(atom.notifications.notifications.length).toBe(0)

  it 'ignores the line if it starts with a "', ->
    expect(command.parseLine('"quit')).toBe(undefined)
    expect(atom.notifications.notifications.length).toBe(0)

  describe "address parsing", ->
    describe "with only one address", ->
      it "parses . as an address", ->
        expect(command.parseLine('.').range).toEqual([0, 0])
        editor.setCursorBufferPosition([2, 0])
        expect(command.parseLine('.').range).toEqual([2, 2])

      it "parses $ as an address", ->
        expect(command.parseLine('$').range)
          .toEqual([lines.length - 1, lines.length - 1])

      it "parses a number as an address", ->
        expect(command.parseLine('3').range).toEqual([2, 2])
        expect(command.parseLine('7').range).toEqual([6, 6])

      it "parses 'a as an address", ->
        vimState.setMark('a', [3, 1])
        expect(command.parseLine("'a").range).toEqual([3, 3])

      it "throws an error if the mark is not set", ->
        vimState.marks.a = undefined
        expect(-> command.parseLine("'a")).toThrow()

      it "parses /a and ?a as addresses", ->
        expect(command.parseLine('/abc').range).toEqual([1, 1])
        editor.setCursorBufferPosition([1, 0])
        expect(command.parseLine('?abc').range).toEqual([0, 0])
        editor.setCursorBufferPosition([0, 0])
        expect(command.parseLine('/bc').range).toEqual([1, 1])

      it "integrates the search history for :/", ->
        vimState.pushSearchHistory('abc')
        expect(command.parseLine('//').range).toEqual([1, 1])
        command.parseLine('/ab/,/bc/+2')
        expect(vimState.getSearchHistoryItem(0)).toEqual('bc')

      describe "case sensitivity for search patterns", ->
        beforeEach ->
          editor.setText('abca\nABC\ndefdDEF\nabcaABC')

        describe "respects the smartcase setting", ->
          describe "with smartcasse off", ->
            beforeEach ->
              atom.config.set('vim-mode.useSmartcaseForSearch', false)
              editor.setCursorBufferPosition([0, 0])

            it "uses case sensitive search if pattern is lowercase", ->
              expect(command.parseLine('/abc').range).toEqual([3, 3])

            it "uses case sensitive search if the pattern is uppercase", ->
              expect(command.parseLine('/ABC').range).toEqual([1, 1])

          describe "with smartcase on", ->
            beforeEach ->
              atom.config.set('vim-mode.useSmartcaseForSearch', true)

            it "uses case insensitive search if the pattern is lowercase", ->
              editor.setCursorBufferPosition([0, 0])
              expect(command.parseLine('/abc').range).toEqual([1, 1])

            it "uses case sensitive search if the pattern is uppercase", ->
              editor.setCursorBufferPosition([3, 3])
              expect(command.parseLine('/ABC').range).toEqual([1, 1])

        describe "\\c and \\C", ->
          describe "only \\c in the pattern", ->
            beforeEach ->
              atom.config.set('vim-mode.useSmartcaseForSearch', false)
              editor.setCursorBufferPosition([0, 0])

            it "uses case insensitive search if smartcase is off", ->
              expect(command.parseLine('/abc\\c').range).toEqual([1, 1])

            it "doesn't matter where it is", ->
              expect(command.parseLine('/ab\\cc').range).toEqual([1, 1])

          describe "only \\C in the pattern with smartcase on", ->
            beforeEach ->
              atom.config.set('vim-mode.useSmartcaseForSearch', true)
              editor.setCursorBufferPosition([0, 0])

            it "uses case sensitive search if the pattern is lowercase", ->
              expect(command.parseLine('/abc\\C').range).toEqual([3, 3])

            it "doesn't matter where it is", ->
              expect(command.parseLine('/ab\\Cc').range).toEqual([3, 3])

          describe "with \\c and \\C in the pattern", ->
            beforeEach ->
              atom.config.set('vim-mode.useSmartcaseForSearch', false)
              editor.setCursorBufferPosition([0, 0])

            it "uses case insensitive search if \\C comes first", ->
              expect(command.parseLine('/a\\Cb\\cc').range).toEqual([1, 1])

            it "uses case insensitive search if \\c comes first", ->
              expect(command.parseLine('/a\\cb\\Cc').range).toEqual([1, 1])

    describe "with two addresses", ->
      it "parses both", ->
        expect(command.parseLine('5,10').range).toEqual([4, 9])

      it "throws an error if it is in reverse order", ->
        expect(-> command.parseLine('10,5').range).toThrow()

      it "uses the current line as second address if empty", ->
        editor.setCursorBufferPosition([3, 0])
        expect(command.parseLine('-2,').range).toEqual([1, 3])

  it "parses a command with a range and no arguments", ->
    expect(command.parseLine('2,/abc/+4delete')).toEqual
      command: ExCommands.commands.delete.callback
      args: ''
      range: [1, 5]

  it "parses a command with no range and arguments", ->
    expect(command.parseLine('edit edit-test test-2')).toEqual
      command: ExCommands.commands.edit.callback
      args: 'edit-test test-2'
      range: [0, 0]

  it "parses a command with range and arguments", ->
    expect(command.parseLine('3,5+2s/abc/def/gi')).toEqual
      command: ExCommands.commands.substitute.callback
      args: '/abc/def/gi'
      range: [2, 6]
