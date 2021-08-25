function main()
    old = ["/home/melonedo/PNGFiles.jl/gen/libpng/libpng_common.jl", "/home/melonedo/PNGFiles.jl/gen/libpng/libpng_api.jl"]
    new = ["/home/melonedo/PNGFiles.jl/gen/libpng/libpng.jl"]
    res = WrapperComparator.compare(old, new)
    println("Added Symbols: $(res.added)\nRemoved Symbols: $(res.removed)\nDifferent Symbols: $(res.different)")
end

main()
