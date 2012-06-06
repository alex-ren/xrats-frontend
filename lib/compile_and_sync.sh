#!/bin/bash

#Recompiles ATS and ATS

set -e

cd /opt/ats028 && make

export ATSHOME=/opt/ats028
export ATSHOMERELOC=ATS-0.2.8

cd /opt/postiats

make -f src/Makefile cleanall
make -f src/Makefile

cp src/patsopt bin/

make -f codegen/Makefile_atsctrb
make -f codegen/Makefile_atslib

rsync -avz ./ /opt/atscc-jail/opt/postiats/