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
    haskey(mapping, s) ? mapping[s] : s        
function subs_variables(ex::Expr, mapping::Dict) 
    start = ex.head == :macrocall ? 2 : 1 
    Expr(ex.head, (subs_variables(a, mapping) for a in ex.args[start:end])...)   
end

"""
Creates a block that when executed renames all the variables.
"""
function rename_block(varlist, var_to_tmp)
    exs = []

    for s in varlist
        t = var_to_tmp[s]
        ss = """\"$(s)\""""
        tt = """\"$(t)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                $(var_to_tmp[s]) = @eval Main $(s)
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
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




"""
Attempts to add variable `name` to the dictionary.
Fail gracefully if not allowed.
"""
function add_tmpvar_to_dict(tmp_name, orig_name, this_state)
    t1 = @eval typeof($(tmp_name))

    if !(isa(t1,Module) || isa(t1, Function))
        try
            this_state[orig_name] = deepcopy(@eval tmp_name)
        catch
        end
    end
end 

"""
Creates a block that when executed saves the tmp vars in `past`.
"""
function save_state_block(var_to_tmp)
    exs = [:(this_state = Dict{Any,Any}())]

    for (k, s) in var_to_tmp
        println(s)

        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Symbol(IJuliaTimeMachine,$ss))""")        
        push!(exs, quote if $q 
                add_tmpvar_to_dict($k, $s, this_state)
                end end)
    end 

    ex = Expr(:block)
    ex.args = exs

    return ex
end


"""
Creates a block that when executed sets all tmp variables to nothing
"""
function clear_block(var_to_tmp)
    exs = []

    for s in collect(values(var_to_tmp))
        ss = """\"$(s)\""""
        q = Meta.parse("""isdefined(Main, Symbol($ss))""")        
        push!(exs, quote if $q 
                $(s) = nothing
                end end)
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
    TM.@spawn begin
        code you want to run
    end

Spawns a process that runs your code, and eventually saves the result when it finishes
in `Out[cellnum]`.  It copies variables, so that changes to those variables do not interact with other cells.
"""
macro spawn(ex::Expr)

    local n = IJulia.n
    println(n)

    varlist = extract_symbols(ex)

    var_to_tmp, tmp_to_var = variable_maps(varlist)

    ex_rename = rename_block(varlist, var_to_tmp)
    ex_new = subs_variables(ex, var_to_tmp)
    ex_clear = clear_block(var_to_tmp)

    ex_save = save_state_block(var_to_tmp)
    # once it works, need to insert below
    
    q = Meta.parse("""
        Threads.@spawn begin
            local val = $(ex_new)
            valc = nothing
            try
                valc = deepcopy(val)
            catch
            end
            IJulia.Out[$(n)] = valc
            $(ex_save)
            IJuliaTimeMachine.past[$n] = IJulia_State(Dict(), valc)
        end
        """)        


    return quote
        $ex_rename
        $q
        $ex_clear
    end

end

#=

    q = Meta.parse("""
        println("xx")
        Threads.@spawn begin
        local val = $(ex_new)
        IJulia.Out[$n] = val

        end
       """)

        try
            valc = deepcopy(val)
        catch
            valc = nothing
        end

        #$(ex_save)
        #past[$n] = IJulia_State(this_state, valc)

=#

macro badspawn(ex::Expr)

    local n = IJulia.n
    println(n)

    varlist = extract_symbols(ex)

    var_to_tmp, tmp_to_var = variable_maps(varlist)

    #ex_save = save_state_block(var_to_tmp)
    
    q = Meta.parse("""
        Threads.@spawn begin
        local val = $(ex)
        IJulia.Out[$n] = val

        end
       """)

    return quote
        $q
    end

end
