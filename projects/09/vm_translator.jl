mutable struct ScopeData
    file_name::AbstractString
    function_name::AbstractString
    function_arg_count::Int
    function_call_count::Dict{AbstractString,Int}
    arithmetic_logic_count::Dict{Regex,Int}

    function ScopeData(; file_name="", function_name="", function_arg_count=0,
                       arithmetic_logical_map=Dict{Regex,Int}(r"add" => 0, r"sub" => 0, r"neg" => 0,
                                                              r"eq"  => 0, r"gt"  => 0, r"lt"  => 0,
                                                              r"and" => 0, r"or"  => 0, r"not" => 0, ),
                       function_call_count=Dict{AbstractString,Int}())
        return new(file_name, function_name, function_arg_count, function_call_count, arithmetic_logical_map, )
    end
end

function remove_comments(line::AbstractString, )
    index = findfirst("//", line)
    if index !== nothing
        return strip(line[1:(index[1]-1)])
    end
    return line
end

function set_file!(scope_data::ScopeData, path_or_file::AbstractString)
    file_name = splitpath(path_or_file)[end]
    @assert file_name[end-2:end] == ".vm" "$(file_name[end-2:end]) != \".vm\""
    scope_data.file_name = file_name[1:end-3]
end

function update_function_scope!(scope_data::ScopeData, line::AbstractString)
    reg_match = match(r"function (.*) ([-+]?\d+)", line)
    if reg_match !== nothing
        scope_data.function_name = reg_match.captures[1]
        scope_data.function_arg_count = parse(Int, reg_match.captures[2])
    end
end

function update_call_counts!(scope_data::ScopeData, line::AbstractString, )
    for (key, _) in scope_data.arithmetic_logic_count
        if occursin(key, line)
            reg_match = match(key, line)
                scope_data.arithmetic_logic_count[key] += 1
            break
        end
    end

    reg_match = match(r"call (.*) \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b", line)
    if reg_match !== nothing
        if haskey(scope_data.function_call_count, reg_match.captures[1])
            scope_data.function_call_count[reg_match.captures[1]] += 1
        else
            scope_data.function_call_count[reg_match.captures[1]] = 1
        end
    end
end

function translate_push_pop(line::AbstractString, stream_out::IO, )
    push_pop_map = Dict{Regex,Function}(
        r"pop local ([-+]?\d+)"    => (_i -> "@$(_i)\nD=A\n@LCL\nD=D+M\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"),
        r"pop argument ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@ARG\nD=D+M\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"),
        r"pop this ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THIS\nD=D+M\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"),
        r"pop that ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THAT\nD=D+M\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"),
        r"pop temp ([0-7])"        => (_i -> "@$(_i)\nD=A\n@R5\nD=D+A\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"),

        r"push constant ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push local ([-+]?\d+)"    => (_i -> "@$(_i)\nD=A\n@LCL\nA=D+M\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push argument ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@ARG\nA=D+M\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push this ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THIS\nA=D+M\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push that ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THAT\nA=D+M\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push temp ([0-7])"        => (_i -> "@$(_i)\nD=A\n@R5\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),

        r"pop pointer 0"           => (_i -> "@SP\nAM=M-1\nD=M\n@THIS\nM=D\n"),
        r"pop pointer 1"           => (_i -> "@SP\nAM=M-1\nD=M\n@THAT\nM=D\n"),

        r"push pointer 0"           => (_i -> "@THIS\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
        r"push pointer 1"           => (_i -> "@THAT\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    )

    for (key, value) in push_pop_map
        if occursin(key, line)
            reg_match = match(key, line)
            (reg_match === nothing) && error("Failed to parse line : \"$line\"")

            write(stream_out, value(isempty(reg_match.captures) ? nothing : reg_match.captures[1]))
            break
        end
    end
end

function translate_static(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    static_memory_map = Dict{Regex,Function}(
        r"pop static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@SP\nAM=M-1\nD=M\n@$(scope_data.file_name).$(_i)\nM=D\n"),
        r"push static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@$(scope_data.file_name).$(_i)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    )

    for (key, value) in static_memory_map
        if occursin(key, line)
            write(stream_out, value(match(key, line).captures[1]))
            break
        end
    end
end

function translate_arithmetic_logic(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    arithmetic_logical_map = Dict{Regex,Function}(
        r"add" => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nM=D+M\n@SP\nM=M+1\n"),
        r"sub" => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nM=D-M\nM=-M\n@SP\nM=M+1\n"),
        r"neg" => (_i -> "@SP\nAM=M-1\nM=-M\n@SP\nM=M+1\n"),

        r"eq"  => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nD=D-M\n@SP\nA=M\nM=0\n@NOT_EQUAL_$(_i)\nD;JNE\n@SP\nA=M\nM=-1\n(NOT_EQUAL_$(_i))\n@SP\nM=M+1\n"),
        r"gt"  => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nD=D-M\nD=-D\n@SP\nA=M\nM=0\n@LESS_THAN_OR_EQUAL_$(_i)\nD;JLE\n@SP\nA=M\nM=-1\n(LESS_THAN_OR_EQUAL_$(_i))\n@SP\nM=M+1\n"),
        r"lt"  => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nD=D-M\nD=-D\n@SP\nA=M\nM=0\n@GREATER_THAN_OR_EQUAL_$(_i)\nD;JGE\n@SP\nA=M\nM=-1\n(GREATER_THAN_OR_EQUAL_$(_i))\n@SP\nM=M+1\n"),

        r"and" => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nM=D&M\n@SP\nM=M+1\n"),
        r"or"  => (_i -> "@SP\nAM=M-1\nD=M\n@SP\nAM=M-1\nM=D|M\n@SP\nM=M+1\n"),
        r"not" => (_i -> "@SP\nAM=M-1\nM=!M\n@SP\nM=M+1\n"),
    )

    for (key, value) in arithmetic_logical_map
        if occursin(key, line)
            write(stream_out, value(scope_data.arithmetic_logic_count[key]))
            break
        end
    end
end

function translate_branching_command(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    branching_command_map = Dict{Regex,Function}(
        r"label (.*)" => (reg_capture -> "($(scope_data.function_name).$reg_capture)\n"),
        r"goto (.*)" => (reg_capture -> "@$(scope_data.function_name).$reg_capture\n0;JMP\n"),
        r"if-goto (.*)" => (reg_capture -> "@SP\nAM=M-1\nD=M\n@$(scope_data.function_name).$reg_capture\nD;JNE\n")
    )

    for (key, value) in branching_command_map
        if occursin(key, line)
            write(stream_out, value(match(key, line).captures[1]))
            break
        end
    end
end

function translate_function_command(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    function_command_map = Dict{Regex,Function}(
        r"function (.*) \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => ((_function_name, _nVars)->"($_function_name)\n@$(_nVars)\nD=A\n@R13\nM=D\nD=M\n@$(_function_name).ADD_LOCALS_LOOP_END\nD;JLE\n($(_function_name).ADD_LOCALS_LOOP_START)\n@SP\nA=M\nM=0\n@SP\nM=M+1\n@R13\nMD=M-1\n@$(_function_name).ADD_LOCALS_LOOP_START\nD;JGT\n($(_function_name).ADD_LOCALS_LOOP_END)\n"),
        r"call (.*) \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => ((_function_name, _nArgs)->"@$(_function_name).RETURN_ADDRESS_$(scope_data.function_call_count[_function_name])\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n@LCL\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n@ARG\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n@THIS\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n@THAT\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n@SP\nD=M\n@$(_nArgs)\nD=D-A\n@5\nD=D-A\n@ARG\nM=D\n@SP\nD=M\n@LCL\nM=D\n@$(_function_name)\n0;JMP\n($(_function_name).RETURN_ADDRESS_$(scope_data.function_call_count[_function_name]))\n"),
        r"return" => (()->"@LCL\nD=M\n@R13\nM=D\n@5\nA=D-A\nD=M\n@R14\nM=D\n@SP\nAM=M-1\nD=M\n@ARG\nA=M\nM=D\n@ARG\nD=M+1\n@SP\nM=D\n@R13\nAM=M-1\nD=M\n@THAT\nM=D\n@R13\nAM=M-1\nD=M\n@THIS\nM=D\n@R13\nAM=M-1\nD=M\n@ARG\nM=D\n@R13\nAM=M-1\nD=M\n@LCL\nM=D\n@R14\nA=M\n0;JMP\n")
    )

    for (key, value) in function_command_map
        if occursin(key, line)
            write(stream_out, value(match(key, line).captures...))
            break
        end
    end
end

function translate_sys_init(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    seekstart(stream_out)
    write(stream_out, "@256\nD=A\n@SP\nM=D\n")

    translate_function_command(scope_data, line, stream_out, )
end

function translate_vm(file_ins::Vector{S}, file_out::S, ) where S<:AbstractString
    scope_data = ScopeData()

    stream_out = open(file_out, "w")

    if any(_x->splitpath(_x)[end] == "Sys.vm", file_ins)
        line = "call Sys.init 0"
        update_call_counts!(scope_data, line)
        translate_sys_init(scope_data, line, stream_out, )
    end

    for file_in in file_ins
        stream_in = open(file_in, "r")
        set_file!(scope_data, file_in)


        for file_line in eachline(stream_in)
            line = remove_comments(file_line)
            update_function_scope!(scope_data, line)
            update_call_counts!(scope_data, line)

            translate_push_pop(line, stream_out)
            translate_arithmetic_logic(scope_data, line, stream_out)
            translate_static(scope_data, line, stream_out)
            translate_branching_command(scope_data, line, stream_out)
            translate_function_command(scope_data, line, stream_out)
        end

        close(stream_in)
    end

    close(stream_out)
end

directories = [
    joinpath(@__DIR__, "ProgramFlow", "BasicLoop"),
    joinpath(@__DIR__, "ProgramFlow", "FibonacciSeries"),
    joinpath(@__DIR__, "FunctionCalls", "SimpleFunction"),
    joinpath(@__DIR__, "FunctionCalls", "FibonacciElement"),
    joinpath(@__DIR__, "FunctionCalls", "NestedCall"),
    joinpath(@__DIR__, "FunctionCalls", "SimpleFunction"),
    joinpath(@__DIR__, "FunctionCalls", "StaticsTest"),
]

for directory in directories
    file_ins = filter(_x->splitext(_x)[2] == ".vm", joinpath.(Ref(directory), readdir(directory)))
    file_out = joinpath(directory, splitpath(directory)[end] * ".asm")

    translate_vm(file_ins, file_out, )
end

