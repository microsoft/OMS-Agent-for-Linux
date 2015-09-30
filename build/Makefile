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
RUBY_DEST_DIR := $(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)/ruby
FLUENTD_DIR := $(BASE_DIR)/source/ext/fluentd
PLUGINS_DIR := $(BASE_DIR)/source/code/plugins

INTERMEDIATE_DIR=$(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)
TARGET_DIR := $(BASE_DIR)/target/$(BUILD_CONFIGURATION)

# Compiler flags

ifeq ($(ENABLE_DEBUG),1)
DEBUG_FLAGS := -g
endif

# Need to use RUBY_COMPILE_FLAGS when compiling code that uses C Ruby interfaces
# (Note that "-Wshadow -Wredundant-decls" don't work with Ruby v2.2.0)
RUBY_COMPILE_FLAGS := $(DEBUG_FLAGS) -D_REENTRANT -fstack-protector-all -Wall -fno-nonansi-builtins -Woverloaded-virtual -Wformat -Wformat-security -Wcast-align -Wswitch-enum  -Wwrite-strings  -Werror -Wcast-qual -fPIC # -Wshadow -Wredundant-decls
# TODO: Horrible, dismal, ugly hack for SSL. We need to figure out the SSL story soon!
PLUGIN_LINK_LIBRARIES := -L$(OMI_ROOT)/output/lib -L$(OMI_ROOT)/output_openssl_0.9.8/lib -lrt -pthread -lmiapi -lprotocol -lsock -lbase -lpal -lwsman
SHARED_FLAGS := -shared

# Support for installbuilder

STAGING_DIR := $(TARGET_DIR)/staging
INSTALLER_TMPDIR := $(TARGET_DIR)/installer_tmp

INSTALLER_DATAFILES := base_omsagent.data linux.data ruby.data
INSTALLER_DATAFILES_RPM := $(INSTALLER_DATAFILES) linux_rpm.data
INSTALLER_DATAFILES_DPKG := $(INSTALLER_DATAFILES) linux_dpkg.data

ifeq ($(PACKAGE_SUFFIX),rpm)
INSTALLER_DATAFILES_CURRENT := $(INSTALLER_DATAFILES_RPM)
else
INSTALLER_DATAFILES_CURRENT := $(INSTALLER_DATAFILES_DPKG)
endif

ifeq ("$(wildcard /usr/bin/dpkg-deb)","")
DPKG_LOCATION="--DPKG_LOCATION=$(SCXPAL_DIR)/installer/InstallBuilder/tools/bin/dpkg-deb-$(PF_ARCH)"
else
DPKG_LOCATION=
endif

# Plugins
IN_PLUGINS_LIB := $(INTERMEDIATE_DIR)/Libomi.so

OMI_INCLUDES := -I$(OMI_ROOT) -I$(OMI_ROOT)/common -I$(OMI_ROOT)/common/linux -I$(OMI_ROOT)/base -I$(OMI_ROOT)/output/include
PAL_INCLUDES := -I$(SCXPAL_DIR)/source/code/include/util
RUBY_INCLUDES := -I$(RUBY_DEST_DIR)/include/ruby-2.2.0/$(RUBY_ARCM) -I$(RUBY_DEST_DIR)/include/ruby-2.2.0

# Hack until we have formal versioning from build system

OMS_BUILDVERSION_MAJOR := 1
OMS_BUILDVERSION_MINOR := 0
OMS_BUILDVERSION_PATCH := 0
OMS_BUILDVERSION_BUILDNR := 2

ifeq ($(ULINUX),1)
  OUTPUT_PACKAGE_PREFIX=omsagent-$(OMS_BUILDVERSION_MAJOR).$(OMS_BUILDVERSION_MINOR).$(OMS_BUILDVERSION_PATCH)-$(OMS_BUILDVERSION_BUILDNR).universal.$(PF_ARCH)
else
  PF_DISTRO_LC := $(shell echo $(PF_DISTRO) | tr A-Z a-z)
  OUTPUT_PACKAGE_PREFIX=omsagent-$(OMS_BUILDVERSION_MAJOR).$(OMS_BUILDVERSION_MINOR).$(OMS_BUILDVERSION_PATCH)-$(OMS_BUILDVERSION_BUILDNR).$(PF_DISTRO_LC).$(PF_MAJOR).$(PF_ARCH)
endif

#--------------------------------------------------------------------------------
# Build targets
.PHONY: all clean clean-ruby distclean clean-status plugins-status kit

all : $(RUBY_DEST_DIR) plugins-status $(IN_PLUGINS_LIB) kit

clean : clean-status
	$(RMDIR) $(INTERMEDIATE_DIR)/source/code
	# On Debian, installer staging directory has root permissions, so sudo elevate
	sudo $(RMDIR) $(BASE_DIR)/target 
	$(RM) $(IN_PLUGINS_LIB)
	-find $(BASE_DIR) -name \*~ -exec rm {} \;

clean-ruby :
	sudo $(RMDIR) $(BASE_DIR)/intermediate
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

distclean : clean clean-ruby
	$(RM) $(BASE_DIR)/build/config.mak
	-$(RM) $(SCXPAL_DIR)/build/config.mak

clean-status :
	@$(ECHO) "========================= Performing make clean"

#--------------------------------------------------------------------------------
# Build the version of Ruby that we distribute

$(RUBY_DEST_DIR) :
	#
	# Warning: This step will clean out checked out files from both Ruby and fluentd directories
	#
	$(BASE_DIR)/build/buildRuby.sh

#================================================================================
# Internal functions
#================================================================================

# Convert a list of src files with absolute paths under BASE_DIR to corresponding
# object files under intermediate directory
# src_to_obj(list_of_cppfiles)
src_to_obj = $(patsubst $(BASE_DIR)%, $(INTERMEDIATE_DIR)%, $(patsubst %.c, %.o, $(patsubst %.cpp, %.o, $(1))))

# No default rules, please
.SUFFIX:

# Rule for compiling cpp files in source tree, ouptut in mirrored intermediate dir
$(INTERMEDIATE_DIR)/%.o : $(BASE_DIR)/%.cpp
	$(MKPATH) $(@D)
	$(CXX) -c $(CXXFLAGS) $(INCLUDES) -I$(<D) -o $@ $<

$(INTERMEDIATE_DIR)/%.o : $(BASE_DIR)/%.c
	$(MKPATH) $(@D)
	$(CXX) -c $(CFLAGS) $(INCLUDES) -I$(<D) -o $@ $<

#--------------------------------------------------------------------------------
# Build the plugins that we require for our agent

STATIC_PLUGINS_SRCFILES = $(PLUGINS_DIR)/omi_interface.cpp
STATIC_PLUGINS_OBJFILES = $(call src_to_obj,$(STATIC_PLUGINS_SRCFILES))

$(IN_PLUGINS_LIB) : CXXFLAGS = $(RUBY_COMPILE_FLAGS)
$(IN_PLUGINS_LIB) : INCLUDES = $(RUBY_INCLUDES) $(OMI_INCLUDES) $(PAL_INCLUDES)
$(IN_PLUGINS_LIB) : $(STATIC_PLUGINS_OBJFILES)
	$(MKPATH) $(INTERMEDIATE_DIR)
	$(MKPATH) $(TARGET_DIR)
	g++ $(SHARED_FLAGS) $(RUBY_INCLUDES) $(OMI_INCLUDES) $(PAL_INCLUDES) -o $@ $(STATIC_PLUGINS_OBJFILES) $(PLUGIN_LINK_LIBRARIES)

plugins-status :
	@echo "========================= Performing Building input plugins"

#--------------------------------------------------------------------------------
# Build the distribution kit
#
# Build the packages via installbuilder
#
# While the "formal build" only builds ULINUX, we may build something else for DEV purposes.
# Assume we ALWAYS build RPM, but only build DPKG if --enable-ulinux is speified in configure.

kit : $(TARGET_DIR)/$(OUTPUT_PACKAGE_PREFIX).tar

$(TARGET_DIR)/$(OUTPUT_PACKAGE_PREFIX).tar : $(RUBY_DEST_DIR) $(IN_PLUGINS_LIB)
ifeq ($(ULINUX),1)

	@echo "========================= Performing Building RPM and DPKG packages"
	$(MKPATH) $(INSTALLER_TMPDIR)
	sudo $(RMDIR) $(STAGING_DIR)
	$(MKPATH) $(TARGET_DIR)
	python $(SCXPAL_DIR)/installer/InstallBuilder/installbuilder.py \
		--BASE_DIR=$(BASE_DIR) \
		--TARGET_DIR=$(TARGET_DIR) \
		--INTERMEDIATE_DIR=$(INSTALLER_TMPDIR) \
		--STAGING_DIR=$(STAGING_DIR) \
		--BUILD_TYPE=$(BUILD_TYPE) \
		--BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) \
		--RUBY_INT=intermediate/$(BUILD_CONFIGURATION)/ruby \
		--RUBY_ARCH=$(RUBY_ARCH) \
		--RUBY_ARCM=$(RUBY_ARCM) \
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(OMS_BUILDVERSION_MAJOR).$(OMS_BUILDVERSION_MINOR).$(OMS_BUILDVERSION_PATCH) \
		--RELEASE=$(OMS_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		--OUTPUTFILE=$(OUTPUT_PACKAGE_PREFIX) \
		$(INSTALLER_DATAFILES_RPM)

	sudo $(RMDIR) $(STAGING_DIR)
	$(MKPATH) $(TARGET_DIR)
	python $(SCXPAL_DIR)/installer/InstallBuilder/installbuilder.py \
		--BASE_DIR=$(BASE_DIR) \
		--TARGET_DIR=$(TARGET_DIR) \
		--INTERMEDIATE_DIR=$(INSTALLER_TMPDIR) \
		--STAGING_DIR=$(STAGING_DIR) \
		--BUILD_TYPE=$(BUILD_TYPE) \
		--BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) \
		--RUBY_INT=intermediate/$(BUILD_CONFIGURATION)/ruby \
		--RUBY_ARCH=$(RUBY_ARCH) \
		--RUBY_ARCM=$(RUBY_ARCM) \
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(OMS_BUILDVERSION_MAJOR).$(OMS_BUILDVERSION_MINOR).$(OMS_BUILDVERSION_PATCH) \
		--RELEASE=$(OMS_BUILDVERSION_BUILDNR) \
		$(DPKG_LOCATION) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		--OUTPUTFILE=$(OUTPUT_PACKAGE_PREFIX) \
		$(INSTALLER_DATAFILES_DPKG)

	# Build the tar file containing both .rpm and .deb packages
	cd $(TARGET_DIR); tar cvf $(OUTPUT_PACKAGE_PREFIX).tar $(OUTPUT_PACKAGE_PREFIX).rpm $(OUTPUT_PACKAGE_PREFIX).deb

else

	@echo "========================= Performing Building RPM and DPKG packages"
	$(MKPATH) $(INSTALLER_TMPDIR)
	sudo $(RMDIR) $(STAGING_DIR)
	python $(SCXPAL_DIR)/installer/InstallBuilder/installbuilder.py \
		--BASE_DIR=$(BASE_DIR) \
		--TARGET_DIR=$(TARGET_DIR) \
		--INTERMEDIATE_DIR=$(INSTALLER_TMPDIR) \
		--STAGING_DIR=$(STAGING_DIR) \
		--BUILD_TYPE=$(BUILD_TYPE) \
		--BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) \
		--RUBY_INT=intermediate/$(BUILD_CONFIGURATION)/ruby \
		--RUBY_ARCH=$(RUBY_ARCH) \
		--RUBY_ARCM=$(RUBY_ARCM) \
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(OMS_BUILDVERSION_MAJOR).$(OMS_BUILDVERSION_MINOR).$(OMS_BUILDVERSION_PATCH) \
		--RELEASE=$(OMS_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		--OUTPUTFILE=$(OUTPUT_PACKAGE_PREFIX) \
		$(INSTALLER_DATAFILES_CURRENT)

	# Build the tar file containing the native installer package
	cd $(TARGET_DIR); tar cvf $(OUTPUT_PACKAGE_PREFIX).tar $(OUTPUT_PACKAGE_PREFIX).$(PACKAGE_SUFFIX)

endif

ifeq (0,1)
	../installer/bundle/create_bundle.sh $(PF)_$(PF_DISTRO) $(TARGET_DIR) $(OUTPUT_PACKAGE_PREFIX)
endif
