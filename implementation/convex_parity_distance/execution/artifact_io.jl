module ConvexParityDistanceArtifactIO

using SHA

export file_sha256, bytes_sha256, csv_bytes, write_csv, read_csv,
       write_sha_manifest, verify_sha_manifest, write_key_values,
       read_key_values, require_empty_directory, pack_bits, unpack_bits,
       f64_text, bool_text

file_sha256(path::AbstractString) = bytes2hex(open(sha256, path))
bytes_sha256(bytes::AbstractVector{UInt8}) = bytes2hex(sha256(bytes))
f64_text(value::Float64) = repr(value)
bool_text(value::Bool) = value ? "true" : "false"

function _csv_field(value)
    text = String(value)
    if occursin(',', text) || occursin('"', text) ||
            occursin('\n', text) || occursin('\r', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    text
end

function csv_bytes(header::Vector{String}, rows::Vector{Vector{String}})
    isempty(header) && throw(ArgumentError("CSV header is empty"))
    length(unique(header)) == length(header) ||
        throw(ArgumentError("CSV header repeats a field"))
    io = IOBuffer()
    println(io, join(_csv_field.(header), ','))
    for row in rows
        length(row) == length(header) ||
            throw(ArgumentError("CSV row width differs from its header"))
        println(io, join(_csv_field.(row), ','))
    end
    take!(io)
end

function write_csv(path::AbstractString, header::Vector{String},
                   rows::Vector{Vector{String}})
    bytes = csv_bytes(header, rows)
    open(path, "w") do io
        write(io, bytes)
    end
    path
end

function _parse_csv_line(line::AbstractString)
    fields = String[]
    buffer = IOBuffer()
    quoted = false
    index = firstindex(line)
    while index <= lastindex(line)
        character = line[index]
        if quoted
            if character == '"'
                next_index = nextind(line, index)
                if next_index <= lastindex(line) && line[next_index] == '"'
                    write(buffer, '"')
                    index = next_index
                else
                    quoted = false
                end
            else
                write(buffer, character)
            end
        elseif character == ','
            push!(fields, String(take!(buffer)))
        elseif character == '"'
            position(buffer) == 0 ||
                throw(ArgumentError("quote begins inside an unquoted CSV field"))
            quoted = true
        else
            write(buffer, character)
        end
        index = nextind(line, index)
    end
    quoted && throw(ArgumentError("unterminated quoted CSV field"))
    push!(fields, String(take!(buffer)))
    fields
end

function read_csv(path::AbstractString)
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("CSV file is empty: $path"))
    header = _parse_csv_line(first(lines))
    length(unique(header)) == length(header) ||
        throw(ArgumentError("CSV header repeats a field: $path"))
    rows = Dict{String,String}[]
    for line in Iterators.drop(lines, 1)
        isempty(line) && continue
        values = _parse_csv_line(line)
        length(values) == length(header) ||
            throw(ArgumentError("CSV row width differs: $path"))
        push!(rows, Dict(zip(header, values)))
    end
    (; header, rows)
end

function require_empty_directory(path::AbstractString)
    absolute = abspath(path)
    if ispath(absolute)
        isdir(absolute) || throw(ArgumentError(
            "output path exists and is not a directory: $absolute"))
        isempty(readdir(absolute)) || throw(ArgumentError(
            "output directory must be empty: $absolute"))
    else
        mkpath(absolute)
    end
    absolute
end

function write_sha_manifest(root::AbstractString, names::Vector{String};
                            filename::String="CANDIDATE_MANIFEST.sha256")
    length(unique(names)) == length(names) ||
        throw(ArgumentError("manifest member list contains duplicates"))
    sorted = sort(names)
    for name in sorted
        isabspath(name) && throw(ArgumentError("manifest member is absolute"))
        normpath(name) == name && !startswith(name, "..") ||
            throw(ArgumentError("manifest member is not canonical: $name"))
        isfile(joinpath(root, name)) ||
            throw(ArgumentError("manifest member is missing: $name"))
    end
    path = joinpath(root, filename)
    open(path, "w") do io
        for name in sorted
            println(io, file_sha256(joinpath(root, name)), "  ", name)
        end
    end
    path
end

function verify_sha_manifest(root::AbstractString, filename::AbstractString;
                             expected_members::Union{Nothing,Vector{String}}=nothing)
    path = joinpath(root, filename)
    isfile(path) || throw(ArgumentError("manifest is missing: $path"))
    members = String[]
    for line in eachline(path)
        isempty(line) && continue
        pieces = split(line, "  "; limit=2)
        length(pieces) == 2 || throw(ArgumentError("malformed SHA manifest"))
        digest, name = pieces
        length(digest) == 64 || throw(ArgumentError("malformed SHA digest"))
        isabspath(name) && throw(ArgumentError("manifest member is absolute"))
        normpath(name) == name && !startswith(name, "..") ||
            throw(ArgumentError("manifest member is not canonical"))
        name in members && throw(ArgumentError("manifest member is repeated"))
        candidate = joinpath(root, name)
        isfile(candidate) || throw(ArgumentError("manifest member is missing: $name"))
        file_sha256(candidate) == digest ||
            throw(ArgumentError("manifest digest differs: $name"))
        push!(members, name)
    end
    isempty(members) && throw(ArgumentError("manifest has no members"))
    if expected_members !== nothing
        Set(members) == Set(expected_members) ||
            throw(ArgumentError("manifest member set differs"))
    end
    true
end

function write_key_values(path::AbstractString, entries::Vector{Pair{String,String}})
    keys = first.(entries)
    length(unique(keys)) == length(keys) ||
        throw(ArgumentError("key-value file repeats a key"))
    open(path, "w") do io
        for (key, value) in entries
            occursin('=', key) && throw(ArgumentError("key contains '='"))
            occursin('\n', value) && throw(ArgumentError("value contains newline"))
            println(io, key, "=", value)
        end
    end
    path
end

function read_key_values(path::AbstractString)
    result = Dict{String,String}()
    for line in eachline(path)
        isempty(line) && continue
        pieces = split(line, '='; limit=2)
        length(pieces) == 2 || throw(ArgumentError("malformed key-value line"))
        haskey(result, pieces[1]) && throw(ArgumentError("key is repeated"))
        result[pieces[1]] = pieces[2]
    end
    result
end

function pack_bits(bits::AbstractVector{Bool})
    packed = zeros(UInt8, cld(length(bits), 8))
    @inbounds for index in eachindex(bits)
        bits[index] || continue
        byte = (index - 1) ÷ 8 + 1
        shift = (index - 1) % 8
        packed[byte] |= UInt8(1) << shift
    end
    packed
end

function unpack_bits(bytes::AbstractVector{UInt8}, count::Integer)
    Int(count) >= 0 || throw(ArgumentError("bit count must be nonnegative"))
    length(bytes) == cld(Int(count), 8) ||
        throw(DimensionMismatch("packed byte count differs"))
    result = falses(Int(count))
    @inbounds for index in 1:Int(count)
        byte = (index - 1) ÷ 8 + 1
        shift = (index - 1) % 8
        result[index] = ((bytes[byte] >> shift) & UInt8(1)) == UInt8(1)
    end
    if count % 8 != 0 && !isempty(bytes)
        used = count % 8
        mask = ~((UInt8(1) << used) - UInt8(1))
        bytes[end] & mask == 0 ||
            throw(ArgumentError("nonzero padding bits in packed hard decision"))
    end
    result
end

end # module
