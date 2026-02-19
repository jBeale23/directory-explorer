# Directory Explorer
A wrapper for cd that adds fuzzy finding, automatic file listing after changing directories, and directory stack based jumps.

# Installation
Place Directory Explorer in a convenient place, and then add the following to your `.bashrc` or a similar alternative:
```bash
. /PATH/TO/YOUR/INSTALLATION/de
```
Directory Explorer is then available to call via `de`.

## Dependencies
- Bash >= v4.2
- GNU Getopt
- GNU Sed
### Required for Fuzzy Searching
- fzf
- tree

# License
Directory Explorer is licensed under the terms of the [MIT License](https://directory.fsf.org/wiki/License:Expat).
