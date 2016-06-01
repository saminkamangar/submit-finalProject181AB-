module mult_accelerator (
	input clk,
	output reg read_n = 1 ,
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

parameter SDRAM_BASE = 32'hC0000000,
	PIXELS_BASE = SDRAM_BASE + 2,
	WEIGHTS_BASE = PIXELS_BASE + 98,
	RESULTS_BASE = WEIGHTS_BASE + 78400,
	LAYER1_BASE = RESULTS_BASE + 400,
	WEIGHTS2_BASE = LAYER1_BASE + 26,
	RESULTS2_BASE = WEIGHTS2_BASE + 20000;

parameter [4:0] 
	IDLE  = 0,
	LOAD_ADDR = 8,
	READ_PIXELS = 1,
	READ_PIXELS_ACK = 6,
	READ_WEIGHTS = 2,
	READ_WEIGHTS_ACK = 7,
	COMP = 3,
	WRITE  = 4,
	WRITE_DONE = 5;
	
// pipeline registers
reg [15:0] weights_in; // read in weights from sdram
reg [15:0] pixels_in; // read in pixels from sdram
reg [31:0] read_address_w= WEIGHTS_BASE, read_address_p = PIXELS_BASE, write_address = RESULTS_BASE;
reg signed [15:0] sum0 = 0; // accumulator registers
reg signed [15:0] sum1 = 0;
reg signed [15:0] sum2 = 0;
reg signed [15:0] sum3 = 0;

// state registers
reg [4:0] state = IDLE, next_state = IDLE;

// control signals
reg weights_load = 0, pixels_load = 0;
reg weights_wait = 0, pixels_wait = 0;
reg shift_en = 0;
reg write_en = 0;
reg idle = 1;
reg addr_load = 0;
reg start = 0, done = 0;
reg result_valid = 0;
reg is_layer2 = 0;

// count registers
reg [1:0] shift_count = 0; // keeps track of how many shifts in pixels_in; tells when to read in new pixels
reg [10:0] pixel_count = 0; 
reg [9:0] row_count = 0; // keeps track of how many rows have been calculated

always @ (posedge clk) // state transition
	state <= (!reset_n) ? IDLE: next_state;

always @ (*) begin// control signals and outputs
	idle = 0;
	addr_load = 0;
	weights_load = 0;
	pixels_load = 0;
	weights_wait = 0;
	pixels_wait = 0;
	shift_en = 0;
	write_en = 0;
	done = 0;
	
	address = SDRAM_BASE;
	read_n = 1;
	write_n = 1;
	writedata = 16'b1;
	
	case (state)
		IDLE: begin
			idle = 1;
			
			address = SDRAM_BASE; 
			read_n = 0;
			
			next_state = (start) ? LOAD_ADDR: IDLE;
			//next_state = (start) ? READ_PIXELS: IDLE;
		end
		LOAD_ADDR: begin
			addr_load = 1;
			
			next_state = READ_PIXELS;
		end
		READ_PIXELS: begin
			pixels_load = 1;
			
			address = read_address_p;
			read_n = 0;
			
			next_state = (!waitrequest) ? READ_PIXELS_ACK: READ_PIXELS;
		end
		READ_PIXELS_ACK: begin
			pixels_wait = 1;
			
			next_state = (readdatavalid) ? READ_WEIGHTS: READ_PIXELS_ACK;
		end
		READ_WEIGHTS: begin
			weights_load = 1;
			
			address = read_address_w;
			read_n = 0;
			
			next_state = (!waitrequest) ? READ_WEIGHTS_ACK: READ_WEIGHTS;
		end
		READ_WEIGHTS_ACK: begin
			weights_wait = 1;
			
			next_state = (readdatavalid) ? COMP: READ_WEIGHTS_ACK;
		end
		COMP: begin
			shift_en = 1;
			
			if (is_layer2) 
				next_state = (pixel_count >= 196) ? WRITE: ((shift_count >= 3) ? READ_PIXELS: READ_WEIGHTS);
			else
				next_state = (pixel_count >= 780) ? WRITE: ((shift_count >= 3) ? READ_PIXELS: READ_WEIGHTS);
		end
		WRITE: begin
			write_en = 1;
			
			writedata = $signed(sum0 + sum1 + sum2 + sum3);
			address = write_address;
			write_n = 0;
			
			next_state = (waitrequest) ? WRITE: ((row_count >= 199) ? WRITE_DONE: READ_PIXELS);
		end
		WRITE_DONE: begin
			done = 1;
			
			writedata = 16'hFFFF;
			address = SDRAM_BASE;
			write_n = 0;
			
			next_state = (waitrequest) ? WRITE_DONE: IDLE;
		end
	endcase
end

always @(posedge clk) begin// Computation pipeline
	sum0 <= sum0;
	sum1 <= sum1;
	sum2 <= sum2;
	sum3 <= sum3;
	weights_in <= weights_in;
	pixels_in <= pixels_in;
	
	if (idle) begin
		sum0 <= 0;
		sum1 <= 0;
		sum2 <= 0;
		sum3 <= 0;
		weights_in <= 0;
		pixels_in <= 0;
	end
	if (weights_wait) begin
		weights_in <= (readdatavalid) ? readdata: weights_in;
	end
	if (pixels_wait) begin
		pixels_in <= (readdatavalid) ? readdata: pixels_in;
	end
	if (shift_en) begin 
		sum0 <= (pixels_in[12] == 1) ? (sum0 + $signed(weights_in[3:0])): sum0;
		sum1 <= (pixels_in[13] == 1) ? (sum1 + $signed(weights_in[7:4])): sum1;
		sum2 <= (pixels_in[14] == 1) ? (sum2 + $signed(weights_in[11:8])): sum2;
		sum3 <= (pixels_in[15] == 1) ? (sum3 + $signed(weights_in[15:12])): sum3;
		pixels_in <= pixels_in << 4;
	end
	if (write_en) begin
		sum0 <= (!waitrequest) ? 0: sum0;
		sum1 <= (!waitrequest) ? 0: sum1;
		sum2 <= (!waitrequest) ? 0: sum2;
		sum3 <= (!waitrequest) ? 0: sum3;
	end
end

always @ (posedge clk) begin // generate addresses
	read_address_p <= read_address_p;
	read_address_w <= read_address_w;
	write_address <= write_address;
	if (idle) begin
		read_address_p <= PIXELS_BASE; //
		read_address_w <= WEIGHTS_BASE; //
		write_address <= RESULTS_BASE; //
	end
	else if (addr_load && is_layer2) begin
		read_address_p <= LAYER1_BASE; //
		read_address_w <= WEIGHTS2_BASE; //
		write_address <= RESULTS2_BASE; //
	end
	else if (pixels_load) begin
		read_address_p <= (!waitrequest) ? read_address_p + 2: read_address_p;
	end
	else if (weights_load) begin
		read_address_w <= (!waitrequest) ? read_address_w + 2: read_address_w;
	end
	else if (write_en) begin
		read_address_p <= (is_layer2) ? LAYER1_BASE: PIXELS_BASE;
		write_address <= (waitrequest) ? write_address: write_address + 2;
	end
end

always @ (posedge clk) begin // counts four shifts; need to read new pixels
	shift_count <= (idle || write_en) ? 0: ((shift_en) ? shift_count + 1: shift_count);
end

always @ (posedge clk) begin // keeps track of how many pixels have been processed
	pixel_count <= (idle || write_en) ? 0: ((shift_en) ? pixel_count + 4: pixel_count);
end

always @ (posedge clk) begin // keeps track of rows calculated
	row_count <= (idle) ? 0: ((write_en && !waitrequest) ? row_count + 1: row_count);
end

always @ (posedge clk) begin// generate start signal
	//start <= (idle_wait && readdatavalid && readdata == 16'hFFFE) ? 1: 0;
	start <= (idle && readdatavalid && (readdata == 16'hFFFE || readdata == 16'hFFFD)) ? 1: 0;
end

always @ (posedge clk) begin
	is_layer2 <= is_layer2;
	if (idle && readdatavalid && readdata == 16'hFFFE)
		is_layer2 <= 0;
	if (idle && readdatavalid && readdata == 16'hFFFD)
		is_layer2 <= 1;
end

endmodule
