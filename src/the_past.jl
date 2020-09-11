# Functions related to capturing the past states of the notebook

"""
Start saving the states of the notebook.  
Is run when module is initialized.
"""
function start_saving()
    IJulia.push_postexecute_hook(save_state)
end

"""
Stop saving states of the notebook.
"""
function stop_saving()
    IJulia.pop_postexecute_hook(save_state)
end

"""
    can_copy(x)

Is supposed to return true if deepcopy works on x.
The code to test this is based on deepcopy, but it could get some strange case wrong.
"""
function can_copy(x) 
    isbitstype(typeof(x)) && return true
    nf = nfields(x)
    nf == 0 && return true
    return all(can_copy.(getfield(x,i) for i in 1:nf))
end
can_copy(x::Union{Core.MethodInstance,Module,Method,GlobalRef,UnionAll,Task,Regex,Function}) = false
can_copy(x::Union{Symbol, DataType, Union, String}) = true
can_copy(x::Union{Tuple,Core.SimpleVector,Array}) = all(can_copy.(x))
can_copy(x::Dict) = all([can_copy((k,s)) for (k,s) in x])


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

    ans = IJulia.ans
    ansc = can_copy(ans) ? deepcopy(ans) : nothing

    return IJulia_State(this_state, ansc)
end

"""
Save the current variables and ans is `past[cell_number]`.
"""
function save_state()    
    past[IJulia.n] = vars_to_state()
    if Base.summarysize(past) > Sys.total_memory()/3
        @warn "IJuliaTimeMachine state takes over 1/3 of system memory.  Consider IJuliaTimeMachine.clear_state()."
    end
end

"""
    @past n

Return to the state after cell `n` was exectued.
"""
macro past(n)
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


