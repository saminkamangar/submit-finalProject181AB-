module sobel_accelerator (
	input clk,
	output reg read_n =1 ,
	output reg write_n  = 1,
	output chipselect,
	input waitrequest,
	output reg [31:0] address = 32'hC0000000,
	output [1:0] byteenable,
	input readdatavalid,
	input [15:0] readdata,
	output reg [15:0] writedata,
	input reset_n
);

assign byteenable = 2'b11;
assign chipselect = 1'b1;

parameter HEIGHT = 512;
parameter WIDTH = 512;
parameter SDRAM_BASE = 32'hC0000000;

parameter [4:0] 
	IDLE  = 0,
	READ_PREV_INIT = 1,
	READ_CURR_INIT = 2,
	READ_NEXT_INIT = 3,
	COMP_INIT  = 4,
	READ_PREV  = 5,
	READ_CURR  = 6,
	READ_NEXT  = 7,
	COMP  = 8,
	WRITE = 9,
	COMP_LAST  = 10,
	WRITE_LAST = 11,
	WRITE_DONE  = 12;
	
// pipeline registers
reg [15:0] prev_row, curr_row, next_row;
reg [31:0] read_address, write_address;
reg  [7:0] O [-1:+1][-1:+1];
reg signed [10:0] Dx, Dy; //
reg [10:0] D;				//
reg  [7:0] abs_D;
reg  [15:0] result;

// state registers
reg [4:0] state = IDLE, next_state = IDLE;

// control signals
reg prev_load = 0, curr_load = 0, next_load = 0;
reg shift_en = 0;
reg write_en = 0;
reg idle = 1;
reg start = 0, done = 0;
reg result_valid = 0;
reg prev_read_sent = 0, curr_read_sent = 0, next_read_sent = 0;

// count registers
//reg [1:0] read_count;
reg shift_count = 0;
reg [19:0] pixel_count = 0;
reg [4:0] fill_count = 0;

function [10:0] abs( input signed [10:0] x);
	abs = (x>=0) ? x : -x;
endfunction

always @ (posedge clk) // state transition
	state <= (!reset_n) ? IDLE: next_state;

always @ (posedge clk) // control signals
begin
	idle <= 0;
	prev_load <= 0;
	curr_load <= 0;
	next_load <= 0;
	shift_en <= 0;
	write_en <= 0;
	done <= 0;
	
	case (next_state)
		IDLE: begin
			idle <= 1;
		end
		READ_PREV_INIT: begin
			prev_load <= 1;
		end
		READ_CURR_INIT: begin
			curr_load <= 1;
		end
		READ_NEXT_INIT: begin
			next_load <= 1;
		end
		COMP_INIT: begin
			shift_en <= 1;
		end
		READ_PREV: begin
			prev_load <= 1;
		end
		READ_CURR: begin
			curr_load <= 1;
		end
		READ_NEXT: begin
			next_load <= 1;
		end
		COMP: begin
			shift_en <= 1;
		end
		WRITE: begin
			write_en <= 1;
		end
		COMP_LAST: begin
			shift_en <= 1;
		end
		WRITE_LAST: begin
			write_en <= 1;
		end
		WRITE_DONE: begin
			done <= 1;
		end
	endcase
end

always @ (*) begin // next state logic
	case (state)
		IDLE: begin
			next_state = (start) ? READ_PREV_INIT: IDLE;
		end
		READ_PREV_INIT: begin
			next_state = (readdatavalid) ? READ_CURR_INIT: READ_PREV_INIT;
		end
		READ_CURR_INIT: begin
			next_state = (readdatavalid) ? READ_NEXT_INIT: READ_CURR_INIT;
		end
		READ_NEXT_INIT: begin
			next_state = (readdatavalid) ? COMP_INIT: READ_NEXT_INIT;
		end
		COMP_INIT: begin
			next_state = (result_valid) ? READ_PREV: ((shift_count) ? READ_PREV_INIT: COMP_INIT);
		end
		READ_PREV: begin
			next_state = (readdatavalid) ? READ_CURR: READ_PREV;
		end
		READ_CURR: begin
			next_state = (readdatavalid) ? READ_NEXT: READ_CURR;
		end
		READ_NEXT: begin
			next_state = (readdatavalid) ? COMP: READ_NEXT;
		end
		COMP: begin
			next_state = (shift_count) ? WRITE: COMP;
		end
		WRITE: begin
			if (pixel_count < ((HEIGHT-2)*WIDTH - 1))
				next_state = (!waitrequest) ? READ_PREV: WRITE;
			else
				next_state = COMP_LAST;
		end
		COMP_LAST: begin
			next_state = (shift_count) ? WRITE_LAST: COMP_LAST;
		end
		WRITE_LAST: begin
			next_state = (!waitrequest) ? WRITE_DONE: WRITE_LAST;
		end
		WRITE_DONE: begin
			next_state = (!waitrequest) ? IDLE: WRITE_DONE;
		end
	endcase
end

always @(posedge clk) begin// Computation pipeline
	if (shift_en) begin
		D = abs(Dx) + abs(Dy);
		abs_D <= (D > 255) ? 255: D[7:0];
		Dx <= - $signed({3'b000, O[-1][-1]})
			+ $signed({3'b000, O[-1][+1]})
			- ($signed({3'b000, O[ 0][-1]}) << 1)
			+ ($signed({3'b000, O[ 0][+1]}) << 1)
			- $signed({3'b000, O[+1][-1]})
			+ $signed({3'b000, O[+1][+1]});
			
		Dy <= $signed({3'b000, O[-1][-1]})
			+ ($signed({3'b000, O[-1][ 0]}) << 1)
			+ $signed({3'b000, O[-1][+1]})
			- $signed({3'b000, O[+1][-1]}) 
			- ($signed({3'b000, O[+1][ 0]}) << 1)
			- $signed({3'b000, O[+1][+1]});
			
		O[-1][-1] <= O[-1][0];
		O[-1][ 0] <= O[-1][+1];
		O[-1][+1] <= prev_row[15:8];
		O[ 0][-1] <= O[0][0];
		O[ 0][ 0] <= O[0][+1];
		O[ 0][+1] <= curr_row[15:8];
		O[+1][-1] <= O[+1][ 0];
		O[+1][ 0] <= O[+1][+1];
		O[+1][+1] <= next_row[15:8];
		prev_row[15:8] <= prev_row[7:0];
		curr_row[15:8] <= curr_row[7:0];
		next_row[15:8] <= next_row[7:0];
	end
	else begin
		prev_row <= (prev_load && readdatavalid) ? readdata: prev_row;
		curr_row <= (curr_load && readdatavalid) ? readdata: curr_row;
		next_row <= (next_load && readdatavalid) ? readdata: next_row;
	end
end
	
always @ (posedge clk) begin // generate addresses, read_n, and write_n
	address <= address;
	read_address <= read_address;
	write_address <= write_address;
	read_n <= 1;
	write_n <= 1;
	writedata <= writedata;
	if (idle) begin
		address <= SDRAM_BASE;
		read_n <= 0;
		read_address <= SDRAM_BASE;
		write_address <= (SDRAM_BASE + WIDTH*HEIGHT + 2);
	end
	else if (shift_en) begin
		read_address <= read_address + 1;
		write_address <= write_address + 1;
	end
	else if (prev_load) begin
		address <= read_address;
		//read_n <= (!prev_read_sent) ? 0: 1;
		read_n <= 0;
	end
	else if (curr_load) begin
		address <= read_address + (WIDTH);
		//read_n <= (!curr_read_sent) ? 0: 1;
		read_n <= 0;
	end
	else if (next_load) begin
		address <= read_address + (2*WIDTH);
		//read_n <= (!next_read_sent) ? 0: 1;
		read_n <= 0;
	end
	else if (write_en) begin
		writedata <= abs_D;
		address <= write_address;
		write_n <= 0;
	end
	else if (done) begin
		writedata <= 16'hFFFF;
		address <= SDRAM_BASE;
		write_n <= 0;
	end
end
/*
always @ (posedge clk) begin // load in read values into rows
	if (!shift_en) begin
		prev_row <= (prev_load && readdatavalid) ? readdata: prev_row;
		curr_row <= (curr_load && readdatavalid) ? readdata: curr_row;
		next_row <= (next_load && readdatavalid) ? readdata: next_row;
	end
end
*/
always @ (posedge clk) begin // counts two shifts; need to read/write rows every two shifts
	shift_count <= (idle) ? 0: ((shift_en) ? shift_count + 1: shift_count);
end

always @ (posedge clk) begin // keeps track of how many pixels have been processed
	pixel_count <= (idle) ? 0: ((shift_en) ? pixel_count + 1: pixel_count);
end
/*
always @ (*) begin // set read_n high after it has been set low for one cycle (prevent duplicate reads)
	if (idle || shift_en) begin
		prev_read_sent = 0;
		curr_read_sent = 0;
		next_read_sent = 0;
	end
	else if (prev_load) begin
		prev_read_sent = (!waitrequest) ? 1:0;
	end		
	else if (curr_load) begin
		curr_read_sent = (!waitrequest) ? 1:0;
	end	
	else if (next_load) begin
		next_read_sent = (!waitrequest) ? 1:0;
	end	
end
*/
always @ (posedge clk) begin // fill the pipeline (6 shifts) before moving on to writing
	if (idle) begin
		result_valid <= 0;
		fill_count <= 0;
	end
	else if (!result_valid && shift_en) begin
		fill_count <= fill_count + 1;
		result_valid <= (fill_count == 6) ? 1:0;
	end
end
	
always @ (posedge clk) // generate start signal
	start <= (idle && readdatavalid && readdata == 16'hFFFE) ? 1: 0;

always @(posedge clk) // Result row register
	if (shift_en) result <= {result[7:0], abs_D};

endmodule