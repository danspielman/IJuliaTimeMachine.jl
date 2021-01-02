# the data structures for storing variables histories

#=

Varchive should contain:
past, a dictionary indexed by cells,
and points to a VarState 

VarState: a dict indexed by name of var,
 with keys being their hashes.
And, it should have ans.

And, Store: a dict from hash to variable.

=#

struct VarState
    vars::Dict
    ans::Any
end


struct Varchive
    past::Dict{Int,VarState}
    store::Dict
end

Varchive() = Varchive(Dict{Int,VarState}(), Dict())

"""
    put_state!(vx::Varchive, key, di::Dict, ansc)
    
Assuming that state indexed by key (=n) is packed into ijstate,
put it into the Varchive.
"""
function put_state!(vx::Varchive, key, di::Dict, ansc)
    vs = VarState(di, ansc)

    if haskey(vx.past, key)
        error("Key $(key) is already stored.")
    end
    vx.past[key] = vs

    for (name, pair) in di
        h, val = pair
        vs.vars[name] = h
        if !haskey(vx.store, h)
            vx.store[h] = val
        end
    end
end

#=
"""
    put_state_copied!(vx::Varchive, key, di::Dict, ansc)
    
Assuming that state indexed by key (=n) is packed into ijstate,
put it into the Varchive.
"""
function put_state_copied!(vx::Varchive, key, di::Dict, ansc)
    vs = VarState(di, ansc)

    if haskey(vx.past, key)
        error("Key $(key) is already stored.")
    end
    vx.past[key] = vs

    for (name, pair) in di
        h, copied = pair
        debug_mode && println(IJulia.orig_stdout[],"$name  : $copied")
        vs.vars[name] = h
        if !haskey(vx.store, h)
            vx.store[h] = copied
        end
    end
end
=#

"""
    vars(cell)
    vars(vx::Varchive, cell)

Returns a dictionary of the variables from cell `cell`.
If `vx` is omitted, returns from the default history.
This is how it is usually used.
"""
function vars(vx::Varchive, cell)
    if !haskey(vx.past, cell)
        error("Cell $(cell) was not saved.")
    end

    di = Dict()

    vs = vx.past[cell]

    for (name, h) in vs.vars
        di[name] = vx.store[h]
    end

    return di
end