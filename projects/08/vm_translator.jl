
# %%
# label label_name
# (file_name.function_name$label_name)

# r"label (.*)" => ((file_name, function_name, reg_capture) -> "($file_name.function_name\$$reg_capture)")

# %%
# goto label
# @file_name.function_name$reg_capture
# 0;JMP

# r"goto (.*)" => ((file_name, function_name, reg_capture) -> "@$file_name.function_name\$$reg_capture\n0;JMP\n")

# %%
# if-goto label
#
# @SP
# AM=M-1
# D=M
# @file_name.function_name$reg_capture
# D;JMP

# r"if-goto (.*)" => ((file_name, function_name, reg_capture) -> "@SP\nAM=M-1\nD=M\n@$file_name.function_name\$$reg_capture\nD;JMP\n")

# %%

mutable struct ScopeData
    file_name::AbstractString
    function_name::AbstractString
    function_arg_count::Int
    arithmetic_logic_count::Dict{Regex,Int}

    function ScopeData(; file_name="", function_name="", function_arg_count=0,
                       arithmetic_logical_map=Dict{Regex,Int}(r"add" => 0, r"sub" => 0, r"neg" => 0,
                                                              r"eq"  => 0, r"gt"  => 0, r"lt"  => 0,
                                                              r"and" => 0, r"or"  => 0, r"not" => 0, ))
        return new(file_name, function_name, function_arg_count, arithmetic_logical_map)
    end
end

function remove_comments(line::AbstractString, )
    index = findfirst("//", line)
    if index !== nothing
        return strip(line[1:(index[1]-1)])
    end
    return line
end

function update_scope!(scope_data::ScopeData, line::AbstractString, )
    reg_match = match(r"function (.*) ([-+]?\d+)", line)
    if reg_match !== nothing
        scope_data.function_name = match.captures[1]
        scope_data.function_arg_count = match.captures[2]
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
        r"pop static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@SP\nAM=M-1\nD=M\n@$(scope_data.filename).$(_i)\nM=D\n"),
        r"push static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@$(scope_data.filename).$(_i)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    )

    for (key, value) in static_memory_map
        if occursin(key, line)
            write(stream_out, value(scope_data.filename, match(key, line).captures[1]))
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
            scope_data.arithmetic_logic_count[key] += 1
            break
        end
    end
end

function translate_branching_command(scope_data::ScopeData, line::AbstractString, stream_out::IO, )
    branching_command_map = Dict{Regex,Function}(
        r"label (.*)" => (reg_capture -> "($(scope_data.function_name)\$$reg_capture)\n"),
        r"goto (.*)" => (reg_capture -> "@$(scope_data.function_name)\$$reg_capture\n0;JMP\n"),
        r"if-goto (.*)" => (reg_capture -> "@SP\nAM=M-1\nD=M\n@$(scope_data.function_name)\$$reg_capture\nD;JNE\n")
    )

    for (key, value) in branching_command_map
        if occursin(key, line)
            write(stream_out, value(match(key, line).captures[1]))
            break
        end
    end
end

function translate_vm(file_in, file_out, )
    stream_in = open(file_in, "r")
    stream_out = open(file_out, "w")
    file_name = split(basename(file_in), ".")[1]

    scope_data = ScopeData(file_name=file_name)

    for file_line in eachline(stream_in)
        line = remove_comments(file_line)
        update_scope!(scope_data, line)

        translate_push_pop(line, stream_out)
        translate_arithmetic_logic(scope_data, line, stream_out)
        translate_static(scope_data, line, stream_out)
        translate_branching_command(scope_data, line, stream_out)
    end

    close(stream_out)
    close(stream_in)
end

vm_files  = [joinpath(@__DIR__, "ProgramFlow", "BasicLoop", "BasicLoop.vm"),
             joinpath(@__DIR__, "ProgramFlow", "FibonacciSeries", "FibonacciSeries.vm")]
asm_files = [joinpath(@__DIR__, "ProgramFlow", "BasicLoop", "BasicLoop.asm"),
             joinpath(@__DIR__, "ProgramFlow", "FibonacciSeries", "FibonacciSeries.asm")]

for (f_in, f_out) in zip(vm_files, asm_files)
    translate_vm(f_in, f_out,)
end

