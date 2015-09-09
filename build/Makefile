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
RUBY_DEST_DIR := $(BASE_DIR)/intermediate/$(BUILD_CONFIGURATION)
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
PLUGIN_LINK_LIBRARIES := -L$(OMI_ROOT)/output/lib -lrt -pthread -lmiapi -lprotocol -lsock -lbase -lpal -lwsman
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

# Plugins
IN_PLUGINS_LIB := $(INTERMEDIATE_DIR)/in_omi.so

OMI_INCLUDES := -I$(OMI_ROOT) -I$(OMI_ROOT)/common -I$(OMI_ROOT)/common/linux -I$(OMI_ROOT)/base -I$(OMI_ROOT)/output/include
PAL_INCLUDES := -I$(SCXPAL_DIR)/source/code/include/util
RUBY_INCLUDES := -I$(RUBY_DEST_DIR)/ruby/include/ruby-2.2.0/$(RUBY_ARCM) -I$(RUBY_DEST_DIR)/ruby/include/ruby-2.2.0

# Hack until we have formal versioning from build system

SCX_BUILDVERSION_MAJOR := 1
SCX_BUILDVERSION_MINOR := 0
SCX_BUILDVERSION_PATCH := 0
SCX_BUILDVERSION_BUILDNR := 1

#--------------------------------------------------------------------------------
# Build targets

all : $(RUBY_DEST_DIR) plugins-status $(IN_PLUGINS_LIB)

clean-plugins : clean-status
	$(RMDIR) $(INTERMEDIATE_DIR)/source/code
	$(RM) $(IN_PLUGINS_LIB)

clean : clean-plugins
	$(RMDIR) $(BASE_DIR)/installer/intermediate $(BASE_DIR)/target $(INTERMEDIATE_DIR)/source/code
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

kit : $(RUBY_DEST_DIR)
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
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		$(INSTALLER_DATAFILES_RPM)

	# The kit has a name including .universalr., and the 'r' is only desired for OM
	sed -e 's/\.universalr\./.universal./' $(TARGET_DIR)/package_filename > $(TARGET_DIR)/package_file.tmp
	mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename` $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`
	mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

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
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DPKG_LOCATION=$(SCXPAL_DIR)/installer/InstallBuilder/tools/bin/dpkg-deb-$(PF_ARCH) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		$(INSTALLER_DATAFILES_DPKG)

	# The kit has a name including .universald., and the 'd' is only desired for OM
	sed -e 's/\.universald\./.universal./' $(TARGET_DIR)/package_filename > $(TARGET_DIR)/package_file.tmp
	mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename` $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`
	mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# Strip the package extension from the package filename
	sed -re 's/.rpm$$|.deb$$//' $(TARGET_DIR)/package_filename > $(TARGET_DIR)/package_file.tmp
	mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# The MP needs architecture of i686 (for x86) and x86_64 (for x64).
	# sed -e 's/\.x86$$/\.i686/' $(TARGET_DIR)/package_filename | sed 's/\.x64$$/.x86_64/' > $(TARGET_DIR)/package_file.tmp
	# mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename`.rpm $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`.rpm
	# mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename`.deb $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`.deb
	# mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# Build the tar file containing both .rpm and .deb packages
	cd $(TARGET_DIR); tar cvf `cat $(TARGET_DIR)/package_filename`.tar `cat $(TARGET_DIR)/package_filename`.rpm `cat $(TARGET_DIR)/package_filename`.deb

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
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		$(INSTALLER_DATAFILES_CURRENT)

	# Strip the package extension from the package filename
	sed -re 's/.rpm$$|.deb$$//' $(TARGET_DIR)/package_filename > $(TARGET_DIR)/package_file.tmp
	mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# The MP needs architecture of i686 (for x86) and x86_64 (for x64).
	# sed -e 's/\.x86$$/\.i686/' $(TARGET_DIR)/package_filename | sed 's/\.x64$$/.x86_64/' > $(TARGET_DIR)/package_file.tmp
	# mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename`.$(PACKAGE_SUFFIX) $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`.$(PACKAGE_SUFFIX)
	# mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# Build the tar file containing the native installer package
	cd $(TARGET_DIR); tar cvf `cat $(TARGET_DIR)/package_filename`.tar `cat $(TARGET_DIR)/package_filename`.$(PACKAGE_SUFFIX)

endif

ifeq (0,1)
	../installer/bundle/create_bundle.sh $(PF)_$(PF_DISTRO) \
                                             $(TARGET_DIR) \
                                             `cat $(TARGET_DIR)/package_filename`
endif
	rm $(TARGET_DIR)/package_filename
