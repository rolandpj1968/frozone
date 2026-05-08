# Makefile for box-first AOT-emitted output.
#
# Usage:
#   make            # parallel-compile (use -j N for N-way) → frozone_box
#   make -j 8       # 8-way parallel build
#   make clean      # remove .o, .gch, binary
#
# Pattern:
#   1. Compile frozone_layouts.hpp.gch once (PCH).
#   2. Compile each frozone*.cpp → .o, using the PCH (each TU re-uses
#      the cached header AST instead of re-parsing 6 MB every time).
#   3. Link all .o into the binary.
#
# Editing one Ruby source → AOT rewrites the corresponding
# frozone_class_<N>.cpp (atomic write-if-different keeps unchanged
# files' mtime stable). make recompiles only that one .o + relinks.
# Incremental cycle: ~5-15 sec instead of ~7 min full rebuild.

CXX      ?= g++
CXXFLAGS ?= -O0 -g0 -DFROZONE_USE_BOEHM_GC -std=c++20
INCLUDES := -I ../../../vendor/Onigmo/_install/include
LIBS     := ../../../vendor/Onigmo/_install/lib/libonigmo.a -lgc

# Glob frozone-generated sources only (cpp/gen/box/ has test artifacts
# from older work too; the prefix filter excludes them).
CPPS := $(wildcard frozone.cpp frozone_*.cpp)
OBJS := $(CPPS:.cpp=.o)

PCH       := frozone_layouts.hpp.gch
PCH_INPUT := frozone_layouts.hpp

# Binary name + location. Default puts it in /tmp like the manual
# build commands have been doing; override via BIN=path on the
# command line if you want it elsewhere.
BIN ?= /tmp/frozone_box

.PHONY: all clean
all: $(BIN)

# Link
$(BIN): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) $(LIBS) -o $@

# PCH compile — runs once unless layouts header changes.
$(PCH): $(PCH_INPUT)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -x c++-header -c $< -o $@

# Per-TU compile. Depends on the PCH so a layouts change rebuilds
# everything; otherwise edits to one .cpp recompile only that .o.
%.o: %.cpp $(PCH)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJS) $(PCH) $(BIN)
