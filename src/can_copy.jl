#=

contains can_copy and tm_hash

We need to be able to tm_hash every variable for which can_copy
    returns true.
tm_hash will basically copy code used for hashing inside Julia,
except that it accounts for all values inside an array, while Julia's
default hash does not. Also, Julia's hash does not change when the values of a mutable struct do.



=#

"""
    can_copy(x)

Is supposed to return true if deepcopy works on x.
The code to test this is based on deepcopy, but it could get some strange case wrong.
"""
can_copy(x) = can_copy_and_hash(x)[1]
tm_hash(x) = can_copy_and_hash(x)[2]

can_copy_and_hash(x) = can_copy_and_hash(x, IdDict(), zero(UInt64))
can_copy_and_hash(x::Union{Core.MethodInstance,Module,Method,GlobalRef,UnionAll,Task,Regex,Function}, id, h) = (false, 0)
can_copy_and_hash(x::Union{Symbol, DataType, Union, String}, id, h) = (true, hash(x,h))

function can_copy_and_hash(x, id, h) 
    isbitstype(typeof(x)) && return (true, hash(x,h))
    haskey(id, x) && return (true, hash(objectid(x),h))
    id[x] = true
    nf = nfields(x) 
    nf == 0 && return (true, hash(x, h))
    id[x] = true
    val = true
    h = hash(typeof(x), h)
    for i in 1:nf
        tf, h = can_copy_and_hash(getfield(x,i),id,h)
        h = hash(i,h)
        val &= tf
    end
    return val, h
end

# edited to here --------- not sure what this could be. need to fix it.

function can_copy_and_hash(x::Union{Tuple,Core.SimpleVector,Array}, id, h) 
    haskey(id, x) && return (true, hash(objectid(x), h))
    id[x] = true
    h = hash(typeof(x), h)
    if isa(x, Array)
        h = hash(size(x), h)
    end
    val = true
    for i in 1:length(x)
        tf, h = can_copy_and_hash(x[i],id,h)
        h = hash(i,h)
        val &= tf
    end
    return val, h
end


function can_copy_and_hash(x::Dict, id, h) 
    haskey(id, x) && return (true, hash(objectid(x), h))
    id[x] = true

    h = hash(typeof(x), h)
    val = true
    for (k,v) in x
        tf, h = can_copy_and_hash((k,v),id,h)
        val &= tf
    end
    return val, h

end

