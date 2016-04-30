## 0.9.0

* Added support for yank commands, ex `:1,10y` (@posgarou)
* Added contributor guidelines, including a pull request template
* Added ability to control splitting with `splitright`, and `splitbelow` (@dragonxwang)

### Fixes

* delete commands now add text to clipboard, ex `:1,4d`

## 0.8.0
* Don't allow :s delimiters not allowed by vim (@jacwah)
* Backspace over empty `:` now cancels ex-mode (@shamrin)
* Added option to register alias keys in atom init config (@GertjanReynaert)
* Allow `:substitute` to replace empty with an empty string and replacing the last search item (@jazzpi)
* Added `:wall`, `:quitall` and `:wqall` commands (@caiocutrim)
* Added `:saveas` command (@bakert)

## 0.6.0
* No project/multiple projects paths (uses first one)
* Support for :set
* Fixes

## 0.5.0
* Comply with upcoming Atom API 1.0
* Added `:d`
* Fixes

## 0.4.1 - C-C-C-Combo Edition
* Added ex command parser, including ranges
* Added `:wq`
* Added `:s`
* Alert on unknown or invalid command

## 0.3.0 - Extrovert Edition
* Register new commands from the outside world
* Added `:tabn`, `:tabp`, `:e`, `:enew`, and a few aliases

## 0.2.0 - NotAOneTrickPony Edition
* Added `:quit`, `:tabedit`, `:wa`, `:split`, `:vsplit`
* Commands can take arguments

## 0.1.0 - First Release
* Every feature added
* Every bug fixed
