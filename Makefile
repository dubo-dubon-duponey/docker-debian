DC_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Output directory
DC_PREFIX ?= $(shell pwd)

# Set to true to disable fancy / colored output
DC_NO_FANCY ?=
TARGET_DATE ?= 2021-06-01
TARGET_SUITE ?= bullseye
ICING ?=
EXTRAS ?=

# Fancy output if interactive
ifndef DC_NO_FANCY
    NC := \033[0m
    GREEN := \033[1;32m
    ORANGE := \033[1;33m
    BLUE := \033[1;34m
    RED := \033[1;31m
endif

# Helper to put out nice title
define title
	@printf "$(GREEN)----------------------------------------------------------------------------------------------------\n"
	@printf "$(GREEN)%*s\n" $$(( ( $(shell echo "☆ $(1) ☆" | wc -c ) + 100 ) / 2 )) "☆ $(1) ☆"
	@printf "$(GREEN)----------------------------------------------------------------------------------------------------\n$(ORANGE)"
endef

define footer
	@printf "$(GREEN)> %s: done!\n" "$(1)"
	@printf "$(GREEN)____________________________________________________________________________________________________\n$(NC)"
endef

retool:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	# Rebuilding local rootfs from online image
	cue --inject from_image=debian:buster-20200130-slim --inject from_tarball="nonexistent*" \
		--inject directory=$(DC_MAKEFILE_DIR)/context/debootstrap --inject platforms= \
		--inject target_date=2020-01-01 \
		${EXTRAS} \
		debootstrap $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	# Rebuilding again but this time from local rootfs
	cue \
		--inject directory=$(DC_MAKEFILE_DIR)/context/debootstrap --inject platforms= \
		--inject target_date=2020-01-01 \
		--inject target_suite=buster \
		${EXTRAS} \
		debootstrap $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

build:
	$(call title, $@)
	$(shell command -v cue > /dev/null || { echo "You need cue installed"; exit 1; })
	# Generate the actual rootfs for our debian image
	cue --inject debootstrap_date=${DEBOOTSTRAP_DATE} --inject debootstrap_suite=${DEBOOTSTRAP_SUITE} \
		${EXTRAS} \
		debootstrap $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	cue --inject debootstrap_date=${DEBOOTSTRAP_DATE} --inject debootstrap_suite=${DEBOOTSTRAP_SUITE} \
		${EXTRAS} \
		debian $(DC_MAKEFILE_DIR)/hack/recipe.cue $(DC_MAKEFILE_DIR)/hack/cue_tool.cue ${ICING}
	$(call footer, $@)

lint:
	$(call title, $@)
	$(DC_MAKEFILE_DIR)/hack/lint.sh
	$(call footer, $@)

test:
	$(call title, $@)
	$(DC_MAKEFILE_DIR)/hack/test.sh
	$(call footer, $@)
