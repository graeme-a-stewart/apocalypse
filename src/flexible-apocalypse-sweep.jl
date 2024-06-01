#! /usr/bin/env julia
#
# Script that sweeps over all possible "apocalypse" matches
# for a given number base
#
# Using the `limit-search.jl` script, empirically one finds that rough limits for 
# non-apocalyptic 3-digit numbers by base for $2^n$ and $3^n$ are:
#
# | Base | Non-apocalyptic $2^n$ | $3^n$ | Apocalypse |
# |------|-----------------------|-------|------------|
# | 3    | 329                   | -     | 222        |
# | 5    | 1943                  | 1739  | 444        |
# | 7    | 9019                  | 4030  | 666        |
# | 10   | 29784                 | 16892 | 666        |
# | 11   | 39017                 | 29834 | 666        |
# | 13   | 79236                 | 57326 | 666        |
# | 17   | 222510                | 139834 | 666       |
#
# N.B. As this search is only done on one match sequence it will be higher for 
# some other matches, so probably one should add a safety factor of ~10%
#
# ⬆ This is obsoleted by the use of the "--safety" option, that continues
# the search until there are no more non-apocalypse matches found
#
# So it is recorded, the new search algorithm (ec939b7fbe083b386eaaab8fa2e9898d8dbb1654) 
# is very much faster than the old
#
# | Search for sequence length 4             |
# | Base | Old search | New search | Speedup |
# |------|-------------------------|---------|
# | 5    | 22         | 13         | x1.7    |
# | 7    | 988        | 221        | x4.5    |
# | 10   | 70771      | 5172       | x13.7   |
#

using ArgParse
using JSON
using LaTeXStrings
using Logging
using Plots
using ProgressBars
using Statistics

const spinner = ['|', '/', '-', '\\']

const default_safety = 1000

"""
Save results to a JSON file

This function saves the results of a search to a JSON file, which can be
used to continue searches at later, or to plot results.

The JSON object stores some metadata as well as the list of non-apocalyptic
matches for each sequence.
"""
function save_search_results(results; power, base, seq_len, start, stop, filename = nothing)
    if isnothing(filename)
        filename = joinpath("results",
            "n-non-apocalypse-v3-base-$(base)-power-$(power)-seq-$(seq_len).json")
    end
    @info "Saving results to $filename at n=$stop (total non-apocalypse matches: $(sum(results)))"
    results = Dict("power" => power, "base" => base, "seq_len" => seq_len,
        "start" => start, "stop" => stop, "results" => results)
    open(filename, "w") do io
        JSON.print(io, results, 2)
    end
end

"""
Load status of the search from a JSON file
"""
function load_search_results(filename)
    @info "Loading results from $filename"
    open(filename, "r") do io
        return JSON.parse(io)
    end
end

"""
Flexible apocalypse search master function
"""
function flexible_apocalypse_search(; power = 2, base = 10, seq_len = 3, start = 1, stop = nothing,
    safety = default_safety, save = 0, n_nonapocalypse = nothing)
    # Calculate all valid match strings for this base
    seq_matches = [Base.GMP.string(BigInt(i - 1), base = base, pad = seq_len)
                   for i in 1:base^seq_len]

    # If we are doing periodic saves, record the current time
    if save != 0
        last_save = time()
    end

    # Optimised search strategy, instead of matching each string against
    # the digit sequence (which scales badly as the base and the sequence
    # length increase), create a map from the sequence match strings, and
    # sweep only once through the digit sequence, marking off matches
    # as we go
    match_counts = Dict{String, Int}()
    for seq in seq_matches
        match_counts[seq] = 0
    end
    # Start of search sequence
    if isnothing(n_nonapocalypse)
        n_nonapocalypse = zeros(Int, length(seq_matches))
        n = start - 1
        last_non_apocalypse_n = 0
    else
        # When we restart from a saved file, we already have the n_nonapocalypse
        # and we start the search from stop+1 (but set to stop here as the value
        # of n is incremented at the start of the loop below)
        n = stop
        last_non_apocalypse_n = stop
    end   
    i = BigInt(power)^n
    last_n = n
    while (n - last_non_apocalypse_n < safety)
        i *= power
        n += 1
        i_str = Base.GMP.string(i, base = base)
        non_apocalypse_count = 0
        # March over the string and check off matches
        for j in 1:(length(i_str)-(seq_len-1))
            m_str = SubString(i_str, j, j + (seq_len - 1))
            if haskey(match_counts, m_str)
                match_counts[m_str] += 1
            end
        end
        # Now check the matches
        for (seq_n, seq) in enumerate(seq_matches)
            if match_counts[seq] == 0
                n_nonapocalypse[seq_n] += 1
                non_apocalypse_count += 1
                last_non_apocalypse_n = n
            else
                # Reset for next iteration
                match_counts[seq] = 0
            end
        end
        print("\r$(spinner[n%length(spinner)+1]) $n $non_apocalypse_count/$(length(seq_matches)) $(n-last_non_apocalypse_n)    ")
        # See if we want to save results
        if save != 0 && time() - last_save > 60 * save
            last_save = time()
            save_search_results(n_nonapocalypse, power = power, base = base, seq_len = seq_len, start = start, stop = n)
        end
    end
    println("\nLast non-matching power was $last_non_apocalypse_n")
    last_n = n

    seq_matches, n_nonapocalypse, last_n
end

parse_command_line(args) = begin
    s = ArgParseSettings(autofix_names = true)
    @add_arg_table! s begin
        "--power"
        help = "Base power, p, to use"
        arg_type = Int
        default = 2

        "--base"
        help = "Number base in which to express the result of p^n"
        arg_type = Int
        default = 10

        "--start"
        help = "Value of n where p^n is the first power searched"
        arg_type = Int
        default = 1

        "--safety"
        help = "Halt after this many numbers have been checked and every match has been found"
        arg_type = Int
        default = 1000

        "--save"
        help = "Save intermediate results every N minutes (set to 0 to disable)"
        arg_type = Int
        default = 10

        "--seq-length"
        help = "Sequence length to search for"
        arg_type = Int
        default = 3

        "--restart"
        help = "Restart scan from saved JSON file"

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

    if !isnothing(args[:restart])
        status = load_search_results(args[:restart])
        power = status["power"]
        base = status["base"]
        seq_len = status["seq_len"]
        start = status["start"]
        stop = status["stop"]
        n_nonapocalypse = status["results"]
        safety = isnothing(args[:safety]) ? args[:safety] : default_safety
        save = args[:save]
    else
        power = args[:power]
        base = args[:base]
        seq_len = args[:seq_length]
        start = args[:start]
        stop = nothing
        safety = args[:safety]
        save = args[:save]
        n_nonapocalypse = nothing
    end

    stats = @timed begin
        seq_matches, n_nonapocalypse, last_n = flexible_apocalypse_search(power = power, base = base,
            seq_len = seq_len, start = start, stop = stop, safety = safety, save = save, n_nonapocalypse = n_nonapocalypse)
    end
    @info "Search took $(stats.time)s"

    # Now plot and summarise results
    na_avg = Int(floor(mean(n_nonapocalypse)))
    na_std = std(n_nonapocalypse)
    norm_n_nonapocalypse = n_nonapocalypse .- na_avg

    # Outlier values for counts
    println("Outlier values from average matches:")
    for (seq_n, seq) in enumerate(seq_matches)
        if abs(norm_n_nonapocalypse[seq_n]) > 3 * na_std
            println(" $seq: $(norm_n_nonapocalypse[seq_n])")
        end
    end

    # Numerical results
    save_search_results(n_nonapocalypse, power = power, base = base, seq_len = seq_len, start = start, stop = last_n)

    # Plot of deviations from the non-apocalypse average
    xticks_n = Int.(collect(range(1, length(seq_matches), base)))
    xlabels = [seq_matches[i] for i in xticks_n]
    non_apocalypse_dist = plot(1:length(seq_matches), norm_n_nonapocalypse,
        xlabel = "Sequence of $(seq_len) digits",
        ylabel = "Non-Apocalypse matches - mean ($na_avg)",
        title = "Non-Apocalyptic Matches for " * L"%$(power)^n" * ", base $base",
        label = "", xticks = (xticks_n, xlabels))
    savefig(non_apocalypse_dist, joinpath("results",
        "non-apocalyptic-matches-v2-base-$(base)-power-$(power)-seq-$(seq_len)-n$(start)-$(last_n).pdf"))

end

main()
