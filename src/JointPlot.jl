module JointPlot
using StatsBase
using LinearAlgebra
using ImageFiltering
using Plots
import Plots
struct JointDist
    params::Array{String}
    #hist::Array{Histogram{Float64, 1},1}
    hist::Array{Array{Histogram{Float64},1}}
end

struct ParamInfo
    name::String
    col::Int
    range::Union{Missing, Tuple{Float64, Float64}}
    nbins::Int
    central_value::Union{Missing, Float64}
    smooth_scale::Float64
end

function load_param_info(param_term::Dict, col::Int)::ParamInfo
    name=param_term["param"]
    range=if haskey(param_term, "range")
        (param_term["range"][1],param_term["range"][2])
    else
        missing
    end
    nbins=param_term["nbins"]
    central_value=if haskey(param_term, "central_value")
        param_term["central_value"]
    else
        missing
    end

    col=if haskey(param_term,"col")
        param_term["col"]
    else
        println("Warning, key col absent, using param order")
        col
    end

    smooth_cale=if haskey(param_term, "smooth_scale")
        param_term["smooth_scale"]
    else
        1.0
    end
    ParamInfo(name, col,range,nbins,central_value,smooth_cale)
end

function calculate_histogram(data::AbstractArray, param::ParamInfo)::Histogram{Float64,1}
    var_range=if ismissing(param.range)
        (minimum(data), maximum(data))
    else
        param.range
    end

    bins=range(var_range[1], var_range[2], length=param.nbins)

    fit(Histogram{Float64}, data, bins)
end

function calculate_histogram2(x::AbstractArray,
    y::AbstractArray,
    param_x::ParamInfo,
    param_y::ParamInfo)::Histogram{Float64,2}
    var_range_x=if ismissing(param_x.range)
        (minimum(x), maximum(x))
    else
        param_x.range
    end

    var_range_y=if ismissing(param_y.range)
        (minimum(y), maximum(y))
    else
        param_y.range
    end

    bins_x=range(var_range_x[1], var_range_x[2], length=param_x.nbins)
    bins_y=range(var_range_y[1], var_range_y[2], length=param_y.nbins)

    h=fit(Histogram{Float64}, (x,y), (bins_x, bins_y))
    h.weights=ImageFiltering.imfilter(h.weights, ImageFiltering.Kernel.gaussian((param_x.smooth_scale, param_x.smooth_scale)))
    h
end


function calculate_histograms(data, cfg::Dict)::JointDist
    params=[load_param_info(p, i) for (i,p) in enumerate(cfg["params"])]
    pnames=[p.name for p in params]
    nparams=length(params)
    println(nparams)
    @assert length(params)<=size(data,2)-1

    #hist=[calculate_histogram(data[:,i], params[i]) for i in 1:nparams]
    hist=
    [vcat([calculate_histogram2(data[:,i], data[:,j],
    params[i],params[j]) for j in 1:i-1], calculate_histogram(data[:,i], params[i])) for i in 1:nparams]
    JointDist(pnames,hist)
end

function Plots.plot(jd::JointDist)
    plts=Plots.Plot[]
    nparams=length(jd.params)
    for i in 1:nparams
        for j in 1:nparams
            if j>i
                push!(plts, Plots.plot(xaxis=false,yaxis=false,leg=false))
            else
                xaxis=i==nparams
                yaxis=j==1
                push!(plts, Plots.plot(jd.hist[i][j],leg=false, xaxis=xaxis, yaxis=yaxis, c=:Greys))
            end
        end
    end
    l=Plots.@layout Plots.grid(nparams, nparams, widths=ones(nparams)/nparams, heights=ones(nparams)/nparams)
    Plots.plot(plts..., layout=l, margin=-3Plots.mm, widen=false)
end

end # module
