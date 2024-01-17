`ifndef LSB
`define LSB
module LSB(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    output wire              lsb_full,

    output reg               memctrl_todo,
    output reg [31:0]        memctrl_addr,
    output reg [ 2:0]        memctrl_len,
    output reg               memctrl_store,
    output reg [31:0]        memctrl_store_data,
    input  wire [31:0]       memctrl_load_res,
    input  wire              memctrl_done,

    output reg               load_done,
    output reg [31:0]        load_res,
    output reg [ 4:0]        load_rob_pos,

    input  wire              alu_done,
    input  wire [31:0]       alu_res,
    input  wire              alu_jump,
    input  wire [31:0]       alu_jump_addr,
    input  wire [ 4:0]       alu_rob_pos,

    input  wire              store_todo,

    input  wire              lsb_todo,
    input  wire [ 5:0]       lsb_inst_type,
    input  wire [ 4:0]       lsb_rs1_rob_pos,
    input  wire [ 4:0]       lsb_rs2_rob_pos,
    input  wire [31:0]       lsb_val1,
    input  wire [31:0]       lsb_val2,
    input  wire [31:0]       lsb_imm,
    input  wire [ 4:0]       lsb_rd_rob_pos
);
    localparam LUI = 0, AUIPC = 1, JAL = 2, JALR = 3,
        BEQ = 4, BNE = 5, BLT = 6, BGE = 7, BLTU = 8, BGEU = 9,
        LB = 10, LH = 11, LW = 12, LBU = 13, LHU = 14, SB = 15, SH = 16, SW = 17,
        ADDI = 18, SLTI = 19, SLTIU = 20, XORI = 21, ORI = 22, ANDI = 23, SLLI = 24, SRLI = 25, SRAI = 26,
        ADD = 27, SUB = 28, SLL = 29, SLT = 30, SLTU = 31, XOR = 32, SRL = 33, SRA = 34, OR = 35, AND = 36;
    localparam IDLE = 0, PENDING = 1;
    reg status;
    reg [3:0] head, tail;
    reg busy[15:0];
    reg todo[15:0];
    reg [5:0] inst_type[15:0];
    reg [4:0] rs1_rob_pos[15:0];
    reg [4:0] rs2_rob_pos[15:0];
    reg [31:0] val1[15:0];
    reg [31:0] val2[15:0];
    reg [31:0] imm[15:0];
    reg [31:0] pc[15:0];
    reg [4:0] rd[15:0];
    reg [4:0] rd_rob_pos[15:0];

    wire empty = head == tail;
    assign lsb_full = tail + 1 == head;
    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            status <= IDLE;
            head <= 0;
            tail <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                busy[i] <= 0;
                todo[i] <= 0;
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
            if (status == PENDING) begin
                if (memctrl_done) begin
                    busy[head] <= 0;
                    todo[head] <= 0;
                    if (LB <= inst_type[head] && inst_type[head] <= LHU) begin
                        load_done <= 1;
                        if (inst_type[head] == LB)
                            load_res <= {{24{memctrl_load_res[7]}}, memctrl_load_res[7:0]};
                        else if (inst_type[head] == LBU)
                            load_res <= {24'b0, memctrl_load_res[7:0]};
                        else if (inst_type[head] == LH)
                            load_res <= {{16{memctrl_load_res[15]}}, memctrl_load_res[15:0]};
                        else if (inst_type[head] == LHU)
                            load_res <= {{16'b0, memctrl_load_res[15:0]}};
                        else load_res <= memctrl_load_res;
                        load_rob_pos <= rd_rob_pos[head];
                    end
                    memctrl_todo <= 0;
                    head <= head + 1;
                    status <= IDLE;
                end
            end
            else begin
                if (!empty && (LB <= inst_type[head] && inst_type[head] <= LW || todo[head])) begin
                    memctrl_todo <= 1;
                    memctrl_addr <= val1[head] + imm[head];
                    if (SB <= inst_type[head] && inst_type[head] <= SW) begin
                        memctrl_store_data <= val2[head];
                        if (inst_type[head] == SB) memctrl_len <= 1;
                        else if (inst_type[head] == SH) memctrl_len <= 2;
                        else memctrl_len <= 4;
                        memctrl_store <= 1;
                    end
                    else begin
                        if (inst_type[head] == LB || inst_type[head] == LBU) memctrl_len <= 1;
                        else if (inst_type[head] == LH || inst_type[head] == LHU) memctrl_len <= 2;
                        else memctrl_len <= 4;
                        memctrl_store <= 0;
                    end
                    status <= PENDING;
                end
            end
            if (alu_done) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (busy[i] && rs1_rob_pos[i] == alu_rob_pos) begin
                        rs1_rob_pos[i] <= 5'b11111;
                        val1[i] <= alu_res;
                    end
                    if (busy[i] && rs2_rob_pos[i] == alu_rob_pos) begin
                        rs2_rob_pos[i] <= 5'b11111;
                        val2[i] <= alu_res;
                    end
                end
            end
            if (store_todo) begin
                todo[head] <= 1;
            end
            if (lsb_todo) begin
                busy[tail] <= 1;
                inst_type[tail] <= lsb_inst_type;
                rs1_rob_pos[tail] <= lsb_rs1_rob_pos;
                rs2_rob_pos[tail] <= lsb_rs2_rob_pos;
                val1[tail] <= lsb_val1;
                val2[tail] <= lsb_val2;
                imm[tail] <= lsb_imm;
                rd_rob_pos[tail] <= lsb_rd_rob_pos;
                tail <= tail + 1;
            end
        end
    end
endmodule
`endif