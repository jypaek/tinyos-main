#!/bin/bash
#
# This version of tinyos-tools builds a package against the 2.1.2
# release tree.  This is gh:tinyos/tinyos-release.  As of 12/2/2012,
# the 2.1.2/2.1.2.0 release has the SHA a2d4e21.  The tarball can
# be found at 
#
# https://github.com/tinyos/tinyos-release/archive/release_tinyos_2_1_2.tar.gz
#
# and files within this tarball are relative to the following path:
#
#     tinyos-release-release_tinyos_2_1_2
#
# which is constructed from <repository-name>-<release-tag>.
#
# The tinyos-tools package normally picks up various tool scripts and binaries
# built from the tinyos source tree.  This makes the tinyos-tools package
# dependent on the current state of the tree.
#
# We build against the released version of the tinyos tree to force the build
# to reflect the tools package at the time of the release.
#
# BUILD_ROOT is assumed to be the same directory as the build.sh file.
#
# set TOSROOT to the head of the tinyos source tree root.
# used to find default PACKAGES_DIR.
#
#
# Env variables used....
#
# TOSROOT	head of the tinyos source tree root.  Used for base of default repo
# PACKAGES_DIR	where packages get stashed.  Defaults to ${BUILD_ROOT}/packages
# REPO_DEST	Where the repository is being built (${TOSROOT}/packaging/repo)
# DEB_DEST	final home once installed.
# CODENAME	which part of the repository to place this build in.
#
# REPO_DEST	must contain a conf/distributions file for reprepro to work
#		properly.   Examples of reprepo configuration can be found in
#               ${TOSROOT}/packaging/repo/conf.
#

COMMON_FUNCTIONS_SCRIPT=../functions-build.sh
source ${COMMON_FUNCTIONS_SCRIPT}


BUILD_ROOT=$(pwd)
CODENAME=wheezy
TINYOSVERSION=2_1_2
SOURCEFILENAME=release_tinyos_${TINYOSVERSION}.tar.gz
TARBALLDIR=tinyos-release-release_tinyos_${TINYOSVERSION}
SOURCEURL=https://github.com/tinyos/tinyos-release/archive/${SOURCEFILENAME}

SOURCENAME=tinyos-tools
SOURCEVERSION=1.4.2
SOURCEDIRNAME=${SOURCENAME}_${SOURCEVERSION}
#PACKAGE_RELEASE=1
PREFIX=/usr
MAKE="make -j8"

download()
{
  if [ ! -f ${SOURCEFILENAME} ]; then
    wget ${SOURCEURL}
  fi
}

unpack()
{
  tar -xzf ${SOURCEFILENAME}
  rm -rf ${SOURCEDIRNAME}
  mkdir -p ${SOURCEDIRNAME}
  cp -R ${TARBALLDIR}/tools ${SOURCEDIRNAME}
  cp -R ${TARBALLDIR}/licenses ${SOURCEDIRNAME}
  
# The TinyOS 2.1.2 release of tinyos-tools (1.4.2) needs the disable_cross_compiler patch 
# Post 1.4.2 versions of tinyos-tools won't need this patch.  Remove for the TinyOS 2.2 release. Remove the patch file as well 10/07/2014
# Without the patch, the make system tries to compile for x86 and x86_64 on every host architecture (even on arm for example)
# With the patch, it only builds for the host architecture
  cd ${SOURCEDIRNAME}/tools
  patch -p1 < ../../disable_cross_compiler.patch
  cd ../..
# End of pathcing
}

build()
{
  set -e
  (
    cd ${SOURCEDIRNAME}/tools
    ./Bootstrap
    ./configure --prefix=${PREFIX}
    ${MAKE}
    cd ${BUILD_ROOT}
  )
}

installto()
{
  set -e
  (
    cd ${SOURCEDIRNAME}/tools
    ${MAKE} DESTDIR=${INSTALLDIR} install
    cd ${BUILD_ROOT}
  )
}

package_deb(){
  package_deb_from ${INSTALLDIR} ${SOURCEVERSION}-${PACKAGE_RELEASE} tinyos-tools.control tinyos-tools.postinst
}

package_rpm(){
  package_rpm_from ${INSTALLDIR} ${SOURCEVERSION} ${PACKAGE_RELEASE} ${PREFIX} tinyos-tools.spec
}

cleanbuild(){
  remove ${SOURCEDIRNAME}
  remove ${TARBALLDIR}
}

cleandownloaded(){
  remove ${SOURCEFILENAME}
}

cleaninstall(){
  remove ${INSTALLDIR}
}

#main function
case $1 in
  test)
    installto
#   package_deb
    ;;

  download)
    download
    ;;
	
	
  clean)
    cleanbuild
    ;;

  veryclean)
    cleanbuild
    cleandownloaded
    ;;

  deb)
    # sets up INSTALLDIR, which package_deb uses
    setup_package_target ${SOURCENAME} ${SOURCEVERSION} ${PACKAGE_RELEASE}
    download
    unpack
    build
    installto
    package_deb
    cleaninstall
    ;;

  sign)
    setup_package_target ${SOURCENAME} ${SOURCEVERSION} ${PACKAGE_RELEASE}
    if [[ -z "$2" ]]; then
        dpkg-sig -s builder ${PACKAGES_DIR}/*
    else
        dpkg-sig -s builder -k $2 ${PACKAGES_DIR}/*
    fi
    ;;

  rpm)
    setup_package_target ${SOURCENAME} ${SOURCEVERSION} ${PACKAGE_RELEASE}
    download
    unpack
    build
    installto
    package_rpm
    cleaninstall
    ;;

  repo)
    setup_package_target ${SOURCENAME} ${SOURCEVERSION} ${PACKAGE_RELEASE}
    if [[ -z "${REPO_DEST}" ]]; then
      REPO_DEST=${TOSROOT}/packaging/repo
    fi
    echo -e "\n*** Building Repository: [${CODENAME}] -> ${REPO_DEST}"
    echo -e   "*** Using packages from ${PACKAGES_DIR}\n"
    find ${PACKAGES_DIR} -iname "*.deb" -exec reprepro -b ${REPO_DEST} includedeb ${CODENAME} '{}' \;
    ;;

  local)
    setup_local_target
    download
    unpack
    build
    installto
    ;;
    
  tarball)
    download
    tar -cjf ${SOURCEDIRNAME}.tar.bz2 ${SOURCEDIRNAME}
    ;;

  *)
    echo -e "\n./build.sh <target>"
    echo -e "    local | rpm | deb | sign | repo | clean | veryclean | download | tarball"
esac
