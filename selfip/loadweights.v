//FILE_HEADER---------------------------------------------------------------------------------------
//ZTE  Copyright (C)
//ZTE Company Confidential
//--------------------------------------------------------------------------------------------------
//Project Name : cnna
//FILE NAME    : loadweights.v
//AUTHOR       : qiu.chao 
//Department   : Technical Planning Department/System Products/ZTE
//Email        : qiu.chao@zte.com.cn
//--------------------------------------------------------------------------------------------------
//Module Hiberarchy :
//        |--U01_loadweights
//        |--U02_axim_wddr
// cnna --|--U03_axis_reg
//        |--U04_main_process
//--------------------------------------------------------------------------------------------------
//Relaese History :
//--------------------------------------------------------------------------------------------------
//Version         Date           Author        Description
// 1.1           july-30-2019                    
//--------------------------------------------------------------------------------------------------
//Main Function:
//a)Get the data from ddr chip using axi master bus
//b)Write it to the ibuf ram
//--------------------------------------------------------------------------------------------------
//REUSE ISSUES: none
//Reset Strategy: synchronization 
//Clock Strategy: one common clock 
//Critical Timing: none 
//Asynchronous Interface: none 
//END_HEADER----------------------------------------------------------------------------------------
module loadweights #(
parameter 
    MEM_STYLE               = "block"   ,
    C_POWER_OF_1ADOTS       = 4         ,
    C_POWER_OF_PECI         = 4         ,
    C_POWER_OF_PECO         = 5         ,
    C_POWER_OF_PECODIV      = 1         ,
    C_CNV_K_WIDTH           = 8         ,
    C_CNV_CH_WIDTH          = 8         ,
    C_M_AXI_ADDR_WIDTH      = 32        ,
    C_M_AXI_DATA_WIDTH      = 128       ,
    C_RAM_ADDR_WIDTH        = 9         ,
    C_RAM_DATA_WIDTH        = 128       
)(
// clk
input                               I_clk           ,
input                               I_rst           ,
// ap 
input                               I_ap_start      ,
output reg                          O_ap_done       ,
// reg
input       [     C_CNV_K_WIDTH-1:0]I_next_kernel   ,
input       [    C_CNV_CH_WIDTH-1:0]I_next_ci       ,
input       [    C_CNV_CH_WIDTH-1:0]I_next_co       ,
input       [C_M_AXI_ADDR_WIDTH-1:0]I_next_mem_addr ,
input       [C_M_AXI_ADDR_WIDTH-1:0]I_base_addr     ,
// master read address channel
output reg  [C_M_AXI_LEN_WIDTH-1 :0]O_maxi_arlen    ,
input                               I_maxi_arready  ,   
output                              O_maxi_arvalid  ,
output reg  [C_M_AXI_ADDR_WIDTH-1:0]O_maxi_araddr   ,
// master read data channel
output reg                          O_maxi_rready   ,
input                               I_maxi_rvalid   ,
input       [C_M_AXI_DATA_WIDTH-1:0]I_maxi_rdata    
);

defparam     C_NCH_GROUP      = C_CNV_CH_WIDTH - C_POWER_OF_1ADOTS + 1  ;
defparam     C_PECO_GROUP     = C_CNV_CH_WIDTH - C_POWER_OF_PECO + 1    ;
defparam     C_FILTER_WIDTH   = C_CNV_K_WIDTH * C_CNV_K_WIDTH           ;
defparam     C_K_BLK_ID_WIDTH = C_NCH_GROUP+C_CNV_CH_WIDTH              ;
defparam     C_M1_WIDTH       = C_POWER_OF_PECI+C_NCH_GROUP             ;
defparam     C_M2_WIDTH       = C_FILTER_WIDTH+C_NCH_GROUP              ; 
defparam     C_M3_WIDTH       = C_M1_WIDTH + C_M2_WIDTH                 ;
defparam     C_DLY_WIDTH      = C_FILTER_WIDTH+C_CNV_CH_WIDTH*3+C_M_AXI_DATA_WIDTH+1;
localparam   C_AP_SHIFT       = 16                                      ;
localparam   C_PECI_NUM       = 1 << C_POWER_OF_PECI                    ; 
localparam   C_PECODIV_NUM    = 1 << C_POWER_OF_PECODIV                 ; 


wire [       C_DLY_WIDTH-1:0]S_dly                          ;
reg  [       C_DLY_WIDTH-1:0]S_1dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_2dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_3dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_4dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_5dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_6dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_7dly                         ;
reg  [       C_DLY_WIDTH-1:0]S_ndly                         ;
reg  [        C_M1_WIDTH-1:0]S_m1                           ;
reg  [        C_M2_WIDTH-1:0]S_m2                           ;
reg  [        C_M3_WIDTH-1:0]S_m3                           ;
wire [   C_POWER_OF_PECI  :0]S_peci_const                   ;
wire [C_POWER_OF_PECODIV  :0]S_pecodiv_const                ;

wire [     C_NCH_GROUP-1  :0]S_next_co_group                ;   
reg                          S_ap_start_1d                  ;

wire [     C_NCH_GROUP-1  :0]S_next_co_group                ;   
wire [  C_CNV_CH_WIDTH-1  :0]S_next_co_align                ;   
wire [    C_PECO_GROUP-1  :0]S_next_co_group_peco           ;   
wire [  C_CNV_CH_WIDTH-1  :0]S_next_co_align_peco           ;   
wire [     C_NCH_GROUP-1  :0]S_next_ci_group                ;   
wire [  C_CNV_CH_WIDTH-1  :0]S_next_ci_align                ;   
wire [  C_FILTER_WIDTH-1  :0]S_next_filter                  ;
reg  [     C_CNV_K_WIDTH-1:0]S_next_kernel_1d               ;
reg  [    C_CNV_CH_WIDTH-1:0]S_next_ci_1d                   ;
reg  [    C_CNV_CH_WIDTH-1:0]S_next_co_1d                   ;
reg  [     C_NCH_GROUP-1  :0]S_next_co_group_1d             ;   
reg  [  C_CNV_CH_WIDTH-1  :0]S_next_co_align_1d             ;   
reg  [    C_PECO_GROUP-1  :0]S_next_co_group_peco_1d        ;   
reg  [  C_CNV_CH_WIDTH-1  :0]S_next_co_align_peco_1d        ;   
reg  [     C_NCH_GROUP-1  :0]S_next_ci_group_1d             ;   
reg  [  C_CNV_CH_WIDTH-1  :0]S_next_ci_align_1d             ;   
reg  [  C_FILTER_WIDTH-1  :0]S_next_filter_1d               ;
reg  [C_K_BLK_ID_WIDTH-1 :0] S_next_ci_group_co_group_peco  ; 
reg  [       C_AP_SHIFT-1:0] S_ap_start_shift               ; 
reg                          S_ap_start_nd                  ; 
reg                          S_ap_start_sd                  ; 
wire [  C_FILTER_WIDTH-1  :0]S_filter_cnt                   ;
wire [    C_CNV_CH_WIDTH-1:0]S_cig_cnt                      ;
wire [    C_CNV_CH_WIDTH-1:0]S_ci_cnt                       ;
wire [    C_CNV_CH_WIDTH-1:0]S_cog_cnt                      ;
wire                         S_cog_valid                    ;
wire                         S_cog_over_flag                ; 
wire                         S_ci_valid                     ;
wire                         S_ci_over_flag                 ; 
wire                         S_cig_valid                    ;
wire                         S_cig_over_flag                ; 
wire                         S_filter_valid                 ;
wire                         S_filter_over_flag             ; 
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id                       ;
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id_t1                    ;
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id_t2                    ;
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id_t3                    ;
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id_t4                    ;
reg  [  C_RAM_ADDR_WIDTH-1:0]S_blk_id_t5                    ;

wire                         S_nd_co_valid                  ;
wire [C_M_AXI_DATA_WIDTH-1:0]S_nd_maxi_rdata                ;    
wire [    C_CNV_CH_WIDTH-1:0]S_nd_cnt_cog                   ;
wire [    C_CNV_CH_WIDTH-1:0]S_nd_cnt_ci                    ;
wire [    C_CNV_CH_WIDTH-1:0]S_nd_cnt_cig                   ;
wire [    C_FILTER_WIDTH-1:0]S_nd_cnt_filter                ;





////////////////////////////////////////////////////////////////////////////////////////////////////
// Calculate blk id addr
// S_blk_id = (S_filter_cnt * S_next_ci_group_co_align_peco +
//            S_cig_cnt * S_next_co_align_peco +
//            S_cog_cnt * (1<<C_POWER_OF_1ADOTS))/(PE_CO)
////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge I_clk)begin
    S_blk_id_t1 <= (S_filter_cnt * S_next_ci_group_co_group_peco);
    S_blk_id_t2 <= (S_cig_cnt * S_next_co_group_peco);  
    S_blk_id_t3 <= (S_cog_cnt[C_CNV_CH_WIDTH-1:1]);
    S_blk_id_t4 <= S_blk_id_t1 + S_blk_id_t2;
    S_blk_id_t5 <= S_blk_id_t4 + S_blk_id_t3;
    S_blk_id    <= S_blk_id_t5;
end

////////////////////////////////////////////////////////////////////////////////////////////////////
// Get the variable value 
////////////////////////////////////////////////////////////////////////////////////////////////////

assign S_peci_const    = {1'b1,(C_POWER_OF_PECI){1'b0}}; 
assign S_pecodiv_const = {1'b1,(C_POWER_OF_PECODIV){1'b0}};
assign S_next_filter = I_next_kernel * I_next_kernel ;

ceil_power_of_2 #(
    .C_DIN_WIDTH    (C_CNV_CH_WIDTH     ),
    .C_POWER2_NUM   (C_POWER_OF_PECO    ))
U0_next_co_group(
    .I_din (I_next_co           ),
    .O_dout(S_next_co_group_peco)   
);

assign S_next_co_align_peco = {S_next_co_group_peco,(C_POWER_OF_PECO){1'b0}};

ceil_power_of_2 #(
    .C_DIN_WIDTH    (C_CNV_CH_WIDTH     ),
    .C_POWER2_NUM   (C_POWER_OF_1ADOTS  ))
U0_next_co_group(
    .I_din (I_next_co       ),
    .O_dout(S_next_co_group )   
);

assign S_next_co_align = {S_next_co_group,(C_POWER_OF_1ADOTS){1'b0}};

ceil_power_of_2 #(
    .C_DIN_WIDTH    (C_CNV_CH_WIDTH     ),
    .C_POWER2_NUM   (C_POWER_OF_1ADOTS  ))
U0_next_ci_group(
    .I_din (I_next_ci       ),
    .O_dout(S_next_ci_group )   
);

assign S_next_ci_align = {S_next_ci_group,(C_POWER_OF_1ADOTS){1'b0}};

always @(posedge I_clk)begin
    S_next_kernel_1d              <= I_next_kernel                                  ;
    S_next_ci_1d                  <= I_next_ci                                      ;  
    S_next_co_1d                  <= I_next_co                                      ; 
    S_next_co_group_peco_1d       <= S_next_co_group_peco                           ;     
    S_next_co_align_peco_1d       <= S_next_co_align_peco                           ;   
    S_next_co_group_1d            <= S_next_co_group                                ;   
    S_next_co_align_1d            <= S_next_co_align                                ;   
    S_next_ci_group_1d            <= S_next_ci_group                                ;   
    S_next_ci_align_1d            <= S_next_ci_align                                ;   
    S_next_filter_1d              <= S_next_filter                                  ;
    S_ap_start_nd                 <= S_ap_start_shift[4]&&I_ap_start                ;           
    S_ap_start_sd                 <= S_ap_start_shift[12]&&I_ap_start               ;           
    S_next_ci_group_co_group_peco <= S_next_ci_group_1d * S_next_co_group_peco_1d   ;
    S_m1                          <= S_peci_const * S_next_co_group_1d              ;
    S_m2                          <= S_next_filter_1d * S_next_ci_group_1d          ;
    S_m3                          <= S_m1 * S_m3                                    ;
    O_maxi_arlen                  <= S_m3[C_M_AXI_LEN_WIDTH-1:0]                    ;
    S_ap_start_shift              <= {S_ap_start_shift[C_AP_SHIFT-2:0],I_ap_start}  ;
end

////////////////////////////////////////////////////////////////////////////////////////////////////
// master axi araddr channel 
////////////////////////////////////////////////////////////////////////////////////////////////////

axvalid_ctrl U0_arvalid(
.I_clk     (I_clk           ),
.I_ap_start(S_ap_start_nd   ),
.I_axready (I_maxi_arready  ),
.O_axvalid (O_maxi_arvalid  )
);

always @(posedge I_clk)begin
    O_maxi_araddr <= I_base_addr + I_next_mem_addr ;
end

////////////////////////////////////////////////////////////////////////////////////////////////////
// master read data channel 
////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge I_clk)begin
    if(S_ap_start_nd)begin
        O_maxi_rready <= 1'b1;
    end
    else begin
        O_maxi_rready <= 1'b0;
    end
end

assign S_cog_valid      = I_maxi_rvalid && S_ap_start_nd    ;
assign S_ci_valid       = S_cog_valid && S_cog_over_flag    ; 
assign S_cig_valid      = S_ci_valid && S_ci_over_flag      ;
assign S_filter_valid   = S_cig_valid && S_cig_over_flag    ;

cm_cnt #(
    .C_WIDTH(C_CNV_CH_WIDTH))
U0_loop1_cog_cnt (
.I_clk       (I_clk                 ),
.I_cnt_en    (S_ap_start_nd         ),
.I_cnt_valid (S_cog_valid           ),
.I_cnt_upper (S_next_co_group_1d    ),
.I_over_flag (S_cog_over_flag       ),
.O_cnt       (S_cog_cnt             )
);

cm_cnt #(
    .C_WIDTH(C_CNV_CH_WIDTH))
U0_loop2_ci_cnt (
.I_clk       (I_clk                 ),
.I_cnt_en    (S_ap_start_nd         ),
.I_cnt_valid (S_ci_valid            ),
.I_cnt_upper (S_peci_const          ),
.I_over_flag (S_ci_over_flag        ),
.O_cnt       (S_ci_cnt              )
);

cm_cnt #(
    .C_WIDTH(C_CNV_CH_WIDTH))
U0_loop3_cig_cnt (
.I_clk       (I_clk                 ),
.I_cnt_en    (S_ap_start_nd         ),
.I_cnt_valid (S_cig_valid           ),
.I_cnt_upper (S_next_ci_group_1d    ),
.I_over_flag (S_cig_over_flag       ),
.O_cnt       (S_cig_cnt             )
);

cm_cnt #(
    .C_WIDTH(C_FILTER_WIDTH))
U0_loop4_filter_cnt (
.I_clk       (I_clk                 ),
.I_cnt_en    (S_ap_start_nd         ),
.I_cnt_valid (S_filter_valid        ),
.I_cnt_upper (S_next_filter_1d      ),
.I_over_flag (S_filter_over_flag    ),
.O_cnt       (S_filter_cnt          )
);

assign S_dly[0]                                                                                        = S_co_valid     ;
assign S_dly[C_M_AXI_DATA_WIDTH                                :                                    1] = I_maxi_rdata   ; 
assign S_dly[C_M_AXI_DATA_WIDTH+C_CNV_CH_WIDTH                 :                 C_M_AXI_DATA_WIDTH+1] = S_cog_cnt      ; 
assign S_dly[C_M_AXI_DATA_WIDTH+2*C_CNV_CH_WIDTH               :  C_M_AXI_DATA_WIDTH+C_CNV_CH_WIDTH+1] = S_ci_cnt       ; 
assign S_dly[C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH               :C_M_AXI_DATA_WIDTH+2*C_CNV_CH_WIDTH+1] = S_cig_cnt      ; 
assign S_dly[C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH+C_FILTER_WIDTH:C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH+1] = S_filter_cnt   ; 

always @(posedge I_clk)begin
    S_1dly <=  S_dly;
    S_2dly <= S_1dly;
    S_3dly <= S_2dly;
    S_4dly <= S_3dly;
    S_5dly <= S_4dly;
    S_6dly <= S_5dly;
    S_7dly <= S_6dly;
    S_ndly <= S_7dly;
end

assign S_nd_co_valid       = S_ndly[0]                                                                                        ;
assign S_nd_maxi_rdata     = S_ndly[C_M_AXI_DATA_WIDTH                                :                                    1] ; 
assign S_nd_cnt_cog        = S_ndly[C_M_AXI_DATA_WIDTH+C_CNV_CH_WIDTH                 :                 C_M_AXI_DATA_WIDTH+1] ; 
assign S_nd_cnt_ci         = S_ndly[C_M_AXI_DATA_WIDTH+2*C_CNV_CH_WIDTH               :  C_M_AXI_DATA_WIDTH+C_CNV_CH_WIDTH+1] ; 
assign S_nd_cnt_cig        = S_ndly[C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH               :C_M_AXI_DATA_WIDTH+2*C_CNV_CH_WIDTH+1] ; 
assign S_nd_cnt_filter     = S_ndly[C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH+C_FILTER_WIDTH:C_M_AXI_DATA_WIDTH+3*C_CNV_CH_WIDTH+1] ; 

genvar ci_idx;
genvar co_idx;

wire [       C_DLY_WIDTH-1:0]S_dly                          ;
wire S_wren[C_PECI_NUM-1:0][C_PECODIV_NUM-1:0]              ;


generate
    for(ci_idx=0;ci_idx<S_peci_const;ci_idx=ci_idx+1'b1)
    begin:wbuf_ci_ctrl
        for(co_idx=0;co_idx<S_pecodiv_const;co_idx=co_idx+1'b1)
        begin:wbuf_co_ctrl
            assign S_wren[ci_idx][co_idx] =  (co_idx == S_nd_cnt_cog[0]) && (ci_idx == S_nd_cnt_ci );       
            spram #(
                .MEM_STYLE  ("block"                 ),//"distributed"
                .ASIZE      (C_RAM_ADDR_WIDTH        ),
                .DSIZE      (C_RAM_DATA_WIDTH        ))
            u_wbuf(
                .I_clk  (I_clk                                      ),
                .I_addr	(S_blk_id                                   ),
                .I_data	(S_nd_maxi_rdata                            ),
                .I_wr	(S_nd_co_valid && S_wren[ci_idx][co_idx]    ),
                .O_data	(                                           )
            );
        end
    end
endgenerate

////////////////////////////////////////////////////////////////////////////////////////////////////
// Get the varance value 
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Naming specification                                                                         
// (1) w+"xxx" name type , means write clock domain                                             
//        such as wrst,wclk,winc,wdata, wptr, waddr,wfull, and so on                            
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                
//    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __
// __|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  
//                                                                                                
//                                                                                                
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
//        u0_wptr_full                                                                           
////////////////////////////////////////////////////////////////////////////////////////////////////

endmodule
