# -*- mode: Makefile; -*- 

#-------------------------------------------------------------------------------
# 2015-08-14
#-------------------------------------------------------------------------------

BASE_DIR := $(subst /build,,$(PWD))
OMI_ROOT := $(shell cd ../../omi/Unix; pwd -P)
SCXPAL_DIR := $(shell cd ../../pal; pwd -P)

PF_POSIX := 1
include $(SCXPAL_DIR)/build/config.mak
include $(BASE_DIR)/build/config.mak
#include $(BASE_DIR)/build/Makefile.version
include $(SCXPAL_DIR)/build/Makefile.pal

ifndef ENABLE_DEBUG
$(error "ENABLE_DEBUG is not set.  Please re-run configure")
endif

RUBY_DIR := $(BASE_DIR)/source/ext/ruby

INTERMEDIATE_DIR=$(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)
TARGET_DIR := $(BASE_DIR)/target/$(BUILD_CONFIGURATION)

# Support for installbuilder

STAGING_DIR := $(TARGET_DIR)/staging

#--------------------------------------------------------------------------------
# Build targets

all : $(RUBY_DIR)/.ext

$(RUBY_DIR)/.ext :
	@echo "========================= Performing Running Ruby configure"
	( cd $(RUBY_DIR); chmod u+x configure tool/ifchange; touch configure; ./configure $(RUBY_CONFIGURE_QUALS) )
	@echo "========================= Performing Building Ruby"
	make -C $(RUBY_DIR)

clean :
	$(RMDIR) $(BASE_DIR)/installer/intermediate $(BASE_DIR)/intermediate $(BASE_DIR)/target
	-find $(BASE_DIR) -name \*~ -exec rm {} \;

distclean : clean
	$(RM) $(BASE_DIR)/build/config.mak
	$(RMDIR) $(RUBY_DIR)/.ext
	#
	# Warning: This step will clean out checked out files from Ruby directory
	#
	@echo "Clensing RUBY source directory ..."
	find $(RUBY_DIR) -type f -perm -u+w -exec rm {} \;
	#
	# -make -C $(OMI_ROOT) distclean
	# -make -C $(SCXPAL_DIR)/build distclean
	# -$(RMDIR) $(OMI_ROOT)/output*
	-$(RM) $(SCXPAL_DIR)/build/config.mak
