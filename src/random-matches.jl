#! /usr/bin/env julia
#
# Search for matches against digit sequences in random numbers
# of a given length.

using ArgParse
using Dates
using Random
using JSON
using LaTeXStrings
using Logging
using Plots
using ProgressBars
using Statistics

"""
Save results to a JSON file

This function saves the results of a search to a JSON file, which can be
used to continue searches at later, or to plot results.

The JSON object stores some metadata as well as the list of non-apocalyptic
matches for each sequence.
"""
function save_search_results(results; base, seq_len, number_length, start, stop, filename = nothing)
    if isnothing(filename)
        filename = joinpath("results",
            "n-non-match-v4-base-$(base)-length-$(number_length)-seq-$(seq_len).json")
    end
    @info "Saving results to $filename at n=$stop (total non-matches: $(sum(results))) at $(string(DateTime(now())))"
    results = Dict("power" => 0, "base" => base, "seq_len" => seq_len,
        "start" => start, "stop" => stop, "results" => results, "length" => number_length,
        "format" => "v4", "method" => "random")
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
Random match search function
"""
function non_match_search(; base = 10, seq_len = 3, number_length = 100,
    start = 1, stop = 100_000, save = 0, rng = Random.GLOBAL_RNG)
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
    n_non_matches = zeros(Int, length(seq_matches))

    # Do the search
    max_number = BigInt(base)^number_length-1
    for n ∈ ProgressBar(start:stop)
        i = rand(rng, BigInt(0):max_number)
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
                n_non_matches[seq_n] += 1
            else
                # Reset for next iteration
                match_counts[seq] = 0
            end
        end
        # See if we want to save results
        if save != 0 && time() - last_save > 60 * save
            last_save = time()
            save_search_results(n_non_matches, base = base, seq_len = seq_len, number_length = number_length, start = 1, stop = n)
        end
    end

    n_non_matches
end

parse_command_line(args) = begin
    s = ArgParseSettings(autofix_names = true)
    @add_arg_table! s begin
        "--base"
        help = "Number base in which to express the result of p^n"
        arg_type = Int
        default = 10

        "--save"
        help = "Save intermediate results every N minutes (set to 0 to disable)"
        arg_type = Int
        default = 10

        "--seq-length"
        help = "Sequence length to search for"
        arg_type = Int
        default = 3

        "--number_length"
        help = "Digit length of random numbers to generate"
        arg_type = Int
        default = 100

        "--stop"
        help = "Stop after this many random numbers have been checked"
        arg_type = Int
        default = 100000

        "--seed"
        help = "Random number seed"
        arg_type = Int
        default = 123456789

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

    base = args[:base]
    seq_len = args[:seq_length]
    number_length = args[:number_length]
    stop = args[:stop]
    save = args[:save]

    stats = @timed begin
        n_non_matches = non_match_search(base = base,
            seq_len = seq_len,
            number_length = number_length,
            start = 1,
            stop = stop,
            save = save,
            rng = Xoshiro(args[:seed]))
    end
    @info "Search took $(stats.time)s"

    # Numerical results
    save_search_results(n_non_matches, base = base, seq_len = seq_len, number_length = number_length, start = 1, stop = stop)
end

main()
