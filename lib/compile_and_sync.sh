#!/bin/bash

# Recompiles ATS and ATS2
# Should also package a tarball to package on the 
# web.
set -e

cd /opt/ats028 && make

export ATSHOME=/opt/ats028
export ATSHOMERELOC=ATS-0.2.8

POSTIATS=/opt/postiats

cd $POSTIATS/src

make cleanall
make

cd $POSTIATS

cp src/patsopt bin/

make -f codegen/Makefile_atsctrb
make -f codegen/Makefile_atslib

rsync -avz ./ /opt/atscc-jail/opt/postiats/