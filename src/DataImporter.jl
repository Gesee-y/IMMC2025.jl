############################# This module will import data #######################################

function GetCSVData(path::String, signature::NTuple{S, DataType}; sep=',') where S
    
    string_data = ""
    try
        string_data = read(path, String)  # Ensure it's a string
    catch e
        println("Failed to open file at $path")
        rethrow(e)
    end

    # Removing empty lines
    string_data = _clean_string_data(string_data)

    pre_data = split(string_data, '\n')
    data = split.(pre_data, sep)

    return parse_data(data, signature)
end

function parse_data(string_data::AbstractArray, signature::NTuple{S, DataType}) where S
    
    data = Vector{Vector}(undef, length(string_data))

    for i in eachindex(data)
        if length(string_data[i]) > 1
            data[i] = _convert_to_signature(string_data[i], signature)
        end
    end

    return data
end

function _clean_string_data(string_data::AbstractString)
    
    ## We ensure there is no empty field

    # Will search if the are too much newline that can cause empty fileds
    m = match(r"\n{2,}", string_data)

    # If it found something, then we remove the empty fields by removing the newline in excess
    while m != nothing
        string_data = replace(string_data, m.match => "\n")
        m = match(r"\n{2,}", string_data)
    end

    # We check if there is an useless newline and the end of the string
    (string_data[end] == '\n') && (string_data = string_data[begin:end-1])

    return string_data
end
function _get_csv_data(path::String, signature::NTuple{S, DataType}; sep=',') where S
    string_data = ""
    try
        string_data = read(path, String)  # Ensure it's a string
    catch e
        println("Failed to open file at $path")
        rethrow(e)
    end

    pre_data = split(string_data, '\n')
    string_data = split.(pre_data, sep)

    data = Vector{Vector}(undef, length(string_data))

    for i in eachindex(data)
        if length(string_data[i]) > 1
            data[i] = _convert_to_signature(string_data[i], signature)
        end
    end

    return data
end

function _convert_to_signature(A::Vector{<:AbstractString}, signature::NTuple{S, DataType}) where S
    
    B = Vector{promote_type(signature...)}(undef, S)

    for i in Base.OneTo(S)
        B[i] = _tovalue(A[i], signature[i])
    end
    return B
end

_tovalue(s::AbstractString, T::Type{<:AbstractString}) = s
_tovalue(s::AbstractString, T::Type{<:Number}) = parse(T, s)