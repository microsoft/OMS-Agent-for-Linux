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
INSTALLER_TMPDIR := $(TARGET_DIR)/installer_tmp

# Hack until we have formal versioning from build system

SCX_BUILDVERSION_MAJOR := 1
SCX_BUILDVERSION_MINOR := 0
SCX_BUILDVERSION_PATCH := 0
SCX_BUILDVERSION_BUILDNR := 1


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
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		base_omsagent.data linux.data linux_rpm.data ruby.data

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
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DPKG_LOCATION=$(SCXPAL_DIR)/installer/InstallBuilder/tools/bin/dpkg-deb-$(PF_ARCH) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		base_omsagent.data linux.data linux_dpkg.data ruby.data

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
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(SCX_BUILDVERSION_MAJOR).$(SCX_BUILDVERSION_MINOR).$(SCX_BUILDVERSION_PATCH) \
		--RELEASE=$(SCX_BUILDVERSION_BUILDNR) \
		--DATAFILE_PATH=$(BASE_DIR)/installer/datafiles \
		base_omsagent.data linux.data linux_rpm.data ruby.data

	# Strip the package extension from the package filename
	sed -re 's/.rpm$$|.deb$$//' $(TARGET_DIR)/package_filename > $(TARGET_DIR)/package_file.tmp
	mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# The MP needs architecture of i686 (for x86) and x86_64 (for x64).
	# sed -e 's/\.x86$$/\.i686/' $(TARGET_DIR)/package_filename | sed 's/\.x64$$/.x86_64/' > $(TARGET_DIR)/package_file.tmp
	# mv $(TARGET_DIR)/`cat $(TARGET_DIR)/package_filename`.rpm $(TARGET_DIR)/`cat $(TARGET_DIR)/package_file.tmp`.rpm
	# mv $(TARGET_DIR)/package_file.tmp $(TARGET_DIR)/package_filename

	# Build the tar file containing the .rpm package
	cd $(TARGET_DIR); tar cvf `cat $(TARGET_DIR)/package_filename`.tar `cat $(TARGET_DIR)/package_filename`.rpm

endif

ifeq (0,1)
	../installer/bundle/create_bundle.sh $(PF)_$(PF_DISTRO) \
                                             $(TARGET_DIR) \
                                             `cat $(TARGET_DIR)/package_filename`
endif
	rm $(TARGET_DIR)/package_filename
