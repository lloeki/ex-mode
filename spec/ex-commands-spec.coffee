fs = require 'fs-plus'
path = require 'path'
os = require 'os'
uuid = require 'node-uuid'
helpers = require './spec-helper'
ExCommands = require('../lib/ex-commands')

describe "the commands", ->
  [editor, editorElement, vimState, exState, dir, dir2] = []
  projectPath = (fileName) -> path.join(dir, fileName)
  beforeEach ->
    vimMode = atom.packages.loadPackage('vim-mode')
    exMode = atom.packages.loadPackage('ex-mode')
    exMode.activate()

    waitsForPromise ->
      vimMode.activate().then ->
        helpers.activateExMode().then ->
          dir = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
          dir2 = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
          fs.makeTreeSync(dir)
          fs.makeTreeSync(dir2)
          atom.project.setPaths([dir, dir2])

          helpers.getEditorElement (element) ->
            atom.commands.dispatch(element, 'ex-mode:open')
            keydown('escape')
            editorElement = element
            editor = editorElement.getModel()
            vimState = vimMode.mainModule.getEditorState(editor)
            exState = exMode.mainModule.exStates.get(editor)
            vimState.activateNormalMode()
            vimState.resetNormalMode()
            editor.setText("abc\ndef\nabc\ndef")

  afterEach ->
    fs.removeSync(dir)
    fs.removeSync(dir2)

  keydown = (key, options={}) ->
    options.element ?= editorElement
    helpers.keydown(key, options)

  normalModeInputKeydown = (key, opts = {}) ->
    editor.normalModeInputView.editorElement.getModel().setText(key)

  submitNormalModeInputText = (text) ->
    commandEditor = editor.normalModeInputView.editorElement
    commandEditor.getModel().setText(text)
    atom.commands.dispatch(commandEditor, "core:confirm")

  describe ":write", ->
    describe "when editing a new file", ->
      beforeEach ->
        editor.getBuffer().setText('abc\ndef')

      it "opens the save dialog", ->
        spyOn(atom, 'showSaveDialogSync')
        keydown(':')
        submitNormalModeInputText('write')
        expect(atom.showSaveDialogSync).toHaveBeenCalled()

      it "saves when a path is specified in the save dialog", ->
        filePath = projectPath('write-from-save-dialog')
        spyOn(atom, 'showSaveDialogSync').andReturn(filePath)
        keydown(':')
        submitNormalModeInputText('write')
        expect(fs.existsSync(filePath)).toBe(true)
        expect(fs.readFileSync(filePath, 'utf-8')).toEqual('abc\ndef')

      it "saves when a path is specified in the save dialog", ->
        spyOn(atom, 'showSaveDialogSync').andReturn(undefined)
        spyOn(fs, 'writeFileSync')
        keydown(':')
        submitNormalModeInputText('write')
        expect(fs.writeFileSync.calls.length).toBe(0)

    describe "when editing an existing file", ->
      filePath = ''
      i = 0

      beforeEach ->
        i++
        filePath = projectPath("write-#{i}")
        editor.setText('abc\ndef')
        editor.saveAs(filePath)

      it "saves the file", ->
        editor.setText('abc')
        keydown(':')
        submitNormalModeInputText('write')
        expect(fs.readFileSync(filePath, 'utf-8')).toEqual('abc')
        expect(editor.isModified()).toBe(false)

      describe "with a specified path", ->
        newPath = ''

        beforeEach ->
          newPath = path.relative(dir, "#{filePath}.new")
          editor.getBuffer().setText('abc')
          keydown(':')

        afterEach ->
          submitNormalModeInputText("write #{newPath}")
          newPath = path.resolve(dir, fs.normalize(newPath))
          expect(fs.existsSync(newPath)).toBe(true)
          expect(fs.readFileSync(newPath, 'utf-8')).toEqual('abc')
          expect(editor.isModified()).toBe(true)
          fs.removeSync(newPath)

        it "saves to the path", ->

        it "expands .", ->
          newPath = path.join('.', newPath)

        it "expands ..", ->
          newPath = path.join('..', newPath)

        it "expands ~", ->
          newPath = path.join('~', newPath)

      it "throws an error with more than one path", ->
        keydown(':')
        submitNormalModeInputText('write path1 path2')
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: Only one file name allowed'
        )

      describe "when the file already exists", ->
        existsPath = ''

        beforeEach ->
          existsPath = projectPath('write-exists')
          fs.writeFileSync(existsPath, 'abc')

        afterEach ->
          fs.removeSync(existsPath)

        it "throws an error if the file already exists", ->
          keydown(':')
          submitNormalModeInputText("write #{existsPath}")
          expect(atom.notifications.notifications[0].message).toEqual(
            'Command error: File exists (add ! to override)'
          )
          expect(fs.readFileSync(existsPath, 'utf-8')).toEqual('abc')

        it "writes if forced with :write!", ->
          keydown(':')
          submitNormalModeInputText("write! #{existsPath}")
          expect(atom.notifications.notifications).toEqual([])
          expect(fs.readFileSync(existsPath, 'utf-8')).toEqual('abc\ndef')

  describe ":quit", ->
    pane = null
    beforeEach ->
      waitsForPromise ->
        pane = atom.workspace.getActivePane()
        spyOn(pane, 'destroyActiveItem').andCallThrough()
        atom.workspace.open()

    it "closes the active pane item if not modified", ->
      keydown(':')
      submitNormalModeInputText('quit')
      expect(pane.destroyActiveItem).toHaveBeenCalled()
      expect(pane.getItems().length).toBe(1)

    describe "when the active pane item is modified", ->
      beforeEach ->
        editor.getBuffer().setText('def')

      it "opens the prompt to save", ->
        spyOn(pane, 'promptToSaveItem')
        keydown(':')
        submitNormalModeInputText('quit')
        expect(pane.promptToSaveItem).toHaveBeenCalled()

  describe ":tabclose", ->
    it "acts as an alias to :quit", ->
      spyOn(ExCommands.commands.tabclose, 'callback').andCallThrough()
      spyOn(ExCommands.commands.quit, 'callback').andCallThrough()
      keydown(':')
      submitNormalModeInputText('tabclose')
      expect(ExCommands.commands.quit.callback)
        .toHaveBeenCalledWith(ExCommands.commands.tabclose.callback
          .calls[0].args[0])

  describe ":qall", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open().then -> atom.workspace.open()
          .then -> atom.workspace.open()

    it "closes the window", ->
      spyOn(atom, 'close')
      keydown(':')
      submitNormalModeInputText('qall')
      expect(atom.close).toHaveBeenCalled()

  describe ":tabnext", ->
    pane = null
    beforeEach ->
      waitsForPromise ->
        pane = atom.workspace.getActivePane()
        atom.workspace.open().then -> atom.workspace.open()
          .then -> atom.workspace.open()

    it "switches to the next tab", ->
      pane.activateItemAtIndex(1)
      keydown(':')
      submitNormalModeInputText('tabnext')
      expect(pane.getActiveItemIndex()).toBe(2)

    it "wraps around", ->
      pane.activateItemAtIndex(pane.getItems().length - 1)
      keydown(':')
      submitNormalModeInputText('tabnext')
      expect(pane.getActiveItemIndex()).toBe(0)

  describe ":tabprevious", ->
    pane = null
    beforeEach ->
      waitsForPromise ->
        pane = atom.workspace.getActivePane()
        atom.workspace.open().then -> atom.workspace.open()
          .then -> atom.workspace.open()

    it "switches to the previous tab", ->
      pane.activateItemAtIndex(1)
      keydown(':')
      submitNormalModeInputText('tabprevious')
      expect(pane.getActiveItemIndex()).toBe(0)

    it "wraps around", ->
      pane.activateItemAtIndex(0)
      keydown(':')
      submitNormalModeInputText('tabprevious')
      expect(pane.getActiveItemIndex()).toBe(pane.getItems().length - 1)

  describe ":update", ->
    it "acts as an alias to :write", ->
      spyOn(ExCommands.commands.update, 'callback')
        .andCallThrough()
      spyOn(ExCommands.commands.write, 'callback')
      keydown(':')
      submitNormalModeInputText('update')
      expect(ExCommands.commands.write.callback).toHaveBeenCalledWith(
        ExCommands.commands.update.callback.calls[0].args[0])

  describe ":wall", ->
    it "saves all open files", ->
      spyOn(atom.workspace, 'saveAll')
      keydown(':')
      submitNormalModeInputText('wall')
      expect(atom.workspace.saveAll).toHaveBeenCalled()

  describe ":wq", ->
    beforeEach ->
      spyOn(ExCommands.commands.write, 'callback').andCallThrough()
      spyOn(ExCommands.commands.quit, 'callback')

    it "writes the file, then quits", ->
      spyOn(atom, 'showSaveDialogSync').andReturn(projectPath('wq-1'))
      keydown(':')
      submitNormalModeInputText('wq')
      expect(ExCommands.commands.write.callback).toHaveBeenCalled()
      # Since `:wq` only calls `:quit` after `:write` is finished, we need to
      #  wait a bit for the `:quit` call to occur
      waitsFor((-> ExCommands.commands.quit.callback.wasCalled),
        "the :quit command to be called", 100)

    it "doesn't quit when the file is new and no path is specified in the save dialog", ->
      spyOn(atom, 'showSaveDialogSync').andReturn(undefined)
      keydown(':')
      submitNormalModeInputText('wq')
      expect(ExCommands.commands.write.callback).toHaveBeenCalled()
      wasNotCalled = false
      # FIXME: This seems dangerous, but setTimeout somehow doesn't work.
      setImmediate((->
        wasNotCalled = not ExCommands.commands.quit.callback.wasCalled))
      waitsFor((-> wasNotCalled), 100)

    it "passes the file name", ->
      keydown(':')
      submitNormalModeInputText('wq wq-2')
      expect(ExCommands.commands.write.callback)
        .toHaveBeenCalled()
      expect(ExCommands.commands.write.callback.calls[0].args[0].args)
        .toEqual('wq-2')
      waitsFor((-> ExCommands.commands.quit.callback.wasCalled),
        "the :quit command to be called", 100)

  describe ":xit", ->
    it "acts as an alias to :wq", ->
      spyOn(ExCommands.commands.wq, 'callback')
      keydown(':')
      submitNormalModeInputText('xit')
      expect(ExCommands.commands.wq.callback).toHaveBeenCalled()

  describe ":exit", ->
    it "is an alias to :xit", ->
      spyOn(ExCommands.commands.xit, 'callback')
      keydown(':')
      submitNormalModeInputText('exit')
      expect(ExCommands.commands.xit.callback).toHaveBeenCalled()

  describe ":xall", ->
    it "saves all open files and closes the window", ->
      spyOn(atom.workspace, 'saveAll')
      spyOn(atom, 'close')
      keydown(':')
      submitNormalModeInputText('xall')
      expect(atom.workspace.saveAll).toHaveBeenCalled()
      expect(atom.close).toHaveBeenCalled()

  describe ":edit", ->
    describe "without a file name", ->
      it "reloads the file from the disk", ->
        filePath = projectPath("edit-1")
        editor.getBuffer().setText('abc')
        editor.saveAs(filePath)
        fs.writeFileSync(filePath, 'def')
        keydown(':')
        submitNormalModeInputText('edit')
        # Reloading takes a bit
        waitsFor((-> editor.getText() is 'def'),
          "the editor's content to change", 100)

      it "doesn't reload when the file has been modified", ->
        filePath = projectPath("edit-2")
        editor.getBuffer().setText('abc')
        editor.saveAs(filePath)
        editor.getBuffer().setText('abcd')
        fs.writeFileSync(filePath, 'def')
        keydown(':')
        submitNormalModeInputText('edit')
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: No write since last change (add ! to override)')
        isntDef = false
        setImmediate(-> isntDef = editor.getText() isnt 'def')
        waitsFor((-> isntDef), "the editor's content not to change", 50)

      it "reloads when the file has been modified and it is forced", ->
        filePath = projectPath("edit-3")
        editor.getBuffer().setText('abc')
        editor.saveAs(filePath)
        editor.getBuffer().setText('abcd')
        fs.writeFileSync(filePath, 'def')
        keydown(':')
        submitNormalModeInputText('edit!')
        expect(atom.notifications.notifications.length).toBe(0)
        waitsFor((-> editor.getText() is 'def')
          "the editor's content to change", 50)

      it "throws an error when editing a new file", ->
        editor.getBuffer().reload()
        keydown(':')
        submitNormalModeInputText('edit')
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: No file name')
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText('edit!')
        expect(atom.notifications.notifications[1].message).toEqual(
          'Command error: No file name')

    describe "with a file name", ->
      beforeEach ->
        spyOn(atom.workspace, 'open')
        editor.getBuffer().reload()

      it "opens the specified path", ->
        filePath = projectPath('edit-new-test')
        keydown(':')
        submitNormalModeInputText("edit #{filePath}")
        expect(atom.workspace.open).toHaveBeenCalledWith(filePath)

      it "opens a relative path", ->
        keydown(':')
        submitNormalModeInputText('edit edit-relative-test')
        expect(atom.workspace.open).toHaveBeenCalledWith(
          projectPath('edit-relative-test'))

      it "throws an error if trying to open more than one file", ->
        keydown(':')
        submitNormalModeInputText('edit edit-new-test-1 edit-new-test-2')
        expect(atom.workspace.open.callCount).toBe(0)
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: Only one file name allowed')

  describe ":tabedit", ->
    it "acts as an alias to :edit if supplied with a path", ->
      spyOn(ExCommands.commands.tabedit, 'callback').andCallThrough()
      spyOn(ExCommands.commands.edit, 'callback')
      keydown(':')
      submitNormalModeInputText('tabedit tabedit-test')
      expect(ExCommands.commands.edit.callback).toHaveBeenCalledWith(
        ExCommands.commands.tabedit.callback.calls[0].args...)

    it "acts as an alias to :tabnew if not supplied with a path", ->
      spyOn(ExCommands.commands.tabedit, 'callback').andCallThrough()
      spyOn(ExCommands.commands.tabnew, 'callback')
      keydown(':')
      submitNormalModeInputText('tabedit  ')
      expect(ExCommands.commands.tabnew.callback).toHaveBeenCalledWith(
        ExCommands.commands.tabedit.callback.calls[0].args...)

  describe ":tabnew", ->
    it "opens a new tab", ->
      spyOn(atom.workspace, 'open')
      keydown(':')
      submitNormalModeInputText('tabnew')
      expect(atom.workspace.open).toHaveBeenCalled()

  describe ":split", ->
    it "splits the current file upwards", ->
      pane = atom.workspace.getActivePane()
      spyOn(pane, 'splitUp').andCallThrough()
      filePath = projectPath('split')
      editor.saveAs(filePath)
      keydown(':')
      submitNormalModeInputText('split')
      expect(pane.splitUp).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains a TextEditor
      #        pointing to the same path

  describe ":new", ->
    it "splits a new file upwards", ->
      pane = atom.workspace.getActivePane()
      spyOn(pane, 'splitUp').andCallThrough()
      keydown(':')
      submitNormalModeInputText('new')
      expect(pane.splitUp).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains an empty file

  describe ":vsplit", ->
    it "splits the current file to the left", ->
      pane = atom.workspace.getActivePane()
      spyOn(pane, 'splitLeft').andCallThrough()
      filePath = projectPath('vsplit')
      editor.saveAs(filePath)
      keydown(':')
      submitNormalModeInputText('vsplit')
      expect(pane.splitLeft).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains a TextEditor
      #        pointing to the same path

  describe ":vnew", ->
    it "splits a new file to the left", ->
      pane = atom.workspace.getActivePane()
      spyOn(pane, 'splitLeft').andCallThrough()
      keydown(':')
      submitNormalModeInputText('vnew')
      expect(pane.splitLeft).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains an empty file

  describe ":delete", ->
    beforeEach ->
      editor.setText('abc\ndef\nghi\njkl')
      editor.setCursorBufferPosition([2, 0])

    it "deletes the current line", ->
      keydown(':')
      submitNormalModeInputText('delete')
      expect(editor.getText()).toEqual('abc\ndef\njkl')

    it "deletes the lines in the given range", ->
      processedOpStack = false
      exState.onDidProcessOpStack -> processedOpStack = true
      keydown(':')
      submitNormalModeInputText('1,2delete')
      expect(editor.getText()).toEqual('ghi\njkl')

      waitsFor -> processedOpStack
      editor.setText('abc\ndef\nghi\njkl')
      editor.setCursorBufferPosition([1, 1])
      # For some reason, keydown(':') doesn't work here :/
      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText(',/k/delete')
      expect(editor.getText()).toEqual('abc\n')

    it "undos deleting several lines at once", ->
      keydown(':')
      submitNormalModeInputText('-1,.delete')
      expect(editor.getText()).toEqual('abc\njkl')
      atom.commands.dispatch(editorElement, 'core:undo')
      expect(editor.getText()).toEqual('abc\ndef\nghi\njkl')

  describe ":substitute", ->
    beforeEach ->
      editor.setText('abcaABC\ndefdDEF\nabcaABC')
      editor.setCursorBufferPosition([0, 0])

    it "replaces a character on the current line", ->
      keydown(':')
      submitNormalModeInputText(':substitute /a/x')
      expect(editor.getText()).toEqual('xbcaABC\ndefdDEF\nabcaABC')

    it "doesn't need a space before the arguments", ->
      keydown(':')
      submitNormalModeInputText(':substitute/a/x')
      expect(editor.getText()).toEqual('xbcaABC\ndefdDEF\nabcaABC')

    it "respects modifiers passed to it", ->
      keydown(':')
      submitNormalModeInputText(':substitute/a/x/g')
      expect(editor.getText()).toEqual('xbcxABC\ndefdDEF\nabcaABC')

      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText(':substitute/a/x/gi')
      expect(editor.getText()).toEqual('xbcxxBC\ndefdDEF\nabcaABC')

    it "replaces on multiple lines", ->
      keydown(':')
      submitNormalModeInputText(':%substitute/abc/ghi')
      expect(editor.getText()).toEqual('ghiaABC\ndefdDEF\nghiaABC')

      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText(':%substitute/abc/ghi/ig')
      expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nghiaghi')

    it "can't be delimited by letters or \\", ->
      keydown(':')
      submitNormalModeInputText(':substitute nanxngi')
      expect(atom.notifications.notifications[0].message).toEqual(
        "Command error: Regular expressions can't be delimited by letters")
      expect(editor.getText()).toEqual('abcaABC\ndefdDEF\nabcaABC')

      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText(':substitute\\a\\x\\gi')
      expect(atom.notifications.notifications[1].message).toEqual(
        "Command error: Regular expressions can't be delimited by \\")
      expect(editor.getText()).toEqual('abcaABC\ndefdDEF\nabcaABC')

    describe "case sensitivity", ->
      describe "respects the smartcase setting", ->
        beforeEach ->
          editor.setText('abcaABC\ndefdDEF\nabcaABC')

        it "uses case sensitive search if smartcase is off and the pattern is lowercase", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', false)
          keydown(':')
          submitNormalModeInputText(':substitute/abc/ghi/g')
          expect(editor.getText()).toEqual('ghiaABC\ndefdDEF\nabcaABC')

        it "uses case sensitive search if smartcase is off and the pattern is uppercase", ->
          editor.setText('abcaABC\ndefdDEF\nabcaABC')
          keydown(':')
          submitNormalModeInputText(':substitute/ABC/ghi/g')
          expect(editor.getText()).toEqual('abcaghi\ndefdDEF\nabcaABC')

        it "uses case insensitive search if smartcase is on and the pattern is lowercase", ->
          editor.setText('abcaABC\ndefdDEF\nabcaABC')
          atom.config.set('vim-mode.useSmartcaseForSearch', true)
          keydown(':')
          submitNormalModeInputText(':substitute/abc/ghi/g')
          expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nabcaABC')

        it "uses case sensitive search if smartcase is on and the pattern is uppercase", ->
          editor.setText('abcaABC\ndefdDEF\nabcaABC')
          keydown(':')
          submitNormalModeInputText(':substitute/ABC/ghi/g')
          expect(editor.getText()).toEqual('abcaghi\ndefdDEF\nabcaABC')

      describe "\\c and \\C in the pattern", ->
        beforeEach ->
          editor.setText('abcaABC\ndefdDEF\nabcaABC')

        it "uses case insensitive search if smartcase is off and \c is in the pattern", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', false)
          keydown(':')
          submitNormalModeInputText(':substitute/abc\\c/ghi/g')
          expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nabcaABC')

        it "doesn't matter where in the pattern \\c is", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', false)
          keydown(':')
          submitNormalModeInputText(':substitute/a\\cbc/ghi/g')
          expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nabcaABC')

        it "uses case sensitive search if smartcase is on, \\C is in the pattern and the pattern is lowercase", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', true)
          keydown(':')
          submitNormalModeInputText(':substitute/a\\Cbc/ghi/g')
          expect(editor.getText()).toEqual('ghiaABC\ndefdDEF\nabcaABC')

        it "overrides \\C with \\c if \\C comes first", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', true)
          keydown(':')
          submitNormalModeInputText(':substitute/a\\Cb\\cc/ghi/g')
          expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nabcaABC')

        it "overrides \\C with \\c if \\c comes first", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', true)
          keydown(':')
          submitNormalModeInputText(':substitute/a\\cb\\Cc/ghi/g')
          expect(editor.getText()).toEqual('ghiaghi\ndefdDEF\nabcaABC')

        it "overrides an appended /i flag with \\C", ->
          atom.config.set('vim-mode.useSmartcaseForSearch', true)
          keydown(':')
          submitNormalModeInputText(':substitute/ab\\Cc/ghi/gi')
          expect(editor.getText()).toEqual('ghiaABC\ndefdDEF\nabcaABC')

    describe "capturing groups", ->
      beforeEach ->
        editor.setText('abcaABC\ndefdDEF\nabcaABC')

      it "replaces \\1 with the first group", ->
        keydown(':')
        submitNormalModeInputText(':substitute/bc(.{2})/X\\1X')
        expect(editor.getText()).toEqual('aXaAXBC\ndefdDEF\nabcaABC')

      it "replaces multiple groups", ->
        keydown(':')
        submitNormalModeInputText(':substitute/a([a-z]*)aA([A-Z]*)/X\\1XY\\2Y')
        expect(editor.getText()).toEqual('XbcXYBCY\ndefdDEF\nabcaABC')

      it "replaces \\0 with the entire match", ->
        keydown(':')
        submitNormalModeInputText(':substitute/ab(ca)AB/X\\0X')
        expect(editor.getText()).toEqual('XabcaABXC\ndefdDEF\nabcaABC')

  describe ":set", ->
    it "throws an error without a specified option", ->
      keydown(':')
      submitNormalModeInputText('set')
      expect(atom.notifications.notifications[0].message).toEqual(
        'Command error: No option specified')

    it "sets multiple options at once", ->
      atom.config.set('editor.showInvisibles', false)
      atom.config.set('editor.showLineNumbers', false)
      keydown(':')
      submitNormalModeInputText('set list number')
      expect(atom.config.get('editor.showInvisibles')).toBe(true)
      expect(atom.config.get('editor.showLineNumbers')).toBe(true)

    it "sets options to false with no{option}", ->
      atom.config.set('editor.showInvisibles', true)
      keydown(':')
      submitNormalModeInputText('set nolist')
      expect(atom.config.get('editor.showInvisibles')).toBe(false)

    it "inverts options with inv{option}", ->
      atom.config.set('editor.showInvisibles', true)
      keydown(':')
      submitNormalModeInputText('set invlist')
      expect(atom.config.get('editor.showInvisibles')).toBe(false)
      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText('set invlist')
      expect(atom.config.get('editor.showInvisibles')).toBe(true)

    it "inverts options with {option}!", ->
      atom.config.set('editor.showInvisibles', true)
      keydown(':')
      submitNormalModeInputText('set list!')
      expect(atom.config.get('editor.showInvisibles')).toBe(false)
      atom.commands.dispatch(editorElement, 'ex-mode:open')
      submitNormalModeInputText('set list!')
      expect(atom.config.get('editor.showInvisibles')).toBe(true)

    describe "the options", ->
      it "sets list", ->
        atom.config.set('editor.showInvisibles', false)
        keydown(':')
        submitNormalModeInputText(':set list')
        expect(atom.config.get('editor.showInvisibles')).toBe(true)

      it "sets nu[mber]", ->
        atom.config.set('editor.showLineNumbers', false)
        keydown(':')
        submitNormalModeInputText(':set nu')
        expect(atom.config.get('editor.showLineNumbers')).toBe(true)
        atom.config.set('editor.showLineNumbers', false)
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText(':set number')
        expect(atom.config.get('editor.showLineNumbers')).toBe(true)
