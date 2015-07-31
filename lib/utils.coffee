_ = require 'underscore-plus'

module.exports =
  getSearchTerm: (term, modifiers = {'g': true}) ->
    escaped = false
    hasc = false
    hasC = false
    term_ = term
    term = ''
    for char in term_
      if char is '\\' and not escaped
        escaped = true
        term += char
      else
        if char is 'c' and escaped
          hasc = true
          term = term[...-1]
        else if char is 'C' and escaped
          hasC = true
          term = term[...-1]
        else if char isnt '\\'
          term += char
        escaped = false

    if hasC
      modifiers['i'] = false
    if (not hasC and not term.match('[A-Z]') and \
        atom.config.get('vim-mode.useSmartcaseForSearch')) or hasc
      modifiers['i'] = true

    modFlags = Object.keys(modifiers).filter((key) -> modifiers[key]).join('')

    try
      new RegExp(term, modFlags)
    catch
      new RegExp(_.escapeRegExp(term), modFlags)
