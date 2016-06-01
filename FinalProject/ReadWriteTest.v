module accelerator (
	input clk,
	output reg read_n =1 ,
	output reg write_n  = 1,
	output chipselect,
	input waitrequest,
	output reg [31:0] address = 0,
	output [1:0] byteenable,
	input readdatavalid,
	input [15:0] readdata,
	output reg [15:0] writedata,
	input reset_n
	
//	output [31:0] state_ex
);
parameter IDLE = 6'b1, READ = 6'h2, WRITE = 6'h3, WRITE_DONE = 6'h4, WAIT_VALID = 6'h5;

//reg [15:0] max = 16'h0;
//reg [15:0] min = 16'hFFFF;
reg [15:0] storedata = 16'h0;
reg [17:0] counter = 18'b0;
reg [16:0] rcv_counter = 17'b0;
reg [5:0] state = IDLE;

parameter SDRAM_BASE = 32'hC0000000;

assign byteenable = 2'b11;
assign chipselect = 1;
//assign state_ex = {max, min};

always @ (posedge clk) // state changes
begin
	if (!reset_n)
		state <= IDLE;
	else
	begin
//		if (waitrequest == 0)
//		begin
			case (state)
			IDLE: // idle state
			begin
				state <= (readdatavalid && readdata == 16'hFFFE) ? READ: IDLE; // 16'hffff <-- start signal
			end

			READ: // read from sdram 
			begin	
				state <= (!waitrequest) ? WAIT_VALID: READ;//readdatavalid
			end
			WAIT_VALID:
			begin
				state <= (readdatavalid) ? WRITE: WAIT_VALID;
			end
			WRITE: // write to sdram 
			begin
				if (waitrequest) //!waitrequest
					state <= WRITE;
				else
					state <= (counter < 262143) ? READ: WRITE_DONE; // change it back to ==
			end
			WRITE_DONE: // write done signal
			begin
				state <= (!waitrequest) ? IDLE: WRITE_DONE;	
			end
			endcase
//		end
//		else 
//			state <= state;
	end
end

always @ (posedge clk) // change address/counter
begin
	address <= address;
	counter <= counter;
	case (state)
	IDLE:
	begin
		//address <= (readdatavalid && readdata == 16'hFFFE) ? SDRAM_BASE: SDRAM_BASE + 'd262144; //!waitrequest
		address <= (readdatavalid && readdata == 16'hFFFE) ? SDRAM_BASE+1: SDRAM_BASE; //!waitrequest
		counter <= 18'b0;
		
	end
	READ:
	begin
		address <= SDRAM_BASE+1 + counter;
	end
	WRITE:
	begin
		//address <= (waitrequest == 0) ? SDRAM_BASE+1 + 262144 + counter + 1: SDRAM_BASE+1 + 262144  + counter;
		address <= SDRAM_BASE+1 + 262144 + counter;
		counter <= (waitrequest == 0) ? counter + 1: counter;
	end
	WRITE_DONE:
	//	address <= SDRAM_BASE + 'd262144;
		address <= SDRAM_BASE;
	endcase
end


always @ (posedge clk) // handle readdata
begin
	if (readdatavalid)
		storedata <= readdata;
end

always @ (posedge clk) // output logic
begin

	read_n <= 1;
	write_n <= 1;
	writedata <= 16'b0;

	case (state)
		IDLE: // idle state
		begin
			read_n <= 0;		
		end
		
		READ:
		begin
			read_n <= 0;
		end

		WRITE:
		begin				
			write_n <= 0;
			writedata <= storedata;
		end
		
		WRITE_DONE:
		begin
			write_n <= 0;
			writedata <= 16'hFFFF;
		end

	endcase 
end


endmodule
