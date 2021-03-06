module memory_map (
	input clk,

	input [31:0] instr_addr,
	output [31:0] instr_data,

	input [31:0] cpu_addr,
	input [31:0] cpu_wrdata,
	output reg [31:0] cpu_rddata,
	input [2:0] cpu_memop,
	input cpu_we,

	input [31:0] vga_char_addr,
	output [31:0] vga_char_data,
	input [31:0] vga_color_addr,
	output [31:0] vga_color_data,
	
	output [31:0] vga_extra_line_cnt,
	output [15:0] vga_cursor_x,
	output [15:0] vga_cursor_y,

	input [31:0] kb_wraddr,
	input [31:0] kb_wrdata,
	input kb_we,

	output [31:0] dbg_data,

	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5,

	output [9:0] LEDR
);

parameter INSTR_OFFSET        = 32'h00000000;
parameter DATA_OFFSET         = 32'h00100000;
parameter VGA_INFO_OFFSET     = 32'h00200000;
parameter VGA_CHAR_OFFSET     = 32'h00300000;
parameter VGA_COLOR_OFFSET    = 32'h00400000;
parameter KB_INFO_OFFSET      = 32'h00500000;
parameter IDT_OFFSET          = 32'h00600000;
parameter TMP_STACK_OFFSET    = 32'h00700000;
parameter OUTPUT_PIN_OFFSET   = 32'h00800000;
parameter SEG7_OFFSET  		  = 32'h00810000;
parameter LEDR_OFFSET         = 32'h00820000;
parameter VIDEO_OFFSET 		  = 32'h00900000;
parameter PREFIX_MASK 		  =	32'hfff00000;	
parameter ADDR_MASK 		  =	32'h000fffff;

wire [31:0] dram_dataout, kb_info_dataout, tmp_stack_dataout, video_dataout;
wire dram_we, vga_we, char_we, color_we, tmp_, stack_we, dbg_we;

assign dram_we = cpu_we && ((cpu_addr & PREFIX_MASK) == DATA_OFFSET);
assign vga_we = cpu_we && ((cpu_addr & PREFIX_MASK) == VGA_INFO_OFFSET);
assign char_we = cpu_we && ((cpu_addr & PREFIX_MASK) == VGA_CHAR_OFFSET);
assign color_we = cpu_we && ((cpu_addr & PREFIX_MASK) == VGA_COLOR_OFFSET);
assign tmp_stack_we = cpu_we && ((cpu_addr & PREFIX_MASK) == TMP_STACK_OFFSET);
assign dbg_we = cpu_we && ((cpu_addr & PREFIX_MASK) == OUTPUT_PIN_OFFSET);

always @(*) begin
	if((cpu_addr & PREFIX_MASK) == DATA_OFFSET)
		cpu_rddata <= dram_dataout;
	else if((cpu_addr & PREFIX_MASK) == KB_INFO_OFFSET)
		cpu_rddata <= kb_info_dataout;
	else if((cpu_addr & PREFIX_MASK) == TMP_STACK_OFFSET)
		cpu_rddata <= tmp_stack_dataout;
	else if((cpu_addr & PREFIX_MASK) == VIDEO_OFFSET)
		cpu_rddata <= video_dataout;
	else
		cpu_rddata <= 0;
end

instr_rom instr_rom_instance((instr_addr&ADDR_MASK)>>2, clk, instr_data);														// 	read: cpu, 	write: none
dram dram_instance(cpu_addr&ADDR_MASK, dram_dataout, cpu_wrdata, clk, clk, cpu_memop, dram_we);								//	read: cpu, 	write: cpu
vga_info vga_info_instance(clk, cpu_addr&ADDR_MASK, cpu_wrdata, vga_we, vga_extra_line_cnt, vga_cursor_x, vga_cursor_y);	// 	read: vga, 	write: cpu
char_ram vga_ram_instance(cpu_wrdata, vga_char_addr&ADDR_MASK, clk, cpu_addr&ADDR_MASK, clk, char_we, vga_char_data);		//	read: vga, 	write: cpu
color_ram color_ram_instance(cpu_wrdata, vga_color_addr&ADDR_MASK, clk, cpu_addr&ADDR_MASK, clk, color_we, vga_color_data);	//	read: vga, 	write: cpu
kb_info kb_info_instance(clk, cpu_addr&ADDR_MASK, kb_info_dataout, kb_wraddr&ADDR_MASK, kb_wrdata, kb_we);					//	read: cpu, 	write: kb
tmp_stack tmp_stack_ram_instance(cpu_addr&ADDR_MASK, tmp_stack_dataout, cpu_wrdata, clk, clk, cpu_memop, tmp_stack_we);		//	read: cpu, 	write: cpu
output_pin_ram output_pin_ram_instance(clk, dbg_we, cpu_addr, cpu_wrdata, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR);
video_rom video_rom_instance((cpu_addr&ADDR_MASK), clk, video_dataout);														//	read: cpu, 	write: none

endmodule

module vga_info (
	input clk,
	input [31:0] wraddr,
	input [31:0] wrdata,
	input wren,
	output [31:0] extra_line_cnt,
	output [15:0] cursor_x,
	output [15:0] cursor_y
);

reg [7:0] data[7:0];

assign extra_line_cnt = {data[3], data[2], data[1], data[0]};
assign cursor_x = {data[5], data[4]};
assign cursor_y = {data[7], data[6]};

always @(posedge clk) begin
	if(wren) begin
		if(wraddr == 0)
			{data[3], data[2], data[1], data[0]} <= wrdata;
		else if(wraddr == 4)
			{data[7], data[6], data[5], data[4]} <= wrdata;
	end
end
	
endmodule

module kb_info (
	input clk,
	input [31:0] kbinfo_rdaddr,
	output [31:0] kbinfo_rddata,
	input [31:0] kbinfo_wraddr,
	input [31:0] kbinfo_wrdata,
	input wren
);

reg [31:0] data;

assign kbinfo_rddata = data;
always @(posedge clk) begin
	if(wren) begin
		data <= kbinfo_wrdata;
	end
end
	
endmodule

module output_pin_ram (
	input clk,
	input wren,
	input [31:0] wraddr,
	input [31:0] wrdata,

	output reg [6:0] HEX0,
	output reg [6:0] HEX1,
	output reg [6:0] HEX2,
	output reg [6:0] HEX3,
	output reg [6:0] HEX4,
	output reg [6:0] HEX5,

	output reg [9:0] LEDR
);

wire [31:0] addr = wraddr & 32'h0000FFFF;
always @(posedge clk) begin
	if(wren) begin
		if((wraddr&32'hFFFF0000)==32'h00810000) begin
			if(addr == 32'h0)
				HEX0 <= wrdata[6:0];
			else if(addr == 32'h4)
				HEX1 <= wrdata[6:0];
			else if(addr == 32'h8)
				HEX2 <= wrdata[6:0];
			else if(addr == 32'hC)
				HEX3 <= wrdata[6:0];
			else if(addr == 32'h10)
				HEX4 <= wrdata[6:0];
			else if(addr == 32'h14)
				HEX5 <= wrdata[6:0];
		end else if((wraddr&32'hFFFF0000)==32'h00820000) begin
				LEDR <= wrdata[9:0];
		end
	end
end
	
endmodule