# WrapperComparator

WrapperComparator is a simple tool that helps you compare two wrappers generated by Clang.jl.

## Usage
```julia
include("WrapperComparator.jl")
old = ["full/path/to/old/wrapper1.jl","full/path/to/old/wrapper2.jl"]
new = ["full/path/to/new/wrapper.jl"]
res = WrapperComparator.compare(old, new)
println("Added Symbols: $(res.added)\nRemoved Symbols: $(res.removed)\nDifferent Symbols: $(res.different)")
```

Also the different part can be easily compared in generated files `abstract_old.jl` and `abstract_new.jl`.