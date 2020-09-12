#=

This is the code for spawning a jupyter cell in a thread.

The main difficulty with doing this is that we need to be sure that 
the variables that are being set in the cell are not also being changed elsewhere.

So, we begin by trying to discover the names of all the variables in the cell,
and then renaming them to unique names (using gensym).
We then run with those unique names.

When we are finished, we need to
* capture and return ans, (maybe not return it)
* 
* clean up those names, 

to do:
clean up names after,
make threaded (is that an issue)?

=#


"""
The goal of extract_symbols is to find all the variables that we need to rename.
Ideally, it would do exactly this.  Right now it probably doesn't.
It returns them in a Set of Symbols.
"""
function extract_symbols(ex::Expr) 
    start = ex.head == :macrocall ? 2 : 1
    union((extract_symbols(arg) for arg in ex.args[start:end])...)
end
extract_symbols(ex::Symbol) = Set{Symbol}([ex])
extract_symbols(ex) = Set{Symbol}()

"""
    var_to_tmp, tmp_to_var = variable_maps(varlist)

Create maps to new names for the variables in varlist.
"""
function variable_maps(varlist)
    var_to_tmp = Dict{Symbol,Symbol}()
    tmp_to_var = Dict{Symbol,Symbol}()

    for s in varlist
        gs = gensym(s)
        var_to_tmp[s] = gs
        tmp_to_var[gs] = s
    end

    return var_to_tmp, tmp_to_var
end

"""
    mapped_ex = subs_variables(ex::Expr, mapping::Dict)

Go through the Expr and use mapping to replace every symbol 
discovered by extract_symbols.
"""
subs_variables(ex, mapping) = ex
subs_variables(s::Symbol, mapping::Dict) = 
    haskey(mapping, s) ? esc(mapping[s]) : s        
function subs_variables(ex::Expr, mapping::Dict) 
    start = ex.head == :macrocall ? 2 : 1 
    Expr(ex.head, (subs_variables(a, mapping) for a in ex.args[start:end])...)   
end

"""
Creates a block that when executed sandboxes all copyable variables.
"""
function sandbox_variable_block(varlist, var_to_tmp)
    exs = []

    for (s, t) in var_to_tmp       
        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                if can_copy(@eval Main $(s))
                    $(esc(t)) = deepcopy(@eval Main $(s))
                else
                    $(esc(t)) = $(esc(s))
                end
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end

"""
Creates a block that when executed saves the tmp vars in `past`.
"""
function save_state_block(var_to_tmp)
    exs = []

    # commented out because it should already exist
    # exs = push!(exs,:(this_state = Dict{Any,Any}())) 


    for (k, s) in var_to_tmp
        debug_mode && println(IJulia.orig_stdout[], k, " ", s, " ", can_copy(@eval Main $k)) 

        ss = """\"$(s)\""""
        kk = """$(k)"""


        q = quote  if can_copy($(esc(s)))
            this_state[Symbol($(esc(kk)))] =  deepcopy($(esc(s))) 
        end
        end
        push!(exs, q)
    end     

    ex = Expr(:block)
    ex.args = exs

    return ex
end

#=

this_state[Symbol($kk)] = esc($s)

q = Meta.parse("""if isdefined(IJuliaTimeMachine,Symbol($ss))
            this_state[Symbol($kk)] = deepcopy(eval(Symbol($ss)))
        end""")   
        =#

# IJuliaTimeMachine.add_tmpvar_to_dict(Symbol($ss), Symbol($kk), this_state)


"""
Creates a block that when executed sets all tmp variables to nothing
"""
function cleanup_block(var_to_tmp)
    exs = []

    for (s, t) in var_to_tmp       
        tt = """$(t)""" 

        push!(exs, :(global $(esc(t)) = nothing))
        #=
        q = Meta.parse("""isdefined(Main, Symbol($tt))""")        
        push!(exs, quote if $q 
            $(t) = nothing
                end end)
                =#
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end


"""
    ans = TM.@sandbox begin
        expression
    end

Run expression in a sandbox.  
Rename all the variables beforehand, and clear the renamed variables after.
Mainly wrote this to test concepts.  But, it could be useful anyway
"""
macro sandbox(ex::Expr)

    varlist = extract_symbols(ex)

    var_to_tmp, tmp_to_var = variable_maps(varlist)

    ex_rename = rename_block(varlist, var_to_tmp)
    ex_new = subs_variables(ex, var_to_tmp)
    ex_clear = clear_block(var_to_tmp)

    return quote
        @eval Main $ex_rename
        local val = @eval Main $ex_new
        @eval Main $ex_clear
        val
    end
end






"""
    TM.@spawn thread
        code you want to run
    end

Spawns a process that runs your code in its own thread, and eventually saves the result when it finishes
in `Out[cellnum]`.  It copies variables, so that changes to those variables do not interact with other cells.
"""
macro thread(ex::Expr)

    local n = IJulia.n

    local saveit = copy(saving)

    if n ∈ spawned
        println("@thread can be called at most once per cell.")
        return
    end

    debug_mode && println(IJulia.orig_stdout[], "Running cell $(n) in a thread.") 

    varlist = extract_symbols(ex)

    debug_mode && println(IJulia.orig_stdout[], varlist) 

    var_to_tmp, tmp_to_var = variable_maps(varlist)

    ex_rename = sandbox_variable_block(varlist, var_to_tmp)
    ex_new = subs_variables(ex, var_to_tmp)
    ex_save = saveit ? save_state_block(var_to_tmp) : nothing
    ex_cleanup = cleanup_block(var_to_tmp)

    return quote
        push!(running, $n)
        push!(spawned, $n)
        if $(saveit)
            this_state = vars_to_state()   
        end
        $(ex_rename)
        Threads.@spawn begin    
            val = $(ex_new)  
            out = can_copy(val) ? deepcopy(val) : nothing
            push!(out_queue, Out_Pair($(n), out))
 
            if $(saveit)
                $(ex_save) 
                Threads.lock(past_lock) do
                    past[$n] = IJulia_State(this_state, val)
                end
            end

            $(ex_cleanup)

            push!(finished, $n)
            $n ∈ running && delete!(running, $n)
        end
    end

end

function process_out_queue()
    while !(isempty(out_queue))
        q = pop!(out_queue)
        Threads.lock(out_lock) do 
            IJulia.Out[q.n] = q.out
        end
        debug_mode && println(IJulia.orig_stdout[], "placed out from cell $(q.n)") 
    end
end


function test(varlist)
    exs = []

    for s in varlist
        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                println($s)
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end   

function test1(varlist)
    exs = []

    for s in varlist
        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                println(Symbol($ss))
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end   

function test1(var_to_tmp::Dict)
    exs = []

    for (k, s) in var_to_tmp
        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                println(Symbol($ss))
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end   

macro tst(ex::Expr)
    varlist = extract_symbols(ex)
    var_to_tmp, tmp_to_var = variable_maps(varlist)
    for (k,s) in var_to_tmp
        println(k, " ", s)
    end
    ex_new = subs_variables(ex, var_to_tmp)
end

macro tst2(ex::Expr)
    varlist = extract_symbols(ex)
    var_to_tmp, tmp_to_var = variable_maps(varlist)
    for (k,s) in var_to_tmp
        println(k, " ", s)
    end
    ex_rename = rename_block(varlist, var_to_tmp)
    ex_new = subs_variables(ex, var_to_tmp)
    return quote
        $(ex_rename)
        $(ex_new)
    end
end
