using StaticArrays

struct StaticDictionary{N,K,V}
    keys::SVector{N, K}
    values::SVector{N, V}
end
Base.haskey(d::StaticDictionary{N,K,V}, x::K) where {N,K,V} = (x in d.keys)
function Base.getindex(d::StaticDictionary{N,K,V}, x::K) where {N,K,V}
    for (key, value) in zip(d.keys, d.values)
        if key == x
            return value
        end
    end
    error("Key $x not found int dictionary!")
end
Base.length(b::StaticDictionary{N}) where {N} = N

# %%
# pop local i
# @i
# D = A     // D = i
# @LCL
# D = D + M // D = i + RAM[LCL]
# @R13
# M = D     // RAM[14] = i + RAM[LCL]
# @SP
# AM=M-1
# D = M     // D = RAM[SP-1]
# @R13
# A = M
# M = D     // RAM[i + RAM[LCL]] = RAM[SP-1]

# pop argument i
# @i
# D = A
# @ARG
# D = D + M
# @R14
# M = D     # Store 5+i in R14
# @SP
# A = M
# D = M
# @R14
# A = M     # Access RAM[5+i]
# M = D     # Store
# @SP
# M = M - 1

# pop this i
# @i
# D = A
# @THIS
# D = D + A
# @R14
# M = D     # Store 5+i in R14
# @SP
# A = M
# D = M
# @R14
# A = M     # Access RAM[5+i]
# M = D     # Store
# @SP
# M = M - 1

# pop that i
# @i
# D = A
# @THIS
# D = D + A
# @R14
# M = D     # Store 5+i in R14
# @SP
# A = M
# D = M
# @R14
# A = M     # Access RAM[5+i]
# M = D     # Store
# @SP
# M = M - 1

# pop temp i
# @i
# D = A
# @R5
# D = D + A
# @R13
# M = D     # Store 5+i in R14
# @SP
# AM=M-1
# D = M     // D = RAM[SP-1]
# @R13
# A = M
# M = D     // RAM[i + RAM[LCL]] = RAM[SP-1]

# pop pointer 0
# @SP
# AM = M - 1
# D = M         // D = RAM[SP-1]
# @THIS
# M = D

# pop static i
# @SP
# AM = M - 1
# D = M         // D = RAM[SP-1]
# @Foo.i
# M = D

# push constant i
# @i
# D = A
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push local i
# @i
# D = A      // D = i
# @LCL
# A = D + M
# D = M      // D = RAM[i + RAM[LCL]]
# @SP
# A = M
# M = D      // RAM[SP] = RAM[i + RAM[LCL]]
# @SP
# M = M + 1

# push temp i
# @i
# D = A         // D = i
# @R5
# A = D + A
# D = M         // D = RAM[i + 5]
# @SP
# A = M
# M = D         // RAM[SP] = RAM[i + 5]
# @SP
# M = M + 1

# push pointer 0
# @THIS
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push static i
# @Foo.i
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# add
# @SP
# AM=M-1
# D = M
# @SP
# AM = M - 1
# M = D + M
# @SP
# M = M + 1

# sub
# @SP
# AM = M - 1
# D = M
# @SP
# AM = M - 1
# M = D - M
# M = -M
# @SP
# M = M + 1

# neg
# @SP
# AM = M - 1
# M = -M
# @SP
# M = M + 1

# eq
# @SP
# AM = M - 1
# D = M       // D = RAM[SP-1]
# @SP
# AM = M - 1
# D = D - M   // D = RAM[SP-1] - RAM[SP-2]
# D = -D      // D = RAM[SP-2] - RAM[SP-1]
# @SP
# A = M
# M = 0
# @NOT_EQUAL_i
# D;JNE       // Jump to (NOT_EQUAL_i) if RAM[SP-2] - RAM[SP-1] != 0
# @SP
# A = M
# M = -1
# (NOT_EQUAL_i)
# @SP
# M=M+1

# gt
# @SP
# AM = M - 1
# D = M       // D = RAM[SP-1]
# @SP
# AM = M - 1
# D = D - M   // D = RAM[SP-1] - RAM[SP-2]
# D = -D      // D = RAM[SP-2] - RAM[SP-1]
# @SP
# A = M
# M = 0
# @LESS_THAN_OR_EQUAL_i
# D;JLE       // Jump to (LESS_THAN_OR_EQUAL_i) if RAM[SP-2] - RAM[SP-1] != 0
# @SP
# A = M
# M = -1
# (LESS_THAN_OR_EQUAL_i)
# @SP
# M=M+1

# and
# @SP
# AM = M - 1
# D = M       // D = RAM[SP-1]
# @SP
# AM = M - 1
# M = D & M   // RAM[SP-2] = RAM[SP-1] & RAM[SP-2]
# @SP
# M=M+1

# not
# @SP
# AM = M - 1
# M = !M       // RAM[SP-1] = !RAM[SP-1]
# @SP
# M=M+1


# %%
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

static_memory_map = Dict{Regex,Function}(
    r"pop static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => ((filename, _i) -> "@SP\nAM=M-1\nD=M\n@$(filename).$(_i)\nM=D\n"),
    r"push static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => ((filename, _i) -> "@$(filename).$(_i)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
)

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

function remove_comments(line::AbstractString, )
    index = findfirst("//", line)
    if index !== nothing
        return strip(line[1:(index[1]-1)])
    end
    return line
end

function translate_push_pop(line::AbstractString, stream_out::IO, )
    for (key, value) in push_pop_map
        if occursin(key, line)
            reg_match = match(key, line)
            (reg_match === nothing) && error("Failed to parse line : \"$line\"")

            write(stream_out, value(isempty(reg_match.captures) ? nothing : reg_match.captures[1]))
            break
        end
    end
end

function translate_static(line::AbstractString, stream_out::IO, filename::AbstractString, )
    for (key, value) in static_memory_map
        if occursin(key, line)
            write(stream_out, value(filename, match(key, line).captures[1]))
            break
        end
    end
end

function translate_arithmetic_logic(line::AbstractString, stream_out::IO, arithmetic_op_counts::Dict{Regex,Int})
    for (key, value) in arithmetic_logical_map
        if occursin(key, line)
            write(stream_out, value(arithmetic_op_counts[key]))
            arithmetic_op_counts[key] += 1
            break
        end
    end
end

function translate_vm(file_in, file_out, )
    stream_in = open(file_in, "r")
    stream_out = open(file_out, "w")
    filename = split(basename(file_in), ".")[1]

    arithmetic_logical_map = Dict{Regex,Int}(
        r"add" => 0, r"sub" => 0, r"neg" => 0,
        r"eq"  => 0, r"gt"  => 0, r"lt"  => 0,
        r"and" => 0, r"or"  => 0, r"not" => 0,
    )

    for file_line in eachline(stream_in)
        line = remove_comments(file_line)
        translate_push_pop(line, stream_out)
        translate_arithmetic_logic(line, stream_out, arithmetic_logical_map)
        translate_static(line, stream_out, filename)
    end

    close(stream_out)
    close(stream_in)
end

vm_files = [joinpath(@__DIR__, "MemoryAccess", "DummyTest", "DummyTest.vm"),
            joinpath(@__DIR__, "MemoryAccess", "BasicTest", "BasicTest.vm"),
            joinpath(@__DIR__, "MemoryAccess", "PointerTest", "PointerTest.vm"),
            joinpath(@__DIR__, "MemoryAccess", "StaticTest", "StaticTest.vm"),
            joinpath(@__DIR__, "StackArithmetic", "SimpleAdd", "SimpleAdd.vm"),
            joinpath(@__DIR__, "StackArithmetic", "StackTest", "StackTest.vm")]
asm_files = [joinpath(@__DIR__, "MemoryAccess", "DummyTest", "DummyTest.asm"),
             joinpath(@__DIR__, "MemoryAccess", "BasicTest", "BasicTest.asm"),
             joinpath(@__DIR__, "MemoryAccess", "PointerTest", "PointerTest.asm"),
             joinpath(@__DIR__, "MemoryAccess", "StaticTest", "StaticTest.asm"),
             joinpath(@__DIR__, "StackArithmetic", "SimpleAdd", "SimpleAdd.asm"),
             joinpath(@__DIR__, "StackArithmetic", "StackTest", "StackTest.asm")]

for (f_in, f_out) in zip(vm_files, asm_files)
    translate_vm(f_in, f_out,)
end

