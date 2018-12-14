#!/bin/bash
echo ' -----------------------------------------------'
echo ' -      Compiling CreateElectronicDatabase     -'
echo ' -----------------------------------------------'
ifort -r8 -I ../../share/INTEL-SINGLE/hdf5-1.8.14/include/ -c create_electronic_database.f90
ifort -r8 create_electronic_database.o -lhdf5_fortran -lhdf5 -lz -L ../../share/INTEL-SINGLE/hdf5-1.8.14/lib/ -o CreateElectronicDatabase # -ldl
rm create_electronic_database.o
echo ' -----------------------------------------------'
echo ' - CreateElectronicDatabase executable created -'
echo ' -----------------------------------------------'
