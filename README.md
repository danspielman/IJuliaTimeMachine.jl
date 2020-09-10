# IJuliaTimeMachine

This package provides two capabilities that can be very useful when running computational experiments in IJulia notebooks:
* It allows you to return all variables to a previous state (the past).
I often run experiments in Julia cells that can take minutes to hours to complete.
Sometimes, I want to re-examine the variables in a cell, but I have already over-written them.
This makes it easy to recall them.

* It allows you to spawn a process to run on another thread while you keep writing other cells (the future).
The process copies all of its variables to variables of new names before running, so it does not effect other cells.
This is especially useful if you plan to run many similar experiments.  
Now, you can just copy, paste and modify cells before running them.

# Installation

~~~julia
> using Pkg; Pkg.add("IJuliaTimeMachine")
~~~

Once you are running a Jupyter notebook, you can start the time machine by typing
~~~julia
> using IJuliaTimeMachine
~~~

As the name of the package is rather long, and all of its commands require it as a prefix, I recommend renaming it like
~~~julia
> TM = IJuliaTimeMachine
~~~

The rest of these docs assume you have renamed it to `TM`.

# Basic Usage

First, note that IJulia already provides some history functionality.
It maintains dictionaries `In` and `Out` that store the input (contents) and output (ans) of every cell.
To see the answer computed in cell 20, examine `Out[20]`.

To go back to the state as it was after cell 20, at any time, type `TM.@past 20`.

To stop saving state, type `TM.stop_saving()`.  To start up again, type `TM.start_saving()`.

If you need to free up memory, type `TM.clear_past()` to clear all the saved state information.
`TM.clear_past(cells)` clears the states in the iterator (or range) given by `cells`.

`TM.running` keeps track of cells that are running.
`TM.finished` of course keeps track of those that stopped.

# Details

* undefined problem solved with `global` in front of variable.

* The state saving features work by using an IJulia `postexecute_hook`.

* Time Machine only saves variables that are in `Main`.  
It stores them in `TM.past`.

* The Time Machine only saves variables that can be copied with deepcopy.  In particular, it does not save functions.  It would be nice to add a way to copy functions.

* The way that we copy and rename variables is a little crude, and relies on a poor understanding of Julia Exprs.  It should be cleaned up. It might make mistakes.


# To do

# URGENT: deep copy to make safe.  and, only deepcopy vars for which we can.

* Fix: output from printlns appears all over, and can not control that.

* when copy variables to make safe spawn, we need to do a deepcopy in case they are modified.
* but, then also need to be sure can do a deepcopy of it

* Come up with better names for all the routines in the interface.

* Find a way to copy and save functions (maybe using IRtools)
* Find a way to capture the output (sent to stdout) of spawned processes.
* Create a GUI to keep track of which spawned processes are running, and which have finished.

* The saving of the past is a little inefficient right now in that it copies all variables at all times. Implement something that only makes copies of new variables (using a hash).

