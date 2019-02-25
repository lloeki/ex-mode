# ex-mode package

ex-mode for Atom's vim-mode

## Use

Install both [vim-mode-plus](https://github.com/t9md/atom-vim-mode-plus) (or
the deprecated `vim-mode`) and ex-mode. Type `:` in command mode. Enter `w` or
`write`.

## Extend

Use the service to register commands, from your own package, or straight from `init.coffee`:

```coffee
# in Atom's init.coffee
atom.packages.onDidActivatePackage (pack) ->
  if pack.name == 'ex-mode'
    Ex = pack.mainModule.provideEx()
    Ex.registerCommand 'z', -> console.log("Zzzzzz...")
```

You can also add aliases:

```coffee
atom.packages.onDidActivatePackage (pack) ->
  if pack.name == 'ex-mode'
    Ex = pack.mainModule.provideEx()
    Ex.registerAlias 'WQ', 'wq'
    Ex.registerAlias 'Wq', 'wq'
```

## Existing commands

This is the baseline list of commands supported in `ex-mode`.

| Command                                 | Operation                          |
| --------------------------------------- | ---------------------------------- |
| `q/quit/tabc/tabclose`                    | Close active tab                   |
| `qall/quitall`                            | Close all tabs                     |
| `tabe/tabedit/tabnew`                     | Open new tab                       |
| `e/edit/tabe/tabedit/tabnew <file>` | Edit given file                    |
| `tabn/tabnext`                            | Go to next tab                     |
| `tabp/tabprevious`                        | Go to previous tab                 |
| `tabo/tabonly`                            | Close other tabs                   |
| `w/write`                                 | Save active tab                    |
| `w/write/saveas <file>`             | Save as                            |
| `wall/wa`                                 | Save all tabs                      |
| `sp/split`                                | Split window                       |
| `sp/split <file>`                   | Open file in split window          |
| `s/substitute`                            | Substitute regular expression in active line                                  |
| `vsp/vsplit`                              | Vertical split window              |
| `vsp/vsplit <file>`                 | Open file in vertical split window |
| `delete`                                  | Cut active line                    |
| `yank`                                    | Copy active line                   |
| `set <options>`                     | Set options                        |
| `sort`                                    | Sort all lines in file             |
| `sort <line range>`                 | Sort lines in line range           |

See `lib/ex.coffee` for the implementations of these commands. Contributions are very welcome!

## Status

Groundwork is done. More ex commands are easy to add and will be coming as time permits and contributions come in.

## License

MIT
