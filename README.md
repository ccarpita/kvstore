# kvstore

Simple file-based key-value store implemented in Bash

# Installation

Available as a [bpkg](bpkg.github.io)
```sh
bpkg install ccarpita/kvstore
```

Or, simply copy kvstore.sh to `$MY_BIN_PATH/kvstore`

You can get command line completions by evaluating the shellinit command:

```sh
# In profile.rc
eval "$(kvstore shellinit)"
```

# Basic Usage

```
$ kvstore set mykvfile akey some_value
$ kvstore set mykvfile "another key" "some value67"

$ kvstore ls
mykvfile
myotherkvfile
urls
favoritecommands

$ kvstore keys mykvfile
akey
another key

$ kvstore get mykvfile akey
some_value

$ kvstore -h
# prints full usage info...
```
# Version

This is version 3.0. This version has an incompatible interface change from the 2.X series: commands' options have been moved from the rear of the argument list to the front, as is custom in UNIX.

# License

MIT - https://opensource.org/licenses/MIT
