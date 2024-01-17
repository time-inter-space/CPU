`ifndef ALU
`define ALU
module ALU(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    input  wire              alu_todo,
    input  wire [ 5:0]       inst_type,
    input  wire [31:0]       val1,
    input  wire [31:0]       val2,
    input  wire [31:0]       imm,
    input  wire [31:0]       pc,
    input  wire [ 4:0]       in_rob_pos,

    output reg               alu_done,
    output reg [31:0]        res,
    output reg               jump,
    output reg [31:0]        jump_addr,
    output wire [4:0]        out_rob_pos
);
    localparam LUI = 0, AUIPC = 1, JAL = 2, JALR = 3,
        BEQ = 4, BNE = 5, BLT = 6, BGE = 7, BLTU = 8, BGEU = 9,
        LB = 10, LH = 11, LW = 12, LBU = 13, LHU = 14, SB = 15, SH = 16, SW = 17,
        ADDI = 18, SLTI = 19, SLTIU = 20, XORI = 21, ORI = 22, ANDI = 23, SLLI = 24, SRLI = 25, SRAI = 26,
        ADD = 27, SUB = 28, SLL = 29, SLT = 30, SLTU = 31, XOR = 32, SRL = 33, SRA = 34, OR = 35, AND = 36;
    assign out_rob_pos = in_rob_pos;
    always @(posedge clk_in) begin
        if (rst_in) begin
            alu_done <= 0;
            res <= 0;
            jump <= 0;
            jump_addr <= 0;
        end
        else if (rdy_in) begin
            if (alu_todo) begin
                alu_done <= 1;
                case (inst_type)
                LUI: begin
                    res <= imm;
                    jump <= 0;
                end
                AUIPC: begin
                    res <= imm + pc;
                    jump <= 0;
                end
                JAL: begin
                    res <= pc + 4;
                    jump <= 1;
                    jump_addr <= pc + imm;
                end
                JALR: begin
                    res <= pc + 4;
                    jump <= 1;
                    jump_addr <= val1 + imm;
                end
                BEQ: begin
                    jump <= val1 == val2;
                    jump_addr <= pc + imm;
                end
                BNE: begin
                    jump <= val1 != val2;
                    jump_addr <= pc + imm;
                end
                BLT: begin
                    jump <= $signed(val1) < $signed(val2);
                    jump_addr <= pc + imm;
                end
                BGE: begin
                    jump <= $signed(val1) >= $signed(val2);
                    jump_addr <= pc + imm;
                end
                BLTU: begin
                    jump <= val1 < val2;
                    jump_addr <= pc + imm;
                end
                BGEU: begin
                    jump <= val1 >= val2;
                    jump_addr <= pc + imm;
                end
                ADDI: begin
                    res <= val1 + imm;
                    jump <= 0;
                end
                SLTI: begin
                    res <= $signed(val1) < $signed(imm);
                    jump <= 0;
                end
                SLTIU: begin
                    res <= val1 < imm;
                    jump <= 0;
                end
                XORI: begin
                    res <= val1 ^ imm;
                    jump <= 0;
                end
                ORI: begin
                    res <= val1 | imm;
                    jump <= 0;
                end
                ANDI: begin
                    res <= val1 & imm;
                    jump <= 0;
                end
                SLLI: begin
                    res <= val1 << imm[4:0];
                    jump <= 0;
                end
                SRLI: begin
                    res <= val1 >> imm[4:0];
                    jump <= 0;
                end
                SRAI: begin
                    res <= $signed(val1) >> imm[4:0];
                    jump <= 0;
                end
                ADD: begin
                    res <= val1 + val2;
                    jump <= 0;
                end
                SUB: begin
                    res <= val1 - val2;
                    jump <= 0;
                end
                SLL: begin
                    res <= val1 << val2[4:0];
                    jump <= 0;
                end
                SLT: begin
                    res <= $signed(val1) < $signed(val2);
                    jump <= 0;
                end
                SLTU: begin
                    res <= val1 < val2;
                    jump <= 0;
                end
                XOR: begin
                    res <= val1 ^ val2;
                    jump <= 0;
                end
                SRL: begin
                    res <= val1 >> val2[4:0];
                    jump <= 0;
                end
                SRA: begin
                    res <= $signed(val1) >> val2[4:0];
                    jump <= 0;
                end
                OR: begin
                    res <= val1 | val2;
                    jump <= 0;
                end
                AND: begin
                    res <= val1 & val2;
                    jump <= 0;
                end
                endcase
            end
            else alu_done <= 0;
        end
    end
endmodule
`endif