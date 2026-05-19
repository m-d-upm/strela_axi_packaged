VIVADO = vivado
TCL_SCRIPT = cgra_axi_lite_v1_0_project.tcl
FLAGS = -mode batch -source

all: project

project:
	$(VIVADO) $(FLAGS) $(TCL_SCRIPT)

clean:
	rm -rf .Xil/ vivado*.log vivado*.jou
