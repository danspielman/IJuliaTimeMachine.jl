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
The goal of extract_symbols is to find all the variables that appear in a block.
It returns them in a Set of Symbols.
This will return many more symbols than we want, so we only save those that we can copy.
"""
function extract_symbols(ex::Expr) 
    ex.head == :-> && return Set{Symbol}()
    start = ex.head == :macrocall ? 2 : 1
    if length(ex.args) >= start
        return union((extract_symbols(arg) for arg in ex.args[start:end])...)
    else
        return Set{Symbol}()
    end
end
extract_symbols(ex::Symbol) = Set{Symbol}([ex])
extract_symbols(ex) = Set{Symbol}()


"""
Creates the let statement for all copyable variables.
"""
function let_block(varlist)
    exs = []

    for s in varlist
        if can_copy(@eval Main $s)
            ex = :($(s) = deepcopy($(s)))
            push!(exs,ex)
        end
    end

    return Expr(:block, exs...)
end

"""
Creates a block that when executed saves the tmp vars in `past`.
"""
function save_state_block(varlist)
    exs = []

    for k in varlist
        debug_mode && println(IJulia.orig_stdout[], k, " ", can_copy(@eval Main $k)) 

        kk = """$(k)"""


        q = quote  if IJuliaTimeMachine.can_copy($(k))
            this_state[Symbol($(kk))] =  deepcopy($(k)) 
        end
        end
        push!(exs, q)
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
    let_blk = let_block(varlist)   

    end_str = "end"

    debug_mode &&  println(IJulia.orig_stdout[], let_blk) 

    ex_save = saveit ? save_state_block(varlist) : nothing

    debug_mode && println(IJulia.orig_stdout[], ex_save) 

    q = quote
        if $(saveit)
            this_state = IJuliaTimeMachine.vars_to_state()   
        end

        Threads.@spawn begin
            val = $(ex)
            out = IJuliaTimeMachine.can_copy(val) ? deepcopy(val) : nothing
            push!(IJuliaTimeMachine.out_queue, IJuliaTimeMachine.Out_Pair($(n), out))

            if $(saveit)
                $(ex_save) 
                Threads.lock(IJuliaTimeMachine.past_lock) do
                    IJuliaTimeMachine.past[$n] = IJuliaTimeMachine.IJulia_State(this_state, val)
                end
            end

            push!(finished, $n)
            $n ∈ running && delete!(running, $n)

        end
    end

    letq = Expr(:let, let_blk, q)

    return quote
        push!(running, $n)
        push!(spawned, $n)
    
        $(esc(letq))
        
    end

end




#=
           if $(saveit)
                $(ex_save) 
                Threads.lock(past_lock) do
                    past[$n] = IJulia_State(this_state, val)
                end
            end

            push!(finished, $n)
            $n ∈ running && delete!(running, $n)

            =#



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
