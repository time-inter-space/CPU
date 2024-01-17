// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "alu.v"
`include "decoder.v"
`include "ifetch.v"
`include "lsb.v"
`include "memctrl.v"
`include "regfile.v"
`include "rob.v"
`include "rs.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)
  wire                       ifetch_memctrl_todo;
  wire [ 31:0]               ifetch_memctrl_addr;
  wire [511:0]               memctrl_ifetch_res;
  wire                       memctrl_ifetch_done;

  wire                       lsb_memctrl_todo;
  wire [31:0]                lsb_memctrl_addr;
  wire [ 2:0]                lsb_memctrl_len;
  wire                       lsb_memctrl_store;
  wire [31:0]                store_memctrl_data;
  wire [31:0]                memctrl_load_res;
  wire                       memctrl_lsb_done;

  wire rob_full, rs_full, lsb_full, memctrl_busy;

  MemCtrl MemCtrl0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .mem_din(mem_din),
    .mem_dout(mem_dout),
    .mem_a(mem_a),
    .mem_wr(mem_wr),

    .io_buffer_full(io_buffer_full),

    .memctrl_busy(memctrl_busy),

    .ifetch_todo(ifetch_memctrl_todo),
    .ifetch_addr(ifetch_memctrl_addr),
    .ifetch_res(memctrl_ifetch_res),
    .ifetch_done(memctrl_ifetch_done),

    .lsb_todo(lsb_memctrl_todo),
    .lsb_addr(lsb_memctrl_addr),
    .lsb_len(lsb_memctrl_len),
    .lsb_store(lsb_memctrl_store),
    .store_data(store_memctrl_data),
    .load_res(memctrl_load_res),
    .lsb_done(memctrl_lsb_done)
  );

  wire ifetch_decoder_todo;
  wire [31:0] ifetch_decoder_inst;
  wire [31:0] ifetch_decoder_pc;

  IFetch IFetch0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .memctrl_res(memctrl_ifetch_res),
    .memctrl_done(memctrl_ifetch_done),
    .memctrl_todo(ifetch_memctrl_todo),
    .memctrl_addr(ifetch_memctrl_addr),

    .decoder_todo(ifetch_decoder_todo),
    .decoder_inst(ifetch_decoder_inst),
    .decoder_pc(ifetch_decoder_pc),

    .rob_full(rob_full),

    .rs_full(rs_full),
    
    .lsb_full(lsb_full)
  );

  wire decoder_done;
  wire [5:0] decoder_inst_type;
  wire [4:0] decoder_rs1;
  wire [4:0] decoder_rs2;
  wire [4:0] decoder_rd;
  wire [31:0] decoder_imm;
  wire [31:0] decoder_pc;

  Decoder Decoder0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .ifetch_todo(ifetch_decoder_todo),
    .ifetch_inst(ifetch_decoder_inst),
    .ifetch_pc(ifetch_decoder_pc),

    .done(decoder_done),
    .inst_type(decoder_inst_type),
    .rs1(decoder_rs1),
    .rs2(decoder_rs2),
    .rd(decoder_rd),
    .imm(decoder_imm),
    .pc(decoder_pc)
  );

  wire alu_todo;
  wire [5:0] alu_inst_type;
  wire [31:0] alu_val1;
  wire [31:0] alu_val2;
  wire [31:0] alu_imm;
  wire [31:0] alu_pc;
  wire [4:0] alu_in_rob_pos;
  wire alu_done;
  wire [31:0] alu_res;
  wire alu_jump;
  wire [31:0] alu_jump_addr;
  wire [4:0] alu_out_rob_pos;

  ALU ALU0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .alu_todo(alu_todo),
    .inst_type(alu_inst_type),
    .val1(alu_val1),
    .val2(alu_val2),
    .imm(alu_imm),
    .pc(alu_pc),
    .in_rob_pos(alu_in_rob_pos),

    .alu_done(alu_done),
    .res(alu_res),
    .jump(alu_jump),
    .jump_addr(alu_jump_addr),
    .out_rob_pos(alu_out_rob_pos)
  );

  wire rob_load_done;
  wire [31:0] rob_load_res;
  wire [4:0] rob_load_rob_pos;

  wire reg_commit;
  wire [4:0] reg_commit_rd;
  wire [31:0] reg_commit_val;
  wire [4:0] reg_commit_rename;

  wire [4:0] reg_rs1;
  wire [31:0] reg_val1;
  wire [4:0] reg_rename1;
  wire [4:0] reg_rs2;
  wire [31:0] reg_val2;
  wire [4:0] reg_rename2;

  wire rob_store_todo;

  wire rob_rs_todo;
  wire [5:0] rob_rs_inst_type;
  wire [4:0] rob_rs_rs1_rob_pos;
  wire [4:0] rob_rs_rs2_rob_pos;
  wire [31:0] rob_rs_val1;
  wire [31:0] rob_rs_val2;
  wire [31:0] rob_rs_imm;
  wire [4:0] rob_rs_rd_rob_pos;
  wire [31:0] rob_rs_pc;

  RoB RoB0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .rob_full(rob_full),

    .decoder_done(decoder_done),
    .decoder_inst_type(decoder_inst_type),
    .decoder_rs1(decoder_rs1),
    .decoder_rs2(decoder_rs2),
    .decoder_rd(decoder_rd),
    .decoder_imm(decoder_imm),
    .decoder_pc(decoder_pc),

    .alu_done(alu_done),
    .alu_res(alu_res),
    .alu_jump(alu_jump),
    .alu_jump_addr(alu_jump_addr),
    .alu_rob_pos(alu_out_rob_pos),

    .load_done(rob_load_done),
    .load_res(rob_load_res),
    .load_rob_pos(rob_load_rob_pos),

    .reg_commit(reg_commit),
    .reg_commit_rd(reg_commit_rd),
    .reg_commit_val(reg_commit_val),
    .reg_commit_rename(reg_commit_rename),

    .reg_rs1(reg_rs1),
    .reg_val1(reg_val1),
    .reg_rename1(reg_rename1),
    .reg_rs2(reg_rs2),
    .reg_val2(reg_val2),
    .reg_rename2(reg_rename2),

    .store_todo(rob_store_todo),
    
    .rs_todo(rob_rs_todo),
    .rs_inst_type(rob_rs_inst_type),
    .rs_rs1_rob_pos(rob_rs_rs1_rob_pos),
    .rs_rs2_rob_pos(rob_rs_rs2_rob_pos),
    .rs_val1(rob_rs_val1),
    .rs_val2(rob_rs_val2),
    .rs_imm(rob_rs_imm),
    .rs_rd_rob_pos(rob_rs_rd_rob_pos),
    .rs_pc(rob_rs_pc)
  );

  wire reg_issue;
  wire [4:0] reg_issue_rd;
  wire [4:0] reg_issue_rename;

  RegFile RegFile0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .issue(reg_issue),
    .issue_rd(reg_issue_rd),
    .issue_rename(reg_issue_rename),

    .commit(reg_commit),
    .commit_rd(reg_commit_rd),
    .commit_val(reg_commit_val),
    .commit_rename(reg_commit_rename),

    .rs1(reg_rs1),
    .val1(reg_val1),
    .rename1(reg_rename1),
    .rs2(reg_rs2),
    .val2(reg_val2),
    .rename2(reg_rename2)
  );

  wire lsb_done;
  wire [31:0] lsb_res;
  wire [4:0] lsb_rob_pos;

  RS RS0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .rs_full(rs_full),

    .rs_todo(rob_rs_todo),
    .rs_inst_type(rob_rs_inst_type),
    .rs_rs1_rob_pos(rob_rs_rs1_rob_pos),
    .rs_rs2_rob_pos(rob_rs_rs2_rob_pos),
    .rs_val1(rob_rs_val1),
    .rs_val2(rob_rs_val2),
    .rs_imm(rob_rs_imm),
    .rs_rd_rob_pos(rob_rs_rd_rob_pos),
    .rs_pc(rob_rs_pc),

    .alu_todo(alu_todo),
    .alu_inst_type(alu_inst_type),
    .alu_val1(alu_val1),
    .alu_val2(alu_val2),
    .alu_imm(alu_imm),
    .alu_pc(alu_pc),
    .alu_in_rob_pos(alu_in_rob_pos),

    .alu_done(alu_done),
    .alu_res(alu_res),
    .alu_out_rob_pos(alu_out_rob_pos),

    .lsb_done(lsb_done),
    .lsb_res(lsb_res),
    .lsb_rob_pos(lsb_rob_pos)
  );

  LSB LSB0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),

    .io_buffer_full(io_buffer_full),

    .lsb_full(lsb_full),

    .memctrl_todo(lsb_memctrl_todo),
    .memctrl_addr(lsb_memctrl_addr),
    .memctrl_len(lsb_memctrl_len),
    .memctrl_store(lsb_memctrl_store),
    .memctrl_store_data(store_memctrl_data),
    .memctrl_load_res(memctrl_load_res),
    .memctrl_done(memctrl_lsb_done),

    .load_done(rob_load_done),
    .load_res(rob_load_res),
    .load_rob_pos(rob_load_rob_pos),

    .alu_done(alu_done),
    .alu_res(alu_res),
    .alu_jump(alu_jump),
    .alu_jump_addr(alu_jump_addr),
    .alu_rob_pos(alu_out_rob_pos),

    .store_todo(rob_store_todo),

    .lsb_todo(rob_rs_todo),
    .lsb_inst_type(rob_rs_inst_type),
    .lsb_rs1_rob_pos(rob_rs_rs1_rob_pos),
    .lsb_rs2_rob_pos(rob_rs_rs2_rob_pos),
    .lsb_val1(rob_rs_val1),
    .lsb_val2(rob_rs_val2),
    .lsb_imm(rob_rs_imm),
    .lsb_rd_rob_pos(rob_rs_rd_rob_pos)
  );
endmodule