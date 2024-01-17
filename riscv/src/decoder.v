`ifndef DECODER
`define DECODER
module Decoder(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    input  wire              ifetch_todo,
    input  wire [31:0]       ifetch_inst,
    input  wire [31:0]       ifetch_pc,

    output reg               done,
    output reg  [ 5:0]       inst_type,
    output wire [ 4:0]       rs1,
    output wire [ 4:0]       rs2,
    output wire [ 4:0]       rd,
    output reg  [31:0]       imm,
    output wire [31:0]       pc
);
    localparam LUI = 0, AUIPC = 1, JAL = 2, JALR = 3,
        BEQ = 4, BNE = 5, BLT = 6, BGE = 7, BLTU = 8, BGEU = 9,
        LB = 10, LH = 11, LW = 12, LBU = 13, LHU = 14, SB = 15, SH = 16, SW = 17,
        ADDI = 18, SLTI = 19, SLTIU = 20, XORI = 21, ORI = 22, ANDI = 23, SLLI = 24, SRLI = 25, SRAI = 26,
        ADD = 27, SUB = 28, SLL = 29, SLT = 30, SLTU = 31, XOR = 32, SRL = 33, SRA = 34, OR = 35, AND = 36;
    wire opcode = ifetch_inst[ 6: 0];
    wire funct3 = ifetch_inst[14:12];
    wire funct7 = ifetch_inst[31:25];
    assign rs1  = ifetch_inst[19:15];
    assign rs2  = ifetch_inst[24:20];
    assign rd   = ifetch_inst[11: 7];
    assign pc   = ifetch_pc;
    always @(posedge clk_in) begin
        if (rst_in) begin
            done <= 0;
            inst_type <= 0;
            imm <= 0;
        end
        else if (rdy_in && ifetch_todo) begin
            done <= 1;
            case (opcode)
            7'b0110111: begin // lui
                imm <= {ifetch_inst[31:12], 12'b0};
                inst_type <= LUI;
            end
            7'b0010111: begin // auipc
                imm <= {ifetch_inst[31:12], 12'b0};
                inst_type <= AUIPC;
            end
            7'b1101111: begin // jal
                imm <= {11'b0, ifetch_inst[31], ifetch_inst[19:12],
                        ifetch_inst[20], ifetch_inst[30:21], 1'b0};
                inst_type <= JAL;
            end
            7'b1100111: begin // jalr
                imm <= {20'b0, ifetch_inst[31:20]};
                inst_type <= JALR;
            end
            7'b1100011: begin // beq ~ bgeu
                imm <= {19'b0, ifetch_inst[31], ifetch_inst[7],
                        ifetch_inst[30:25], ifetch_inst[11:8], 1'b0};
                case (funct3)
                3'b000: inst_type <= BEQ;
                3'b001: inst_type <= BNE;
                3'b100: inst_type <= BLT;
                3'b101: inst_type <= BGE;
                3'b110: inst_type <= BLTU;
                3'b111: inst_type <= BGEU;
                endcase
            end
            7'b0000011: begin // lb ~ lhu
                imm <= {20'b0, ifetch_inst[31:20]};
                case (funct3)
                3'b000: inst_type <= LB;
                3'b001: inst_type <= LH;
                3'b010: inst_type <= LW;
                3'b100: inst_type <= LBU;
                3'b101: inst_type <= LHU;
                endcase
            end
            7'b0100011: begin // sb ~ sw
                imm <= {20'b0, ifetch_inst[31:25], ifetch_inst[11:7]};
                case(funct3)
                3'b000: inst_type <= SB;
                3'b001: inst_type <= SH;
                3'b010: inst_type <= SW;
                endcase
            end
            7'b0010011: begin // addi ~ srai
                imm <= {20'b0, ifetch_inst[31:25]};
                case (funct3)
                3'b000: inst_type <= ADDI;
                3'b010: inst_type <= SLTI;
                3'b011: inst_type <= SLTIU;
                3'b100: inst_type <= XORI;
                3'b110: inst_type <= ORI;
                3'b111: inst_type <= ANDI;
                3'b001: inst_type <= SLLI;
                3'b101: begin
                    if (funct7 == 0) inst_type <= SRLI;
                    else inst_type <= SRAI;
                end
                endcase
            end
            7'b0110011: begin // add ~ and
                imm <= 0;
                case (funct3)
                3'b000: begin
                    if (funct7 == 0) inst_type <= ADD;
                    else inst_type <= SUB;
                end
                3'b001: inst_type <= SLL;
                3'b010: inst_type <= SLT;
                3'b011: inst_type <= SLTU;
                3'b100: inst_type <= XOR;
                3'b101: begin
                    if (funct7 == 0) inst_type <= SRL;
                    else inst_type <= SRA;
                end
                3'b110: inst_type <= OR;
                3'b111: inst_type <= AND;
                endcase
            end
            endcase
        end
    end
endmodule
`endif