#!/bin/bash
set -ex

cp $RECIPE_DIR/Makefile.conda.SEQ ./Makefile.inc


if [[ "$target_platform" == linux-* || "$target_platform" == "osx-arm64" || "$target_platform" == "osx-64" ]]
then
  # Workaround for https://github.com/conda-forge/scalapack-feedstock/pull/30#issuecomment-1061196317
  export FFLAGS="${FFLAGS} -fallow-argument-mismatch"
  export OMPI_FCFLAGS=${FFLAGS}
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  # This is only used by open-mpi's mpicc
  # ignored in other cases
  export OMPI_CC=$CC
  export OMPI_CXX=$CXX
  export OMPI_FC=$FC
  export OPAL_PREFIX=$PREFIX
fi

if [[ "$(uname)" == "Darwin" ]]; then
  export SONAME="-install_name"
  export LDFLAGS="${LDFLAGS} -headerpad_max_install_names"
  function set_soname () {
    install_name_tool -id "@rpath/$(basename $1)" "$1"
  }
else
  export SONAME="-soname"
  function set_soname () {
    patchelf --set-soname "$(basename $1)" "$1"
  }
fi

# Makefile doesn't accept LDFLAGS in linking, pass via SHARED_OPT
export LIBEXT_SHARED=${SHLIB_EXT}
export SHARED_OPT="${LDFLAGS} -shared"
export RPATH_OPT="-Wl,-rpath,$PREFIX/lib"

make allshared PLAT=_seq

mkdir -p "${PREFIX}/lib"
mkdir -p "${PREFIX}/include/mumps_seq"

ls lib
cd lib
# resolve -lmpiseq to libmpiseq_seq.dylib
test -f libmpiseq_seq${SHLIB_EXT}
ln -s libmpiseq_seq${SHLIB_EXT} libmpiseq${SHLIB_EXT}
test -f libmpiseq${SHLIB_EXT}
cd ..

# make sure SONAME is right, which it isn't
for dylib in lib/*${SHLIB_EXT}; do
  set_soname "$dylib"
done


cp -av lib/*${SHLIB_EXT} ${PREFIX}/lib/
cp -av libseq/*${SHLIB_EXT} ${PREFIX}/lib/
cp -av libseq/mpi*.h ${PREFIX}/include/mumps_seq/

python3 $RECIPE_DIR/make_pkg_config.py

if [[ "$CONDA_BUILD_CROSS_COMPILATION" != "1" ]]; then
  cd examples

  ./ssimpletest < input_simpletest_real
  ./dsimpletest < input_simpletest_real
  ./csimpletest < input_simpletest_cmplx
  ./zsimpletest < input_simpletest_cmplx
  ./c_example
fi
