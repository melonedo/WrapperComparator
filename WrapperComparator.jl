module WrapperComparator
using MLStyle
using Base: Meta.isexpr
using Dictionaries

# Both matchers are adopted from https://thautwarm.github.io/MLStyle.jl/latest/syntax/pattern.html#expr-patterns

is_doc_macro(ex) = ex.args[1] == GlobalRef(Core, Symbol("@doc"))

function preprocess(e)
    @match e begin
        Expr(:macrocall, head, doc, body) && 
            GuardBy(is_doc_macro)   => preprocess(body)
        Expr(head, args...)         => Expr(head, filter(x -> x !== nothing, map(preprocess, args))...)
        ::LineNumberNode            => nothing
        _                           => e
    end
end

is_enum_macro(ex) = ex.args[1] in [Symbol("@cenum"), Symbol("@enum")]

function extract_name(e)
    @expand MLStyle.@match e begin
        ::Symbol                           => e
        Expr(:<:, a, _)                    => extract_name(a)
        Expr(:struct, _, name, _)          => extract_name(name)
        Expr(:call, f, _...)               => extract_name(f)
        Expr(:function, sig, _...)         => extract_name(sig)
        Expr(:const, assn, _...)           => extract_name(assn)
        Expr(:(=), fn, body, _...)         => extract_name(fn)
        Expr(:macrocall, _, _, body) && 
            GuardBy(is_enum_macro)         => extract_name(body)
        :($name::$type)                    => extract_name(name)
        :(Base.$prop)                      ||
        ::LineNumberNode                   ||
        :(using $mod)                      ||
        :(export $mod)                     ||
        Expr(:for, args...)                => nothing
        Expr(expr_type,  _...)             => error("Can't extract name from ",
                                                    expr_type, " expression:\n",
                                                    "    $e\n")
    end
end


function index_exprs(exprs::Expr)
    @assert isexpr(exprs, :toplevel) || isexpr(exprs, :block)
    res = Pair{Symbol, Expr}[]
    for ex in exprs.args
        name = extract_name(ex)
        if !isnothing(name)
            push!(res, name=>ex)
        end
    end
    res
end

function index_files(files)
    pairs = Pair{Symbol, Expr}[]
    for file in files
        ex = open(file) do io
            Meta.parseall(read(io, String))
        end
        ex = preprocess(ex)
        # module
        if length(ex.args) == 1
            ex = ex.args[].args[3]
        end
        append!(pairs, index_exprs(ex))
    end
    pairs
end

function compare(old_files, new_files)
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

    (added=added_symbols, removed=removed_symbols, different=different_symbols)
end

end

