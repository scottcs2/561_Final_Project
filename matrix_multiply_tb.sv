`ifndef MATRIX_MULTIPLY_TB_SV
`define MATRIX_MULTIPLY_TB_SV

`define NUM_ROWS_GAINS 3
`define NUM_COLS_GAINS 11
`define NUM_ROWS_STATES 11
`define NUM_COLS_STATES 1
`define NUM_ROWS_OUT   `NUM_ROWS_GAINS
`define NUM_COLS_OUT   `NUM_COLS_STATES

`define SIZE_GAINS  `NUM_ROWS_GAINS * `NUM_COLS_GAINS
`define SIZE_STATES `NUM_ROWS_STATES * `NUM_COLS_STATES
`define SIZE_OUT    `NUM_ROWS_OUT * `NUM_COLS_OUT
`define NUM_ADDS    `NUM_ROWS_STATES
`define NUM_MULTS   `NUM_ROWS_STATES


module matrix_multiply_tb;

    logic [`SIZE_GAINS - 1:0]   [63:0]  input_gains_matrix;
    logic [`SIZE_STATES - 1:0]  [63:0]  input_states_matrix;
    logic                               clock;
    logic                               reset;
    logic                       [31:0]  sample_time;

    logic [`SIZE_OUT - 1:0]     [63:0]  output_matrix;
    logic                               output_valid;


    matrix_multiply mm(
        .input_gains_matrix,
        .input_states_matrix,
        .clock,
        .reset,
        .sample_time,

        .output_matrix,
        .output_valid
    );

    always begin
        clock = ~clock;
        #10;
    end

    function makeRandom(output real value);
		// generates a random double between 1 and 100.		
		int before_double;
		before_double = $random;
		
		value = 0 + (1000-0)*($itor(before_double) / 32'hffffffff);
		
    endfunction

    real temp;
    
    task runTest;

        sample_time = 1000;

        for(int i = 0; i < `SIZE_GAINS; i++) begin 
            temp = 1.0 + i;
            input_gains_matrix[i] = $realtobits(temp);
        end

        for(int i = 0; i < `SIZE_STATES; i++) begin 
            temp = 1.0 + i;
            input_states_matrix[i] = $realtobits(temp);
        end

        $display("GAIN MATRIX: ");
        for(int i = 0; i < `NUM_ROWS_GAINS; i++) begin
            for(int j = 0; j < `NUM_COLS_GAINS; j++) begin
                $write("%f\t", $bitstoreal(input_gains_matrix[i * `NUM_COLS_GAINS + j]));
            end
            $write("\n");
        end


        $display("STATE MATRIX: ");
        for(int i = 0; i < `NUM_ROWS_STATES; i++) begin
            for(int j = 0; j < `NUM_COLS_STATES; j++) begin
                $write("%f\t", $bitstoreal(input_states_matrix[i * `NUM_COLS_STATES + j]));
            end
            $write("\n");
        end

        while(!output_valid)
            @(negedge clock);

        for(int i = 0; i < `SIZE_OUT; i++) begin
            $display("Output at index %d is %f", i, $bitstoreal(output_matrix[i]));
        end

    endtask

    initial begin
        clock = 0;
        reset = 1;
        @(negedge clock);
        @(negedge clock);

        reset = 0;
        runTest();


        $display("all tests passed");
        $finish;


    end
    

endmodule

`endif