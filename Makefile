# Copyright (c) 2015 Damien Ciabrini
# This file is part of ngdevkit
#
# ngdevkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# ngdevkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

# Install dir, GNU mirrors...
include Makefile.config

# Version of external dependencies
SRC_BINUTILS=binutils-2.25
SRC_GCC=gcc-4.9.2
SRC_NEWLIB=newlib-1.14.0
SRC_GDB=gdb-7.8.2

all: \
	download-toolchain \
	unpack-toolchain \
	build-compiler \
	build-debugger \
	build-tools \
	download-emulator \
	build-emulator

download-toolchain: \
	toolchain/$(SRC_BINUTILS).tar.bz2 \
	toolchain/$(SRC_GCC).tar.bz2 \
	toolchain/$(SRC_NEWLIB).tar.gz \
	toolchain/$(SRC_GDB).tar.gz \

download-emulator: toolchain/gngeo

toolchain/$(SRC_BINUTILS).tar.bz2:
	curl $(GNU_MIRROR)/binutils/$(notdir $@) > $@

toolchain/$(SRC_GCC).tar.bz2:
	curl $(GNU_MIRROR)/gcc/$(SRC_GCC)/$(notdir $@) > $@

toolchain/$(SRC_NEWLIB).tar.gz:
	curl ftp://sourceware.org/pub/newlib/$(notdir $@) > $@

toolchain/$(SRC_GDB).tar.gz:
	curl $(GNU_MIRROR)/gdb/$(notdir $@) > $@

toolchain/gngeo:
	git clone https://github.com/dciabrin/GnGeo-Pi.git $@

clean-toolchain:
	rm -f toolchain/*.tar.* toolchain/gngeo


unpack-toolchain: \
	toolchain/$(SRC_BINUTILS) \
	toolchain/$(SRC_GCC) \
	toolchain/$(SRC_NEWLIB) \
	toolchain/$(SRC_GDB) \

toolchain/$(SRC_BINUTILS): toolchain/$(SRC_BINUTILS).tar.bz2
toolchain/$(SRC_GCC): toolchain/$(SRC_GCC).tar.bz2
toolchain/$(SRC_NEWLIB): toolchain/$(SRC_NEWLIB).tar.gz
toolchain/$(SRC_GDB): toolchain/$(SRC_GDB).tar.gz


toolchain/%: 
	echo uncompressing $(notdir $@)...; \
	cd toolchain; \
	tar $(if $(filter %.gz, $<),z,j)xmf $(notdir $<); \
	f=../patch/$(subst /,.diff,$(dir $(subst -,/,$(notdir $@)))); \
	if [ -f $$f ]; then (cd $(notdir $@); patch -p1 < ../$$f); fi; \
	echo Done.


build-compiler: build/ngbinutils build/nggcc build/ngnewlib
build-debugger: build/nggdb
build-emulator: build/gngeo

build/ngbinutils:
	@ echo compiling binutils...; \
	mkdir -p build/ngbinutils; \
	cd build/ngbinutils; \
	../../toolchain/$(SRC_BINUTILS)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	-v; \
	make $(HOSTOPTS); \
	make install

build/nggcc:
	@ echo compiling gcc...; \
	mkdir -p build/nggcc; \
	cd build/nggcc; \
	../../toolchain/$(SRC_GCC)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	--with-cpu=m68000 \
	--with-threads=single \
	--with-libs=$(LOCALDIR)/lib \
	--with-gnu-as \
	--with-gnu-ld \
	--with-newlib \
	--disable-multilib \
	--disable-libssp \
	--enable-languages=c \
	-v; \
	make $(HOSTOPTS); \
	make install

build/ngnewlib: build
	@ echo compiling newlib...; \
	export PATH=$(LOCALDIR)/bin:$$PATH; \
	mkdir -p build/ngnewlib; \
	cd build/ngnewlib; \
	../../toolchain/$(SRC_NEWLIB)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	--enable-target-optspace=yes \
	--enable-newlib-multithread=no \
	-v; \
	make $(HOSTOPTS); \
	make install

build/nggdb: build
	@ echo compiling gdb...; \
	export PATH=$(LOCALDIR)/bin:$$PATH; \
	mkdir -p build/nggdb; \
	cd build/nggdb; \
	../../toolchain/$(SRC_GDB)/configure \
	--prefix=$(LOCALDIR) \
	--target=m68k-neogeo-elf \
	-v; \
	make $(HOSTOPTS); \
	make install

build/gngeo: build
	@ echo compiling gngeo...; \
	export PATH=$(LOCALDIR)/bin:$$PATH; \
	mkdir -p build/gngeo; \
	cd build/gngeo; \
	../../toolchain/gngeo/gngeo/configure \
	--prefix=$(LOCALDIR) \
	--disable-i386asm \
	--target=x86_64 \
	-v CFLAGS="-I$(LOCALDIR)/include" LDFLAGS="-L$(LOCALDIR)/lib"; \
	make $(HOSTOPTS); \
	make install

# (find . -name Makefile | xargs sed -i.bk -e 's/-frerun-loop-opt//g' -e 's/-funroll-loops//g' -e 's/-malign-double//g');

build-tools:
	for i in nullbios runtime include tools/tiletool debugger; do \
	  $(MAKE) -C $$i install; \
	done

shellinit:
	@ echo Variables set with eval $$\(make shellinit\) >&2
	@ echo export PATH=$(LOCALDIR)/bin:\$$PATH
ifeq ($(shell uname), Darwin)
	@ echo export DYLD_LIBRARY_PATH=$(LOCALDIR)/lib:\$$DYLD_LIBRARY_PATH
else
	@ echo export LD_LIBRARY_PATH=$(LOCALDIR)/lib:\$$LD_LIBRARY_PATH
endif
	@ echo export PYTHONPATH=$(LOCALDIR)/bin:\$$PYTHONPATH

clean:
	rm -rf build/ngbinutils build/nggcc build/ngnewlib
	rm -rf local/*

distclean: clean
	find toolchain -mindepth 1 -maxdepth 1 -not -name README.md -exec rm -rf {} \;
	rm -rf build local
	find . -name '*~' -exec rm -f {} \;

.PHONY: clean distclean
