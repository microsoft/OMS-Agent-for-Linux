# -*- mode: Makefile; -*- 

#-------------------------------------------------------------------------------
# 2015-08-14
#-------------------------------------------------------------------------------

BASE_DIR := $(subst /build,,$(PWD))
OMI_ROOT := $(shell cd ../../omi/Unix; pwd -P)
SCXPAL_DIR := $(shell cd ../../pal; pwd -P)

RUBY_DEST_DIR := $(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)

PF_POSIX := 1
include $(SCXPAL_DIR)/build/config.mak
include $(BASE_DIR)/build/config.mak
#include $(BASE_DIR)/build/Makefile.version
include $(SCXPAL_DIR)/build/Makefile.pal

ifndef ENABLE_DEBUG
$(error "ENABLE_DEBUG is not set.  Please re-run configure")
endif

RUBY_DIR := $(BASE_DIR)/source/ext/ruby
FLUENTD_DIR := $(BASE_DIR)/source/ext/fluentd

INTERMEDIATE_DIR=$(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)
TARGET_DIR := $(BASE_DIR)/target/$(BUILD_CONFIGURATION)

# Support for installbuilder

STAGING_DIR := $(TARGET_DIR)/staging

#--------------------------------------------------------------------------------
# Build targets

all : $(RUBY_DEST_DIR)

$(RUBY_DEST_DIR) :
	#
	# Warning: This step will clean out checked out files from both Ruby and fluentd directories
	#
	$(BASE_DIR)/build/buildRuby.sh

clean :
	$(RMDIR) $(BASE_DIR)/installer/intermediate $(BASE_DIR)/target
	sudo $(RMDIR) $(BASE_DIR)/intermediate
	-find $(BASE_DIR) -name \*~ -exec rm {} \;

distclean : clean
	$(RM) $(BASE_DIR)/build/config.mak
	sudo $(RMDIR) $(RUBY_DIR)/.ext
	#
	# Warning: This step will clean out checked out files from Ruby directory
	#
	@echo "Cleaning RUBY source directory ..."
	find $(RUBY_DIR) -type f -perm -u+w -exec rm -f {} \;
	#
	# Warning: This step will clean out checked out files from fluentd directory
	#
	@echo "Cleaning fluentd source directory ..."
	find $(FLUENTD_DIR) -type f -perm -u+w -print -exec rm {} \;
	#
	# -make -C $(OMI_ROOT) distclean
	# -make -C $(SCXPAL_DIR)/build distclean
	# -$(RMDIR) $(OMI_ROOT)/output*
	-$(RM) $(SCXPAL_DIR)/build/config.mak
