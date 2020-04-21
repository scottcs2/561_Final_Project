`ifndef MATRIX_MULTIPLY_SV
`define MATRIX_MULTIPLY_SV

//values for synthesis
`define NUM_ROWS_GAINS 3
`define NUM_COLS_GAINS 9
`define NUM_ROWS_STATES 9
`define NUM_COLS_STATES 1
`define NUM_ROWS_OUT   `NUM_ROWS_GAINS
`define NUM_COLS_OUT   `NUM_COLS_STATES

`define SIZE_GAINS  `NUM_ROWS_GAINS * `NUM_COLS_GAINS
`define SIZE_STATES `NUM_ROWS_STATES * `NUM_COLS_STATES
`define SIZE_OUT    `NUM_ROWS_OUT * `NUM_COLS_OUT
`define NUM_ADDS    `NUM_ROWS_STATES
`define NUM_MULTS   `NUM_ROWS_STATES

// we are doing Gains * States, so out takes X of Gains and Y of States

module matrix_multiply (

    // inputs
    input   logic [`SIZE_GAINS - 1:0]   [63:0]  input_gains_matrix,
    input   logic [`SIZE_STATES - 1:0]  [63:0]  input_states_matrix,
    input   logic                               clock,
    input   logic                               reset,
    input   logic                       [31:0]  sample_time,

    // outputs
    output  logic [`SIZE_OUT - 1:0]     [63:0]  output_matrix,
    output  logic                               output_valid
    
);

    // sampled inputs
    logic   [`SIZE_GAINS - 1:0]   [63:0]  latched_gains_matrix, next_latched_gains_matrix;
    logic   [`SIZE_STATES - 1:0]  [63:0]  latched_states_matrix, next_latched_states_matrix;

    logic   [`SIZE_OUT - 1:0]     [63:0]  temp_output_matrix, next_temp_output_matrix, next_output_matrix;

    // output logic
    logic                                           next_output_valid;

    logic [32:0] next_counter, counter;

    /* index into specific double
    GAIN_MATRIX[5][6][3]
                x  y  i
                i is index into [63:0]
                if number is 0101010
                                ^     
    */

    // matrix multiply pseudo code
    // for(int i = 0; i < `X_DIM_GAINS; i++) begin
    //     for(int j = 0; j < `Y_DIM_STATES; j++) begin
    //         for(int k = 0; k < `Y_DIM_GAINS; k++) begin
    //             OUTPUT_MATRIX[i][j] += GAIN_MATRIX[i][k] * STATE_MATRIX[k][i];    
    //         end
    //     end
    // end



    // matrix index logic
    logic [$clog2(`NUM_ROWS_GAINS)-1:0] gain_row_idx, next_gain_row_idx;
    logic [$clog2(`NUM_COLS_STATES)-1:0] states_col_idx, next_states_col_idx;

    // state logic
    logic [2:0] state, next_state;
    parameter
            sample          = 4'd0,
            init_mult       = 4'd1,
            wait_mult       = 4'd2,
            init_add        = 4'd3,
            wait_add        = 4'd4,
            hold            = 4'd5;

    // multipliers logic
    logic [`NUM_MULTS-1:0]  [63:0]  input_a_mults, input_b_mults, output_z_mults;
    logic [`NUM_MULTS-1:0]          input_valid_mults, reset_mults, done_mults;

    // adders logic
    logic [63:0]  input_a_adders, input_b_adders, output_z_adders;
    logic         input_valid_adders, reset_adders, done_adders;

    logic [$clog2(`NUM_ADDS):0] add_idx, next_add_idx;

    // temporary values for next_state logic
    logic all_mults_done; 
    logic move_on;
    logic trigger_next_sample;


    // always_ff @(posedge clock) begin
    //     $display("---------------------");
    //     if(done_adders)
    //         $display("Adder has output:%f", $bitstoreal(output_z_adders));
    //     if(reset_adders) begin
    //         $display("RESETTING ADDER");
    //     end

    //     if(reset_mults) begin
    //         $display("RESETTING MULTIPLIER");
    //     end

    //     for(int i = 0; i < `NUM_MULTS; i++) begin
    //         if(done_mults[i])
    //             $display("Multiplier:%d has output:%f", i, $bitstoreal(output_z_mults[i]));
    //     end

    //     if(input_valid_adders) begin
    //         $display("input a:%f", $bitstoreal(input_a_adders));
    //         $display("input b:%f", $bitstoreal(input_b_adders));
    //         $display("add_idx:%d", add_idx);
    //     end

    //     if(next_add_idx != add_idx) begin
    //         $display("TRANSITION add_idx from:%d to %d", add_idx, next_add_idx);
    //     end

    //     if(state != next_state) begin
    //         $write("TRANSITION FROM STATE: ");
    //         if(state == 0) begin
    //             $write("SAMPLE");
    //         end
    //         if(state == 1) begin
    //             $write("INIT_MULT");
    //         end
    //         if(state == 2) begin
    //             $write("WAIT_MULT");
    //         end
    //         if(state == 3) begin
    //             $write("INIT_ADD");
    //         end
    //         if(state == 4) begin
    //             $write("WAIT_ADD");
    //         end
    //         if(state == 5) begin
    //             $write("HOLD");
    //         end
    //         $write(" TO STATE: ");

    //         if(next_state == 0) begin
    //             $write("SAMPLE");
    //         end
    //         if(next_state == 1) begin
    //             $write("INIT_MULT");
    //         end
    //         if(next_state == 2) begin
    //             $write("WAIT_MULT");
    //         end
    //         if(next_state == 3) begin
    //             $write("INIT_ADD");
    //         end
    //         if(next_state == 4) begin
    //             $write("WAIT_ADD");
    //         end
    //         if(next_state == 5) begin
    //             $write("HOLD");
    //         end
    //         $display("\n");
    //     end

    //     $display("---------------------");

    // end

    always_comb begin

        next_state              = state;
        next_output_matrix      = output_matrix;
        next_gain_row_idx       = gain_row_idx;
        next_states_col_idx     = states_col_idx;
        next_add_idx            = add_idx;
        next_output_valid       = output_valid;

        next_latched_gains_matrix   = latched_gains_matrix;
        next_latched_states_matrix  = latched_states_matrix;
        next_output_matrix          = output_matrix;
        next_temp_output_matrix     = temp_output_matrix;

        reset_adders        = 1'b0;
        reset_mults         = 1'b0;

        input_a_adders      = 0;
        input_b_adders      = 0;
        input_valid_adders  = 0;

        input_a_mults       = 0;
        input_b_mults       = 0;
        input_valid_mults   = 0;

        all_mults_done      = 1'b1;
        trigger_next_sample = 1'b0;
        move_on             = 1'b0;

        // counter logic
        if(counter >= sample_time) begin
            trigger_next_sample = 1'b1;
        end else begin
            next_counter = counter + 1;
        end

        case(state)

            sample: // latch in data on input and begin to work. 
            begin
                for (int i = 0; i < `NUM_MULTS; i++) begin
                    reset_mults[i] = 1;
                end
                reset_adders = 1;
                next_states_col_idx = 0;
                next_gain_row_idx = 0;
                next_add_idx = 0;

                // for(int i = 0; i < `X_DIM_GAINS; i++) begin
                //     for(int j = 0; j < `Y_DIM_GAINS; j++) begin
                //         next_latched_gains_matrix[i] = input_gains_matrix[i];
                //         next_latched_gains_matrix_2D[i][j] = input_gains_matrix[j + i * `X_DIM_GAINS];
                //     end
                // end

                for(int i = 0; i < `SIZE_GAINS; i++) begin
                    next_latched_gains_matrix[i] = input_gains_matrix[i];
                end

                for(int i = 0; i < `SIZE_STATES; i++) begin
                    next_latched_states_matrix[i] = input_states_matrix[i];
                end

                next_state = init_mult;

            end

            init_mult: // start a multiplication sequence.
            begin

                // all columns of the current row
                for(int i = 0; i < `NUM_MULTS; i++) begin
                    input_a_mults[i] = latched_gains_matrix[gain_row_idx * `NUM_COLS_GAINS + i];
                    input_b_mults[i] = latched_states_matrix[states_col_idx + `NUM_COLS_STATES * i];
                    input_valid_mults[i] = 1'b1;
                end

                next_state = wait_mult;

            end

            wait_mult: // wait for multiplications to finish
            begin

                // check if all multiplies finished
                for(int i = 0; i < `NUM_MULTS; i++) begin
                    all_mults_done = all_mults_done & done_mults[i];
                end
                
                if(all_mults_done) begin
                    next_state = init_add;
                    next_add_idx = 0;
                end

            end

            init_add: // initialize additions for summing all of the previous multiplications.
            begin
                if(`NUM_MULTS >= 2) begin

                    // first addition
                    if(add_idx == 0 && `NUM_MULTS >= 2) begin
                        input_a_adders      = output_z_mults[add_idx];
                        input_b_adders      = output_z_mults[add_idx + 1];
                        input_valid_adders  = 1'b1;
                        next_state          = wait_add;

                    // add product to sum of previous addition
                    end else begin
                        input_a_adders      = output_z_mults[add_idx];
                        input_b_adders      = temp_output_matrix[gain_row_idx * `NUM_COLS_OUT + states_col_idx];
                        input_valid_adders  = 1'b1;
                        next_state          = wait_add;
                    end

                end else begin // only one number, nothing to add.
                    next_temp_output_matrix[gain_row_idx * `NUM_COLS_OUT + states_col_idx] = output_z_mults;
                    move_on = 1'b1;
                end
                    
            end

            wait_add: // wait for addition to finish, and handle transition when it does finish.
            begin

                if(done_adders) begin

                    next_temp_output_matrix[gain_row_idx * `NUM_COLS_OUT + states_col_idx] = output_z_adders;

                    if(add_idx == 0) begin

                        // did we finish all additions for this past sequence?
                        if(add_idx + 2 >= `NUM_ADDS) begin
                            move_on = 1'b1;
                        end else begin // if not done, increment add_idx by 2
                            next_add_idx = add_idx + 2;
                            reset_adders = 1'b1;
                            next_state = init_add;
                        end

                    end else begin
                        // did we finish all additions for this past sequence?
                        if(add_idx + 1 >= `NUM_ADDS) begin
                            move_on = 1'b1;
                        end else begin // if not, increment add_idx by 1
                            next_add_idx = add_idx + 1;
                            reset_adders = 1'b1;
                            next_state = init_add;
                        end
                    end

                end else begin
                    next_state = wait_add;
                end
            end

            hold:
            begin
                next_output_valid = 1'b1;
                if(trigger_next_sample) begin
                    next_counter = 0;
                    next_state = sample;
                end else begin
                    next_state = hold;
                end
            end

        endcase

        if(move_on) begin
            
            next_add_idx = 0;
            // done with this current row? move on
            if(gain_row_idx + 1 >= `NUM_ROWS_GAINS) begin

                next_gain_row_idx = 0; // reset row idx

                // if done with all columns too, then we are completely done. 
                if(states_col_idx + 1 >= `NUM_COLS_STATES) begin

                    next_states_col_idx = 0; // reset column idx
                    next_state = hold;       // go to hold state

                    // update the output
                    for(int i = 0; i < `SIZE_OUT; i++) begin
                        next_output_matrix[i] = next_temp_output_matrix[i];
                    end

                end else begin // not done with current column
                    next_states_col_idx = states_col_idx + 1;
                    next_state = init_mult;
                    for (int i = 0; i < `NUM_MULTS; i++) begin
                        reset_mults[i] = 1;
                    end
                    reset_adders = 1;
                end

            end else begin // not done with current row
                next_gain_row_idx = gain_row_idx + 1;
                next_state = init_mult;
                for (int i = 0; i < `NUM_MULTS; i++) begin
                    reset_mults[i] = 1;
                end
                reset_adders = 1;
            end
        end

    end

    // one multiplication for each x,y pair
    double_multiply multipliers [`NUM_MULTS-1:0] (

        // inputs
        .input_a(input_a_mults),
        .input_b(input_b_mults),
        .input_valid(input_valid_mults),
        .clock(clock),
        .reset(reset_mults),

        // outputs
        .output_z(output_z_mults),
        .output_done(done_mults)
            
    );

    // need one less adder than number of terms being added
    double_adder adders (
        //inputs
        .input_a(input_a_adders),
        .input_b(input_b_adders),
        .input_valid(input_valid_adders),
        .clock(clock),
        .reset(reset_adders),

        //outputs
        .output_z(output_z_adders),
        .output_done(done_adders)
    );

    // sequential logic
    always_ff @(posedge clock) begin
        if(reset) begin
            state                    <= sample;
            add_idx                  <= 0;
            gain_row_idx             <= 0;
            states_col_idx           <= 0;
            latched_gains_matrix     <= 0;
            latched_states_matrix    <= 0;
            temp_output_matrix       <= 0;
            output_matrix            <= 0;
            output_valid             <= 0;
            counter                  <= 0;
        end else begin
            counter                  <= next_counter;
            state                    <= next_state;
            add_idx                  <= next_add_idx;
            gain_row_idx             <= next_gain_row_idx;
            states_col_idx           <= next_states_col_idx;
            latched_gains_matrix     <= next_latched_gains_matrix;
            latched_states_matrix    <= next_latched_states_matrix;
            temp_output_matrix       <= next_temp_output_matrix;
            output_matrix            <= next_output_matrix;
            output_valid             <= next_output_valid;
        end

    end


endmodule
`endif