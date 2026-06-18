`timescale 1ns / 1ps

`define HEADER 1080
`define W      512
`define H      512
`define IMG_SZ (`W*`H)

module TESTBENCH;

    // clock & reset
    reg        clk;
    reg        axi_reset_n;

    // input stream
    reg  [7:0] imgData;
    reg        imgDataValid;

    // output stream
    wire [7:0] outData;
    wire       outDataValid;

    // control
    wire intr;

    // bookkeeping (TB ONLY)
    integer file_i, file_o;
    integer i;
    integer sent_lines;
    integer recv_pixels;

    // -------------------------------------------------
    // CLOCK: 100 MHz
    // -------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------
    // STIMULUS
    // -------------------------------------------------
    initial begin
        imgDataValid = 0;
        imgData      = 0;
        sent_lines   = 0;
        recv_pixels  = 0;

        // ACTIVE-LOW RESET
        axi_reset_n = 0;
        #100;
        axi_reset_n = 1;
        #100;

        // open files
        file_i = $fopen("lena_gray.bmp", "rb");
        file_o = $fopen("blurred_lena.bmp", "wb");

        if (file_i == 0) begin
            $display("ERROR: input image not found");
            $finish;
        end

        // -------------------------------------------------
        // COPY BMP HEADER
        // -------------------------------------------------
        for (i = 0; i < `HEADER; i = i + 1) begin
            $fscanf(file_i, "%c", imgData);
            $fwrite(file_o, "%c", imgData);
        end

        // -------------------------------------------------
        // START STREAMING (VALID STAYS HIGH FOREVER)
        // -------------------------------------------------
        imgDataValid = 1'b1;

        // -------------------------------------------------
        // PRIME PIPELINE : 4 FULL LINES
        // -------------------------------------------------
        for (i = 0; i < 4*`W; i = i + 1) begin
            @(posedge clk);
            $fscanf(file_i, "%c", imgData);
        end
        sent_lines = 4;

        // -------------------------------------------------
        // MAIN IMAGE (LINE-DRIVEN BY o_intr)
        // -------------------------------------------------
        while (sent_lines < `H) begin
            @(posedge intr);   // request for next line

            for (i = 0; i < `W; i = i + 1) begin
                @(posedge clk);
                $fscanf(file_i, "%c", imgData);
            end

            sent_lines = sent_lines + 1;
        end

        // -------------------------------------------------
        // FLUSH PIPELINE : 2 ZERO LINES
        // -------------------------------------------------
        repeat (2) begin
            @(posedge intr);
            for (i = 0; i < `W; i = i + 1) begin
                @(posedge clk);
                imgData <= 8'd0;
            end
        end

        $fclose(file_i);
    end

    // -------------------------------------------------
    // CAPTURE OUTPUT
    // -------------------------------------------------
    always @(posedge clk) begin
        if (outDataValid) begin
            $fwrite(file_o, "%c", outData);
            recv_pixels = recv_pixels + 1;
        end

        if (recv_pixels == `IMG_SZ) begin
            $display("DONE: received %0d pixels", recv_pixels);
            $fclose(file_o);
            $stop;
        end
    end

    // -------------------------------------------------
    // DUT
    // -------------------------------------------------
    imageProcessTop dut (
        .axi_clk        (clk),
        .axi_reset_n    (axi_reset_n),

        // input
        .i_data_valid   (imgDataValid),
        .i_data         (imgData),
        .o_data_ready   (),

        // output
        .o_data_valid   (outDataValid),
        .o_data         (outData),
        .i_data_ready   (1'b1),

        // control
        .o_intr         (intr)
    );

endmodule