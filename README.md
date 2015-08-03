# ex-mode package

ex-mode for Atom's vim-mode

## Use

Install both [vim-mode](https://github.com/atom/vim-mode) and ex-mode. Type `:` in command mode. Enter `w` or `write`.

## Extend

Use the service to register commands, from your own package, or straight from `init.coffee`:

```coffee
# in Atom's init.coffee
atom.packages.onDidActivatePackage (pack) ->
  if pack.name == 'ex-mode'
    Ex = pack.mainModule.provideEx_0_30()
    Ex.registerCommand
      name: 'z'
      priority: 1
      callback: -> console.log('zzzzzz')
```

See `lib/ex.coffee` for some examples commands. Contributions are very welcome!

## Status

Groundwork is done. More ex commands are easy to add and will be coming as time permits and contributions come in.

## License

MIT
