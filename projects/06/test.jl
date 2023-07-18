Base.convert(::Type{BitVector}, int::Int16) = BitVector([bit == '1' for bit in bitstring(int)])
is_a_instruction(line)::Bool = occursin("@", line)


function AssembleHack(in_assembly::IO, out_machine_code::IO)
    seek(in_assembly, 0)

    symbol_table = ConstructHackSymbolTable(in_assembly)
    seek(in_assembly, 0)

    for line in eachline(in_assembly)
        if is_a_instruction(line)
            bit_array = AssembleAInstruction(line, symbol_table)
            write(out_machine_code, bitstring(bit_array))
        else
            bit_array = AssembleCInstruction(line)
            write(out_machine_code, bitstring(bit_array))
        end
        write(out_machine_code, "\n")
    end
end

# %%
tmp = IOBuffer()
io = open(joinpath(@__DIR__, "rect", "Rect.asm"))
AssembleHack(io, tmp)
close(io)

# %%
AssembleHack(IO, out_machine_code::IOStream)

# %%
AssembleCInstruction("MD=M-1")
AssembleCInstruction("0;JMP")
AssembleCInstruction("D=A+1;JLE")
