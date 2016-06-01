module mult_accelerator (
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

parameter SDRAM_BASE = 32'hC0000000,
		PIXELS_BASE = SDRAM_BASE + 2,
		WEIGHTS_BASE = PIXELS_BASE + 98,
		RESULTS_BASE = WEIGHTS_BASE + 78400;

parameter [4:0] 
	IDLE  = 0,
	IDLE_ACK = 8,
	READ_PIXELS = 1,
	READ_PIXELS_ACK = 2,
	READ_WEIGHTS = 3,
	READ_WEIGHTS_ACK = 4,
	COMP = 5,
	COMP_DELAY = 9,
	WRITE = 6,
	WRITE_DONE = 7;
	
// pipeline registers
reg signed [15:0] weights_in; // read in weights from sdram
reg [15:0]  pixels_in; // read in pixels from sdram
reg [31:0] read_address_w = WEIGHTS_BASE, read_address_p = PIXELS_BASE, write_address = RESULTS_BASE;
reg signed [15:0] sum1 = 0, sum2 = 0, sum3 = 0, sum0 = 0; // accumulator registers
//reg signed [15:0] result; // stores final sum

// state registers
reg [4:0] state = IDLE, next_state = IDLE;

// count registers
reg [1:0] shift_count = 0; // keeps track of how many shifts in pixels_in; tells when to read in new pixels
reg [9:0] pixel_count = 0; 
reg [9:0] row_count = 0; // keeps track of how many rows have been calculated
	
always @ (posedge clk) // state transition
	state <= (!reset_n) ? IDLE: next_state;

always @ (*) begin // next state logic
	case (state)
	/*
		IDLE: begin
			next_state = (waitrequest) ? IDLE: IDLE_ACK;
		end
		IDLE_ACK: begin
			next_state = (readdatavalid) ? ((readdata == 16'hFFFE) ? READ_PIXELS: IDLE): IDLE_ACK;
		end
	*/
		IDLE: begin
			next_state = (readdatavalid && readdata == 16'hFFFE) ? READ_PIXELS: IDLE;
		end
		READ_PIXELS: begin
			next_state = (waitrequest) ? READ_PIXELS: READ_PIXELS_ACK;
		end
		READ_PIXELS_ACK: begin
			next_state = (readdatavalid) ? READ_WEIGHTS: READ_PIXELS_ACK;
		end
		READ_WEIGHTS: begin
			next_state = (waitrequest) ? READ_WEIGHTS: READ_WEIGHTS_ACK;
		end
		READ_WEIGHTS_ACK: begin
			next_state = (readdatavalid) ? COMP: READ_WEIGHTS_ACK;
		end
		COMP: begin
			next_state = (pixel_count >= 780) ? COMP_DELAY: ((shift_count >= 3) ? READ_PIXELS: READ_WEIGHTS);
		end
		COMP_DELAY: begin
			next_state = WRITE;
		end
		WRITE: begin
			next_state = (waitrequest) ? WRITE: ((row_count >= 199) ? WRITE_DONE: READ_PIXELS);
		end
		WRITE_DONE: begin
			next_state = (waitrequest) ? WRITE_DONE: IDLE;
		end
	endcase
end

always @ (posedge clk) // control signals
begin
	//start <= start;
	sum0 <= sum0;
	sum1 <= sum1;
	sum2 <= sum2;
	sum3 <= sum3;
	shift_count <= shift_count;
	pixel_count <= pixel_count;
	row_count <= row_count;
	pixels_in <= pixels_in;
	weights_in <= weights_in;
	address <= address;
	read_address_p <= read_address_p;
	read_address_w <= read_address_w;
	write_address <= write_address;
	read_n <= 1;
	write_n <= 1;
	writedata <= writedata;
	
	case (next_state)
	/*
		IDLE: begin
			//idle <= 1;
			shift_count <= 0;
			pixel_count <= 0;
			row_count <= 0;
			address <= SDRAM_BASE; 
			read_n <= 0;
			read_address_w <= WEIGHTS_BASE;
			read_address_p <= PIXELS_BASE;
			write_address <= RESULTS_BASE;
			writedata <= 0;
		end
	*/
		READ_PIXELS: begin
			//pixels_load <= 1;
			address <= read_address_p;
			read_n <= 0;
		end
		READ_WEIGHTS: begin
			//weights_load <= 1;
			address <= read_address_w;
			read_n <= 0;
		end
		WRITE: begin
			//write_en <= 1;
			writedata <= $signed(sum0 + sum1 + sum2 + sum3); 
			address <= write_address;
			write_n <= 0;
			sum0 <= 0;
			sum1 <= 0;
			sum2 <= 0;
			sum3 <= 0;
			pixel_count <= 0;
			read_address_p <= PIXELS_BASE;
		end
		WRITE_DONE: begin
			//done <= 1;
			writedata <= 16'hFFFF;
			address <= SDRAM_BASE;
			write_n <= 0;
			//start <= 0;
		end
	endcase
	case (state) 
		IDLE: begin
			//idle <= 1;
			shift_count <= 0;
			pixel_count <= 0;
			row_count <= 0;
			address <= SDRAM_BASE; 
			read_n <= 0;
			read_address_w <= WEIGHTS_BASE;
			read_address_p <= PIXELS_BASE;
			write_address <= RESULTS_BASE;
			writedata <= 0;
		end
		COMP: begin
			//shift_en <= 1;
			sum0 <= (pixels_in[12]) ? sum0 + $signed(weights_in[3:0]): sum0;
			sum1 <= (pixels_in[13]) ? sum1 + $signed(weights_in[7:4]): sum1;
			sum2 <= (pixels_in[14]) ? sum2 + $signed(weights_in[11:8]): sum2;
			sum3 <= (pixels_in[15]) ? sum3 + $signed(weights_in[15:12]): sum3;
			pixels_in <= pixels_in << 4;
			pixel_count <= pixel_count + 4;
			shift_count <= shift_count + 1;
		end
		READ_PIXELS_ACK: begin
			pixels_in <= (readdatavalid) ? readdata: pixels_in;
			read_address_p <= (readdatavalid) ? read_address_p + 2: read_address_p;
		end
		READ_WEIGHTS_ACK: begin
			weights_in <= (readdatavalid) ? readdata: weights_in;
			read_address_w <= (readdatavalid) ? read_address_w + 2: read_address_w;
		end
		WRITE: begin
			write_address <= (waitrequest) ? write_address: write_address + 2;
			row_count <= (waitrequest) ? row_count: row_count + 1;
		end
	endcase
end

/*
always @ (*) // control signals
begin
	start = start;
	sum0 = sum0;
	sum1 = sum1;
	sum2 = sum2;
	sum3 = sum3;
	shift_count = shift_count;
	pixel_count = pixel_count;
	row_count = row_count;
	pixels_in = pixels_in;
	weights_in = weights_in
	address = address;
	read_address_p = read_address_p;
	read_address_w = read_address_w;
	write_address = write_address;
	read_n = 1;
	write_n = 1;
	writedata = writedata;
	
	case (state)
		IDLE: begin
			//idle = 1;
			shift_count = 0;
			pixel_count = 0;
			row_count = 0;
			address = SDRAM_BASE; 
			read_n = 0;
			read_address_w = WEIGHTS_BASE;
			read_address_p = PIXELS_BASE;
			write_address = RESULTS_BASE;
		end
		READ_PIXELS: begin
			//pixels_load = 1;
			address = read_address_p;
			read_n = 0;
		end
		READ_PIXELS_ACK: begin
			pixels_in = (readdatavalid) ? readdata: pixels_in;
			read_address_p = (readdatavalid) ? read_address_p + 2: read_address_p;
		end
		READ_WEIGHTS: begin
			//weights_load = 1;
			address = read_address_w;
			read_n = 0;
		end
		READ_WEIGHTS_ACK: begin
			weights_in = (readdatavalid) ? readdata: weights_in;
			read_address_w = (readdatavalid) ? read_address_w + 2: read_address_w;
		end
		COMP: begin
			//shift_en = 1;
			sum0 = (pixels_in[12]) ? sum0 + $signed(weights_in[3:0]): sum0;
			sum1 = (pixels_in[13]) ? sum1 + $signed(weights_in[7:4]): sum1;
			sum2 = (pixels_in[14]) ? sum2 + $signed(weights_in[11:8]): sum2;
			sum3 = (pixels_in[15]) ? sum3 + $signed(weights_in[15:12]): sum3;
			pixels_in = pixels_in << 4;
			pixel_count = pixel_count + 4;
		end
		WRITE: begin
			//write_en = 1;
			writedata = $signed(sum0 + sum1 + sum2 + sum3); 
			address = write_address;
			write_n = 0;
			sum0 = 0;
			sum1 = 0;
			sum2 = 0;
			sum3 = 0;
			write_address = (waitrequest) ? write_address: write_address + 2;
			pixel_count = 0;
			row_count = (waitrequest) ? row_count: row_count + 1;
		end
		WRITE_DONE: begin
			//done = 1;
			writedata = 16'hFFFF;
			address = SDRAM_BASE;
			write_n = 0;
			start = 0;
		end
	endcase
end
*/
endmodule
