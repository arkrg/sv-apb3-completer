# make run MODE=ALWAYS     # ALWAYS_READY 모드로 컴파일 + 실행
# make run MODE=RANDOM     # RANDOM_DELAY 모드로 컴파일 + 실행
# make both                # 두 모드를 연달아 실행
# make wave
# make clean
SHELL := /bin/bash
ROOT  := $(CURDIR)
BUILD := build
TOP   := tb_top

# 허용 모드 목록과 모드별 READY_MODE 값 (enum: RANDOM=0, ALWAYS=1)
ALL_MODES    := ALWAYS RANDOM
READY_ALWAYS := 1
READY_RANDOM := 0

MODE   ?= ALWAYS
SNAP   := $(TOP)_$(MODE)_snap
SIMLOG := $(TOP)_$(MODE).log
SRCS    :=  $(wildcard pkg/*.sv) $(wildcard ext/*.sv) $(wildcard rtl/*.sv) $(wildcard tb/$(TOP).sv)

.PHONY: all check compile sim run both clean wave
all: run

# MODE가 목록에 없으면 여기서 중단
check:
	$(if $(filter $(MODE),$(ALL_MODES)),,$(error MODE='$(MODE)' 은 허용되지 않음. 가능한 값: $(ALL_MODES)))

compile: check
	mkdir -p $(BUILD)
	cd $(BUILD) && xvlog -sv $(INCDIRS) $(addprefix ../,$(SRCS)) -log xvlog.log > /dev/null
	cd $(BUILD) && xelab -debug typical -generic_top "READY_MODE=$(READY_$(MODE))" -s $(SNAP) work.$(TOP) -log xelab_$(MODE).log > /dev/null

sim: check
	@echo Simulation Start, mode: $(MODE)
	@cd $(BUILD) && xsim $(SNAP) -R -log $(SIMLOG) > /dev/null
	@grep -E '\[(PASS|FAIL)\]|MISMATCH|ERROR|RESULT|COVER|DEBUG' $(BUILD)/$(SIMLOG) || true

run: compile sim

both:
	@for m in $(ALL_MODES); do $(MAKE) --no-print-directory run MODE=$$m || exit 1; done

clean:
	rm -rf $(BUILD)/*

wave:
	gtkwave $(BUILD)/*.vcd &
