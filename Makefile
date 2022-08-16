BUILDDIR = build
INSTALLDIR ?= ../antd-web-apps/apps/assets/scripts
SED=sed
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SED=gsed
endif

main: js asm

js:
	-rm *.js
	coffee --compile WVNC.coffee
	coffee --compile decoder.coffee
	$(SED) '2d' decoder.js > tmp.js
	$(SED) '$$ d' tmp.js > decoder.js
	cp WVNC.js decoder.js $(BUILDDIR)/ 
	#uglifyjs WVNC.js --compress --mangle --output $(BUILDDIR)/wvnc.js
	#uglifyjs decoder.js --compress --mangle --output $(BUILDDIR)/decoder.js
	rm *.js

dep:
	cd wasm && ./dep.sh

all: dep asm js

asm:
	emcc -o $(BUILDDIR)/wvnc_asm.js -I wasm/libjpeg/  wasm/decoder.c \
	wasm/libjpeg/.libs/libjpeg.a \
	-O3 -s ALLOW_MEMORY_GROWTH=1  -s WASM=1 -s NO_EXIT_RUNTIME=1 -s \
	'EXTRA_EXPORTED_RUNTIME_METHODS=["cwrap"]' 

install: js asm
	cp $(BUILDDIR)/* $(INSTALLDIR)

install_decoder: js asm
	cp $(BUILDDIR)/decoder.js $(INSTALLDIR)/decoder_asm.js
	cp $(BUILDDIR)/wvnc_asm.js $(INSTALLDIR)
	cp $(BUILDDIR)/wvnc_asm.wasm $(INSTALLDIR)

clean:
	-rm *.js
	-rm -rf $(BUILDDIR)/*  