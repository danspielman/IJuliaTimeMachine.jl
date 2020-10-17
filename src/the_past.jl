# Functions related to capturing the past states of the notebook


"""
    can_copy(x)

Is supposed to return true if deepcopy works on x.
The code to test this is based on deepcopy, but it could get some strange case wrong.
"""
can_copy(x) = can_copy(x, IdDict())
can_copy(x::Union{Core.MethodInstance,Module,Method,GlobalRef,UnionAll,Task,Regex,Function}, id) = false
can_copy(x::Union{Symbol, DataType, Union, String}, id) = true

function can_copy(x, id) 
    isbitstype(typeof(x)) && return true
    haskey(id, x) && return true
    id[x] = true
    nf = nfields(x)
    nf == 0 && return true
    id[x] = true
    return all([can_copy(getfield(x,i),id) for i in 1:nf])
end

function can_copy(x::Union{Tuple,Core.SimpleVector,Array}, id) 
    haskey(id, x) && return true
    id[x] = true
    all([can_copy(xi, id) for xi in x])
end

function can_copy(x::Dict, id) 
    haskey(id, x) && return true
    id[x] = true
    if x === IJulia.Out
        return false
    end

    if x === past
        return false
    end

    return all([can_copy((k,s), id) for (k,s) in x])
end

"""
Go over every symbol in Main.  
If `deepcopy` works on it, wrap it and `ans` in an IJulia_State.
Note that it doesn't capture functions, which is unfortunate.
"""
function vars_to_state()
    this_state = Dict{Any,Any}()
    for n in names(Main)
        if can_copy(@eval Main $n)
            this_state[n] = @eval Main deepcopy($(n))
        end
    end

    return this_state
end

"""
Save the current variables and ans is `past[cell_number]`.
"""
function save_state()    
    if !(IJulia.n ∈ spawned)
        this_state = vars_to_state()
        ans = IJulia.ans
        ansc = can_copy(ans) ? deepcopy(ans) : nothing   
        past[IJulia.n] = IJulia_State(this_state, ansc)

        if Base.summarysize(past) > Sys.total_memory()/3
            @warn "IJuliaTimeMachine state takes over 1/3 of system memory.  Consider IJuliaTimeMachine.clear_state()."
        end
        debug_mode && println(IJulia.orig_stdout[], "Saved state $(IJulia.n)")
    end
end

"""
    @past n

Return to the state after cell `n` was exectued.
"""
macro past(n_in)

    n = n_in
    if typeof(n_in) == Symbol
        n = @eval Main $(n_in)
    end

    if haskey(past, n)
        local s = past[n].vars
        local ans = past[n].ans
        return quote
            ($([esc(x) for x in keys(s)]...),) = 
                ($([esc(x) for x in values(s)]...),) 
            $ans
        end
    else
        return quote
            error("State $($n) was not saved.")
        end
    end
end


"""
Empty all storage of the past.  Use to free up memory.
"""
function clear_past()
    empty!(past)
end

"""
Empty storage from the cells that are in `indices`.
"""
function clear_past(indices)
    for k in indices
        if haskey(past, k)
            delete!(past, k)
        end
    end
end

"""
Returns the variables saved in a given cell as a dictionary.
"""
vars(n::Int) = vars(past, n)

function vars(di::Dict, n::Int)
    if haskey(di,n)
        return di[n].vars
    else
        println("Cell $n was not saved.")
    end
end