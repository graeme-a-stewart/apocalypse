#! /usr/bin/env julia
#
# Fractal Spiral PLot 
# - produce a 2D plot of a fractal spiral
# - produce an animation of a fractal spiral growing

using ArgParse
using CairoMakie
using Colors
using ResumableFunctions
using ProgressBars

"""Return the x, y *end point* coordinates of the next (nth) line segment"""
@resumable function spiral(s::Real, nmax::Int)
    x = 1.0
    y = 0.0
    angle = rotation_angle = 0.0
    for _ ∈ 1:nmax
        @yield x, y
        # To avoid round off error, we always keep angle in [0, 2π)
        rotation_angle = rem(rotation_angle + 2π * s, 2π)
        angle = rem(angle + rotation_angle, 2π)
        x += cos(angle)
        y += sin(angle)
    end
end

"""Obtain the spiral in a pair of x,y vectors"""
function spiral_xy(s::Real, nmax::Int)
    xv = [0.0]
    yv = [0.0]
    sizehint!(xv, nmax + 1)
    sizehint!(yv, nmax + 1)
    for (x, y) in spiral(s, nmax)
        push!(xv, x)
        push!(yv, y)
    end
    xv, yv
end

"""Plot the fractal spiral"""
function plot_spiral(s, nmax, output)
    xv, yv = spiral_xy(s, nmax)

    fig = Figure()
    ax = Axis(
        fig[1, 1];
        title = "Fractal Sprial for s=$(s), $nmax interations",
        xlabel = "x",
        ylabel = "y",
    )
    lines!(ax, xv, yv)

    save(output, fig)
end

"""Animate the fractal spiral"""
function animate_spiral(
    s,
    nmax,
    output;
    framerate = 100,
    floataxes = false,
    axispadding = 1.0,
)
    xv, yv = spiral_xy(s, nmax)

    points = Observable(Point2f[(0.0, 0.0)])

    if floataxes
        limits = @lift (
            minimum(p[1] for p in $points) - axispadding,
            maximum(p[1] for p in $points) + axispadding,
            minimum(p[2] for p in $points) - axispadding,
            maximum(p[2] for p in $points) + axispadding,
        )
    else
        limits =
            (extrema(xv)..., extrema(yv)...) .+
            (-axispadding, axispadding, -axispadding, axispadding)
    end

    ax = (
        title = "Fractal Spiral for s=$(s), $nmax interations",
        xlabel = "x",
        ylabel = "y",
        limits = limits,
    )
    fig = lines(points; axis = ax)
    record(fig, output, ProgressBar(1:nmax); framerate = framerate) do iteration
        points[] = push!(points[], Point2f(xv[iteration], yv[iteration]))
    end
end

function main()
    aps = ArgParseSettings(autofix_names = true)
    @add_arg_table aps begin
        "--constant", "-s"
        help = "Constant value to control the spiral angle"
        arg_type = String
        required = true

        "--nmax", "-n"
        help = "Number of interations"
        arg_type = Int
        default = 1000

        "--animate", "-a"
        help = "Make animation instead of animation"
        action = :store_true

        "--floataxes"
        help = "For animation, float the axes as the spiral grows (otherwise fix the axes to the size needed)"
        action = :store_true

        "--framerate"
        help = "Frame rate for the animation"
        arg_type = Int
        default = 100

        "output"
        help = "File for output"
        default = "jetreco.mp4"
    end
    args = parse_args(ARGS, aps; as_symbols = true)

    # For the "s" constant, we try to recognise irrational constants that Julia
    # supports, such as π, e, φ, etc.
    s = nothing
    try
        s = eval(Symbol(args[:constant]))
    catch UndefVarError
        s = parse(Float64, args[:constant])
    end

    if args[:animate]
        animate_spiral(
            s,
            args[:nmax],
            args[:output];
            framerate = args[:framerate],
            floataxes = args[:floataxes],
        )
    else
        plot_spiral(s, args[:nmax], args[:output])
    end
end

main()
