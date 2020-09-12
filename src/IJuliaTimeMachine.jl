module IJuliaTimeMachine

    import IJulia
    #using Markdown

    debug_mode = false
    function debug!(x::Bool = true)
        global debug_mode = x
    end

    function __init__()
        start_saving()
        nothing
    end

    """
    `vars` is a dictionary of the variables at the time.
    `ans` is the value of `ans`, which is stored separately.
    """
    struct IJulia_State
        vars::Dict
        ans::Any
    end

    const past = Dict{Int,IJulia_State}()
    const TMOut = Dict{Int,Any}()

    # we use these locks to (hopefully) avoid two threads writing to IJulia.out or TM.past at the same time.
    # Unfortunately, there is still a chance of error here when IJulia writes to Out.
    # perhaps we can fix that, maybe with a TM.Out ?   
    past_lock = Threads.SpinLock()
    out_lock = Threads.SpinLock()

    #=
    spawned lists the cells that have been spawned off
    running is the subset that are still running
    finished is the ones that completed 
    =#
    const spawned = Set()
    const running = Set()
    const finished = Vector{Int}()

    saving = true

    include("the_past.jl")
    include("spawn.jl")


end
