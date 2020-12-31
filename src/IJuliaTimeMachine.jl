module IJuliaTimeMachine

    import IJulia

    include("varchive.jl")
    include("can_copy.jl")
    include("the_past.jl")
    include("spawn.jl")

    export @past, vars

    #================================

    __init__

    =#

    function __init__()
        dontsave(VX)
        dontsave(VX.past)
        dontsave(VX.store)
        dontsave(IJulia.Out)

        IJulia.push_preexecute_hook(tm_cleanup)
        saving!()

        notify_terminal!()

        nothing
    end

    """
        unhook()

    Remove the pre and postexecute hooks created by Time Machine.
    Made for when the Time Machine is causing strange errors.
    These typically cause strange errors to happen whenever a cell is executed.
    """
    function unhook()
        try
            IJulia.pop_preexecute_hook(tm_cleanup)    
        catch _
            nothing
        end

        try
            IJulia.pop_postexecute_hook(save_state)    
        catch _
            nothing
        end

    end

    #===========================================

    Variables that change behavior of the time machine

    =#

    debug_mode = false
    function debug!(x::Bool = true)
        global debug_mode = x
        println("debug: $(x)")
    end

    saving = false

    """
        saving!(bool)

    Turn saving of state on or off.  Works by pushing or poping an IJulia postexecute_hook.
    True by default.
    """
    function saving!(x = true)
        global saving = x
        if saving 
            IJulia.push_postexecute_hook(save_state)
        else
            IJulia.pop_postexecute_hook(save_state)
        end                
    end

    notify_jupyter = false
    notify_terminal = false
    notify_gui = false

    """
        notify_jupyter!(bool)

    If true, Print notifications about finishing jobs to the current jupyter output cell.
    """
    function notify_jupyter!(x::Bool = true)
        global notify_jupyter = x
    end

    """
    notify_terminal!(bool)

    If true, Print notifications about finishing jobs to the terminal from which jupyter was started.
    """
    function notify_terminal!(x::Bool = true)
        global notify_terminal = x
    end

    #================================================

    Variables the user might want to consult

    spawned lists the cells that have been spawned off
    running is the subset that are still running
    finished is the ones that completed 
    tasks is gives a reference to the task run in a given cell.
    =#
    const spawned = Set()
    const running = Set()
    const finished = Vector{Int}()
    const tasks = Dict{Int,Task}()


    #==================================

    Intended for internal use only

    =#

    """
    `vars` is a dictionary of the variables at the time.
    `ans` is the value of `ans`, which is stored separately.
    """
    #=
    struct IJulia_State
        vars::Dict
        ans::Any
    end

    const past = Dict{Int,IJulia_State}()
=#

    const VX = Varchive()

    # DontSave is a set of variables not to save
    const DontSave = Set()

    """
        dontsave(x)

    Do not save variable `x` in the history.
    """
    function dontsave(x)
        push!(DontSave, objectid(x))
        nothing
    end

    struct Queue_Pair
        n::Int
        out::Any
    end

    const out_queue = Vector{Queue_Pair}()
    const past_queue = Vector{Queue_Pair}()

    # If a process is spawned in a thread, it will need to save its results.
    # We do this in a two-phase process.  First, it puts its results into a queue.
    # Then, during the start of an execution, we run a process in the main thread that checks
    # the queue and puts its results into Out an past.
    # The part that is executed during a thread has a lock.
    tm_lock = Threads.SpinLock()


end
