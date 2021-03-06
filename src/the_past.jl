#= 

Functions related to capturing the past states of the notebook

We always deepcopy variables before saving them in the archive.
So, we use the routine can_copy to determine if deepcopy will work on them.
It is not perfect.

To capture all current variables in a dictionary, we use `main_to_dict`.


=#

"""
Go over every symbol in Main.  
If `deepcopy` works on it, put it in the dict `d`.
Note that it doesn't capture functions, which is unfortunate.
"""
function main_to_dict()
    d = Dict{Any,Any}()
    for n in names(Main)
        # you would expect that every name in Main corresponds to a defined variable, but this assumption can fail.
        if isdefined(Main, n)
            val = @eval Main $n
            if !(objectid(val) ∈ DontSave)
                can, h = can_copy_and_hash(val)
                if can
                    copyval = haskey(VX.store, h) ? nothing : deepcopy(isa(val, Union{Expr,Symbol}) ? Meta.quot(val) : val)
                    d[n] = (h,copyval)
                end
            end
        end
    end

    return d
end


"""
Save the current variables and ans in VX (a Varchive).
"""
function save_state()    
    # if this was spawned by TM.@thread, then its variables will be saved later.
    if !(IJulia.n ∈ spawned)
        di = main_to_dict()
        
        # get a version of ans we can copy, if it exists
        ans = IJulia.ans
        ansc = can_copy(ans) ? deepcopy(isa(ans,Union{Expr,Symbol}) ? Meta.quot(ans) : ans) : nothing   

        put_state!(VX, IJulia.n, di, ansc)

        if Base.summarysize(VX) > Sys.total_memory()/3
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

    if haskey(VX.past, n)
        local s = IJuliaTimeMachine.vars(n)
        local ans = VX.past[n].ans
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
    @dict_to_main dict

Place all variables in dict into Main memory.
"""
macro dict_to_main(dict)
    s = @eval Main $(dict)
    return quote
        ($([esc(x) for x in keys(s)]...),) = 
            ($([esc(x) for x in values(s)]...),) 
        nothing
    end
end



"""
    clear_past(indices)

Empty all storage of the past.  Use to free up memory.
If indices is omitted, it clears all history.
"""
function clear_past()
    empty!(VX.store)
    empty!(VX.past)
    return nothing
end

function clear_past(indices)
    # first, mark all variables that are not in indices
    keepvar = Set()
    for (n, vs) in VX.past
        if !(n ∈ indices)
            for h in values(vs.vars)
                push!(keepvar,h)
            end
        end
    end

    # now, remove from store every unmarked variable
    for k in keys(VX.store)
        if !(k ∈ keepvar)
            delete!(VX.store, k)
        end
    end

    for k ∈ indices
        delete!(VX.past, k)
    end
end

vars(n::Int) = haskey(VX.past,n) ? vars(VX, n) : error("Cell $(n) was not saved.")

"""
Recall the answer from a cell
"""
ans(n::Int) = haskey(VX.past,n) ? VX.past[n].ans : error("Cell $(n) was not saved.")