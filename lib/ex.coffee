class Ex
  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  q: =>
    @quit()

  s: ->
    setTimeout(->
        atom.commands.dispatch(atom.views.getView(atom.workspace.getActiveEditor()), 'find-and-replace:show')
    , 100) # Timeout is for working around issue where the search area doesn't focus

  tabedit: (filenames) ->
    if filenames? and filenames.length > 0
      atom.open(pathsToOpen: filenames)
    else
      atom.open()

  tabe: (filenames) =>
    @tabedit(filenames)

  write: () =>
    dfd = Promise.defer()

    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      atom.workspace.getActivePane().saveItem(atom.workspace.getActivePane().getActiveItem(), dfd.resolve)
    else
      atom.workspace.getActivePane().saveActiveItemAs(dfd.resolve)

    dfd.promise

  w: => @write()
  wq: => @write().then(=>@quit())

module.exports = Ex
