# =========================================================================
# PICLas CMake configuration
# =========================================================================
CMAKE_MINIMUM_REQUIRED(VERSION 2.8.11)
# TODO: eventually require CMake 3.0 in future releases
# Advantages: Possible to split string
IF ("${CMAKE_VERSION}" VERSION_GREATER 3.11)
    # use the <PackageName>_ROOT for searching packages
    cmake_policy (SET CMP0074 NEW)
    # From the following TWO settings,  the OLD behavior is deprecated
    # produces a "FATAL_ERROR" if "get_target_property()"is called with a
    # non-existing argument
    cmake_policy (SET CMP0045 NEW) 
    # error in non-existing dependencies, NEW report error
    cmake_policy (SET CMP0046 NEW)
ELSE()
  IF ("${CMAKE_VERSION}" VERSION_GREATER 3.0.0)
    cmake_policy (SET CMP0045 OLD)
    cmake_policy (SET CMP0046 OLD)
  ENDIF()
ENDIF()
LIST(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
SET_PROPERTY(GLOBAL PROPERTY USE_FOLDERS ON)
INCLUDE(ExternalProject)
INCLUDE(CMakeDependentOption)

# =========================================================================
# Check whether we are on Github or at IAG
# =========================================================================
EXECUTE_PROCESS(COMMAND git ls-remote --get-url OUTPUT_VARIABLE GIT_ORIGIN)
STRING(FIND "${GIT_ORIGIN}" ".iag.uni-stuttgart.de" HOMERUN)
STRING(FIND "${GIT_ORIGIN}" "git@" USESSH)
IF (HOMERUN GREATER -1)
  IF(USESSH EQUAL 0)
    SET(PICLAS_DLPATH "git@gitlab.iag.uni-stuttgart.de:")
  ELSE()
    SET(PICLAS_DLPATH "https://gitlabext.iag.uni-stuttgart.de/")
  ENDIF()
  SET (HDF5DOWNLOAD ${PICLAS_DLPATH}libs/hdf5.git )
ELSE()
  IF(USESSH EQUAL 0)
    SET(PICLAS_DLPATH "git@github.com:piclas-framework")
  ELSE()
    SET(PICLAS_DLPATH "https://github.com/piclas-framework")
  ENDIF()
  SET (HDF5DOWNLOAD https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git )
ENDIF()
SET (HDF5TAG "hdf5-1_10_0-patch1" CACHE STRING "HDF5 version tag")

# =========================================================================
# Detect machine environements
# =========================================================================
SITE_NAME(CMAKE_HOSTNAME)
STRING(FIND "${CMAKE_HOSTNAME}" "eslogin" ONHORNET)
# Set options that need to be enabled BEFORE ANY PROJECT OR LANGUAGE COMMAND
IF (ONHORNET GREATER -1)
  SET(CMAKE_C_COMPILER       cc)
  SET(CMAKE_CXX_COMPILER     CC)
  SET(CMAKE_Fortran_COMPILER ftn)
  SET(HDF5_USE_STATIC_LIBRARIES TRUE)
  MARK_AS_ADVANCED(C_PATH CXX_PATH Fortran_PATH)
  MESSAGE(STATUS "Compiling on Hazelhen")
  ADD_DEFINITIONS(-DLUSTRE)
ENDIF()

# =========================================================================
# Project definitions and output paths
# =========================================================================

PROJECT(PICLas)
ENABLE_LANGUAGE(Fortran)

SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin)
SET(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
SET(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib)
SET(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib)

# Set custom install dir (needs to be done after project has been defined!)
IF(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  SET(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH "Prefix prepended to install directories" FORCE)
ENDIF()

# =========================================================================
# Options
# =========================================================================

MACRO(SUBDIRLIST result curdir)
  FILE(GLOB children RELATIVE ${curdir} ${curdir}/*)
  SET(dirlist "")
  FOREACH(child ${children})
    IF(IS_DIRECTORY ${curdir}/${child})
      LIST(APPEND dirlist ${child})
    ENDIF()
  ENDFOREACH()
  SET(${result} ${dirlist})
ENDMACRO()
SUBDIRLIST(EQNSYSTEMS ${CMAKE_CURRENT_SOURCE_DIR}/src/equations/)

OPTION(PICLAS_PARTICLES "Particles" ON)
SET(PICLAS_TIMEDISCMETHOD "RK4" CACHE STRING "Time integration method")
SET_PROPERTY(CACHE PICLAS_TIMEDISCMETHOD PROPERTY STRINGS Euler-Explicit
                                                          Leapfrog
                                                          RK3
                                                          RK4
                                                          RK14
                                                          ParticleEuler-FieldRK4
                                                          DSMC
                                                          RESERVOIR
                                                          CN
                                                          ImplicitO3
                                                          ImplicitO4
                                                          Ascher3
                                                          ROS2
                                                          ROS3
                                                          ROS4
                                                          ROS46
                                                          ROS6
                                                          FieldRelaxation
                                                          FieldRelaxation-AdaptiveTimeStep
                                                          LD
                                                          LD-DSMC)

OPTION(PICLAS_QDS_DG "enable QDS method discretized by DGSEM" OFF)
OPTION(PICLAS_BUILDPOSTI "Build POSTI toolset" OFF)
OPTION(PICLAS_MPI "Compile SINGLE or MPI version" ON)
CMAKE_DEPENDENT_OPTION(PICLAS_LOADBALANCE "Use LoadBalance timemeasurement" ON "PICLAS_MPI" OFF)
OPTION(PICLAS_MKL "Use MKL libraries instead of BLAS/LAPACK" OFF)
OPTION(PICLAS_PAPI "Use PAPI library to perform performance measurements (e.g. flop counts)." OFF)
SET(PICLAS_BUILD_HDF5 OFF  CACHE BOOL "Compile and build hdf5 library")
OPTION(PICLAS_HDF5F90 "enable old HDF5 interface" OFF)

SET(PICLAS_EQNSYSNAME "maxwell" CACHE STRING "Used equation system")
SET_PROPERTY(CACHE PICLAS_EQNSYSNAME PROPERTY STRINGS ${EQNSYSTEMS})

OPTION(PICLAS_IMPLICIT_ANALYZE "IMPLICIT_ANALYZE" OFF)

SET(PICLAS_POLYNOMIAL_DEGREE "N" CACHE STRING "N: compile with variable polynomial degree. 1,2,3,...: compile with fixed polynomial degree for performance (untested).")
ADD_DEFINITIONS(-DPP_N=${PICLAS_POLYNOMIAL_DEGREE})

##### Node type
SET(PICLAS_NODETYPE "GAUSS" CACHE STRING "Set of nodes used for representing the solution (GAUSS/GAUSS-LOBATTO).")
SET_PROPERTY(CACHE PICLAS_NODETYPE PROPERTY STRINGS "GAUSS" "GAUSS-LOBATTO")
IF(PICLAS_NODETYPE STREQUAL "GAUSS")
  ADD_DEFINITIONS(-DPP_NodeType=1)
ELSEIF(PICLAS_NODETYPE STREQUAL "GAUSS-LOBATTO")
  ADD_DEFINITIONS(-DPP_NodeType=2)
ELSE()
  MESSAGE(ERROR "No such node type known.")
ENDIF()
ADD_DEFINITIONS(-DPP_nElems=NELEMZ)

# code development
OPTION(PICLAS_CODE_ANALYZE "Code Analyze" OFF)
OPTION(PICLAS_CTAGS "Use Ctags" ON)

# =========================================================================
# Equation system
# =========================================================================

IF(PICLAS_EQNSYSNAME STREQUAL "maxwell")
  #SET(PICLAS_C_PREPROC ${F2P_C_PREPROC} -Dmaxwell)
  ADD_DEFINITIONS(-DPP_nVar=8 -Dmaxwell)
  SET(PICLAS_HDG OFF)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "maxwell_pois")
  ADD_DEFINITIONS(-DPP_nVar=8 -Dmaxwell_pois -DPOIS)
  SET(PICLAS_HDG OFF)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "electrostatic_pois")
  ADD_DEFINITIONS(-DPP_nVar=4 -Delectostratic -DPOIS)
  SET(PICLAS_HDG OFF)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "electrostatic")
  ADD_DEFINITIONS(-DPP_nVar=4 -Delectrostatic)
  SET(PICLAS_HDG OFF)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "poisson")
  ADD_DEFINITIONS(-DPP_nVar=1 -Dpoisson)
  SET(PICLAS_HDG ON)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "magnetostatic")
  ADD_DEFINITIONS(-DPP_nVar=3 -Dmagnetostatic)
  SET(PICLAS_HDG ON)
ELSEIF(PICLAS_EQNSYSNAME STREQUAL "magnetostatic_poisson")
  ADD_DEFINITIONS(-DPP_nVar=4 -Dmagnetostatic_poisson)
  SET(PICLAS_HDG ON)
ELSE()
   MESSAGE(ERROR "Unknown equation system.")
ENDIF()

# =========================================================================
# PARTICLES
# =========================================================================

IF(PICLAS_PARTICLES)
  ADD_DEFINITIONS(-DPARTICLES)
ENDIF(PICLAS_PARTICLES)

# =========================================================================
# CODE_ANALYZE
# =========================================================================

IF(PICLAS_CODE_ANALYZE)
  ADD_DEFINITIONS(-DCODE_ANALYZE)
ENDIF(PICLAS_CODE_ANALYZE)

# =========================================================================
# Timedisc method
# =========================================================================
SET(PICLAS_IMPLICIT OFF)
IF(PICLAS_TIMEDISCMETHOD STREQUAL "Euler-Explicit")
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG -DPP_TimeDiscMethod=500)
  ELSE()
      ADD_DEFINITIONS(-DPP_TimeDiscMethod=0)
  ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "Leapfrog")
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG -DPP_TimeDiscMethod=509)
  ELSE()
      ADD_DEFINITIONS(-DPP_TimeDiscMethod=0)
  ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK3")
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG -DPP_TimeDiscMethod=501 -DLSERK)
  ELSE()
      ADD_DEFINITIONS(-DPP_TimeDiscMethod=1 -DLSERK)
  ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK4")
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG -DPP_TimeDiscMethod=502 -DLSERK)
  ELSE()
      ADD_DEFINITIONS(-DPP_TimeDiscMethod=2 -DLSERK)
  ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK14")
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG -DPP_TimeDiscMethod=506 -DLSERK)
  ELSE()
      ADD_DEFINITIONS(-DPP_TimeDiscMethod=6 -DLSERK)
  ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ParticleEuler-FieldRK4")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=5)
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "DSMC")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=4)
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RESERVOIR")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=42)
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "CN")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=120 -DIMPA)
   SET(PICLAS_IMPLICIT ON)
   IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ImplicitO3")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=121 -DIMPA)
   SET(PICLAS_IMPLICIT ON)
   IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ImplicitO4")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=122 -DIMPA)
   SET(PICLAS_IMPLICIT ON)
   IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "Ascher3")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=123 -DIMPA)
   SET(PICLAS_IMPLICIT ON)
   IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS2")
  ADD_DEFINITIONS(-DPP_TimeDiscMethod=130 -DROS)
  SET(PICLAS_IMPLICIT ON)
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS3")
  ADD_DEFINITIONS(-DPP_TimeDiscMethod=131 -DROS)
  SET(PICLAS_IMPLICIT ON)
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS4")
  ADD_DEFINITIONS(-DPP_TimeDiscMethod=132 -DROS)
  SET(PICLAS_IMPLICIT ON)
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS46")
  ADD_DEFINITIONS(-DPP_TimeDiscMethod=133 -DROS)
  SET(PICLAS_IMPLICIT ON)
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS6")
  ADD_DEFINITIONS(-DPP_TimeDiscMethod=134 -DROS)
  SET(PICLAS_IMPLICIT ON)
  IF(PICLAS_HDG)
      ADD_DEFINITIONS(-DPP_HDG)
   ENDIF()
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "FieldRelaxation")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=200)
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "FieldRelaxation-AdaptiveTimeStep")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=201)
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "LD")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=1000)
 ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "LD-DSMC")
   ADD_DEFINITIONS(-DPP_TimeDiscMethod=1001)
ELSE()
   MESSAGE(ERROR "Unknown timedisc method system.")
ENDIF()
IF(PICLAS_IMPLICIT_ANALYZE)
  ADD_DEFINITIONS(-DIMPLICIT_ANALYZE)
ENDIF(PICLAS_IMPLICIT_ANALYZE)

# =========================================================================
# HDG
# =========================================================================

IF(PICLAS_HDG)
  ADD_DEFINITIONS(-DPP_HDG)
  IF(PICLAS_TIMEDISCMETHOD STREQUAL "Euler-Explicit")
      MESSAGE(STATUS "use HDG with Euler-Explicit")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "Leapfrog")
      MESSAGE(STATUS "use HDG with Leapfrog")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK3")
      MESSAGE(STATUS "use HDG with RK3")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK4")
      MESSAGE(STATUS "use HDG with RK4")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "RK14")
      MESSAGE(STATUS "use HDG with RK14")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "CN")
      MESSAGE(STATUS "use HDG with CN")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ImplicitO3")
     MESSAGE(STATUS "use HDG with ImplicitO3")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ImplicitO4")
     MESSAGE(STATUS "use HDG with ImplicitO4")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS2")
     MESSAGE(STATUS "use HDG with ROS2")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS4")
     MESSAGE(STATUS "use HDG with ROS4")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS46")
     MESSAGE(STATUS "use HDG with ROS46")
  ELSEIF(PICLAS_TIMEDISCMETHOD STREQUAL "ROS6")
     MESSAGE(STATUS "use HDG with ROS6")
  ELSE()
      MESSAGE(ERROR ": Unknown timedisc method system for HDG.")
  ENDIF()
ENDIF(PICLAS_HDG)

# =========================================================================
# USERBLOCK + Preproc_flags
# =========================================================================

# A function to get all user defined variables with a specified prefix
function (getListOfVarsStartingWith _prefix _varResult)
    GET_CMAKE_PROPERTY(_vars CACHE_VARIABLES)
    STRING(REGEX MATCHALL "(^|;)${_prefix}[A-Za-z0-9_]*" _matchedVars "${_vars}")
    SET(${_varResult} ${_matchedVars} PARENT_SCOPE)
endfunction()

# A function to get all user defined variables with a specified prefix
SET(configuration ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/configuration.cmake)
FILE(WRITE ${configuration} "")
GETLISTOFVARSSTARTINGWITH("PICLAS_" piclasVars)
FOREACH (_var IN LISTS piclasVars)
  GET_PROPERTY(currentHelpString CACHE "${_var}" PROPERTY HELPSTRING)
  SET(boolian (${${_var}} STREQUAL "ON" OR ${${_var}} STREQUAL "OFF")) 
  IF(${boolian})
    FILE(APPEND ${configuration} "OPTION(${_var} \"${currentHelpString}\" ${${_var}})\n")
  ELSE()
    IF(${_var})
      STRING(REPLACE "\\" "\\\\" ${_var} ${${_var}})
    ENDIF()
    FILE(APPEND ${configuration} "SET(${_var} \"${${_var}}\" CACHE STRING \"${currentHelpString}\")\n")
  ENDIF()
ENDFOREACH()


# =========================================================================
# Build type
# =========================================================================
# make sure that the default is a RELEASE
IF (NOT CMAKE_BUILD_TYPE)
   SET (CMAKE_BUILD_TYPE Release CACHE STRING
      "Choose the type of build, options are: Debug Release Profile."
      FORCE)
   IF (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
     SET_PROPERTY(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release Profile SANI)
   ELSEIF (CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
     SET_PROPERTY(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release Profile)
   ELSEIF (CMAKE_Fortran_COMPILER_ID MATCHES "Cray")
     SET_PROPERTY(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release Profile)
   ENDIF()
ENDIF (NOT CMAKE_BUILD_TYPE)

IF (CMAKE_BUILD_TYPE MATCHES "Debug")
  ADD_DEFINITIONS("-DDEBUG")
ENDIF()

# =========================================================================
# Location of binary and filenames
# =========================================================================

# append relative filename-macro for __FILENAME__ in Stamp of abort function (see piclas.h)
SET(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -D__FILENAME__='\"$(subst ${CMAKE_SOURCE_DIR}/,,$(abspath $<))\"'")

# add basedir for location of corresponding userblock-file
ADD_DEFINITIONS("-DBASEDIR='\"${CMAKE_CURRENT_BINARY_DIR}/\"'")

# =========================================================================
# COMPILER FLAGS
# =========================================================================

# FFLAGS depend on the compiler
GET_FILENAME_COMPONENT (Fortran_COMPILER_NAME ${CMAKE_Fortran_COMPILER} NAME)

IF (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
  #environment specific variables
  IF(ONHORNET GREATER -1)
    SET(PICLAS_INSTRUCTION "-march=core-avx2")
  ELSE()
    SET(PICLAS_INSTRUCTION "-march=native")
  ENDIF()
  # set Flags
  SET (CMAKE_Fortran_FLAGS         "${CMAKE_Fortran_FLAGS} -fdefault-real-8 -fdefault-double-8 -fbackslash -ffree-line-length-0 -DGNU")
  SET (CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS}     -O3 ${PICLAS_INSTRUCTION} -finline-functions -fstack-arrays -finit-character=0")
  SET (CMAKE_Fortran_FLAGS_PROFILE "${CMAKE_Fortran_FLAGS} -pg -O0 ${PICLAS_INSTRUCTION} -finline-functions -fstack-arrays -finit-character=0")
  SET (CMAKE_Fortran_FLAGS_DEBUG   "${CMAKE_Fortran_FLAGS} -g  -O0 -ggdb3 -fcheck=bounds,do,mem,pointer -finit-real=snan -finit-integer=snan -finit-logical=false -finit-character=0 -ffpe-trap=invalid,zero,overflow -fbacktrace  -Wall")
  SET (CMAKE_Fortran_FLAGS_SANI    "${CMAKE_Fortran_FLAGS} -g  -O0 -ggdb3 -fcheck=bounds,do,mem,pointer -finit-real=snan -finit-integer=snan -finit-logical=false -finit-character=0 -ffpe-trap=invalid,zero,overflow -fbacktrace  -Wall -fsanitize=address,undefined,leak -fno-omit-frame-pointer -Wc-binding-type -Wuninitialized")
  # add flags only for compiling not linking!
  SET (PICLAS_COMPILE_FLAGS "-xf95-cpp-input")

ELSEIF (CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
   #environment specific variables
   IF(ONHORNET GREATER -1)
     SET(PICLAS_INSTRUCTION "-xCORE-AVX2")
   ELSE()
     SET(PICLAS_INSTRUCTION "-xHost")
   ENDIF()
   # set Flags
  SET (CMAKE_Fortran_FLAGS         "${CMAKE_Fortran_FLAGS} -r8 -i4 -traceback -warn all -shared-intel -DINTEL")
  SET (CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS}    -O2 ${PICLAS_INSTRUCTION} -qopt-report0 -qopt-report-phase=vec -no-prec-div")
  SET (CMAKE_Fortran_FLAGS_PROFILE "${CMAKE_Fortran_FLAGS} -p -O2 ${PICLAS_INSTRUCTION} -qopt-report0 -qopt-report-phase=vec -no-prec-div")
  SET (CMAKE_Fortran_FLAGS_DEBUG   "${CMAKE_Fortran_FLAGS} -g -O0 -fpe0 -traceback -check all,noarg_temp_created,noformat,nooutput_conversion,pointer,uninit -init=snan -init=arrays")
   # add flags only for compiling not linking!
   SET (PICLAS_COMPILE_FLAGS "-fpp -assume bscc")

ELSEIF (CMAKE_Fortran_COMPILER_ID MATCHES "Cray")
  # set Flags
  SET (CMAKE_Fortran_FLAGS         "${CMAKE_Fortran_FLAGS} -f free -s real64 -em -DCRAY")
  SET (CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS} -O3 -hfp3 -p . -rm")
  SET (CMAKE_Fortran_FLAGS_PROFILE "${CMAKE_Fortran_FLAGS} -O3 -hfp3 -h profile_generate -p . -rm")
  SET (CMAKE_Fortran_FLAGS_DEBUG   "${CMAKE_Fortran_FLAGS} -O0 -eD -rm")
  # add flags only for compiling not linking!
  SET (PICLAS_COMPILE_FLAGS "-F")

ELSE()
   MESSAGE(ERROR "Unknown compiler")
ENDIF()

# =========================================================================
# Add the libraries
# =========================================================================

IF(PICLAS_MPI)
  SET(PICLAS_EXTERNAL_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/share/${CMAKE_Fortran_COMPILER_ID}-MPI)
ELSE()
  SET(PICLAS_EXTERNAL_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/share/${CMAKE_Fortran_COMPILER_ID})
ENDIF()
MARK_AS_ADVANCED(PICLAS_EXTERNAL_LIB_DIR)

# =========================================================================
# HDF5 library
# =========================================================================
SET(LIB_TYPE STATIC) # OR SHARED
STRING(TOLOWER ${LIB_TYPE} SEARCH_TYPE)

# We support two methods for finding HDF5:
# the version built using configure scripts and using CMake
# Support for CMake-built HDF5 is limited to version >1.10.2
# which require at CMake >3.10
# Recommendations: use configure version if possible

IF(NOT PICLAS_BUILD_HDF5)
  SET(PICLAS_HDF5_CMAKE TRUE) # try to find the CMake version
  FIND_PACKAGE(HDF5 NAMES hdf5 COMPONENTS C Fortran ${SEARCH_TYPE} QUIET PATH_SUFFIXES share/cmake )
  IF (HDF5_FOUND)
    IF(${CMAKE_VERSION} VERSION_LESS "3.10.0")
      MESSAGE (WARNING "HDF5 built with CMake was found! This feature is only supported for CMake 3.10+ and HDF5 1.10.2+ !")
    ENDIF()
    MESSAGE (STATUS "HDF5 C libs:${HDF5_FOUND} static:${HDF5_static_C_FOUND} and shared:${HDF5_shared_C_FOUND}")
    MESSAGE (STATUS "HDF5 Fortran libs: static:${HDF5_static_Fortran_FOUND} and shared:${HDF5_shared_Fortran_FOUND}")
    MESSAGE (STATUS "h5diff found:${HDF5_DIFF_EXECUTABLE}")
  ELSE()
    SET(PICLAS_HDF5_CMAKE FALSE) # try to find the configure version
    FIND_PACKAGE(HDF5 COMPONENTS C Fortran)
  ENDIF()

ELSE()

  SET(PICLAS_HDF5_DLDIR ${PICLAS_EXTERNAL_LIB_DIR}/HDF5)
  SET(PICLAS_HDF5_DIR  ${PICLAS_HDF5_DLDIR}/build)
  IF (NOT EXISTS "${PICLAS_HDF5_DIR}/lib/libhdf5.a")
    IF(PICLAS_MPI)
      SET(PICLAS_HDF5PARALLEL --enable-parallel)
      SET(PICLAS_HDF5FC ${MPI_Fortran_COMPILER})
      SET(PICLAS_HDF5CC ${MPI_C_COMPILER})
    ELSE()
      UNSET(PICLAS_HDF5PARALLEL)
      SET(PICLAS_HDF5FC ${CMAKE_Fortran_COMPILER})
      SET(PICLAS_HDF5CC ${CMAKE_C_COMPILER} )
    ENDIF()
    #NOTE: old 1.8.X versions of HDF5 require additional flag --enable-fortran2003
    ExternalProject_Add(HDF5
      GIT_REPOSITORY ${HDF5DOWNLOAD}
      GIT_TAG ${HDF5TAG}
      PREFIX ${PICLAS_HDF5_DIR}
      UPDATE_COMMAND ""
      CONFIGURE_COMMAND FC=${PICLAS_HDF5FC} CC=${PICLAS_HDF5CC} ${PICLAS_HDF5_DIR}/src/HDF5/configure --prefix=${PICLAS_HDF5_DIR} --enable-fortran ${PICLAS_HDF5PARALLEL} --disable-shared --libdir=${PICLAS_HDF5_DIR}/lib
      BUILD_COMMAND ${MAKE}
    )
    LIST(APPEND SELFBUILTEXTERNALS HDF5)
    # CMake HDF5 is fast but not that reliable
    #ExternalProject_Add(HDF5
    #  GIT_REPOSITORY ${HDF5DOWNLOAD}
    #  GIT_TAG ${HDF5TAG}
    #  PREFIX ${PICLAS_HDF5_DIR}
    #  UPDATE_COMMAND ""
    #  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${PICLAS_HDF5_DIR} -DCMAKE_C_COMPILER=${PICLAS_HDF5CC} -DCMAKE_Fortran_COMPILER=${PICLAS_HDF5FC} -DBUILD-TESTING=OFF -DHDF5_BUILD_EXAMPLES=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_FORTRAN=ON -DHDF5_ENABLE_PARALLEL=ON
    #  BUILD_COMMAND ${MAKE}
    #)
  ENDIF()
  
  SET(PICLAS_HDF5_CMAKE FALSE)
  SET(HDF5_hdf5_LIBRARY_RELEASE         ${PICLAS_HDF5_DIR}/lib/libhdf5.a)
  SET(HDF5_hdf5_fortran_LIBRARY_RELEASE ${PICLAS_HDF5_DIR}/lib/libhdf5_fortran.a)
  SET(HDF5_C_INCLUDE_DIR                ${PICLAS_HDF5_DIR}/include)
  SET(HDF5_Fortran_INCLUDE_DIR          ${PICLAS_HDF5_DIR}/include)
  UNSET(HDF5_LIBRARIES)
  UNSET(HDF5_INCLUDE_DIR_FORTRAN)
  UNSET(HDF5_INCLUDE_DIR)
  UNSET(HDF5_DIFF_EXECUTABLE)
  SET(HDF5_DIFF_EXECUTABLE              ${PICLAS_HDF5_DIR}/bin/h5diff)
  LIST(APPEND HDF5_INCLUDE_DIR_FORTRAN ${HDF5_Fortran_INCLUDE_DIR} ${HDF5_C_INCLUDE_DIR})
  LIST(APPEND HDF5_INCLUDE_DIR  ${HDF5_C_INCLUDE_DIR})
  FIND_LIBRARY(HDF5_z_LIBRARY_RELEASE z)
  LIST(APPEND HDF5_LIBRARIES ${HDF5_hdf5_fortran_LIBRARY_RELEASE} ${HDF5_hdf5_LIBRARY_RELEASE} ${HDF5_z_LIBRARY_RELEASE} -ldl)
ENDIF()
IF (PICLAS_HDF5F90)
   ADD_DEFINITIONS(-DHDF5_F90)
ENDIF()
MESSAGE (STATUS "h5diff: ${HDF5_DIFF_EXECUTABLE}")

IF(PICLAS_HDF5_CMAKE)
  INCLUDE_DIRECTORIES(${HDF5_INCLUDE_DIR} ${HDF5_INCLUDE_DIR_FORTRAN})
  LIST(APPEND linkedlibs ${HDF5_C_${LIB_TYPE}_LIBRARY} ${HDF5_FORTRAN_${LIB_TYPE}_LIBRARY} )
ELSE()
  INCLUDE_DIRECTORIES (${HDF5_INCLUDE_DIR_FORTRAN} ${HDF5_INCLUDE_DIR})
  MESSAGE(STATUS "Found HDF5 Libs: " ${HDF5_LIBRARIES})
  LIST(APPEND linkedlibs ${HDF5_LIBRARIES} )
ENDIF()

# =========================================================================
# LAPACK/MKL library
# =========================================================================
# use Lapack/Blas for GNU
MESSAGE(STATUS "Using BLAS/Lapack library")
IF (PICLAS_MKL)
  SET(BLA_VENDOR "Intel") #search only for Intel BLAS (=MKL)
ENDIF()
FIND_PACKAGE(LAPACK QUIET)
IF (LAPACK_FOUND)
  LIST(APPEND linkedlibs ${LAPACK_LIBRARIES})
ENDIF()

# =========================================================================
# MPI
# =========================================================================
IF(PICLAS_MPI)
  FIND_PACKAGE(MPI REQUIRED)
  IF (NOT MPI_Fortran_NO_INTERROGATE)
    FOREACH(DIR ${MPI_INCLUDE_PATH})
      INCLUDE_DIRECTORIES(${DIR})
    ENDFOREACH()
    FOREACH(DIR ${MPI_Fortran_INCLUDE_PATH})
      INCLUDE_DIRECTORIES(${DIR})
    ENDFOREACH()
    LIST(APPEND linkedlibs ${MPI_Fortran_LIBRARIES})
  ENDIF()
  MARK_AS_ADVANCED(MPI_LIBRARY MPI_EXTRA_LIBRARY) # don't show these ones
  ADD_DEFINITIONS(-DMPI)
  MESSAGE(STATUS "Building PICLas with MPI")
  MESSAGE(STATUS "MPI Compiler: " ${MPI_Fortran_COMPILER})
ENDIF()

# ========================================================================
# LOADBALANCE
# =========================================================================
IF(PICLAS_MPI)
  IF(PICLAS_LOADBALANCE)
    MESSAGE(STATUS "Building PICLas with LoadBalance")
    ADD_DEFINITIONS(-DUSE_LOADBALANCE=1)
  ELSE()
    ADD_DEFINITIONS(-DUSE_LOADBALANCE=0)
  ENDIF()
ELSE()
  ADD_DEFINITIONS(-DUSE_LOADBALANCE=0)
ENDIF()

# ========================================================================= 
# PAPI library 
# ========================================================================= 
IF(PICLAS_PAPI)
  FIND_PACKAGE(PAPI REQUIRED)
  ADD_DEFINITIONS(-DPAPI) 
  LIST(APPEND linkedlibs ${PAPI_LIBRARIES})
  INCLUDE_DIRECTORIES(${PAPI_INCLUDE_DIRS})
  MESSAGE(STATUS "Building PICLas with PAPI benchmark support.") 
ENDIF()

# ========================================================================= 
# QDS with DGSEM
# ========================================================================= 
IF(PICLAS_QDS_DG)
  MESSAGE(STATUS "Building PICLas with QDS-DGSEM")
  ADD_DEFINITIONS(-DUSE_QDS_DG=1)
ELSE()
  ADD_DEFINITIONS(-DUSE_QDS_DG=0)
ENDIF()

# =========================================================================
# PICLas sources & targets
# =========================================================================

function(add_exec target)
  ADD_EXECUTABLE(${target} ${ARGN})
  TARGET_LINK_LIBRARIES(${target} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/userblock.o piclaslib userblocklib stacksizelib ${linkedlibs})
  SET_TARGET_PROPERTIES(${target} PROPERTIES COMPILE_FLAGS ${PICLAS_COMPILE_FLAGS}) 
  SET_TARGET_PROPERTIES(${target} PROPERTIES LINKER_LANGUAGE Fortran)
  INSTALL(PROGRAMS ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${target} DESTINATION bin)
  STRING(TOUPPER ${target} TARGETUP)
  ADD_CUSTOM_COMMAND(TARGET ${target} POST_BUILD COMMAND ${CMAKE_COMMAND} -E cmake_echo_color --cyan "SUCCESS: ${TARGETUP} BUILD COMPLETE!")
endfunction()

# include piclas.h 
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR}/src) 

# collect all F90 files needed for piclaslib
FILE(GLOB_RECURSE piclasF90 ./src/init/*.f90
                                ./src/analyze/*.f90
                                ./src/filter/*.f90
                                ./src/globals/*.f90
                                ./src/mortar/*.f90
                                ./src/interpolation/basis.f90
                                ./src/interpolation/interpolation.f90
                                ./src/interpolation/interpolation_vars.f90
                                ./src/interpolation/changeBasis.f90
                                ./src/io_hdf5/*.f90
                                ./src/loadbalance/*.f90
                                ./src/mesh/*.f90
                                ./src/interfaces/*.f90
                                ./src/dielectric/*.f90
                                ./src/mpi/*.f90
                                ./src/output/*.f90
                                ./src/readintools/*.f90
                                ./src/recordpoints/*.f90
                                ./src/restart/*.f90
                                ./src/timedisc/*.f90
                                ./src/utils/*.f90 )

FILE(GLOB_RECURSE dgF90 ./src/dg/*.f90
                        ./src/interpolation/prolongtoface.f90
                        ./src/pml/*.f90
                        ./src/equations/${PICLAS_EQNSYSNAME}/*.f90)

FILE(GLOB_RECURSE hdgF90 ./src/hdg/*.f90
                         ./src/dg/dg.f90
                         ./src/dg/dg_vars.f90
                         ./src/equations/${PICLAS_EQNSYSNAME}/equation.f90
                         ./src/equations/${PICLAS_EQNSYSNAME}/equation_vars.f90
                         ./src/equations/${PICLAS_EQNSYSNAME}/timeavg.f90
                         ./src/equations/${PICLAS_EQNSYSNAME}/timeavg_vars.f90
                         ./src/equations/${PICLAS_EQNSYSNAME}/getboundaryflux.f90)


FILE(GLOB_RECURSE implicitF90 ./src/linearsolver/linearsolver.f90
                              ./src/linearsolver/linearsolver_vars.f90
                              ./src/linearsolver/particlesolver.f90
                              ./src/linearsolver/predictor.f90
                              ./src/linearsolver/linearoperator/linearoperator.f90
                              ./src/linearsolver/newton.f90)

                            IF(PICLAS_EQNSYSNAME STREQUAL "maxwell_pois")
  FILE(GLOB_RECURSE precondF90 ./src/precond/precond.f90
                               ./src/precond/precond_vars.f90
                               ./src/precond/applypreconditioner.f90
                               ./src/linearsolver/linearoperator/sparse_ilu.f90
                               ./src/precond/csr/*.f90
                               ./src/precond/ilu/*.f90
                               ./src/precond/jacdg/*.f90
                               ./src/precond/jac_fd/*.f90
                               ./src/precond/jac_ex/${PICLAS_EQNSYSNAME}/*.f90)
ELSE()
  FILE(GLOB_RECURSE precondF90 ./src/precond/precond.f90
                               ./src/precond/precond_vars.f90
                               ./src/precond/applypreconditioner.f90
                               ./src/linearsolver/linearoperator/sparse_ilu.f90
                               ./src/precond/csr/*.f90
                               ./src/precond/ilu/*.f90
                               ./src/precond/jacdg/*.f90
                               ./src/precond/jac_fd/*.f90
                               ./src/precond/jac_ex/maxwell/*.f90)
ENDIF()

FILE(GLOB mainF90 ./src/piclas.f90)
FILE(GLOB_RECURSE particlesF90 ./src/particles/*.f90
                               ./src/interpolation/eval_xyz.f90)
FILE(GLOB noparticlesF90 ./src/particles/analyze/particle_analyze_vars.f90 
                         ./src/particles/particle_mesh/particle_surfaces_vars.f90
                         ./src/particles/particle_mesh/particle_mesh_vars.f90
                         ./src/particles/particle_vars.f90
                         ./src/particles/boundary/particle_boundary_vars.f90)

FILE(GLOB_RECURSE QDSF90 ./src/qds/*.f90
                         ./src/interpolation/prolongtoface.f90)

                       IF(PICLAS_HDG)
  LIST(APPEND piclasF90 ${hdgF90})
  IF(PICLAS_IMPLICIT)
    LIST(APPEND piclasF90 ${implicitF90})
  ENDIF(PICLAS_IMPLICIT)
ELSE()
  LIST(APPEND piclasF90 ${dgF90})
  IF(PICLAS_IMPLICIT)
    LIST(APPEND piclasF90 ${implicitF90})
    LIST(APPEND piclasF90 ${precondF90})
  ENDIF(PICLAS_IMPLICIT)
ENDIF(PICLAS_HDG)

LIST(APPEND piclasF90 ${mainF90})
IF (PICLAS_PARTICLES)
   LIST(APPEND piclasF90 ${particlesF90})
 ELSE()
   LIST(APPEND piclasF90 ${noparticlesF90})
 ENDIF(PICLAS_PARTICLES)
 IF(PICLAS_QDS_DG)
  LIST(APPEND piclasF90 ${QDSF90}) 
ENDIF()

# define libs
ADD_LIBRARY(piclaslibF90 OBJECT ${piclasF90} )
SET_TARGET_PROPERTIES(piclaslibF90 PROPERTIES COMPILE_FLAGS ${PICLAS_COMPILE_FLAGS}) 
ADD_LIBRARY(piclaslib STATIC $<TARGET_OBJECTS:piclaslibF90>)
IF(SELFBUILTEXTERNALS)
  ADD_DEPENDENCIES(piclaslibF90 ${SELFBUILTEXTERNALS})
ENDIF()

ADD_LIBRARY(userblocklib STATIC ./src/output/read_userblock.c)
SET_TARGET_PROPERTIES(userblocklib PROPERTIES LINKER_LANGUAGE C)
SET_TARGET_PROPERTIES(userblocklib PROPERTIES COMPILE_FLAGS "-fPIC")

ADD_LIBRARY(stacksizelib STATIC ./src/globals/stacksize.c)
SET_TARGET_PROPERTIES(stacksizelib PROPERTIES LINKER_LANGUAGE C)
SET_TARGET_PROPERTIES(stacksizelib PROPERTIES COMPILE_FLAGS "-fPIC")

add_exec(piclas ./src/piclas.f90)
ADD_DEPENDENCIES(piclas piclaslib userblocklib stacksizelib ${INTERNALLIBS})

# special compiler flags to avoid warnings for empty functions of testcase.f90 and overwrite of intrinsic abort in globals.f90
IF (CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
   SET_SOURCE_FILES_PROPERTIES(${CMAKE_CURRENT_SOURCE_DIR}/src/globals/globals.f90 PROPERTIES COMPILE_FLAGS "-Wno-intrinsic-shadow")
ENDIF()

# -------------------------------------------------------------------------
# echo COMPILE_DEFINITIONS
# -------------------------------------------------------------------------
GET_DIRECTORY_PROPERTY(comp_defs DIRECTORY ${CMAKE_SOURCE_DIR} COMPILE_DEFINITIONS )
SET(comp_defs_str "COMPILE_DEFINITIONS = ")
FOREACH (def ${comp_defs})
   SET(comp_defs_str "${comp_defs_str} -D${def}")
ENDFOREACH()
ADD_CUSTOM_TARGET(preproc_defines COMMAND echo ${comp_defs_str})

# =========================================================================
# Add H5piclas2VTK tool
# =========================================================================
add_exec(h5piclas2vtk ./src/h5piclas2vtk.f90)
ADD_DEPENDENCIES(h5piclas2vtk piclaslib)

# =========================================================================
# Posti
# =========================================================================
IF(PICLAS_BUILDPOSTI)
  INCLUDE(${CMAKE_CURRENT_SOURCE_DIR}/posti/CMakeLists.txt)
ELSE()
  GETLISTOFVARSSTARTINGWITH("POSTI_" postiVars)
  FOREACH (_var IN LISTS postiVars)
    UNSET(${_var} CACHE)
  ENDFOREACH()
ENDIF()

#   # =========================================================================
#   # RegressionCheck tool && Examples
#   # =========================================================================
#   add_exec(regressioncheck ./regressioncheck/regressioncheck.f90 
#                            ./regressioncheck/regressioncheck_vars.f90 
#                            ./regressioncheck/regressioncheck_build.f90 
#                            ./regressioncheck/regressioncheck_compare.f90 
#                            ./regressioncheck/regressioncheck_run.f90 
#                            ./regressioncheck/regressioncheck_tools.f90 )
#   ADD_DEFINITIONS(-DH5DIFF="${HDF5_DIFF_EXECUTABLE}")
#   SET(PICLAS_REGRESSIONCHECK_EXAMPLES "${CMAKE_CURRENT_SOURCE_DIR}/regressioncheck/examples")

# =========================================================================
# Userblock
# =========================================================================
ADD_CUSTOM_COMMAND(TARGET piclaslib PRE_BUILD COMMAND 
  sh ${CMAKE_CURRENT_SOURCE_DIR}/tools/userblock/generateuserblock.sh ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}  ${CMAKE_CACHEFILE_DIR} "${CMAKE_CACHE_MAJOR_VERSION}.${CMAKE_CACHE_MINOR_VERSION}.${CMAKE_CACHE_PATCH_VERSION}")

# =========================================================================
# generate .piclas in $HOME
# =========================================================================
ADD_CUSTOM_COMMAND(TARGET piclas     POST_BUILD COMMAND echo \"export PICLAS_DIR=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}\" > $ENV{HOME}/.piclas)
ADD_CUSTOM_COMMAND(TARGET piclas     POST_BUILD COMMAND echo \"alias piclas='${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/piclas'\" >> $ENV{HOME}/.piclas)

# =========================================================================
# Install
# =========================================================================
INSTALL(FILES    ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/configuration.cmake ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/userblock.txt DESTINATION bin)

# =========================================================================
# Ctags
# =========================================================================
IF(PICLAS_CTAGS)
  SET(EQNS_WO_ACTUAL ${EQNSYSTEMS})
  LIST(REMOVE_ITEM EQNS_WO_ACTUAL ${PICLAS_EQNSYSNAME})
  SET(EXLUDES "")
  FOREACH(item ${EQNS_WO_ACTUAL})
     SET(EXLUDES "--exclude=src/equations/${item}/*" ${EXLUDES})
  ENDFOREACH()
  ADD_CUSTOM_COMMAND(OUTPUT ctags.txt COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR} && ctags -R -f ctags.txt ${EXLUDES} src)
  ADD_CUSTOM_TARGET(tags DEPENDS ctags.txt)
  FIND_PROGRAM(CTAGS_PATH ctags)
  IF(CTAGS_PATH)
      MESSAGE(STATUS "Found ctags: ${CTAGS_PATH}")
      ADD_DEPENDENCIES(piclas tags)
  ENDIF(CTAGS_PATH)
ENDIF(PICLAS_CTAGS)
