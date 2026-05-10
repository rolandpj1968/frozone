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
CXXFLAGS ?= -O0 -g -DFROZONE_USE_BOEHM_GC -std=c++20
INCLUDES := -I ../../../vendor/Onigmo/_install/include
LIBS     := ../../../vendor/Onigmo/_install/lib/libonigmo.a -lgc

# Default to parallel build using all cores. Override with `make -j N`
# to limit (or `make JOBS=4` to set the auto-default). This appends
# `-j N` to MAKEFLAGS for the current invocation; a user-supplied
# `-j` on the command line takes precedence (make merges -j flags;
# the explicit one wins for the actual job-server).
JOBS ?= $(shell nproc 2>/dev/null || echo 4)
MAKEFLAGS += -j$(JOBS)

# Glob frozone-generated sources only (cpp/gen/box/ has test artifacts
# from older work too; the prefix filter excludes them).
CPPS := $(wildcard frozone.cpp frozone_*.cpp)
OBJS := $(CPPS:.cpp=.o)

# Stage 3 Path 2 of the layouts.hpp split: PCH the cache-root meta-
# header frozone_all.hpp (which is just `#include base + post +
# layouts`). Per-class TUs start with `#include "frozone_all.hpp"`
# so gcc activates the .gch and the entire 50k-line universe loads
# from cache. Decoupled from include strategy: when layouts.hpp
# eventually goes away, edit frozone_all.hpp's include list — per-
# class .cpp first-include doesn't change.
PCH       := frozone_all.hpp.gch
PCH_INPUT := frozone_all.hpp

# Binary name + location. Default puts it in /tmp like the manual
# build commands have been doing; override via BIN=path on the
# command line if you want it elsewhere.
BIN ?= /tmp/frozone_box

.PHONY: all clean
all: $(BIN)

# Link
$(BIN): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) $(LIBS) -o $@

# PCH compile — runs once unless layouts header (or anything it
# transitively includes — box_first.hpp, intrinsics.hpp,
# frozone.hpp, …) changes. -MMD generates a .d file alongside
# the PCH listing every header it pulled in; -include picks it
# up on the next make invocation so subsequent edits to those
# headers correctly trigger a PCH rebuild → full recompile.
$(PCH): $(PCH_INPUT)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -MF $@.d -x c++-header -c $< -o $@

# Per-TU compile. Depends on the PCH so a layouts change rebuilds
# everything; otherwise edits to one .cpp recompile only that .o.
# -MMD on each .o records its own header deps (mostly redundant
# with the PCH dep but covers cases where a TU includes something
# the PCH doesn't).
%.o: %.cpp $(PCH)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -MF $@.d -c $< -o $@

# Pull in generated dep files so transitive header edits invalidate
# the right targets. `-` swallows the "no such file" warning on
# clean trees.
-include $(PCH).d
-include $(OBJS:.o=.o.d)

clean:
	rm -f $(OBJS) $(OBJS:.o=.o.d) $(PCH) $(PCH).d $(BIN)
