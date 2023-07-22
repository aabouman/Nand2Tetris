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
# D = A
# @LCL
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

# pop argument i
# @i
# D = A
# @ARG
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

# pop pointer 0
# @SP
# D = M
# @THIS
# M = D
# @SP
# M = M - 1

# pop pointer 1
# @SP
# D = M
# @THAT
# M = D
# @SP
# M = M - 1

# pop static i
# @SP
# D = M
# @Foo.i
# M = D
# @SP
# M = M - 1

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
# D = A
# @LCL
# A = D + A
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push argument i
# @i
# D = A
# @ARG
# A = D + A
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push this i
# @i
# D = A
# @THIS
# A = D + A
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push that i
# @i
# D = A
# @THAT
# A = D + A
# D = M
# @SP
# A = M
# M = D
# @SP
# M = M + 1

# push temp i
# @i
# D = A
# @R5
# A = D + A
# D = M
# @SP
# A = M
# M = D
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

# push pointer 1
# @THAT
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
# A = M
# D = M
# @SP
# M = M - 1
# A = M
# M = D + M

# sub
# @SP
# A = M
# D = M
# @SP
# M = M - 1
# A = M
# M = D - M
# M = -M

# neg
# @SP
# A = M
# M = -M

# eq
# @SP
# A = M
# D = M      // D = RAM[SP]
# @R13
# M = D      // RAM[13] = RAM[SP]
# @SP
# M = M - 1  // SP = SP - 1
# A = M
# D = M      // D = RAM[SP-1]
# @R14
# M = D      // RAM[14] = RAM[SP-1]
# D = M      // D = RAM[SP-1]
# @R15
# M = D      // RAM[15] = RAM[SP-1]
# @R13
# D = M      // D = RAM[13] = RAM[SP]
# @R15
# D = D & M  // D = RAM[SP] && RAM[15] = RAM[SP] && RAM[SP-1]
# @SP
# A = M
# M = D      // RAM[SP] = RAM[SP] && RAM[SP-1]
# @R14
# D = M      // D = RAM[14] = RAM[SP-1]
# @R15
# M = D      // RAM[15] = RAM[SP-1]
# @R13
# D = M      // D = RAM[13] = RAM[SP]
# @R15
# M = D & M  // RAM[15] = RAM[SP] || RAM[15] = RAM[SP] || RAM[SP-1]
# D = !M     // D = !RAM[15] = !(RAM[SP] || RAM[SP-1]) = !RAM[SP] && !RAM[SP-1]
# @SP
# A = M
# M = D||M   // RAM[SP] = (!RAM[SP] && !RAM[SP-1]) || RAM[SP] = (!RAM[SP] && !RAM[SP-1]) || (RAM[SP] && RAM[SP-1])

# gt
# @SP
# A = M
# D = M      // D = RAM[SP]
# @R13
# M = D      // RAM[13] = RAM[SP]
# @SP
# M = M - 1  // SP = SP - 1
# A = M
# D = M      // D = RAM[SP-1]
# @R14
# M = D      // RAM[14] = RAM[SP-1]
# D = M      // D = RAM[SP-1]
# @R13
# D = M      // D = RAM[13] = RAM[SP]
# @SP
# A = M
# M = D - M  // RAM[SP] = D - RAM[SP-1] = RAM[SP] - RAM[SP-1]



# %%
stack_operation_map = Dict{Regex,Function}(
    r"pop local ([-+]?\d+)"    => (_i -> "@$(_i)\nD=A\n@LCL\nD=D+A\n@R14\nM=D\n@SP\nA=M\nD=M\n@R14\nA=M\nM=D\n@SP\nM=M-1\n"),
    r"pop argument ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@ARG\nD=D+A\n@R14\nM=D\n@SP\nA=M\nD=M\n@R14\nA=M\nM=D\n@SP\nM=M-1\n"),
    r"pop this ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THIS\nD=D+A\n@R14\nM=D\n@SP\nA=M\nD=M\n@R14\nA=M\nM=D\n@SP\nM=M-1\n"),
    r"pop that ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THAT\nD=D+A\n@R14\nM=D\n@SP\nA=M\nD=M\n@R14\nA=M\nM=D\n@SP\nM=M-1\n"),
    r"pop temp ([0-7])"        => (_i -> "@$(_i)\nD=A\n@R5\nD=D+A\n@R14\nM=D\n@SP\nA=M\nD=M\n@R14\nA=M\nM=D\n@SP\nM=M-1\n"),
    r"pop pointer 0"           => (_i -> "@SP\nD=M\n@THIS\nM=D\n@SP\nM=M-1\n"),
    r"pop pointer 1"           => (_i -> "@SP\nD=M\n@THAT\nM=D\n@SP\nM=M-1\n"),
    r"pop static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@SP\nD=M\n@Foo.$(_i)\nM=D\n@SP\nM=M-1\n"),

    r"push constant ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push local ([-+]?\d+)"    => (_i -> "@$(_i)\nD=A\n@LCL\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push argument ([-+]?\d+)" => (_i -> "@$(_i)\nD=A\n@ARG\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push this ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THIS\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push that ([-+]?\d+)"     => (_i -> "@$(_i)\nD=A\n@THAT\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push temp ([0-7])"        => (_i -> "@$(_i)\nD=A\n@R5\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push pointer 0"           => (_i -> "@THIS\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push pointer 1"           => (_i -> "@THAT\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
    r"push static \b(0|[1-9]\d?|1\d\d|2[0-3]\d)\b" => (_i -> "@Foo.$(_i)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"),
)

arithmetic_operation_map = Dict{Regex,Function}()

# %%
in_buf = IOBuffer("push constant 10
pop local 0
push constant 21
push constant 22
pop argument 2
pop argument 1
push constant 36
")
out_buf = IOBuffer()



for line in eachline(in_buf)
    for (key, value) in stack_operation_map
        if occursin(key, line)
            write(out_buf, value(match(key, line).captures[1]))
            continue
        end
    end
end

print(String(out_buf.data))

# %%
function translate_pop(stream_in::IO, stream_out::IO,)
    for (key, value) in stack_operation_map
        if occursin(key, line)
            write(stream_out, value(match(key, line).captures[1]))
        end
    end
end

# %%
const segment_map1 = Dict{Regex,String}(
        r"constant ([-+]?\d+)" => "@([-+]?\d+)",
        r"temp ([0-7])" => "@R5\n",


        r"local ([-+]?\d+)" => "@LCL\n"

        SA[r"local ([-+]?\d+)", r"argument ([-+]?\d+)", r"this ([-+]?\d+)", r"that ([-+]?\d+)"],
        SA[             "@LCL\n",                 "@ARG",            "@THIS",            "@THAT"]
    )
const segment_map2 = Dict{Regex,String}(
        SA[r"pointer 0", r"pointer 1"],
        SA[     "@THIS",      "@THAT"]
    )
const segment_map3 = StaticDictionary{5,Regex,String}(SA[r"temp ([0-7])"], SA["@R5"])
const segment_map4 = StaticDictionary{5,Regex,String}(SA[r"constant ([-+]?\d+)"], SA["@([-+]?\d+)"])

function translate_push(out_stream::IO, in_stream::IO)



    if segment == constant::MemorySegment
        write(stream, "D=$(index)\n")
    elseif any(_x->segment ==_x,  SA[lcl::MemorySegment, argument::MemorySegment, this::MemorySegment])
        write(stream, "D=$(Int16(segment)+index)\n")
    end

    match
    if "constant"
        "@$(7)"
    end


    wrtie(stream, "@SP\n")
    wrtie(stream, "A=M\n")
    wrtie(stream, "M=D\n")
    wrtie(stream, "@SP\n")
    wrtie(stream, "M=M+1\n")
end

# %%
function translate_pop(stream::IO, segment::MemorySegment, index::Int16)
    #
    write(stream, "@SP\n")
    write(stream, "D=M\n")

    #
    write(stream, "@$(Int16(segment)+index)\n")
    write(stream, "@SP\n")
    write(stream, "M=M-1\n")

    wrtie(stream, "@SP\nA=M\nM=D\n@SP\nM=M+1\n")
end


# %%
using StaticTools
using StaticArrays
using BenchmarkTools

iobuf = IOBuffer()

@btime begin
    # a = 3
    # b = 4
    # a + b
    # SA["Heello","Heello","Heello"]
    # "what $(3)"
    # String(3)
    # Base.ImmutableDict("Hello" => Int16(1), "Goodbye" => Int16(2))
    # write($iobuf, Int16(3))
    # write($iobuf, "3")
    occursin(r"Alex (.*)", "Hello this is Alex speaking")
    # write($iobuf, " ", string(3,base=10,pad=1))
end

