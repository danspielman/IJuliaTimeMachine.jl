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


* can_copy returns false on IJulia.Out, and probably should on past
* so, do not store Out or past .

# To do



* do not store Out in past.  and, maybe don't even put it in ans?  not sure.
* use a queue to move our generated out items to IJulia's out items, make it a preexecution hook.
* bad examples are things that point to themselves.  they will break `can_copy` causing a stack overflow.  need to fix that.  examples like `x = []; push!(x,x)`


* need to break error if just look at Out ... not sure why the error, but some sort of loop happens.
* maybe keep our output in TMOut.  And, could just redirect Julia's out ptr to ours. depends on when it is set.
* maybe we could use a precell hook to check if Outs need to be cleaned up.
* we could have a queue of those that need fixing - and are put into the queue when the jobs finish.
* Or, can I disable IJulia's store history?

* in execute request, it stores history, then runs preexecute, then code, then store output, then postexecute.
So, preexecute could turn off store history, and postexecute could turn it back on, allowing us to do the storage into out.  We would store result / ans, just like Julia does?  But, make it locking. except that store history is not a variable we can change.  it is local.

* put in some locks

* could give it a save option

* Fix: output from printlns appears all over, and can not control that.

* add an option to declare a variable not for copy, so we don't mess with big data.


* Come up with better names for all the routines in the interface.

* Find a way to copy and save functions (maybe using IRtools)

* Find a way to capture the output (sent to stdout) of spawned processes.

* Create a GUI to keep track of which spawned processes are running, and which have finished.

* The saving of the past is a little inefficient right now in that it copies all variables at all times. Implement something that only makes copies of new variables (using a hash).

