#!/bin/bash

###########################################################################
#
#	Finesse Helper Script
#	Andreas Freise & Daniel Brown
#
#	This build helper script has been modified with the permission of 
#	Oliver Bock from the Einstein@Home Project to work with Finesse.
#
#	Usage can be found by typing ./finesse.sh at the terminal
#
###########################################################################

###########################################################################
#   Copyright (C) 2008-2009 by Oliver Bock                                #
#   oliver.bock[AT]aei.mpg.de                                             #
#                                                                         #
#   This file is part of Einstein@Home.                                   #
#                                                                         #
#   Einstein@Home is free software: you can redistribute it and/or modify #
#   it under the terms of the GNU General Public License as published     #
#   by the Free Software Foundation, version 2 of the License.            #
#                                                                         #
#   Einstein@Home is distributed in the hope that it will be useful,      #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the          #
#   GNU General Public License for more details.                          #
#                                                                         #
#   You should have received a copy of the GNU General Public License     #
#   along with Einstein@Home. If not, see <http://www.gnu.org/licenses/>. #
#                                                                         #
###########################################################################


### globals ###############################################################

ROOT=`pwd`
PATH_ORG="$PATH"
PATH_MINGW="$PATH"
LOGFILE=$ROOT/build.log
CC=gcc

verbose=0

TARGET=0

TARGET_LINUX=1
TARGET_MAC=2
TARGET_WIN32=3
TARGET_CHECKOUT=4
TARGET_REMOVE=5
TARGET_CLEAN=6
TARGET_NATIVE=7

BRANCH_DEVELOP=1
BRANCH_STABLE=2

### functions (tools) #############################################################

failure()
{
    echo "************************************" 
    echo "Error detected! Stopping build!"
    echo "`date`" | tee -a $LOGFILE

    if [ -f "$LOGFILE" ]; then
        echo "------------------------------------"
        echo "Please check logfile: `basename $LOGFILE`"
        echo "These are the final 20 lines:"
        echo "------------------------------------"
        tail -n 14 $LOGFILE | head -n 20
    fi

    echo "************************************"

    exit 1
}


clean()
{
    cd $ROOT || failure

    echo "Cleaning Finesse files..." | tee -a $LOGFILE

    rm -rf lib || failure
    rm -rf src || failure
    rm kat || failure
}

### functions (features) #############################################################

check_OSX_GSL_architecture()
{
		lib1=$gsl_libpath/libgsl.dylib
		lib2=$gsl_libpath/libgsl.a

		if [ -f $lib1 ]
		then
				libinfo=`file -L $lib1`
				if [[ "$libinfo" == *x86_64* ]] 
				then
						CPUARCH="x86_64"
				elif [[ "$libinfo" == *i386* || "$libinfo" == *i686* ]]
				then
						CPUARCH="i686"
				fi
		elif [ -f $lib2 ]
		then
				testfile=version.o
				ar -x $lib2 $testfile
				libinfo=`file $testfile`
				rm $testfile
				if [[ "$libinfo" == *x86_64* ]] 
				then
						CPUARCH="x86_64"
				elif [[ "$libinfo" == *i386* || "$libinfo" == *i686* ]]
				then
						CPUARCH="i686"
				fi
		else
				echo"  - Could not determine architecture (x86_64 or i686) of GSL library" | tee -a $LOGFILE
		return 1
		fi
}

check_prerequisites()
{

  # setting default compiler 
  export CC
	# check if the src and lib directories are here
	echo "Required source and library folders exist?"
	if [ ! -d "src" ]; then
		echo "	- Source folder is not present, please run with --checkout before building"
		failure
	else
		echo "	- Source folder exists" | tee -a $LOGFILE
	fi
	
	if [ ! -d "lib" ]; then
		echo "	- Library folder is not present, please run with --checkout before building"
		failure
	else
		echo "	- Library folder exists" | tee -a $LOGFILE
	fi
	
    echo "Checking prerequisites..." | tee -a $LOGFILE
		
    # required toolchain
    if [[ $target_arch == "win" ]]; then
    	if [[ $platform == "win" ]]; then
		TOOLS="gcc ar ranlib"
	else
	    echo "	- Compiling windows version on non-windows machine"	
            TOOLS="i586-mingw32msvc-gcc i586-mingw32msvc-ar i586-mingw32msvc-ranlib"
    	fi
    else
    	TOOLS="gcc ar ranlib"
    fi
		
    for tool in $TOOLS; do
		if which ls &> /dev/null; then
			echo "	- Found \"$tool\"..." | tee -a $LOGFILE
		else
			echo "	- Missing \"$tool\" which is required tool!" | tee -a $LOGFILE
            return 1
		fi
    done
	
	if ! (which gsl-config &> /dev/null); then
			echo "	- Missing GSL which is a required library" | tee -a $LOGFILE
			return 1
	else
			gsl_libpath=`gsl-config --libs | cut -d " " -f1`
			gsl_libpath=${gsl_libpath#-L}
			gsl_libpath=${gsl_libpath#-l}
			echo "	- GSL found!" | tee -a $LOGFILE
			if [[ $platform == "mac" ]]
			then
					check_OSX_GSL_architecture
					echo "	- setting architecture based on GSL to $CPUARCH " | tee -a $LOGFILE
			fi
	fi
	
  echo "	- Required toolchain found!" | tee -a $LOGFILE
				
	return 0
}

build()
{
		echo "Configuring CUBA" | tee -a $LOGFILE
		pwdbefore=`pwd`
		
		if [ ! -f "./lib/Cuba-3.0/config.h" ];
		then
				cd ./lib/Cuba-3.0
				chmod 700 ./configure
				if [[ $platform == "mac" ]]
				then
						echo "Configuring Cuba with extra flags CFLAGS=-arch $CPUARCH"
						./configure -q CFLAGS="-arch $CPUARCH"
				else
						./configure -q
				fi
				cd $pwdbefore
		else
				echo "	- Cuba is already configured"
		fi
		

		gsl_libpath=`gsl-config --libs | cut -d " " -f1`
		gsl_libpath=${gsl_libpath#-L}
		gsl_libpath=${gsl_libpath#-l}
		# Setting GSL_LIBS flags to allow static linking
    export GSL_LIBS="$gsl_libpath/libgslcblas.a $gsl_libpath/libgsl.a"

		echo "Calling make file, see make.log for more details..."
		echo ""
	#Don't know why but the config file is not being generated for
	#the linux build so..

		if [ $verbose == 1 ]
		then
				make config 2>&1 | tee make.log
				make ARCH=$target_arch BUILD=$platform kat 2>&1 | tee make.log
		else
				make config 2>&1 1>make.log 
				make ARCH=$target_arch BUILD=$platform kat 2>&1 1>make.log 
		fi

		if grep " Error " make.log 1>/dev/null 2>&1
		then
				#cat make.err > $LOGFILE
				failure
		else
				return 0;
		fi
}

make-win-package()
{
	echo "Making Win32 package..." | tee -a $LOGFILE
	mkdir tmp
	cd tmp
	
	# copies dll's needed from the cygwin installation
	cp /bin/cygwin1.dll .
	#cp /bin/cyggcc_s-1.dll .                                                
	#cp /bin/cygiconv-2.dll .                                                
	#cp /bin/cygintl-8.dll .                                                 
	#cp /bin/cygncursesw-10.dll .
	#cp /bin/cygpath.exe .                                             
	#cp /bin/sh.exe .                                             
	#cp /bin/cygreadline7.dll .
	#cp /bin/ls.exe .
	
	cp ../kat.exe .
	cp ../CHANGES .
	cp ../LICENSES .
	cp ../README .
	cp ../INSTALL .
	
	zip ../finesse_win.zip *
	
	echo "Created Win32 distribution finesse_win32.zip" | tee -a $LOGFILE
	
	cd ..
	rm tmp -rf
}

print_usage()
{
    cd $ROOT

    echo "******************************************************************************"
    echo "Usage: `basename $0` <option> <--checkout: option>"
    echo
		echo "Run with the checkout command first, this fetches the latest stable"
		echo "version of Finesse source. You can then build it by using the system"
		echo "specific build argument to get the required version."
		echo
    echo "Available Arguments:"
    echo "  --checkout"
		echo "       When using --checkout you can use either of these 2 options"
		echo "       to select which version of Finesse to download. You can swap"
		echo "       your current version by using --checkout <option>. If you are"
		echo "       swapping branches make sure you call --clean before building."
		echo "       stable (Default)"
		echo "       develop"
		echo "  "
		echo "  --build"
		echo "       Builds Finesse executable that is native to the system you are running"
		echo "       You must have run `basename $0` using the --checkout argument first."
		echo ""
		echo "  --build-linux"
    echo "  --build-mac"
    echo "  --build-win32"
		echo "       Choose the system which you would like to build an executable for."
		echo "       You must have run `basename $0` using the --checkout argument first."
		echo ""
    echo "  --clean"
		echo "       This cleans up all the build files. Should be used if you have"
		echo "       swapped branches."
		echo ""
    echo "  --remove"
		echo "       This removes any build or downloaded files."
		echo ""
		echo "  --make-win-package"
		echo "       This creates the binary distribution for win32. Only runs on Cygwin capable Windows machines."
    echo "******************************************************************************"

    echo "Wrong usage. Stopping!" >> $LOGFILE

    return 0
}

### main control ##########################################################

# crude command line parsing :-)

if [ $# -ne 1 ]; then
	if [ $# -ne 2 ]; then
		print_usage
		exit 1
	fi
fi

echo "************************************" | tee -a $LOGFILE
echo "Starting new build!" | tee -a $LOGFILE
echo "`date`" | tee -a $LOGFILE
echo "************************************" | tee -a $LOGFILE


platform='unknown'
unamestr=`uname`

if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='mac'
elif [[ "$unamestr" == *CYGWIN* ]]; then
   platform='win'
else
   echo "Platform could not be determined" | tee -a $LOGFILE
   failure
fi

echo 'Running on' $platform
		
case "$1" in
    "--build")
        if [[ "$platform" == 'linux' ]]; then
		   TARGET=$TARGET_LINUX
		elif [[ "$platform" == 'mac' ]]; then
		   TARGET=$TARGET_MAC
		elif [[ "$platform" == 'win' ]]; then
		   TARGET=$TARGET_WIN32
		else
		   echo "Platform Target could not be determined" | tee -a $LOGFILE
		   failure
		fi   
		
		CPUARCH="native"
		target_arch=$platform
        echo "Building native Finesse version:" | tee -a $LOGFILE        
        ;;
    "--build-linux")
        TARGET=$TARGET_LINUX   
		CPUARCH="native"
		target_arch="linux"
        echo "Building Linux version:" | tee -a $LOGFILE        
        ;;
    "--build-mac")
        TARGET=$TARGET_MAC        
		CPUARCH=""
		target_arch="mac"
		echo "Building Mac (Intel) version:" | tee -a $LOGFILE        
        ;;
    "--build-win32")
        TARGET=$TARGET_WIN32        
		CPUARCH="i686"
		target_arch="win"
        echo "Building Win32 version:" | tee -a $LOGFILE        
        ;;
    "--checkout")
        TARGET=$TARGET_CHECKOUT

		case "$2" in
			"develop")
				echo "Checking out Finesse development branch..." | tee -a $LOGFILE
				BRANCH=$BRANCH_DEVELOP;
				;;
			"stable")
				echo "Checking out Finesse stable branch..." | tee -a $LOGFILE
				BRANCH=$BRANCH_STABLE;
				;;
			*)
				echo "Checking out Finesse stable branch..." | tee -a $LOGFILE
				BRANCH=$BRANCH_STABLE
				;;
		esac
		
        ;;	
    "--remove")
		TARGET=$TARGET_REMOVE
        ;;
	"--clean")
		TARGET=$TARGET_CLEAN
        ;;
	"--make-win-package")
		make-win-package
		exit 0
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

# here we go...

export OPTIM_CFLAGS="-O3 -ffast-math -fexpensive-optimizations -fomit-frame-pointer -funroll-loops -DNDEBUG "

case $TARGET in
    $TARGET_LINUX)
        check_prerequisites || failure
				export CFLAGS=$OPTIM_CFLAGS"-march=native"
        build || failure
        ;;
    $TARGET_MAC)
        check_prerequisites || failure
				if [ -d /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/ ]; then
            echo "Preparing Mac OS X 10.7 SDK build environment..." | tee -a $LOGFILE
						export OSX_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/"
						export OSX_CFLAGS=$OPTIM_CFLAGS"-isysroot $OSX_SDK -arch x86_64 -mmacosx-version-min=10.6"
						export OSX_LDFLAGS="-isysroot $OSX_SDK -Wl,-syslibroot,$OSX_SDK -arch x86_64 -mmacosx-version-min=10.6"
						export CFLAGS=$OSX_CFLAGS
						export CXXFLAGS=$OSX_CFLAGS
						export LDFLAGS=$OSX_LDFLAGS
            export MACOSX_DEPLOYMENT_TARGET="10.6"
        elif [ -d /Developer/SDKs/MacOSX10.6.sdk ]; then
            echo "Preparing Mac OS X 10.6 x86_64 SDK build environment..." | tee -a $LOGFILE
            export LDFLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -Wl,-syslibroot,/Developer/SDKs/MacOSX10.6.sdk -arch $CPUARCH $LDFLAGS"
            export CPPFLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -arch $CPUARCH $CPPFLAGS"
            export CFLAGS=$OPTIM_CFLAGS"-isysroot /Developer/SDKs/MacOSX10.6.sdk -arch $CPUARCH $CFLAGS"
            export CXXFLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -arch $CPUARCH $CXXFLAGS"
            export SDKROOT="/Developer/SDKs/MacOSX10.6.sdk"
            export MACOSX_DEPLOYMENT_TARGET="10.6"
        elif [ -d /Developer/SDKs/MacOSX10.5u.sdk ]; then
            echo "Preparing Mac OS X 10.5 i386 SDK build environment..." | tee -a $LOGFILE
            export LDFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -Wl,-syslibroot,/Developer/SDKs/MacOSX10.5.sdk -arch $CPUARCH $LDFLAGS"
            export CPPFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch $CPUARCH $CPPFLAGS"
            export CFLAGS=$OPTIM_CFLAGS"-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch $CPUARCH $CFLAGS"
            export CXXFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch $CPUARCH $CXXFLAGS"
            export SDKROOT="/Developer/SDKs/MacOSX10.5.sdk"
            export MACOSX_DEPLOYMENT_TARGET="10.5"
        elif [ -d /Developer/SDKs/MacOSX10.4u.sdk ]; then
            echo "Preparing Mac OS X 10.4 i386 SDK build environment..." | tee -a $LOGFILE
            export LDFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -Wl,-syslibroot,/Developer/SDKs/MacOSX10.4u.sdk -arch $CPUARCH $LDFLAGS"
            export CPPFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch $CPUARCH $CPPFLAGS"
            export CFLAGS=$OPTIM_CFLAGS"-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch $CPUARCH $CFLAGS"
            export CXXFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch $CPUARCH $CXXFLAGS"
            export SDKROOT="/Developer/SDKs/MacOSX10.4u.sdk"
            export MACOSX_DEPLOYMENT_TARGET="10.4"
        else
            echo "Mac OS X 10.4/10.5/10.6/10.7 SDK required but missing!" | tee -a $LOGFILE
            failure
        fi
        #prepare_tree || failure
        build $TARGET_MAC || failure
        ;;
    $TARGET_WIN32)
        check_prerequisites || failure
				export CFLAGS=$OPTIM_CFLAGS"-march=native"
        build || failure
		
        ;;
    $TARGET_CHECKOUT)
		echo "Checking for Git..." | tee -a $LOGFILE
        if ! (which git &> /dev/null); then
			echo "	- Git is not installed!" | tee -a $LOGFILE
			failure
		else
			echo "	- Git is installed" | tee -a $LOGFILE
		fi

		echo "Checking out src"
		if [ ! -d "src" ]; then
			#git clone git://git.aei.uni-hannover.de/shared/finesse/src || failure
			git clone git://gitmaster.atlas.aei.uni-hannover.de/finesse/src.git || failure
			echo "	- Setting core.filemode = false for src repository"
			cd src
			git config core.filemode false
			cd $ROOT
		else
			echo "	- Source repository already exists" | tee -a $LOGFILE
			echo "	- Pulling latest version"
			cd src
			git pull
			cd $ROOT
		fi

		# checkout relevant branch
		cd src
		case $BRANCH in
			$BRANCH_STABLE)
				echo "	- Branch: stable" | tee -a $LOGFILE
				git checkout master  >> $LOGFILE 2>&1  || failure
				;;
			$BRANCH_DEVELOP)
				echo "	- Branch: develop" | tee -a $LOGFILE
				git checkout develop >> $LOGFILE 2>&1  || failure
				;;
			*)
				print_usage
				exit 1
				;;
		esac

		git pull || failure
		
		cd $ROOT
		
		echo "Checking out lib"
		if [ ! -d "lib" ]; then
			git clone git://gitmaster.atlas.aei.uni-hannover.de/finesse/lib.git || failure
			echo "	- Setting core.filemode = false for lib repository"
			cd lib
			git config core.filemode false
			cd $ROOT
		else
			echo "	- Library repository already exists" | tee -a $LOGFILE
			echo "	- Pulling latest version"
			cd lib
			git pull
			cd $ROOT
		fi

		cd lib
		git pull || failure
		cd $ROOT
		
		echo "Completed" | tee -a $LOGFILE
        ;;
	$TARGET_REMOVE)
		read -p "This will remove all the source and library folders along with any changes made, are you sure you want to continue? (y/n)?"
		[ "$REPLY" == "y" ] || exit 0;
		clean || failure
		;;
	$TARGET_CLEAN)
		echo "Cleaning up build files, see clean.err and clean.log for more details..."

		make ARCH=$target_arch BUILD=$platform realclean 2>&1 1>make.log 

		if grep " Error " make.log 1>/dev/null 2>&1
		then
			#cat make.err > $LOGFILE
			failure
		fi
		;;
    *)
        # should be unreachable
        print_usage
        exit 1
        ;;
esac

echo
echo "************************************	" | tee -a $LOGFILE
echo " Finished with no errors              " | tee -a $LOGFILE
echo "`date`" | tee -a $LOGFILE
echo "************************************" | tee -a $LOGFILE

cd $ROOT

exit 0
