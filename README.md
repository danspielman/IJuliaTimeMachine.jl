# IJuliaTimeMachine

This package provides two capabilities that can be  useful when running computational experiments in IJulia notebooks:
* It allows you to return all variables to a previous state (the past).
I often run experiments in Julia cells that can take minutes to hours to complete.
Sometimes, I want to re-examine the variables in a cell, but I have already over-written them.
This makes it easy to recall them.

* It allows you to spawn a process to run on another thread while you keep writing other cells (the future).
The process copies all of its variables to variables of new names before running, so it does not impact other cells.
This is especially useful if you plan to run many similar experiments.  
Now, you can just copy, paste and modify cells before running them.

# Installation

To check how many threads you have available, type

~~~julia
> Threads.nthreads()
~~~

If you only have one, but should have more, then you have to do some configuration.

To make sure that your Jupyter notebook starts with threads, 
and you are running Jupyter from a cell, you could type

~~~shell
export JULIA_NUM_THREADS=4
jupyter notebook
~~~

Or, on a Mac, put the following line in the file
`~/.profile`:
~~~shell
export JULIA_NUM_THREADS=2
~~~

Of course, replace 2 or 4 with the number of threads you should have.  Usually, this is twice the number of cores.
To find out how many this could be, you could start Julia with the `-t auto` option, and then check how many threads it chooses to start with.


~~~julia
> using Pkg; Pkg.add(url="https://github.com/danspielman/IJuliaTimeMachine.jl")
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

You can run code in a thread by using `TM.@thread`.  It can be used at most once per cell.
Examples are like.

~~~julia
TM.@thread my_intensive_function(x)
~~~

~~~julia
TM.@thread begin
    a number of computationally intense lines
end
~~~

`TM.running` keeps track of cells that are running.
`TM.finished` of course keeps track of those that stopped.

You can find a demonstration of the time machine in action in the `examples` directory.
It is saved as a Jupyter notebook, html, and pdf.
To find the directory this package is in, try

~~~julia
Base.find_package("IJuliaTimeMachine")
~~~

# Bugs

* Any data structures with circular references will cause a stack overflow.
The problem is in the routine `can_copy`.

* Output from threads that is supposed to go to stdout winds up in whatever cell is current.
It would be terrific to capture this instead, and ideally make it something we can play back later.

* If you look at Demo, you will see some bug that happened when we tried to launch two threads from one cell: one of them is listed as running when it should have finished.

* There must be more!  Please try it and find them.

# Details

* The state saving features work by using an IJulia `postexecute_hook`.

* Time Machine only saves variables that are in `Main`.  
It stores them in `TM.past`.

* The Time Machine only saves variables that can be copied with deepcopy.  In particular, it does not save functions.  It would be nice to add a way to copy functions.

* The use of Julia macros in this code is a little crude.  It should probably be cleaned up.


# To do

Please take on one of these tasks!

* Fix `can_copy` so that it doesn't break on examples like `x = []; push!(x,x)`. 
  (look at the code for deepcopy to see how to fix it)

* Fix any other bug listed above.

* The saving of the past is a inefficient right now in that it copies all variables at all times. Implement something that only makes copies of new variables, and just gives pointers to old ones (using a hash).


* add an option to declare a variable not for copy, so we don't make many copies of big data items.

* Come up with better names for all the routines in the interface.

* Find a way to copy and save functions (maybe using IRtools)

* Create a GUI to keep track of which spawned processes are running, and which have finished.

* Think of what other features this needs.

* Improve the documentation so we can release it to the public.  Really, we need to set up documenter.

* Note: to modify the package, type `] dev IJuliaTimeMachine`.  You might need to check out some information about developing packages.