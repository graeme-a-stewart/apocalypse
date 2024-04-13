#! /usr/bin/env julia
#
# Search for the highest non-apocalypse number we can find for
# a particular patterm
#
# The idea is to keep searching until we have found a certain
# consecutive number of apocalypse numbers
#
# As we are sweeping through the space for apocalypse numbers,
# optionally make a plot with the histogram of density

using ArgParse
using Logging
using Plots

function search_limit(;stop=10000, start=1, base=10, power=2, sequence="666")
    apocalypse_n = Int[]
    println("Searching for limit for \"$sequence\", will stop after $stop hits")
    n = start
    i = BigInt(power)^n
    apocalypse_count = 0
    n_non_apocalypse = 0
    last_non_apocalypse = n
    while (apocalypse_count < stop)
        if rem(n, 1000) == 0
            @info "Reached $n - $n_non_apocalypse in last chunk"
            n_non_apocalypse = 0
        end
        digit_string = Base.GMP.string(i, base=base)
        if occursin(sequence, digit_string)
            apocalypse_count += 1
            @debug "$n is apocalypse ($apocalypse_count consecutive)"
            push!(apocalypse_n, n)
        else
            @debug "$n is not apocalypse ($apocalypse_count consecutive)"
            apocalypse_count = 0
            last_non_apocalypse = n
            n_non_apocalypse += 1
        end
        n += 1
        i *= power
    end
    println("Searched to n=$n, last non-apocalypse n was n=$last_non_apocalypse")
    apocalypse_n
end

function apocalypse_density_plot(apocalypse_n, plot_name, sequence; bin_width=0)
    if bin_width > 0
    	n_bins = ceil(Int, last(apocalypse_n)/bin_width)
        bins = range(0, n_bins*bin_width, n_bins+1)
    else
        n_bins = 50
        bins = range(0, last(apocalypse_n), n_bins+1)
        bin_width = last(apocalypse_n) / n_bins
    end
    plt = histogram(apocalypse_n, bins=bins, 
        ylabel="Density", 
        xlabel="n (power of 2)", label="",
        title="Density of 'apocalypse' numbers for $sequence",
        normalize=:density)
    savefig(plt, plot_name)
end

parse_command_line(args) = begin
    s = ArgParseSettings(autofix_names = true)
	@add_arg_table! s begin
		"--sequence"
		help = "Apocalypse sequence to search for"
		default = "666"

		"--stop"
		help = "Stopping criteria, after this many hits the sequence is deemed complete"
		arg_type = Int
		default = 10000

        "--start"
        help = "Value of n where 2^n is the first power searched"
        arg_type = Int
        default = 1

        "--base"
        help = "Number base in which to express the result"
        arg_type = Int
        default = 10

        "--power"
        help = "Power to use for generating numbers (power^n)"
        arg_type = Int
        default = 2

        "--plot"
        help = "Save plot of apocalyptic density"

        "--bin-width"
        help = "Width of bins for histogram plot"
        arg_type = Int
        default = 0

		"--info"
		help = "Print info level log messages"
		action = :store_true

		"--debug"
		help = "Print debug level log messages"
		action = :store_true
	end
	return parse_args(args, s; as_symbols = true)
end

function main()
	args = parse_command_line(ARGS)
	if args[:debug]
		logger = ConsoleLogger(stdout, Logging.Debug)
	elseif args[:info]
		logger = ConsoleLogger(stdout, Logging.Info)
	else
		logger = ConsoleLogger(stdout, Logging.Warn)
	end

    stats = @timed begin
        apocalypse_n = search_limit(stop = args[:stop], start = args[:start], base = args[:base], power = args[:power], sequence = args[:sequence])
    end

    if !isnothing(args[:plot])
        apocalypse_density_plot(apocalypse_n, args[:plot], args[:sequence]; bin_width=args[:bin_width])
    end
    @info "Search took $(stats.time)s"
end

main()
