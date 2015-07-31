class VimOption
  @options =
    'list': 'editor.showInvisibles'
    'nu': 'editor.showLineNumbers'
    'number': 'editor.showLineNumbers'

  @registerOption: (vimName, atomName) ->
    @options[vimName] = atomName

  @set: (name, value) ->
    atom.config.set(@options[name], value)

  @get: (name) ->
    atom.config.get(@options[name])

  @inv: (name) ->
    atom.config.set(@options[name], not atom.config.get(@options[name]))

module.exports = VimOption
