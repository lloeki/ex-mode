fs = require 'fs-plus'
path = require 'path'
os = require 'os'
uuid = require 'node-uuid'

helpers = require './spec-helper'
AutoComplete = require '../lib/autocomplete'

describe "autocomplete functionality", ->
  beforeEach ->
    @autoComplete = new AutoComplete(['taba', 'tabb', 'tabc'])
    @testDir = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
    @nonExistentTestDir = path.join(os.tmpdir(), "atom-ex-mode-spec-#{uuid.v4()}")
    @testFile1 = path.join(@testDir, "atom-ex-testfile-a.txt")
    @testFile2 = path.join(@testDir, "atom-ex-testfile-b.txt")

    runs =>
      fs.makeTreeSync(@testDir)
      fs.closeSync(fs.openSync(@testFile1, 'w'));
      fs.closeSync(fs.openSync(@testFile2, 'w'));
      spyOn(@autoComplete, 'resetCompletion').andCallThrough()
      spyOn(@autoComplete, 'getFilePathCompletion').andCallThrough()
      spyOn(@autoComplete, 'getCommandCompletion').andCallThrough()

  afterEach ->
    fs.removeSync(@testDir)

  describe "autocomplete commands", ->
    beforeEach ->
      @completed = @autoComplete.getAutocomplete('tab')

    it "returns taba", ->
      expect(@completed).toEqual('taba')

    it "calls command function", ->
      expect(@autoComplete.getCommandCompletion.callCount).toBe(1)

  describe "autocomplete commands, then autoComplete again", ->
    beforeEach ->
      @completed = @autoComplete.getAutocomplete('tab')
      @completed = @autoComplete.getAutocomplete('tab')

    it "returns tabb", ->
      expect(@completed).toEqual('tabb')

    it "calls command function", ->
      expect(@autoComplete.getCommandCompletion.callCount).toBe(1)

  describe "autocomplete directory", ->
    beforeEach ->
      filePath = path.join(os.tmpdir(), 'atom-ex-mode-spec-')
      @completed = @autoComplete.getAutocomplete('tabe ' + filePath)

    it "returns testDir", ->
      expected = 'tabe ' + @testDir + path.sep
      expect(@completed).toEqual(expected)

    it "clears autocomplete", ->
      expect(@autoComplete.resetCompletion.callCount).toBe(1)

  describe "autocomplete directory, then autocomplete again", ->
    beforeEach ->
      filePath = path.join(os.tmpdir(), 'atom-ex-mode-spec-')
      @completed = @autoComplete.getAutocomplete('tabe ' + filePath)
      @completed = @autoComplete.getAutocomplete(@completed)

    it "returns test file 1", ->
      expect(@completed).toEqual('tabe ' + @testFile1)

    it "lists files twice", ->
      expect(@autoComplete.getFilePathCompletion.callCount).toBe(2)

  describe "autocomplete full directory, then autocomplete again", ->
    beforeEach ->
      filePath = path.join(@testDir, 'a')
      @completed = @autoComplete.getAutocomplete('tabe ' + filePath)
      @completed = @autoComplete.getAutocomplete(@completed)

    it "returns test file 2", ->
      expect(@completed).toEqual('tabe ' + @testFile2)

    it "lists files once", ->
      expect(@autoComplete.getFilePathCompletion.callCount).toBe(1)

  describe "autocomplete non existent directory", ->
    beforeEach ->
      @completed = @autoComplete.getAutocomplete('tabe ' + @nonExistentTestDir)

    it "returns no completions", ->
      expected = '';
      expect(@completed).toEqual(expected)

  describe "autocomplete existing file as directory", ->
    beforeEach ->
      filePath = @testFile1 + path.sep
      @completed = @autoComplete.getAutocomplete('tabe ' + filePath)

    it "returns no completions", ->
      expected = '';
      expect(@completed).toEqual(expected)
