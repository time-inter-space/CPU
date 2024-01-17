`ifndef ROB
`define ROB
module RoB(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    output wire              rob_full,

    input  wire              decoder_done,
    input  wire [ 5:0]       decoder_inst_type,
    input  wire [ 4:0]       decoder_rs1,
    input  wire [ 4:0]       decoder_rs2,
    input  wire [ 4:0]       decoder_rd,
    input  wire [31:0]       decoder_imm,
    input  wire [31:0]       decoder_pc,

    input  wire              alu_done,
    input  wire [31:0]       alu_res,
    input  wire              alu_jump,
    input  wire [31:0]       alu_jump_addr,
    input  wire [ 4:0]       alu_rob_pos,

    input  wire              load_done,
    input  wire [31:0]       load_res,
    input  wire [ 4:0]       load_rob_pos,

    output reg               reg_commit,
    output reg  [ 4:0]       reg_commit_rd,
    output reg  [31:0]       reg_commit_val,
    output reg  [ 4:0]       reg_commit_rename,

    output reg  [ 4:0]       reg_rs1,
    input  wire [31:0]       reg_val1,
    input  wire [ 4:0]       reg_rename1,
    output reg  [ 4:0]       reg_rs2,
    input  wire [31:0]       reg_val2,
    input  wire [ 4:0]       reg_rename2,

    output reg               store_todo,

    output reg               rs_todo,
    output reg [ 5:0]        rs_inst_type,
    output reg [ 4:0]        rs_rs1_rob_pos,
    output reg [ 4:0]        rs_rs2_rob_pos,
    output reg [31:0]        rs_val1,
    output reg [31:0]        rs_val2,
    output reg [31:0]        rs_imm,
    output reg [ 4:0]        rs_rd_rob_pos,
    output reg [31:0]        rs_pc
);
    localparam LUI = 0, AUIPC = 1, JAL = 2, JALR = 3,
        BEQ = 4, BNE = 5, BLT = 6, BGE = 7, BLTU = 8, BGEU = 9,
        LB = 10, LH = 11, LW = 12, LBU = 13, LHU = 14, SB = 15, SH = 16, SW = 17,
        ADDI = 18, SLTI = 19, SLTIU = 20, XORI = 21, ORI = 22, ANDI = 23, SLLI = 24, SRLI = 25, SRAI = 26,
        ADD = 27, SUB = 28, SLL = 29, SLT = 30, SLTU = 31, XOR = 32, SRL = 33, SRA = 34, OR = 35, AND = 36;
    reg [3:0] head, tail;
    reg busy[15:0];
    reg ready[15:0];
    reg [5:0] inst_type[15:0];
    reg [4:0] rs1[15:0];
    reg [4:0] rs2[15:0];
    reg [4:0] rd[15:0];
    reg [31:0] imm[15:0];
    reg [31:0] pc[15:0];
    reg [31:0] val[15:0];
    reg jump[15:0];
    reg pred[15:0];
    reg [31:0] jump_addr[15:0];
    
    wire empty = head == tail;
    assign rob_full = head == tail + 1;

    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            head <= 0;
            tail <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                busy[i] <= 0;
                ready[i] <= 0;
                inst_type[i] <= 0;
                rs1[i] <= 0;
                rs2[i] <= 0;
                rd[i] <= 0;
                imm[i] <= 0;
            end
        end
        else if (rdy_in) begin
            if (decoder_done) begin
                busy[tail] <= 1;
                ready[tail] <= 0;
                inst_type[tail] <= decoder_inst_type;
                rs1[tail] <= decoder_rs1;
                rs2[tail] <= decoder_rs2;
                rd[tail] <= decoder_rd;
                
                rs_todo <= 1;
                rs_inst_type <= decoder_inst_type;
                reg_rs1 <= decoder_rs1;
                rs_rs1_rob_pos <= reg_rename1;
                rs_val1 <= reg_val1;
                reg_rs2 <= decoder_rs2;
                rs_rs2_rob_pos <= reg_rename2;
                rs_val2 <= reg_val2;
                rs_imm <= decoder_imm;
                rs_rd_rob_pos <= tail;
                rs_pc <= decoder_pc;

                tail <= tail + 1;
            end
            if (alu_done) begin
                val[alu_rob_pos] <= alu_res;
                jump[alu_rob_pos] <= alu_jump;
                jump_addr[alu_rob_pos] <= alu_jump_addr;
                ready[alu_rob_pos] <= 1;
            end
            if (load_done) begin
                val[load_rob_pos] <= load_res;
                jump[load_rob_pos] <= 0;
                ready[load_rob_pos] <= 1;
            end
            if (!empty && ready[head]) begin
                if (SB <= inst_type[head] && inst_type[head] <= SW) begin
                    store_todo <= 1;
                end
                else if (!(BEQ <= inst_type[head] && inst_type[head] <= BGEU)) begin
                    reg_commit <= 1;
                    reg_commit_rd <= rd[head];
                    reg_commit_val <= val[head];
                    reg_commit_rename <= {1'b0, head};
                end
                if (BEQ <= inst_type[head] && inst_type[head] <= BGEU) begin

                end
                busy[head] <= 0;
                ready[head] <= 0;
                head <= head + 1;
            end
        end
    end
endmodule
`endif