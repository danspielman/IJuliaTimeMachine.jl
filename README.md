# IJuliaTimeMachine
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://danspielman.github.io/IJuliaTimeMachine.jl/dev/)

This package provides two capabilities that can be  useful when running long computational experiments in IJulia notebooks:
* It allows you to return all variables to a previous state (the past).
This is useful if you run experiments in Julia cells that can take minutes or longer to complete, and want to re-examine the variables in a cell you have over-written.

* It allows you to spawn a process to run on another thread while you keep writing other cells (the future).
The process sandboxes the variables it uses, so it does not impact other cells.
This is especially useful if you plan to run many similar experiments.  
Now, you can just copy, paste and modify cells before running them.

[More documentation can be found here.](https://danspielman.github.io/IJuliaTimeMachine.jl/dev/)

# Installation


~~~julia
using Pkg; Pkg.add(url="https://github.com/danspielman/IJuliaTimeMachine.jl")
~~~

Once you are running a Jupyter notebook, you can start the time machine by typing
~~~julia
import IJuliaTimeMachine
~~~

As the name of the package is rather long, and all of its commands require it as a prefix, I recommend renaming it like
~~~julia
TM = IJuliaTimeMachine
~~~

The rest of these docs assume you have renamed it to `TM`.

If you use the Time Machine a lot, and don't want to type `TM`, all the time, you can instead type
~~~julia
using IJuliaTimeMachine
~~~
This will export the function `vars` and the macro `@past`.


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


# Basic Usage

First, note that IJulia already provides some history functionality.
It maintains dictionaries `In` and `Out` that store the input (contents) and output (ans) of every cell.
To see the answer computed in cell 20, examine `Out[20]`.

To go back to the state as it was after cell 20, at any time, type `TM.@past 20`.

If you just want to look at a dictionary of the variables from cell 20, type `TM.vars(20)`.

To stop saving state, type `TM.saving!(false)`. 
This is especially useful if IJuliaTimeMachine is causing errors. To start up again, type `TM.saving!(true)`.
If you want to turn off IJuliaTimeMachine, run `TM.unhook()`.

To prevent IJuliaTimeMachine from saving a variable `x`, run `TM.dontsave(x)`.

If you need to free up memory, type `TM.clear_past()` to clear all the saved state information.
`TM.clear_past(cells)` clears the states in the iterator (or range) given by `cells`. It also clears all variables that are saved only in those states. 

All of the saved data is kept in a structure that we internally call a `Varchive`. It is stored at `TM.VX`. If you want to save all variables so that you can recover them when restarting Jupyter, save this variable. For example, using 
~~~julia
bson("vars from this notebook.bson", VX = TM.VX)
~~~

You can then load and access dictionaries of those variables using `TM.vars(VX, n)`. Say, to get the variables from cell 10, you could type
~~~julia
VXold = BSON.load("vars from this notebook.bson")[:VX]
TM.vars(VXold, 10)
~~~

If picking variables out of that dictionary is too slow for you, you can emulate the `@past` macro and put all the variables from the dictionary into Main by typing
~~~
TM.@dict_to_main(TM.vars(VXold,10))
~~~
Of course, you can use any dictionary in place of `TM.vars(VXold,10)`.




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

By default, notifications about finished cells are printed to the terminal from which Jupyter was started.  You can turn this on or off with `TM.notify_terminal!()`.  
You can choose to have notifications printed to the current Jupyter cell by setting `TM.notify_jupyter!(true)`.


You can find a demonstration of the time machine in action in the [`examples` directory](https://github.com/](https://github.com/danspielman/IJuliaTimeMachine.jl/tree/master/examples).
It is saved as a Jupyter notebook, html, and pdf.


# In case of errors

If IJuliaTimeMachine develops problems, it can cause strange errors to appear in every cell. The usual reason is some type of variable that it does not know how to handle. The easy solution is to prevent saving of that variable with `dontsave`.

If that doesn't fix it, you will probably want to disable the Time Machine. The following command does this

~~~julia
TM.unhook()
~~~

# Contributing

Please help improve this. Someone who understands Julia Macros and internals could do a much better job of this. Feel free to file issues, create pull requests, or get in touch with `daniel.spielman@yale.edu` if you can improve it.
Here are some things that would be worth doing:

* Find a way to copy and save functions 

* Create a GUI to keep track of which spawned processes are running, and which have finished.

* Think of what other features this needs.

* Figure out a way to create tests for this package. The difficulty is that it needs to run inside Jupyter.




# Known Issues

* Output from @thread that is supposed to go to stdout winds up in whatever cell is current.
It would be terrific to capture this instead, and ideally make it something we can play back later.

* Sometimes we get an error that says `error in running finalizer: ErrorException("concurrency violation detected")`.  Not sure why.

# Details / how it works

* Time Machine only saves variables that are in `Main`.  
It stores them in `TM.VX`.
The data structure is described in `varchive.jl`.

* The Time Machine only saves variables that can be copied with deepcopy.  In particular, it does not save functions.  It would be nice to add a way to copy functions. 

* It keeps track of these variables by hashes (using `tm_hash`, which is more robust than `Base.hash`). So, if two variables store data that has the same hash, one of them will be lost. This is unlikely to be a problem for most notebooks, because a heuristic probabilistic, analysis of hashing suggests that the chance of a collision when there are `v` variables is around `v^2 / 2^64.`

* The state saving features work by using an IJulia `postexecute_hook`.
This would not work for processes launched with `@thread` because their postexecute hooks fire before the job finishes.
So, those jobs finish by putting the data they should save into a queue.
That data is then saved into VX during the preexecute phase of the next cell execution, using a preexecute hook. The queue is managed with a SpinLock so that two threads can not write to it at the same time.


# Acknowledgements

The development of this package has been supported in part by a Simons Investigator Award to Daniel A. Spielman.



