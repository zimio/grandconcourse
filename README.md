# grand-concourse

Emacs mode to visualize concourse pipelines.

## Disclaimer

This program is given freely with no warranties. The only thing I ask is that if you improve this program, please send me back those improvements. I won't promise to merge them into this code base, but being aware of possible improvements can help out a lot.

## Getting started

This package is not available in MEL-PA, so you will have to load it the old fashioned way using: 

`(require 'grand-concourse)`


There are two variables that you would need to customize: `grand-concourse-fly-path`, which should contain the path to the binary of fly, usually something like /usr/local/bin/fly, and `grand-concourse-target`, which should contain the target name to operate in concourse. 


Before doing anything, you will want to run `grand-concourse-login` so you can authenticate in your target. Then, the starting point is `grand-concourse-list-pipelines`, this will allow you to view all the pipelines and drill down to the specific build you want the logs for.
