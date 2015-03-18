# kvstore

Simple file-based key-value store implemented in Bash

# Installation

Available as a [bpkg](bpkg.github.io)
```sh
bpkg install carpita/kvstore
```

Or, simply copy kvstore.sh to `$MY_BIN_PATH/kvstore`

You can get command line completions by evaluating the shellinit command:

```sh
# In profile.rc
eval "$(kvstore shellinit)"
```

# Basic Usage

```
$ kvstore set mykvfile key some_value

$ kvstore ls
> mykvfile

$ kvstore ls mykvfile
> key

$ kvstore get key
> some_value

$ kvstore -h
> ...Usage...
```
