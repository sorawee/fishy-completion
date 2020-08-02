# Fishy Completion

This [Quickscript](https://docs.racket-lang.org/quickscript/) script allows users to autocomplete
an identifier via static analysis. 

To run the script, either use the menu or the keybinding (`ctrl ,` or `ctrl <` for version 1, and `ctrl m` for version 2). Running repeatedly will cycle through all candidates (similar to the [dynamic completion](https://github.com/Metaxal/quickscript-extra/blob/master/scripts/dynamic-abbrev.rkt) in Quickscript Extra).

Fishy completion has two versions: version 1 (`script.rkt`) and version 2 (`script-2.rkt`). The latter is supposed to be faster and more expressive (see the limitation of version 1 below).

## Guarantee and limitation

The script guarantees that any autocompleted identifier at a position will definitely be in scope (according to [Check Syntax](https://docs.racket-lang.org/tools/Check_Syntax.html)), but it does not guarantee that it will be able to recognize every candidate identifier in the scope. For example, identifiers that are imported from other modules, either explicitly (e.g., via `require`) or implicitly (e.g., via `#lang`) are not supported. To autocomplete identifiers from other modules, use the built-in autocomplete feature in DrRacket (`ctrl .`).

In order to run the completion, the program must not have any compile-time error. However, this is too strict because the fact that you intend to use autocompletion probably means that the current program contains invalid identifiers (and thus compile-time errors). Therefore, errors that are caused by the identifier at the current position (i.e., attempting to use non-identifier macro as an identifier macro) and unbound identifiers are tolerated as special cases. Other errors such as unbalanced parentheses or errors in macro expansion will disable the completion.

For version 1, the autocompletion only works on code in phase 0 and phase 1. Version 2 doesn't have this restriction, but unbound identifier errors in phase higher than 1 (in different position than the current position) will not be tolerated.

## Demo

![Demo 1](./demo/demo-fishy-1.gif "Demo 1")

Fishy completion can be used to autocomplete any identifiers that are defined in a module.
Autocompleted identifiers are guaranteed to be in scope.

![Demo 2](./demo/demo-fishy-2.gif "Demo 2")

Fishy completion recognizes non-apparent bindings such as those generated from the `struct` form. It also recognizes macros. Note that it does not recognize identifiers imported from other modules. Use the built-in autocomplete feature in DrRacket for that case.

![Demo 3](./demo/demo-fishy-3.gif "Demo 3")

Fishy completion can autocomplete quoted identifiers and identifiers that start with a number.

If the current position is not associated with any token that could become an identifier, or if there is no candidate that could be in scope (up to the limitation described above), fishy completion will disable itself. 

![Demo 4](./demo/demo-fishy-4.gif "Demo 4")

When there is a compile-time error, fishy completion will disable itself. There are a few exceptions as described above.

## Related work

There are several completion framework for Racket. 

- [Quickscript Extra](https://github.com/Metaxal/quickscript-extra/blob/master/README.md)'s dynamic completion (`dynamic-abbrev`) autocompletes words using existing words in the current file. Using it to autocomplete an identifier however means that it will suggest invalid identifiers taken from string literals.
- DrRacket itself has the completion functionality via `ctrl .`. It does not autocomplete identifiers defined within a module.
- [Racket Mode](https://www.racket-mode.com/) has its own completion functionality. In addition to supporting identifiers required from other modules, it supports identifiers within a module via Check Syntax (and also other things like autocompleting `require`). However, it only considers identifiers that appear textually in the code, so identifiers generated programmatically (e.g., from the `struct` form) are not considered. It does not autocomplete only identifiers that would be in scope.
- [DrComplete](https://github.com/yjqww6/drcomplete) enhances the completion functionality in DrRacket significantly. Similar to Racket Mode, it can autocomplete variety of things, including identifiers defined in a module. Additionally, it can discover identifiers generated programmatically. However, similar to Racket Mode, it does not autocomplete only identifiers that would be in scope.
