`ifndef DOUBLE_MULTIPLY_SV
`define DOUBLE_MULTIPLY_SV
//Original Version:
//IEEE Floating Point Multiplier (Double Precision)
//Copyright (C) Jonathan P Dawson 2014
//2014-01-10
//Found here: https://github.com/dawsonjon/fpu

//NOTE: DISCLAIMER
//We took this double precision floating point unit (FPU) from an online source since they are difficult to design properly. 
//They are very complex and small errors can result in subtle errors that are difficult to debug.
//The focus of this project isn't on the microarchitecture of floating point multiplication!
//Spending substantial effort designing an FPU would have taken away from the "control" aspect of the project.
//The goal is to use this FPU to demonstrate that dedicated compute hardware can be useful for controls projects.

//The original version of the FPU was modified to better fit this project.
//Scott Smith used this FPU in a project for another course as well.
//Very little work was done on this FPU specifically for this class.
//However, the matrix multiplication hardware that utilizes this FPU was designed specifically for this course.

module double_multiply (

// inputs
    input   logic [63:0]  input_a,
    input   logic [63:0]  input_b,
    input   logic         input_valid,
    input   logic         clock,
    input   logic         reset,

    // outputs
    output  logic [63:0]  output_z,
    output  logic         output_done
        
);

  logic       [63:0] z, next_z;

  logic       [3:0] state, next_state;
  parameter 
            unpack        = 4'd0,
            special_cases = 4'd1,
            normalise     = 4'd2,
            multiply_0    = 4'd3,
            multiply_1    = 4'd4,
            normalise_1   = 4'd5,
            normalise_2   = 4'd6,
            round         = 4'd7,
            pack          = 4'd8,
            put_z         = 4'd9,
            standby       = 4'd10;

  logic       [63:0] a, b;
  logic       [52:0] a_m, b_m, z_m, next_a_m, next_b_m, next_z_m;
  logic       [12:0] a_e, b_e, z_e, next_a_e, next_b_e, next_z_e;
  logic       a_s, b_s, z_s, next_a_s, next_b_s, next_z_s;
  logic       guard, round_bit, sticky, next_guard, next_round_bit, next_sticky;
  logic       [107:0] product, next_product;

  assign a = input_a;
  assign b = input_b;
  logic [5:0] shift_counter_a, shift_counter_b;

    always_comb
    begin

        next_state = state;
        next_a_m = a_m;
        next_a_e = a_e;
        next_a_s = a_s;
        next_b_e = b_e;
        next_b_m = b_m;
        next_b_s = b_s;
        next_guard = guard;
        next_product = product;
        next_round_bit = round_bit;
        next_sticky = sticky;
        next_z = z;
        next_z_e = z_e;
        next_z_m = z_m;
        next_z_s = z_s;
        shift_counter_a = 0;
        shift_counter_b = 0;

        case(state)

            unpack:
            begin
                if(input_valid) begin
                next_a_m = a[51 : 0];
                next_b_m = b[51 : 0];
                next_a_e = a[62 : 52] - 1023;
                next_b_e = b[62 : 52] - 1023;
                next_a_s = a[63];
                next_b_s = b[63];
                next_state = special_cases;
                end
            end

            special_cases:
            begin
                //if a is NaN or b is NaN return NaN 
                if ((a_e == 1024 && a_m != 0) ||
                    (b_e == 1024 && b_m != 0)) begin

                    next_z[63]     = 1;
                    next_z[62:52]  = 2047;
                    next_z[51]     = 1;
                    next_z[50:0]   = 0;
                    next_state     = put_z;

                //if a is inf return inf
                end else if (a_e == 1024) begin

                    next_z[63]     = a_s ^ b_s;
                    next_z[62:52]  = 2047;
                    next_z[51:0]   = 0;
                    next_state     = put_z;

                    //if b is zero return NaN
                    if (($signed(b_e) == -1023) && (b_m == 0)) begin

                        next_z[63]     = 1;
                        next_z[62:52]  = 2047;
                        next_z[51]     = 1;
                        next_z[50:0]   = 0;
                        next_state     = put_z;
        
                    end

                //if b is inf return inf
                end else if (b_e == 1024) begin

                    next_z[63]     = a_s ^ b_s;
                    next_z[62:52]  = 2047;
                    next_z[51:0]   = 0;

                    //if b is zero return NaN
                    if (($signed(a_e) == -1023) && (a_m == 0)) begin
                        next_z[63]     = 1;
                        next_z[62:52]  = 2047;
                        next_z[51]     = 1;
                        next_z[50:0]   = 0;
                        next_state     = put_z;
                    end

                    next_state = put_z;

                //if a is zero return zero
                end else if (($signed(a_e) == -1023) && (a_m == 0)) begin
                    next_z[63] = a_s ^ b_s;
                    next_z[62:52] = 0;
                    next_z[51:0] = 0;
                    next_state = put_z;
                //if b is zero return zero
                end else if (($signed(b_e) == -1023) && (b_m == 0)) begin
                    next_z[63] = a_s ^ b_s;
                    next_z[62:52] = 0;
                    next_z[51:0] = 0;
                    next_state = put_z;
                end else begin
                //Denormalised Number
                if ($signed(a_e) == -1023) 
                begin
                    next_a_e = -1022;
                end else begin
                    next_a_m[52] = 1;
                end
                //Denormalised Number
                if ($signed(b_e) == -1023) begin
                    next_b_e = -1022;
                end else begin
                    next_b_m[52] = 1;
                end

                next_state = normalise;

                end

            end

            normalise:
            begin
                if(!a_m[52]) begin
                    for(int i = 52; i >= 0; i--) begin
                        if(a_m[i] == 1) begin
                            shift_counter_a = 52-i;
                            break;
                        end
                    end
                end
                
                if(!b_m[52]) begin
                    for(int i = 52; i >= 0; i--) begin
                        if(b_m[i] == 1) begin
                            shift_counter_b = 52-i;
                            break;
                        end
                    end
                end
                
                next_a_m = a_m << shift_counter_a;
                next_a_e = a_e - shift_counter_a;
                
                next_b_m = b_m << shift_counter_b;
                next_b_e = b_e - shift_counter_b;
                
                next_state = multiply_0;
                
            end

            multiply_0:
            begin
                next_z_s = a_s ^ b_s;
                next_z_e = a_e + b_e + 1;
                next_product = a_m * b_m * 4;
                next_state = multiply_1;
            end

            multiply_1:
            begin
                next_z_m = product[107:55];
                next_guard = product[54];
                next_round_bit = product[53];
                next_sticky = (product[52:0] != 0);
                next_state = normalise_1;
            end

            normalise_1:
            begin
                if (z_m[52] == 0) begin
                    next_z_e = z_e - 1;
                    next_z_m = z_m << 1;
                    next_z_m[0] = guard;
                    next_guard = round_bit;
                    next_round_bit = 0;
                end else begin
                    next_state = normalise_2;
                end
            end

            normalise_2:
            begin
                if ($signed(z_e) < -1022) begin
                    next_z_e = z_e + 1;
                    next_z_m = z_m >> 1;
                    next_guard = z_m[0];
                    next_round_bit = guard;
                    next_sticky = sticky | round_bit;
                end else begin
                    next_state = round;
                end
            end

            round:
            begin
                if (guard && (round_bit | sticky | z_m[0])) begin
                    next_z_m = z_m + 1;
                    if (z_m == 53'h1fffffffffffff) begin
                        next_z_e =z_e + 1;
                    end
                end
                next_state = pack;
            end

            pack:
            begin
                next_z[51 : 0] = z_m[51:0];
                next_z[62 : 52] = z_e[11:0] + 1023;
                next_z[63] = z_s;

                if ($signed(z_e) == -1022 && z_m[52] == 0) begin
                    next_z[62 : 52] = 0;
                end

                //if overflow occurs, return inf
                if ($signed(z_e) > 1023) begin
                    next_z[51 : 0] = 0;
                    next_z[62 : 52] = 2047;
                    next_z[63] = z_s;
                end

                next_state = standby;
            end

            standby:
            begin
            end

        endcase

    end 

    always_ff @(posedge clock) 
    begin
        if(reset) begin
            state <= unpack;
            a_m <= 0;
            a_e <= 0;
            a_s <= 0;
            b_e <= 0;
            b_m <= 0;
            b_s <= 0;
            guard <= 0;
            product <= 0;
            round_bit <= 0;
            state <= 0;
            sticky <= 0;
            z <= 0;
            z_e <= 0;
            z_m <= 0;
            z_s <= 0;
        end else begin
            state <= next_state;
            a_m <= next_a_m;
            a_e <= next_a_e;
            a_s <= next_a_s;
            b_e <= next_b_e;
            b_m <= next_b_m;
            b_s <= next_b_s;
            guard <= next_guard;
            product <= next_product;
            round_bit <= next_round_bit;
            sticky <= next_sticky;
            z <= next_z;
            z_e <= next_z_e;
            z_m <= next_z_m;
            z_s <= next_z_s;
        end
    end

    assign output_done = (state == standby);
    assign output_z = z;

endmodule


`endif