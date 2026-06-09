// Module for CGRA integration in the target platform
//
// Interfaces:
// - AXI Master port for DMA, AXI Slave port for configuration
// - Clock and Reset
//
// Includes:
// - Strela CGRA
// - Custom DMA Interface
// - Control-Status Registers
// - Miscelaneous protocol adapters

`include "register_interface_assign.svh"
`include "register_interface_typedef.svh"

module axi_cgra_top #(
    parameter int unsigned AXI_ADDR_WIDTH_M      = -1,
    parameter int unsigned AXI_DATA_WIDTH_M      = -1,
    parameter int unsigned AXI_ADDR_WIDTH_S      = -1,
    parameter int unsigned AXI_DATA_WIDTH_S      = -1
    ) (
    input logic clk_i,
    input logic rst_ni,
   
   	// Ports of Axi Slave Bus Interface S00_AXI
    input logic [AXI_ADDR_WIDTH_S-1 : 0] s00_axi_awaddr,
    input logic [2 : 0] s00_axi_awprot,
    input logic  s00_axi_awvalid,
    output logic  s00_axi_awready,
    input logic [AXI_DATA_WIDTH_S-1 : 0] s00_axi_wdata,
    input logic [(AXI_DATA_WIDTH_S/8)-1 : 0] s00_axi_wstrb,
    input logic  s00_axi_wvalid,
    output logic  s00_axi_wready,
    output logic [1 : 0] s00_axi_bresp,
    output logic  s00_axi_bvalid,
    input logic  s00_axi_bready,
    input logic [AXI_ADDR_WIDTH_S-1 : 0] s00_axi_araddr,
    input logic [2 : 0] s00_axi_arprot,
    input logic  s00_axi_arvalid,
    output logic  s00_axi_arready,
    output logic [AXI_DATA_WIDTH_S-1 : 0] s00_axi_rdata,
    output logic [1 : 0] s00_axi_rresp,
    output logic  s00_axi_rvalid,
    input logic  s00_axi_rready,
    // Ports of Axi Master Bus Interface M00_AXI
    output logic [AXI_ADDR_WIDTH_M-1 : 0] m00_axi_awaddr,
    output logic [2 : 0] m00_axi_awprot,
    output logic  m00_axi_awvalid,
    input logic  m00_axi_awready,
    output logic [AXI_DATA_WIDTH_M-1 : 0] m00_axi_wdata,
    output logic [AXI_DATA_WIDTH_M/8-1 : 0] m00_axi_wstrb,
    output logic  m00_axi_wvalid,
    input logic  m00_axi_wready,
    input logic [1 : 0] m00_axi_bresp,
    input logic  m00_axi_bvalid,
    output logic  m00_axi_bready,
    output logic [AXI_ADDR_WIDTH_M-1 : 0] m00_axi_araddr,
    output logic [2 : 0] m00_axi_arprot,
    output logic  m00_axi_arvalid,
    input logic  m00_axi_arready,
    input logic [AXI_DATA_WIDTH_M-1 : 0] m00_axi_rdata,
    input logic [1 : 0] m00_axi_rresp,
    input logic  m00_axi_rvalid,
    output logic  m00_axi_rready,
    output logic[1:0]  int_lines, // two - one to signal exec done index [1], other to signal config loading done index [0]
    output logic int_line_shared // shared IRQ, combined int_lines from above, ok to be shared since config and exec operations should be executed sequentially
);

  localparam INPUT_NODES_NUM = 4;
  localparam OUTPUT_NODES_NUM = 4;

  // define types regbus_req_t, regbus_rsp_t
  `REG_BUS_TYPEDEF_ALL(regbus, logic[31:0], logic[31:0], logic[3:0])
  regbus_req_t regbus_req;
  regbus_rsp_t regbus_rsp;

  REG_BUS #(
      .ADDR_WIDTH ( 32 ),
      .DATA_WIDTH ( 32 )
  ) reg_bus (clk_i);

  `REG_BUS_ASSIGN_TO_REQ(regbus_req, reg_bus)
  `REG_BUS_ASSIGN_FROM_RSP(reg_bus, regbus_rsp)

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH_S        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH_S        )
  ) axi_slave_port();
  
  // Write Address Channel
  assign axi_slave_port.aw_addr  = s00_axi_awaddr;
  assign axi_slave_port.aw_prot  = s00_axi_awprot;
  assign axi_slave_port.aw_valid = s00_axi_awvalid;
  assign s00_axi_awready        = axi_slave_port.aw_ready;
    
  // Write Data Channel
  assign axi_slave_port.w_data   = s00_axi_wdata;
  assign axi_slave_port.w_strb   = s00_axi_wstrb;
  assign axi_slave_port.w_valid  = s00_axi_wvalid;
  assign s00_axi_wready         = axi_slave_port.w_ready;
    
  // Write Response Channel
  assign s00_axi_bresp          = axi_slave_port.b_resp;
  assign s00_axi_bvalid         = axi_slave_port.b_valid;
  assign axi_slave_port.b_ready  = s00_axi_bready;
    
  // Read Address Channel
  assign axi_slave_port.ar_addr  = s00_axi_araddr;
  assign axi_slave_port.ar_prot  = s00_axi_arprot;
  assign axi_slave_port.ar_valid = s00_axi_arvalid;
  assign s00_axi_arready        = axi_slave_port.ar_ready;
    
  // Read Data Channel
  assign s00_axi_rdata          = axi_slave_port.r_data;
  assign s00_axi_rresp          = axi_slave_port.r_resp;
  assign s00_axi_rvalid         = axi_slave_port.r_valid;
  assign axi_slave_port.r_ready  = s00_axi_rready;

  axi_lite_to_reg_intf #(
    .ADDR_WIDTH(AXI_ADDR_WIDTH_S),
    .DATA_WIDTH(AXI_DATA_WIDTH_S)
  ) i_axi_lite_to_reg_intf (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .axi_i(axi_slave_port),
    .reg_o(reg_bus)
  );

  AXI_LITE #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH_M        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH_M        )
  ) axi_master_port();

  // Write Address Channel (Master Outputs)
  assign m00_axi_awaddr         = axi_master_port.aw_addr;
  assign m00_axi_awprot         = axi_master_port.aw_prot;
  assign m00_axi_awvalid        = axi_master_port.aw_valid;
  assign axi_master_port.aw_ready = m00_axi_awready;
    
  // Write Data Channel (Master Outputs)
  assign m00_axi_wdata          = axi_master_port.w_data;
  assign m00_axi_wstrb          = axi_master_port.w_strb;
  assign m00_axi_wvalid         = axi_master_port.w_valid;
  assign axi_master_port.w_ready  = m00_axi_wready;
    
  // Write Response Channel (Master Inputs)
  assign axi_master_port.b_resp   = m00_axi_bresp;
  assign axi_master_port.b_valid  = m00_axi_bvalid;
  assign m00_axi_bready         = axi_master_port.b_ready;
    
  // Read Address Channel (Master Outputs)
  assign m00_axi_araddr         = axi_master_port.ar_addr;
  assign m00_axi_arprot         = axi_master_port.ar_prot;
  assign m00_axi_arvalid        = axi_master_port.ar_valid;
  assign axi_master_port.ar_ready = m00_axi_arready;
    
  // Read Data Channel (Master Inputs)
  assign axi_master_port.r_data   = m00_axi_rdata;
  assign axi_master_port.r_resp   = m00_axi_rresp;
  assign axi_master_port.r_valid  = m00_axi_rvalid;
  assign m00_axi_rready         = axi_master_port.r_ready;

  logic [31:0] data_input_addr  [ INPUT_NODES_NUM-1:0];
  logic [31:0] data_input_size  [ INPUT_NODES_NUM-1:0];
  logic [31:0] data_input_stride[ INPUT_NODES_NUM-1:0];

  logic [31:0] data_config_addr;
  logic [15:0] data_config_size;

  logic [31:0] data_output_addr [OUTPUT_NODES_NUM-1:0];
  logic [31:0] data_output_size [OUTPUT_NODES_NUM-1:0];
  logic done_exec, done_config;
  logic csr_execute_input_output;
  logic csr_load_config;

  logic reset_state_machines;
  logic [31:0] test_cycle_count;

  logic clear_cgra_config, clear_cgra_state;

  logic output_arbiter_hold;

  logic [1:0] clear_interrupt_lines;
  logic [1:0] interrupt_lines;
  logic interrupt_line_shared;

  logic [31:0] cycle_count_load_config, cycle_count_execute, cycle_count_stall;

  dma_config_csr #(
      .reg_req_t(regbus_req_t),
      .reg_rsp_t(regbus_rsp_t)
  ) i_dma_config_csr (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .reg_req_i(regbus_req),
      .reg_rsp_o(regbus_rsp),

      .data_input_addr_o  (data_input_addr),
      .data_input_size_o  (data_input_size),
      .data_input_stride_o(data_input_stride),
      .data_config_addr_o (data_config_addr),
      .data_config_size_o (data_config_size),
      .data_output_addr_o (data_output_addr),
      .data_output_size_o (data_output_size),

      .done_exec_output_i  (done_exec),
      .done_config_i       (done_config),
      .start_execution_o   (csr_execute_input_output),
      .load_configuration_o(csr_load_config),

      // Performance counters
      .cycle_count_load_config_i(cycle_count_load_config),
      .cycle_count_execute_i    (cycle_count_execute),
      .cycle_count_stall_i      (cycle_count_stall),

      .clear_cgra_config_o(clear_cgra_config),
      .clear_cgra_state_o (clear_cgra_state),

      .reset_state_machines_o (reset_state_machines),
      .output_arbiter_hold_o  (output_arbiter_hold),
      .clear_interrupt_lines_o(clear_interrupt_lines),
      .pending_interrupts_i   (interrupt_lines)
  );


  logic control_execute_config, control_execute_input, control_execute_output;
  logic counters_read_stall, counters_write_stall;

  control_unit i_control_unit (
      // Clock and reset
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // From CSR
      .start_execution_i(csr_execute_input_output),
      .load_configuration_i(csr_load_config),

      // Control signals
      .execute_config_o(control_execute_config),
      .execute_input_o (control_execute_input),
      .execute_output_o(control_execute_output),

      // Input signals
      .data_config_done_i(done_config),
      .data_output_done_i(done_exec),

      .data_read_stall_i (counters_read_stall),
      .data_write_stall_i(counters_write_stall),

      // Performance counters
      .cycle_count_load_config_o(cycle_count_load_config),
      .cycle_count_execute_o    (cycle_count_execute),
      .cycle_count_stall_o      (cycle_count_stall)

  );

  logic [AXI_DATA_WIDTH_M*INPUT_NODES_NUM-1:0] cgra_data_input_data;
  logic [INPUT_NODES_NUM-1:0] cgra_data_input_valid;
  logic [INPUT_NODES_NUM-1:0] cgra_data_input_ready;

  logic [AXI_DATA_WIDTH_M*OUTPUT_NODES_NUM-1:0] cgra_data_output_data;
  logic [OUTPUT_NODES_NUM-1:0] cgra_data_output_valid;
  logic [OUTPUT_NODES_NUM-1:0] cgra_data_output_ready;

  logic [3:0] config_enable;

  dma_interface #(
    .DATA_WIDTH(AXI_DATA_WIDTH_M)
  ) i_dma_interface (
      .clk_i(clk_i),
      .rst_ni(!(!rst_ni | reset_state_machines)),
      .axi_master_port(axi_master_port),

      // Execute
      .execute_input_i (control_execute_input),
      .execute_output_i(control_execute_output),
      .execute_config_i(control_execute_config),

      // CGRA input data signals
      .data_input_o       (cgra_data_input_data),
      .data_input_valid_o (cgra_data_input_valid),
      .data_input_ready_i (cgra_data_input_ready),
      .data_input_addr_i  (data_input_addr),
      .data_input_size_i  (data_input_size),
      .data_input_stride_i(data_input_stride),

      // CGRA config data signals
      .data_config_addr_i  (data_config_addr),
      .data_config_size_i  (data_config_size),
      .data_config_done_o  (done_config),

      // CGRA output data signals
      .data_output_i        (cgra_data_output_data),
      .data_output_valid_i  (cgra_data_output_valid),
      .data_output_ready_o  (cgra_data_output_ready),
      .data_output_addr_i   (data_output_addr),
      .data_output_size_i   (data_output_size),
      .data_output_done_o   (done_exec),
      .output_arbiter_hold_i(output_arbiter_hold),

      .output_config_enable (config_enable),

      // For stall cycle calculation
      .input_outst_fifo_full_o (counters_read_stall),
      .output_outst_fifo_full_o(counters_write_stall)
  );

  cgra #(
      .DATA_WIDTH(AXI_DATA_WIDTH_M)
  ) cgra_i (
      .clk_i             (clk_i),
      .rst_ni            (!(!rst_ni | clear_cgra_config)),   // Reset internal state
      .clr_i             (clear_cgra_state),
      .din_i           (cgra_data_input_data),
      .din_v_i     (cgra_data_input_valid),
      .din_r_o     (cgra_data_input_ready),
      .dout_o          (cgra_data_output_data),
      .dout_v_o    (cgra_data_output_valid),
      .dout_r_i    (cgra_data_output_ready),
      .conf_en_i         (config_enable)
  );

  interrupt_controller int_ctrl_conf (
      .clk_i          (clk_i),
      .rst_ni         (!(!rst_ni | clear_interrupt_lines[0])),
      .event_started_i(csr_load_config),
      .event_done_i   (done_config),
      .int_line_o     (interrupt_lines[0])
  );

  interrupt_controller int_ctrl_exec (
      .clk_i          (clk_i),
      .rst_ni         (!(!rst_ni | clear_interrupt_lines[1])),
      .event_started_i(csr_execute_input_output),
      .event_done_i   (done_exec),
      .int_line_o     (interrupt_lines[1])
  );

  assign interrupt_line_shared = interrupt_lines[0] | interrupt_lines[1];

  assign int_lines = interrupt_lines;
  assign int_line_shared = interrupt_line_shared;

endmodule
