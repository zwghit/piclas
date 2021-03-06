!==================================================================================================================================
! Copyright (c) 2010 - 2018 Prof. Claus-Dieter Munz and Prof. Stefanos Fasoulas
!
! This file is part of PICLas (gitlab.com/piclas/piclas). PICLas is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3
! of the License, or (at your option) any later version.
!
! PICLas is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with PICLas. If not, see <http://www.gnu.org/licenses/>.
!==================================================================================================================================
MODULE MOD_RPData_Vars
!===================================================================================================================================
! Contains global variables used for/by the RPSe


!===================================================================================================================================
! MODULES
IMPLICIT NONE
PUBLIC
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
INTEGER                         :: nSamples_global ! complete number of samples (all RP data files)
INTEGER                         :: nVar_HDF5       ! all Variable names (without time, we assume the 0 index corresponds with time 
CHARACTER(LEN=255),ALLOCATABLE  :: VarNames_HDF5(:)
REAL,ALLOCATABLE                :: RPData(:,:,:)
REAL,ALLOCATABLE                :: RPTime(:)
!-----------------------------------------------------------------------------------------------------------------------------------
! Output Buffer
!-----------------------------------------------------------------------------------------------------------------------------------
TYPE tRPDataSet
  REAL,ALLOCATABLE              :: data(:,:,:)
  INTEGER                       :: nSamples
  TYPE(tRPDataSet),POINTER      :: nextset
END TYPE tRPDataSet

TYPE(tRPDataSet),POINTER        :: firstset, actualset

!===================================================================================================================================

INTERFACE getNewRPDataSet
  MODULE PROCEDURE getNewRPDataSet
END INTERFACE 

PUBLIC :: getNewRPDataSet

CONTAINS 

SUBROUTINE getNewRPDataSet(RPDataSet,nSamples_in)
!===================================================================================================================================
! Read RP parameters from ini file and RP definitions from HDF5 
!===================================================================================================================================
! MODULES
USE MOD_RPSetVisuVisu_Vars            ,ONLY: nRP_global
IMPLICIT NONE
! INPUT/OUTPUT VARIABLES
INTEGER,INTENT(IN)            :: nSamples_in
TYPE(tRPDataSet),POINTER      :: RPDataSet
!===================================================================================================================================
ALLOCATE(RPDataSet)
ALLOCATE(RPDataSet%data(0:nVar_HDF5,1:nRP_global,1:nSamples_in))
RPDataSet%data=0.
NULLIFY(RPDataSet%nextset)
RPDataSet%nSamples=nSamples_in
END SUBROUTINE getNewRPDataSet

END MODULE MOD_RPData_Vars
