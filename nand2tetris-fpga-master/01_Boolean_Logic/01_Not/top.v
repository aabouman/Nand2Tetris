`default_nettype none
module top(
	input BUT1,
	input BUT2,
	output LED1,
	output LED2
);

	Not NOT1(.in(BUT1),.out(LED1));
	Not NOT2(.in(BUT2),.out(LED2));
	
endmodule
