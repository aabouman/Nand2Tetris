Base.convert(::Type{BitVector}, int::Int16) = BitVector([bit == '1' for bit in bitstring(int)])

function AssembleHack(in_assembly_filename::String, out_machine_code_filename::String)
    input = open(in_assembly_filename, "r")
    out = open(out_machine_code_filename, "w")

    seek(input, 0)
    symbol_table = ConstructHackSymbolTable(input)

    seek(input, 0)
    lines = strip.(eachline(input))
    filter!(_x-> !(length(_x) >= 2 && _x[1:2] == "//"), lines)
    filter!(_x-> !(length(_x) >= 2 && _x[1] == '('), lines)
    filter!(!isempty, lines)

    for line in lines
        if is_a_instruction(line)
            bit_array = AssembleAInstruction(line, symbol_table)
            write.(Ref(out), map(_x->_x ? "1" : "0", bit_array))
        else
            bit_array = AssembleCInstruction(line)
            write.(Ref(out), map(_x->_x ? "1" : "0", bit_array))
        end
        write(out, "\n")
    end

    close(input)
    close(out)
end

function ConstructHackSymbolTable(assembly::IO)
    symbol_table = Dict{String,BitVector}("R$i" => Int16(i) for i in 0:15)
    merge!(symbol_table, Dict{String,BitVector}(
        "SP"     => Int16(0),
        "LCL"    => Int16(1),
        "ARG"    => Int16(2),
        "THIS"   => Int16(3),
        "THAT"   => Int16(4),
        "SCREEN" => Int16(16384),
        "KBD"    => Int16(24576),
    ))

    # Filter comments and empty lines.
    lines = strip.(eachline(assembly))
    filter!(_x-> !(length(_x) >= 2 && _x[1:2] == "//"), lines)
    filter!(!isempty, lines)
    # Find all lines containing labels.
    label_addresses = findall(_x->_x[1]=='(', lines)
    labels = map(_i->match(r"\((.*?)\)", lines[_i]).captures[1], label_addresses)
    @assert length(unique(labels)) == length(labels)
    # Find all lines containing labels.
    variable_addresses = findall(_x->_x[1]=='@' && tryparse(Int16, _x[2:end]) === nothing, lines)
    filter!(_i->!haskey(symbol_table, lines[_i][2:end]), variable_addresses)
    variables = map(_i->lines[_i][2:end], variable_addresses)
    filter!(_i->!(_i in labels), variables) # Ensure labels are not added to variable list.
    unique!(variables)

    merge!(symbol_table, Dict{String,Int16}(labels .=> label_addresses))
    merge!(symbol_table, Dict{String,Int16}(variables[i] => 15+i for i in eachindex(variables)))

    return symbol_table
end

is_a_instruction(line)::Bool = occursin("@", line)

function AssembleAInstruction(line, symbol_table::Dict{String,BitVector})
    regex_match = match(r"@(.*)", line).captures[1]

    a_symbol = tryparse(Int16, regex_match)
    if (a_symbol === nothing)
        a_symbol = symbol_table[regex_match]
    end

    return convert(BitVector, a_symbol)
end

function AssembleCInstruction(line)
    function get_jump_code(line)
        jump_label_map = Dict{String,BitVector}(
            ""    => [0,0,0],
            "JGT" => [0,0,1],
            "JEQ" => [0,1,0],
            "JGE" => [0,1,1],
            "JLT" => [1,0,0],
            "JNE" => [1,0,1],
            "JLE" => [1,1,0],
            "JMP" => [1,1,1],
        )
        regex_match = match(r";(.*)", line)
        return jump_label_map[regex_match === nothing ? "" : regex_match.captures[1]]
    end

    function get_dest_code(line)
        dest_label_map = Dict{String,BitVector}(
            ""    => [0,0,0],
            "M"   => [0,0,1],
            "D"   => [0,1,0],
            "DM"  => [0,1,1],
            "MD"  => [0,1,1],
            "A"   => [1,0,0],
            "AM"  => [1,0,1],
            "MA"  => [1,0,1],
            "AD"  => [1,1,0],
            "DA"  => [1,1,0],
            "ADM" => [1,1,1],
            "DAM" => [1,1,1],
            "DMA" => [1,1,1],
            "MDA" => [1,1,1],
            "MAD" => [1,1,1],
            "AMD" => [1,1,1],
        )
        regex_match = match(r"(.*)=", line)
        return dest_label_map[regex_match === nothing ? "" : regex_match.captures[1]]

    end

    function get_comp_code(line)
        regex_str = r"(.*)"
        if occursin("=", line) && occursin(";", line)
            regex_str = r"=(.*);"
        elseif occursin("=", line)
            regex_str = r"=(.*)"
        elseif occursin(";", line)
            regex_str = r"(.*);"
        end

        comp_label = match(regex_str, line).captures[1]
        acode_label = occursin("A", comp_label) ? "A" : "M"
        dest_label_map = Dict{String,BitVector}(
            "0"              => [1,0,1,0,1,0],
            "1"              => [1,1,1,1,1,1],
            "-1"             => [1,1,1,0,1,0],
            "D"              => [0,0,1,1,0,0],
            "$acode_label"   => [1,1,0,0,0,0],
            "!D"             => [0,0,1,1,0,1],
            "!$acode_label"  => [1,1,0,0,0,1],
            "-D"             => [0,0,1,1,1,1],
            "-A"             => [1,1,0,0,1,1],
            "D+1"            => [0,1,1,1,1,0],
            "$acode_label+1" => [1,1,0,0,1,0],
            "D-1"            => [0,0,1,1,1,0],
            "$acode_label-1" => [1,1,0,0,1,0],
            "D+$acode_label" => [0,0,0,0,1,0],
            "D-$acode_label" => [0,1,0,0,1,1],
            "$acode_label-D" => [0,0,0,1,1,1],
            "D&$acode_label" => [0,0,0,0,0,0],
            "D|$acode_label" => [0,1,0,1,0,1],
        )
        acode = acode_label == "A" ? 1 : 0
        return [acode; dest_label_map[comp_label]]
    end

    return BitVector([[1,1,1]; get_comp_code(line); get_dest_code(line); get_jump_code(line)])
end

# %%
input_filename = (joinpath(@__DIR__, "rect", "Rect.asm"))
out_filename = (joinpath(@__DIR__, "rect", "Rect.hack"))
AssembleHack(input_filename, out_filename)
input_filename = (joinpath(@__DIR__, "rect", "RectL.asm"))
out_filename = (joinpath(@__DIR__, "rect", "RectL.hack"))
AssembleHack(input_filename, out_filename)

input_filename = (joinpath(@__DIR__, "pong", "Pong.asm"))
out_filename = (joinpath(@__DIR__, "pong", "Pong.hack"))
AssembleHack(input_filename, out_filename)
input_filename = (joinpath(@__DIR__, "pong", "PongL.asm"))
out_filename = (joinpath(@__DIR__, "pong", "PongL.hack"))
AssembleHack(input_filename, out_filename)

input_filename = (joinpath(@__DIR__, "max", "Max.asm"))
out_filename = (joinpath(@__DIR__, "max", "Max.hack"))
AssembleHack(input_filename, out_filename)
input_filename = (joinpath(@__DIR__, "max", "MaxL.asm"))
out_filename = (joinpath(@__DIR__, "max", "MaxL.hack"))
AssembleHack(input_filename, out_filename)

input_filename = (joinpath(@__DIR__, "add", "Add.asm"))
out_filename = (joinpath(@__DIR__, "add", "Add.hack"))
AssembleHack(input_filename, out_filename)
