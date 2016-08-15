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

  splitright: =>
    atom.config.set("ex-mode.splitright", true)

  spr: =>
    @splitright()

  nosplitright: =>
    atom.config.set("ex-mode.splitright", false)

  nospr: =>
    @nosplitright()

  splitbelow: =>
    atom.config.set("ex-mode.splitbelow", true)

  sb: =>
    @splitbelow()

  nosplitbelow: =>
    atom.config.set("ex-mode.splitbelow", false)

  nosb: =>
    @nosplitbelow()

  smartcase: =>
    atom.config.set("vim-mode.useSmartcaseForSearch", true)

  scs: =>
    @smartcase()

  nosmartcase: =>
    atom.config.set("vim-mode.useSmartcaseForSearch", false)

  noscs: =>
    @nosmartcase()

module.exports = VimOption
