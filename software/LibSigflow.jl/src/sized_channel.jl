import Base.close, Base.put!, Base.close, Base.isempty
abstract type AbstractSizedChannel{T} <: AbstractChannel{T} end

struct MatrixSizedChannel{T} <: AbstractSizedChannel{T}
    num_samples::Int
    num_antenna_channels::Int
    channel::Channel{Matrix{T}}
    function MatrixSizedChannel{T}(num_samples, num_antenna_channels, sz::Integer = 0) where T
        return new(num_samples, num_antenna_channels, Channel{Matrix{T}}(sz))
    end
end

struct VectorSizedChannel{T} <: AbstractSizedChannel{T}
    num_antenna_channels::Int
    channel::Channel{Vector{T}}
    function VectorSizedChannel{T}(num_antenna_channels, sz::Integer = 0) where T
        return new(num_antenna_channels, Channel{Vector{T}}(sz))
    end
end

function Base.put!(c::MatrixSizedChannel, v::AbstractMatrix)
    if size(v, 1) != c.num_samples || size(v, 2) != c.num_antenna_channels
        throw(ArgumentError("First dimension must be the number of samples and second dimension number of channels"))
    end
    Base.put!(c.channel, v)
end
function Base.put!(c::VectorSizedChannel, v::AbstractVector)
    if size(v, 1) != c.num_antenna_channels
        throw(ArgumentError("Vector must have length of number of antenna channels"))
    end
    Base.put!(c.channel, v)
end
Base.take!(c::AbstractSizedChannel) = Base.take!(c.channel)
Base.close(c::AbstractSizedChannel, excp::Exception=Base.closed_exception()) = Base.close(c.channel, excp)
Base.isopen(c::AbstractSizedChannel) = Base.isopen(c.channel)
Base.close_chnl_on_taskdone(t::Task, c::AbstractSizedChannel) = Base.close_chnl_on_taskdone(t, c.channel)
Base.isready(c::AbstractSizedChannel) = Base.isready(c.channel)
Base.isempty(c::AbstractSizedChannel) = Base.isempty(c.channel)
Base.n_avail(c::AbstractSizedChannel) = Base.n_avail(c.channel)

Base.lock(c::AbstractSizedChannel) = Base.lock(c.channel)
Base.lock(f, c::AbstractSizedChannel) = Base.lock(f, c.channel)
Base.unlock(c::AbstractSizedChannel) = Base.unlock(c.channel)
Base.trylock(c::AbstractSizedChannel) = Base.trylock(c.channel)
Base.wait(c::AbstractSizedChannel) = Base.wait(c.channel)
Base.eltype(c::AbstractSizedChannel) = Base.eltype(c.channel)
Base.show(io::IO, c::AbstractSizedChannel) = Base.show(io, c.channel)
Base.iterate(c::AbstractSizedChannel, state=nothing) = Base.iterate(c.channel, state)
#IteratorSize(::Type{<:AbstractSizedChannel}) = Base.IteratorSize(::Type{<:Channel})