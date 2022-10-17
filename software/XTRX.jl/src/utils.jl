using Random

# A little bit of type piracy to get a useful `randn()` for us
function Random.randn(::Type{Complex{Int16}}, dims::Integer...)
    return Complex{Int16}.(
        clamp.(round.(Int32, randn(dims...) .* 2^8), -2^11, 2^11 - 1),
        clamp.(round.(Int32, randn(dims...) .* 2^8), -2^11, 2^11 - 1),
    )
end
