class VimOption
  @singleton: =>
    @option ||= new VimOption

  list: =>
    atom.config.set("editor.showInvisibles", true)

  nolist: =>
    atom.config.set("editor.showInvisibles", false)

  number: =>
    atom.config.set("editor.showLineNumbers", true)

  nu: =>
    @number()

  nonumber: =>
    atom.config.set("editor.showLineNumbers", false)

  nonu: =>
    @nonumber()

module.exports = VimOption
