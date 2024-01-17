`ifndef RS
`define RS
module RS(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    output wire              rs_full,

    input  wire              rs_todo,
    input  wire [ 5:0]       rs_inst_type,
    input  wire [ 4:0]       rs_rs1_rob_pos,
    input  wire [ 4:0]       rs_rs2_rob_pos,
    input  wire [31:0]       rs_val1,
    input  wire [31:0]       rs_val2,
    input  wire [31:0]       rs_imm,
    input  wire [ 4:0]       rs_rd_rob_pos,
    input  wire [31:0]       rs_pc,

    output reg               alu_todo,
    output reg [ 5:0]        alu_inst_type,
    output reg [31:0]        alu_val1,
    output reg [31:0]        alu_val2,
    output reg [31:0]        alu_imm,
    output reg [31:0]        alu_pc,
    output reg [ 4:0]        alu_in_rob_pos,

    input  wire              alu_done,
    input  wire [31:0]       alu_res,
    input  wire [ 4:0]       alu_out_rob_pos,

    input  wire              lsb_done,
    input  wire [31:0]       lsb_res,
    input  wire [ 4:0]       lsb_rob_pos
);
    localparam LUI = 0, AUIPC = 1, JAL = 2, JALR = 3,
        BEQ = 4, BNE = 5, BLT = 6, BGE = 7, BLTU = 8, BGEU = 9,
        LB = 10, LH = 11, LW = 12, LBU = 13, LHU = 14, SB = 15, SH = 16, SW = 17,
        ADDI = 18, SLTI = 19, SLTIU = 20, XORI = 21, ORI = 22, ANDI = 23, SLLI = 24, SRLI = 25, SRAI = 26,
        ADD = 27, SUB = 28, SLL = 29, SLT = 30, SLTU = 31, XOR = 32, SRL = 33, SRA = 34, OR = 35, AND = 36;
    reg busy[15:0];
    reg [5:0] inst_type[15:0];
    reg [4:0] rs1_rob_pos[15:0];
    reg [4:0] rs2_rob_pos[15:0];
    reg [31:0] val1[15:0];
    reg [31:0] val2[15:0];
    reg [31:0] imm[15:0];
    reg [31:0] pc[15:0];
    reg [4:0] rd[15:0];
    reg [4:0] rd_rob_pos[15:0];

    integer busy_cnt;
    assign rob_full = busy_cnt == 15;

    reg [3:0] ready_pos, idle_pos;
    integer i;
    always @(*) begin
        ready_pos = 0;
        for (i = 1; i < 16; i = i + 1) begin
            if (busy[i] && rs1_rob_pos[i] == 5'b11111
                && rs2_rob_pos[i] == 5'b11111) begin
                    ready_pos = i;
                end
            if (!busy[i]) idle_pos = i;
        end
    end
    always @(posedge clk_in) begin
        if (rst_in) begin
            busy_cnt <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                busy[i] <= 0;
                inst_type[i] <= 0;
                rs1_rob_pos[i] <= 0;
                rs2_rob_pos[i] <= 0;
                val1[i] <= 0;
                val2[i] <= 0;
                imm[i] <= 0;
                pc[i] <= 0;
                rd[i] <= 0;
                rd_rob_pos[i] <= 0;
            end
        end
        else if (rdy_in) begin
            if (rs_todo && !(LB <= rs_inst_type && rs_inst_type <= SW)) begin
                inst_type[idle_pos] <= rs_inst_type;
                rs1_rob_pos[idle_pos] <= rs_rs1_rob_pos;
                rs2_rob_pos[idle_pos] <= rs_rs2_rob_pos;
                val1[idle_pos] <= rs_val1;
                val2[idle_pos] <= rs_val2;
                imm[idle_pos] <= rs_imm;
                rd_rob_pos[idle_pos] <= rs_rd_rob_pos;
                pc[idle_pos] <= rs_pc;
                busy[idle_pos] <= 1;
                busy_cnt <= busy_cnt + 1;
            end
            if (ready_pos != 0) begin
                alu_todo <= 1;
                alu_inst_type <= inst_type[ready_pos];
                alu_val1 <= val1[ready_pos];
                alu_val2 <= val2[ready_pos];
                alu_imm <= imm[ready_pos];
                alu_pc <= pc[ready_pos];
                alu_in_rob_pos <= rd_rob_pos[ready_pos];
                busy[ready_pos] <= 0;
                busy_cnt <= busy_cnt - 1;
            end
            if (alu_done) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (rs1_rob_pos[i] == alu_out_rob_pos) begin
                        rs1_rob_pos[i] <= 5'b11111;
                        val1[i] <= alu_res;
                    end
                    if (rs2_rob_pos[i] == alu_out_rob_pos) begin
                        rs2_rob_pos[i] <= 5'b11111;
                        val2[i] <= alu_res;
                    end
                end
            end
            if (lsb_done) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (rs1_rob_pos[i] == alu_out_rob_pos) begin
                        rs1_rob_pos[i] <= 5'b11111;
                        val1[i] <= alu_res;
                    end
                    if (rs2_rob_pos[i] == alu_out_rob_pos) begin
                        rs2_rob_pos[i] <= 5'b11111;
                        val2[i] <= alu_res;
                    end
                end
            end
        end
    end
endmodule
`endif