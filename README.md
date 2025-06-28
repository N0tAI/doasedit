# doasedit

This version of doasedit is a script designed to implement basic sudoedit functionality for users of opendoas.
More specifically this script will open a shell as the target user and attempt to read and copy the file over
to your shell. You are then prompted to edit the file and after successfully editing the value is copied back
over to the original file.

**Important to note this implementation unlike every other I can find only uses ONE doas call**

Note that this shell intends to remain a fully posix compliant script, if you have any issues running this on a posix
compliant shell please report it. (currently only testing on my system)

## Acknowledgement
Thanks to the [Sudo Project](https://github.com/sudo-project/sudo) for the initial idea

Thanks to repositories such as [TotallyLeGIT/doasedit](https://codeberg.org/TotallyLeGIT/doasedit) for helping me think through what I have to do
