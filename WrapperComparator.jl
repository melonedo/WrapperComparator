module WrapperComparator
using MLStyle
using Base: Meta.isexpr
using Dictionaries

# Both matchers are adopted from https://thautwarm.github.io/MLStyle.jl/latest/syntax/pattern.html#expr-patterns

is_doc_macro(ex) = ex.args[1] == GlobalRef(Core, Symbol("@doc"))

function preprocess(e)
    @match e begin
        Expr(:macrocall, head, line, doc, body) && 
            GuardBy(is_doc_macro)   => preprocess(body)
        Expr(:macrocall, args...)   => Expr(:macrocall, map(preprocess, args)...)
        Expr(head, args...)         => Expr(head, filter(x -> x !== nothing, map(preprocess, args))...)
        ::LineNumberNode            => nothing
        _                           => e
    end
end

is_enum_macro(ex) = ex.args[1] in [Symbol("@cenum"), Symbol("@enum")]

is_ignored_expr(ex) = ex.head in [:for, :using, :export]

function extract_name(e)
    @match e begin
        ::Symbol                           => e
        Expr(:<:, a, _)                    => extract_name(a)
        Expr(:struct, _, name, _)          => extract_name(name)
        Expr(:call, f, _...)               => extract_name(f)
        Expr(:function, sig, _...)         => extract_name(sig)
        Expr(:const, assn, _...)           => extract_name(assn)
        Expr(:(=), fn, body, _...)         => extract_name(fn)
        Expr(:macrocall, head, line, name, body) &&
            GuardBy(is_enum_macro)         => extract_name(name)
        :($name::$type)                    => extract_name(name)
        :(Base.$prop)                      ||
        ::LineNumberNode                   ||
        Expr && GuardBy(is_ignored_expr)   => nothing
        Expr(expr_type,  _...)             => @info("Can't extract name from expression:\n$e")
    end
end


function extract_enums(e)
    args = @match e begin
        Expr(:macrocall, _, _, _, Expr(:block, args...)) && 
            GuardBy(is_enum_macro)  => args
        _                           => []
    end
    map(args) do ex
        extract_name(ex) => ex
    end
end


function index_exprs(exprs::AbstractVector)
    res = Pair{Symbol, Expr}[]
    for ex in exprs
        name = extract_name(ex)
        if !isnothing(name)
            push!(res, name=>ex)
            append!(res, extract_enums(ex))
        end
    end
    res
end


function get_exprs(ex)
    @match ex begin
        Expr(:toplevel, args...)                    ||
        Expr(:module, _, _, Expr(:block, args...))  => reduce(vcat, get_exprs.(args), init=Expr[])
        _                                           => ex
    end
end


function index_files(files)
    pairs = Pair{Symbol, Expr}[]
    for file in files
        ex = open(file) do io
            Meta.parseall(read(io, String))
        end
        ex = preprocess(ex)
        ex = get_exprs(ex)
        append!(pairs, index_exprs(ex))
    end
    pairs
end

function print_expr(io, sym, index)
    println(io, index[sym], '\n')
end

function compare(old_files, new_files, abstract_files=joinpath.(@__DIR__, ("abstract_old.jl","abstract_new.jl")))
    new = dictionary(index_files(new_files))
    old = dictionary(index_files(old_files))
    added_symbols = collect(setdiff(keys(new), keys(old)))
    removed_symbols = collect(setdiff(keys(old), keys(new)))
    different_symbols = Symbol[]
    
    for k in intersect(keys(new), keys(old))
        if new[k] != old[k]
            push!(different_symbols, k)
        end
    end
    
    if !isnothing(abstract_files)
        old_abstract, new_abstract = abstract_files
        
        open(old_abstract; write=true) do io
            println(io, "# Removed symbols")
            foreach(k->print_expr(io, k, old), removed_symbols)
            println(io, "# Changed symbols")
            foreach(k->print_expr(io, k, old), different_symbols)
        end

        open(new_abstract; write=true) do io
            println(io, "# Added symbols")
            foreach(k->print_expr(io, k, new), added_symbols)
            println(io, "# Changed symbols")
            foreach(k->print_expr(io, k, new), different_symbols)
        end
    end

    (added=added_symbols, removed=removed_symbols, different=different_symbols)
end

end

