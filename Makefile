# $Id: Makefile 3068 2008-04-16 13:29:30Z adf $
#
# Main Makefile for Finesse


# work out the name of the host we're on
HOSTNAME = $(shell uname -n)

#echo "seeting CC=gcc"
#CC ?= gcc
#export CC = gcc


.PHONY: clean lib src doc/manual api api_clean realclean

default: kat

kat: testarch lib src 

fast: kat

testarch:
ifeq (,$(ARCH)) 
	$(error No ARCH flag found) 
endif

# library building target
lib:
	$(MAKE) --directory=$@ ARCH=$(ARCH)  

# finesse building targets
src: lib
	$(MAKE) --directory=$@ ARCH=$(ARCH) kat 

debug: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

prof: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

config: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

cover: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

versionnumber: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

test: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

test_cover: lib
	$(MAKE) --directory=src ARCH=$(ARCH) $@

# documentation building targets
doc: doc/manual

doc/manual:
	$(MAKE) --directory=$@

api:
	$(MAKE) --directory=src $@

api_clean:
	$(MAKE) --directory=src $@

cover_report:
	$(MAKE) --directory=src $@

# cleanup targets
clean:
	$(MAKE) --directory=src $@

realclean:
	for d in lib src;  \
	do  \
	     $(MAKE) --directory=$$d clean; \
	done 
	rm lib/KLUsparse/*/Lib/*.a; 
	rm lib/Cuba-3.0/*.a; 

# print out the possible options to pass to make
help:
	@echo "Possible targets are:"
	@echo "For building Finesse:"
	@echo "    kat: build with all optimisations"
	@echo "    fast: an alias for kat"
	@echo "    prof: build with profiling information switched on"
	@echo "    cover: build with code coverage information switched on"
	@echo "    debug: build with debugging information switched on"
	@echo "    versionnumber: build with all optimisations, and append"
	@echo "         svn (or svk) revision number to binary name"
	@echo "Testing:"
	@echo "    test: build and runs the unit tests"
	@echo "    test_cover: build and runs the unit tests, with coverage"
	@echo "                information switched on"
	@echo "For building the associated libraries:"
	@echo "    lib: builds all libraries required to build Finesse"
	@echo "Documentation:"
	@echo "    api: build the API level documentation"
	@echo "    cover_report: generate the coverage report with lcov"
	@echo "Other targets:"
	@echo "    clean: remove relevant object and binary files"
	@echo "    realclean: remove all object and binary files for Finesse,"
	@echo "         libraries, and documentation"
	@echo "    help: print this information to the screen"

# vim: shiftwidth=4:
