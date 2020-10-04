module IJuliaTimeMachine

    import IJulia
    #using Markdown

    debug_mode = false
    function debug!(x::Bool = true)
        global debug_mode = x
        println("debug: $(x)")
    end

    saving = false

    """
    `vars` is a dictionary of the variables at the time.
    `ans` is the value of `ans`, which is stored separately.
    """
    struct IJulia_State
        vars::Dict
        ans::Any
    end

    const past = Dict{Int,IJulia_State}()

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

    #=
    spawned lists the cells that have been spawned off
    running is the subset that are still running
    finished is the ones that completed 
    tasks is gives a reference to the task run in a given cell.
    =#
    const spawned = Set()
    const running = Set()
    const finished = Vector{Int}()
    const tasks = Dict{Int,Task}()

    include("the_past.jl")
    include("spawn.jl")

    function __init__()
        IJulia.push_preexecute_hook(tm_cleanup)
        start_saving()
        nothing
    end

end
