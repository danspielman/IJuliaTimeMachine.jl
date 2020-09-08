module IJuliaTimeMachine

    import IJulia
    using Markdown

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

    include("the_past.jl")
    include("spawn.jl")


end
