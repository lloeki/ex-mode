fs = require 'fs-plus'
path = require 'path'
os = require 'os'
uuid = require 'node-uuid'
helpers = require './spec-helper'

ExClass = require('../lib/ex')
Ex = ExClass.singleton()

describe "the commands", ->
  [editor, editorElement, vimState, exState, dir, dir2] = []
  projectPath = (fileName) -> path.join(dir, fileName)
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
      dir = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
      dir2 = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
      fs.makeTreeSync(dir)
      fs.makeTreeSync(dir2)
      atom.project.setPaths([dir, dir2])

      helpers.getEditorElement (element) ->
        atom.commands.dispatch(element, "ex-mode:open")
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

  describe ":wall", ->
    it "saves all", ->
      spyOn(atom.workspace, 'saveAll')
      keydown(':')
      submitNormalModeInputText('wall')
      expect(atom.workspace.saveAll).toHaveBeenCalled()

  describe ":saveas", ->
    describe "when editing a new file", ->
      beforeEach ->
        editor.getBuffer().setText('abc\ndef')

      it "opens the save dialog", ->
        spyOn(atom, 'showSaveDialogSync')
        keydown(':')
        submitNormalModeInputText('saveas')
        expect(atom.showSaveDialogSync).toHaveBeenCalled()

      it "saves when a path is specified in the save dialog", ->
        filePath = projectPath('saveas-from-save-dialog')
        spyOn(atom, 'showSaveDialogSync').andReturn(filePath)
        keydown(':')
        submitNormalModeInputText('saveas')
        expect(fs.existsSync(filePath)).toBe(true)
        expect(fs.readFileSync(filePath, 'utf-8')).toEqual('abc\ndef')

      it "saves when a path is specified in the save dialog", ->
        spyOn(atom, 'showSaveDialogSync').andReturn(undefined)
        spyOn(fs, 'writeFileSync')
        keydown(':')
        submitNormalModeInputText('saveas')
        expect(fs.writeFileSync.calls.length).toBe(0)

    describe "when editing an existing file", ->
      filePath = ''
      i = 0

      beforeEach ->
        i++
        filePath = projectPath("saveas-#{i}")
        editor.setText('abc\ndef')
        editor.saveAs(filePath)

      it "complains if no path given", ->
        editor.setText('abc')
        keydown(':')
        submitNormalModeInputText('saveas')
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: Argument required'
        )

      describe "with a specified path", ->
        newPath = ''

        beforeEach ->
          newPath = path.relative(dir, "#{filePath}.new")
          editor.getBuffer().setText('abc')
          keydown(':')

        afterEach ->
          submitNormalModeInputText("saveas #{newPath}")
          newPath = path.resolve(dir, fs.normalize(newPath))
          expect(fs.existsSync(newPath)).toBe(true)
          expect(fs.readFileSync(newPath, 'utf-8')).toEqual('abc')
          expect(editor.isModified()).toBe(false)
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
        submitNormalModeInputText('saveas path1 path2')
        expect(atom.notifications.notifications[0].message).toEqual(
          'Command error: Only one file name allowed'
        )

      describe "when the file already exists", ->
        existsPath = ''

        beforeEach ->
          existsPath = projectPath('saveas-exists')
          fs.writeFileSync(existsPath, 'abc')

        afterEach ->
          fs.removeSync(existsPath)

        it "throws an error if the file already exists", ->
          keydown(':')
          submitNormalModeInputText("saveas #{existsPath}")
          expect(atom.notifications.notifications[0].message).toEqual(
            'Command error: File exists (add ! to override)'
          )
          expect(fs.readFileSync(existsPath, 'utf-8')).toEqual('abc')

        it "writes if forced with :saveas!", ->
          keydown(':')
          submitNormalModeInputText("saveas! #{existsPath}")
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

  describe ":quitall", ->
    it "closes Atom", ->
      spyOn(atom, 'close')
      keydown(':')
      submitNormalModeInputText('quitall')
      expect(atom.close).toHaveBeenCalled()

  describe ":tabclose", ->
    it "acts as an alias to :quit", ->
      spyOn(Ex, 'tabclose').andCallThrough()
      spyOn(Ex, 'quit').andCallThrough()
      keydown(':')
      submitNormalModeInputText('tabclose')
      expect(Ex.quit).toHaveBeenCalledWith(Ex.tabclose.calls[0].args...)

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

  describe ":wq", ->
    beforeEach ->
      spyOn(Ex, 'write').andCallThrough()
      spyOn(Ex, 'quit')

    it "writes the file, then quits", ->
      spyOn(atom, 'showSaveDialogSync').andReturn(projectPath('wq-1'))
      keydown(':')
      submitNormalModeInputText('wq')
      expect(Ex.write).toHaveBeenCalled()
      # Since `:wq` only calls `:quit` after `:write` is finished, we need to
      #  wait a bit for the `:quit` call to occur
      waitsFor((-> Ex.quit.wasCalled), "the :quit command to be called", 100)

    it "doesn't quit when the file is new and no path is specified in the save dialog", ->
      spyOn(atom, 'showSaveDialogSync').andReturn(undefined)
      keydown(':')
      submitNormalModeInputText('wq')
      expect(Ex.write).toHaveBeenCalled()
      wasNotCalled = false
      # FIXME: This seems dangerous, but setTimeout somehow doesn't work.
      setImmediate((->
        wasNotCalled = not Ex.quit.wasCalled))
      waitsFor((-> wasNotCalled), 100)

    it "passes the file name", ->
      keydown(':')
      submitNormalModeInputText('wq wq-2')
      expect(Ex.write)
        .toHaveBeenCalled()
      expect(Ex.write.calls[0].args[0].args.trim()).toEqual('wq-2')
      waitsFor((-> Ex.quit.wasCalled), "the :quit command to be called", 100)

  describe ":xit", ->
    it "acts as an alias to :wq", ->
      spyOn(Ex, 'wq')
      keydown(':')
      submitNormalModeInputText('xit')
      expect(Ex.wq).toHaveBeenCalled()

  describe ":wqall", ->
    it "calls :wall, then :quitall", ->
      spyOn(Ex, 'wall')
      spyOn(Ex, 'quitall')
      keydown(':')
      submitNormalModeInputText('wqall')
      expect(Ex.wall).toHaveBeenCalled()
      expect(Ex.quitall).toHaveBeenCalled()

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
      spyOn(Ex, 'tabedit').andCallThrough()
      spyOn(Ex, 'edit')
      keydown(':')
      submitNormalModeInputText('tabedit tabedit-test')
      expect(Ex.edit).toHaveBeenCalledWith(Ex.tabedit.calls[0].args...)

    it "acts as an alias to :tabnew if not supplied with a path", ->
      spyOn(Ex, 'tabedit').andCallThrough()
      spyOn(Ex, 'tabnew')
      keydown(':')
      submitNormalModeInputText('tabedit  ')
      expect(Ex.tabnew)
        .toHaveBeenCalledWith(Ex.tabedit.calls[0].args...)

  describe ":tabnew", ->
    it "opens a new tab", ->
      spyOn(atom.workspace, 'open')
      keydown(':')
      submitNormalModeInputText('tabnew')
      expect(atom.workspace.open).toHaveBeenCalled()

  describe ":split", ->
    it "splits the current file upwards/downward", ->
      pane = atom.workspace.getActivePane()
      if atom.config.get('ex-mode.splitbelow')
        spyOn(pane, 'splitDown').andCallThrough()
        filePath = projectPath('split')
        editor.saveAs(filePath)
        keydown(':')
        submitNormalModeInputText('split')
        expect(pane.splitDown).toHaveBeenCalled()
      else
        spyOn(pane, 'splitUp').andCallThrough()
        filePath = projectPath('split')
        editor.saveAs(filePath)
        keydown(':')
        submitNormalModeInputText('split')
        expect(pane.splitUp).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains a TextEditor
      #        pointing to the same path

  describe ":vsplit", ->
    it "splits the current file to the left/right", ->
      if atom.config.get('ex-mode.splitright')
        pane = atom.workspace.getActivePane()
        spyOn(pane, 'splitRight').andCallThrough()
        filePath = projectPath('vsplit')
        editor.saveAs(filePath)
        keydown(':')
        submitNormalModeInputText('vsplit')
        expect(pane.splitLeft).toHaveBeenCalled()
      else
        pane = atom.workspace.getActivePane()
        spyOn(pane, 'splitLeft').andCallThrough()
        filePath = projectPath('vsplit')
        editor.saveAs(filePath)
        keydown(':')
        submitNormalModeInputText('vsplit')
        expect(pane.splitLeft).toHaveBeenCalled()
      # FIXME: Should test whether the new pane contains a TextEditor
      #        pointing to the same path

  describe ":delete", ->
    beforeEach ->
      editor.setText('abc\ndef\nghi\njkl')
      editor.setCursorBufferPosition([2, 0])

    it "deletes the current line", ->
      keydown(':')
      submitNormalModeInputText('delete')
      expect(editor.getText()).toEqual('abc\ndef\njkl')

    it "copies the deleted text", ->
      keydown(':')
      submitNormalModeInputText('delete')
      expect(atom.clipboard.read()).toEqual('ghi\n')

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

    describe ":yank", ->
      beforeEach ->
        editor.setText('abc\ndef\nghi\njkl')
        editor.setCursorBufferPosition([2, 0])

      it "yanks the current line", ->
        keydown(':')
        submitNormalModeInputText('yank')
        expect(atom.clipboard.read()).toEqual('ghi\n')

      it "yanks the lines in the given range", ->
        keydown(':')
        submitNormalModeInputText('1,2yank')
        expect(atom.clipboard.read()).toEqual('abc\ndef\n')

    describe "illegal delimiters", ->
      test = (delim) ->
        keydown(':')
        submitNormalModeInputText(":substitute #{delim}a#{delim}x#{delim}gi")
        expect(atom.notifications.notifications[0].message).toEqual(
          "Command error: Regular expressions can't be delimited by alphanumeric characters, '\\', '\"' or '|'")
        expect(editor.getText()).toEqual('abcaABC\ndefdDEF\nabcaABC')

      it "can't be delimited by letters", -> test 'n'
      it "can't be delimited by numbers", -> test '3'
      it "can't be delimited by '\\'",    -> test '\\'
      it "can't be delimited by '\"'",    -> test '"'
      it "can't be delimited by '|'",     -> test '|'

    describe "empty replacement", ->
      beforeEach ->
        editor.setText('abcabc\nabcabc')

      it "removes the pattern without modifiers", ->
        keydown(':')
        submitNormalModeInputText(":substitute/abc//")
        expect(editor.getText()).toEqual('abc\nabcabc')

      it "removes the pattern with modifiers", ->
        keydown(':')
        submitNormalModeInputText(":substitute/abc//g")
        expect(editor.getText()).toEqual('\nabcabc')

    describe "replacing with escape sequences", ->
      beforeEach ->
        editor.setText('abc,def,ghi')

      test = (escapeChar, escaped) ->
        keydown(':')
        submitNormalModeInputText(":substitute/,/\\#{escapeChar}/g")
        expect(editor.getText()).toEqual("abc#{escaped}def#{escaped}ghi")

      it "replaces with a tab", -> test('t', '\t')
      it "replaces with a linefeed", -> test('n', '\n')
      it "replaces with a carriage return", -> test('r', '\r')

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
      submitNormalModeInputText(':set')
      expect(atom.notifications.notifications[0].message).toEqual(
        'Command error: No option specified')

    it "sets multiple options at once", ->
      atom.config.set('editor.showInvisibles', false)
      atom.config.set('editor.showLineNumbers', false)
      keydown(':')
      submitNormalModeInputText(':set list number')
      expect(atom.config.get('editor.showInvisibles')).toBe(true)
      expect(atom.config.get('editor.showLineNumbers')).toBe(true)

    describe "the options", ->
      beforeEach ->
        atom.config.set('editor.showInvisibles', false)
        atom.config.set('editor.showLineNumbers', false)

      it "sets (no)list", ->
        keydown(':')
        submitNormalModeInputText(':set list')
        expect(atom.config.get('editor.showInvisibles')).toBe(true)
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText(':set nolist')
        expect(atom.config.get('editor.showInvisibles')).toBe(false)

      it "sets (no)nu(mber)", ->
        keydown(':')
        submitNormalModeInputText(':set nu')
        expect(atom.config.get('editor.showLineNumbers')).toBe(true)
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText(':set nonu')
        expect(atom.config.get('editor.showLineNumbers')).toBe(false)
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText(':set number')
        expect(atom.config.get('editor.showLineNumbers')).toBe(true)
        atom.commands.dispatch(editorElement, 'ex-mode:open')
        submitNormalModeInputText(':set nonumber')
        expect(atom.config.get('editor.showLineNumbers')).toBe(false)

  describe "aliases", ->
    it "calls the aliased function without arguments", ->
      ExClass.registerAlias('W', 'w')
      spyOn(Ex, 'write')
      keydown(':')
      submitNormalModeInputText('W')
      expect(Ex.write).toHaveBeenCalled()

    it "calls the aliased function with arguments", ->
      ExClass.registerAlias('W', 'write')
      spyOn(Ex, 'W').andCallThrough()
      spyOn(Ex, 'write')
      keydown(':')
      submitNormalModeInputText('W')
      WArgs = Ex.W.calls[0].args[0]
      writeArgs = Ex.write.calls[0].args[0]
      expect(WArgs).toBe writeArgs
