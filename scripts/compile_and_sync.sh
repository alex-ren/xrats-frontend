#!/bin/bash

# Recompiles ATS and ATS2
# Should also process a tarball to package on the
# web.
# This really should just be a makefile
set -e

ATSGIT=/opt/ats-0.2.9
ATSSVN=/opt/ats-svn

POSTIATS=/opt/postiats

#This changes infrequently
ATSVERSION=ATS-0.2.9

cd $ATSGIT

CURR_SVN=$(git log | grep "Bump to svn commit" | head -1 \
    | grep -Po '\d+')

cd $ATSSVN

svn update

NEW_SVN=$(svn info | grep "Revision" | grep -Po '\d+')

if [ "$CURR_SVN" == "$NEW_SVN" ]; then
    echo "The git repo is up to date!"
else

    svn diff -r $CURR_SVN:$NEW_SVN > update.patch
    
    cd $ATSGIT
    
    patch -p0 < $ATSSVN/update.patch
    
    if [ "$?" > 0 ]; then
        echo "Patching failed, you're on your own buddy..."
        exit 1
        
    else
        
        export ATSHOME=
        export ATSHOMERELOC=
    
        make cleanall
        
        aclocal 
        autoconf
        
        make -j4
        
        if [ "$?" > 0 ]; then
            echo "ATS Failed to compile, check what happened."
            exit 1
        fi
    fi
fi

export ATSHOME=$ATSGIT
export ATSHOMERELOC=$ATSVERSION

cd $POSTIATS

git pull origin master

cd $POSTIATS/src

make cleanall
make -j4

cd $POSTIATS

cp src/patsopt bin/

make -f codegen/Makefile_atsctrb
make -f codegen/Makefile_atslib
