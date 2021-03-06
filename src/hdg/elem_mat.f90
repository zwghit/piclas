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
#include "piclas.h"
MODULE MOD_Elem_Mat
!===================================================================================================================================
! Module for the HDG element matrices
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------

#ifdef PP_HDG
INTERFACE Elem_Mat
  MODULE PROCEDURE Elem_Mat
END INTERFACE

!INTERFACE BuildPrecond
!  MODULE PROCEDURE BuildPrecond
!END INTERFACE

!INTERFACE PostProcessGradient
!  MODULE PROCEDURE PostProcessGradient
!END INTERFACE

PUBLIC :: Elem_Mat
PUBLIC :: BuildPrecond 
PUBLIC :: PostProcessGradient
#endif /* PP_HDG*/
!===================================================================================================================================

CONTAINS

#ifdef PP_HDG
SUBROUTINE Elem_Mat(td_iter)
!===================================================================================================================================
! 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Equation_Vars     , ONLY: chitens
#if defined(IMPA) || defined(ROS)
USE MOD_LinearSolver_Vars, ONLY:DoPrintConvInfo
#endif
USE MOD_Interpolation_Vars ,ONLY: wGP
USE MOD_Mesh_Vars          ,ONLY: sJ, Metrics_fTilde, Metrics_gTilde,Metrics_hTilde
USE MOD_Mesh_Vars          ,ONLY: SurfElem
USE MOD_Mesh_Vars          ,ONLY: VolToSideA,VolToSideIJKA,ElemToSide!,VolToSide2A
USE MOD_Basis              ,ONLY: getSPDInverse
USE MOD_TimeDisc_Vars      ,ONLY: IterDisplayStep,DoDisplayIter
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER(KIND=8),INTENT(IN)  :: td_iter
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER              :: l,p,q,g1,g2,g3
INTEGER              :: i,j,iElem, i_m,i_p,j_m,j_p
INTEGER              :: iDir,jDir 
INTEGER              :: iLocSide, jLocSide
INTEGER              :: SideID(6),Flip(6)
REAL                 :: TauS(2,3)
REAL                 :: Dhat(nGP_vol,nGP_vol)
REAL                 :: Ktilde(3,3)
REAL                 :: Stmp1(nGP_vol,nGP_face), Stmp2(nGP_face,nGP_face)
INTEGER              :: idx(3),jdx(3),gdx(3)
REAL                 :: time0, time
!===================================================================================================================================

#if defined(IMPA) || defined(ROS)
IF(DoPrintConvInfo)THEN
  SWRITE(UNIT_stdOut,'(132("-"))')
  SWRITE(*,*)'HDG ELEM_MAT: Pre-compute HDG local element matrices...'
  time0=PICLASTIME()
END IF
#else
IF(DoDisplayIter)THEN
  IF(MOD(td_iter,IterDisplayStep).EQ.0) THEN
    time0=PICLASTIME()
    SWRITE(UNIT_stdOut,'(132("-"))')
    SWRITE(*,*)'HDG ELEM_MAT: Pre-compute HDG local element matrices...'
  END IF
END IF
#endif


Ehat = 0.0
Smat = 0.0
DO iElem=1,PP_nElems
  SideID(:)=ElemToSide(E2S_SIDE_ID,:,iElem)
  Flip(:)  =ElemToSide(E2S_FLIP,:,iElem)

  ! Loop over the Gauss points with indexes (g1,g2,g3); for each
  ! point, compute all the i,j contributions in the local matrices.
  Dhat = 0.0
  DO g3=0,PP_N
    DO g2=0,PP_N
      DO g1=0,PP_N
        ASSOCIATE( JaCon1 => Metrics_fTilde(:,g1,g2,g3,iElem) , &
                   JaCon2 => Metrics_gTilde(:,g1,g2,g3,iElem) , &
                   JaCon3 => Metrics_hTilde(:,g1,g2,g3,iElem) , &
                   chi    =>      chitens(:,:,g1,g2,g3,iElem) )
          Ktilde(1,1) =  SUM( JaCon1 * MATMUL( chi , JaCon1 ))
          Ktilde(2,2) =  SUM( JaCon2 * MATMUL( chi , JaCon2 ))
          Ktilde(3,3) =  SUM( JaCon3 * MATMUL( chi , JaCon3 ))
          Ktilde(2,1) =  SUM( JaCon2 * MATMUL( chi , JaCon1 ))
          Ktilde(3,1) =  SUM( JaCon3 * MATMUL( chi , JaCon1 ))
          Ktilde(3,2) =  SUM( JaCon3 * MATMUL( chi , JaCon2 ))
        END ASSOCIATE
        Ktilde(1,2)=Ktilde(2,1) 
        Ktilde(1,3)=Ktilde(3,1) 
        Ktilde(2,3)=Ktilde(3,2) 
        !scale with omega_ijk/J
        Ktilde=(sJ(g1,g2,g3,iElem)*wGP_vol(index_3to1(g1,g2,g3)) )*Ktilde

        ! scaled tau: omega* tau * SurfElem
        DO iLocSide=1,6
          ASSOCIATE( p => VolToSideA(1,g1,g2,g3,Flip(iLocSide),iLocSide), &
                     q => VolToSideA(2,g1,g2,g3,Flip(iLocSide),iLocSide), &
                     l1=> VolToSideIJKA(1,g1,g2,g3,Flip(iLocSide),iLocSide), &
                     l2=> VolToSideIJKA(2,g1,g2,g3,Flip(iLocSide),iLocSide)  )
             Taus(pm(iLocSide),SideDir(iLocSide))=wGP(l1)*wGP(l2)*SurfElem(p,q,SideID(iLocSide))
           END ASSOCIATE
         END DO !iLocSide

        Taus=Taus*Tau(ielem)
        
        !---------------------------------------------------------------
        ! Dhat = D - B A^{-1} B^T      

        !  D  volume contribution for nonlinear stuff
        IF (nonlinear.AND.(NonLinSolver.EQ.1)) THEN
          j = index_3to1(g1,g2,g3)
          Dhat(j,j) = Dhat(j,j) - JwGP_vol( j,iElem)*NonlinVolumeFac(j,iElem)
        END IF
        !  D  surface contribution

        gdx=(/g1,g2,g3/)

        j = index_3to1(g1,g2,g3)
        DO iDir=1,3
          idx = gdx 
          DO l=0,PP_N
            idx(iDir) = l
            i = index_3to1(idx(1),idx(2),idx(3))
            Dhat(i,j) = Dhat(i,j) - (TauS(1,iDir)*LL_minus(l,gdx(iDir))+TauS(2,iDir)*LL_plus(l,gdx(iDir)))
          END DO !l
        END DO !iDir


        !  [- B A^{-1} B^T]  contribution
        DO jDir=1,3
          jdx = gdx 
          DO q=0,PP_N
            jdx(jDir)=q
            j = index_3to1(jdx(1),jdx(2),jdx(3))
            DO iDir=1,3
              idx = gdx 
              DO p=0,PP_N
                idx(iDir) = p
                i = index_3to1(idx(1),idx(2),idx(3))
                Dhat(i,j) = Dhat(i,j) - Ktilde(iDir,jDir)*Domega(p,gdx(iDir))*Domega(q,gdx(jDir))
              END DO !p
            END DO !iDir
          END DO !q
        END DO !jDir
        !---------------------------------------------------------------

        !---------------------------------------------------------------
        ! Ehat = E - B A^{-1} C^T
        DO iDir=1,3
          ASSOCIATE(mLocSide=>dirPm2iSide(1,iDir), & 
                    pLocSide=>dirPm2iSide(2,iDir) )
          ! X direction
          i_m = sindex_3to1(g1,g2,g3,mLocSide) ! index on the side
          i_p = sindex_3to1(g1,g2,g3,pLocSide)
          ASSOCIATE( Ehat_m => Ehat(i_m,:,mLocSide,iElem) , &
                     Ehat_p => Ehat(i_p,:,pLocSide,iElem) )
            !  E  contribution
            j = index_3to1(g1,g2,g3)
            Ehat_m(j) = Ehat_m(j) + TauS(1,iDir)*wGP(gdx(iDir))*(-Lomega_m(gdx(iDir)))
            Ehat_p(j) = Ehat_p(j) + TauS(2,iDir)*wGP(gdx(iDir))*( Lomega_p(gdx(iDir)))
            !  [- B A^{-1} C^T]  contribution
            DO q=0,PP_N
              j = index_3to1( q,g2,g3)
              Ehat_m(j) = Ehat_m(j) + Ktilde(1,iDir)*Domega(q,g1)*Lomega_m(gdx(iDir))
              Ehat_p(j) = Ehat_p(j) + Ktilde(1,iDir)*Domega(q,g1)*Lomega_p(gdx(iDir))
              j = index_3to1(g1, q,g3)                           
              Ehat_m(j) = Ehat_m(j) + Ktilde(2,iDir)*Domega(q,g2)*Lomega_m(gdx(iDir))
              Ehat_p(j) = Ehat_p(j) + Ktilde(2,iDir)*Domega(q,g2)*Lomega_p(gdx(iDir))
              j = index_3to1(g1,g2, q)                           
              Ehat_m(j) = Ehat_m(j) + Ktilde(3,iDir)*Domega(q,g3)*Lomega_m(gdx(iDir))
              Ehat_p(j) = Ehat_p(j) + Ktilde(3,iDir)*Domega(q,g3)*Lomega_p(gdx(iDir))
            END DO !q
          END ASSOCIATE
          END ASSOCIATE
        END DO !iDir

        !---------------------------------------------------------------

        !---------------------------------------------------------------
        ! Smat:  C A(-1) C^T  contribution

        ASSOCIATE( SmatK => Smat(:,:,:,:,iElem) )
        DO jDir=1,3
          ! TODO: it would be better to have another index to loop
          ! over PLUS and MINUS.
          ASSOCIATE( jLS_m => dirPm2iSide(1,jDir) , &
                     jLS_p => dirPm2iSide(2,jDir) )
          j_m = sindex_3to1(g1,g2,g3,jLS_m)
          j_p = sindex_3to1(g1,g2,g3,jLS_p)

          DO iDir=1,3
            ASSOCIATE( iLS_m => dirPm2iSide(1,iDir) , &
                       iLS_p => dirPm2iSide(2,iDir) )
            i_m = sindex_3to1(g1,g2,g3,iLS_m)
            i_p = sindex_3to1(g1,g2,g3,iLS_p)

            SmatK(i_m,j_m,iLS_m,jLS_m) = SmatK(i_m,j_m,iLS_m,jLS_m) &
              + Ktilde(iDir,jDir) * Lomega_m(gdx(iDir)) * Lomega_m(gdx(jDir))

            SmatK(i_p,j_m,iLS_p,jLS_m) = SmatK(i_p,j_m,iLS_p,jLS_m) &
              + Ktilde(iDir,jDir) * Lomega_p(gdx(iDir)) * Lomega_m(gdx(jDir))

            SmatK(i_m,j_p,iLS_m,jLS_p) = SmatK(i_m,j_p,iLS_m,jLS_p) &
              + Ktilde(iDir,jDir) * Lomega_m(gdx(iDir)) * Lomega_p(gdx(jDir))

            SmatK(i_p,j_p,iLS_p,jLS_p) = SmatK(i_p,j_p,iLS_p,jLS_p) &
              + Ktilde(iDir,jDir) * Lomega_p(gdx(iDir)) * Lomega_p(gdx(jDir))

            END ASSOCIATE
          END DO !iDir
          END ASSOCIATE
        END DO !jDir
        END ASSOCIATE

        !---------------------------------------------------------------

      END DO !g1
    END DO !g2
  END DO !g3
  InvDhat(:,:,iElem)=-getSPDInverse(nGP_vol,-Dhat)
  ! Compute for each side pair  Ehat Dhat^{-1} Ehat^T
  DO jLocSide=1,6
    !Stmp1 = TRANSPOSE( MATMUL( Ehat(:,:,jLocSide,iElem) , InvDhat(:,:,iElem) ) )
    CALL DSYMM('L','U',nGP_vol,nGP_face,1., &
                InvDhat(:,:,iElem),nGP_vol, &
                TRANSPOSE( Ehat(:,:,jLocSide,iElem)),nGP_vol,0., &
                Stmp1,nGP_vol)
    ! diagonal term
    !Stmp2 = MATMUL( Ehat(:,:,jLocSide,iElem) , Stmp1 )
    CALL DGEMM('N','N',nGP_face,nGP_face,nGP_vol,1., &
                        Ehat(:,:,jLocSide,iElem), nGP_face, &
                        Stmp1,nGP_vol,0.,& 
                        Stmp2,nGP_face)  
    Smat(:,:,jLocSide,jLocSide,iElem) = Smat(:,:,jLocSide,jLocSide,iElem) + Stmp2
    ! off-diagonal terms
    DO iLocSide=jLocSide+1,6
      !Stmp2 = MATMUL( Ehat(:,:,iLocSide,iElem) , Stmp1 )
      CALL DGEMM('N','N',nGP_face,nGP_face,nGP_vol,1., &
                          Ehat(:,:,iLocSide,iElem), nGP_face, &
                          Stmp1,nGP_vol,0.,& 
                          Stmp2,nGP_face)  
      ! Using the fact that Smat is symmetric
      Smat(:,:,iLocSide,jLocSide,iElem) = Smat(:,:,iLocSide,jLocSide,iElem) + Stmp2
      Smat(:,:,jLocSide,iLocSide,iElem) = Smat(:,:,jLocSide,iLocSide,iElem) + TRANSPOSE(Stmp2)
    END DO !iLocSide
  END DO !jLocSide

END DO !iElem


#if defined(IMPA) || defined(ROS)
IF(DoPrintConvInfo)THEN
  time=PICLASTIME()
  SWRITE(UNIT_stdOut,'(A,F14.2,A)') ' HDG ELEME_MAT DONE! [',Time-time0,' sec ]'
  SWRITE(UNIT_stdOut,'(132("-"))')
END IF
#else
IF(DoDisplayIter)THEN
  IF(MOD(td_iter,IterDisplayStep).EQ.0) THEN
    time=PICLASTIME()
    SWRITE(UNIT_stdOut,'(A,F14.2,A)') ' HDG ELEME_MAT DONE! [',Time-time0,' sec ]'
    SWRITE(UNIT_stdOut,'(132("-"))')
  END IF
END IF
#endif

CONTAINS

 PURE FUNCTION index_3to1(i1,i2,i3) RESULT(i)
  INTEGER, INTENT(IN) :: i1, i2, i3
  INTEGER :: i
   i = i3*(PP_N+1)**2 + i2*(PP_N+1) + i1 + 1
 END FUNCTION index_3to1

 PURE FUNCTION sindex_3to1(i1,i2,i3,iLocSide) RESULT(i)
  INTEGER, INTENT(IN) :: i1, i2, i3, iLocSide
  INTEGER :: i
  !local variables
  INTEGER :: p, q

   p = VolToSideA(1,i1,i2,i3,Flip(iLocSide),iLocSide)
   q = VolToSideA(2,i1,i2,i3,Flip(iLocSide),iLocSide)

   i = q*(PP_N+1) + p + 1

 END FUNCTION sindex_3to1

END SUBROUTINE Elem_Mat


SUBROUTINE BuildPrecond()
!===================================================================================================================================
! Build a block-diagonal preconditioner for the lambda system 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_HDG_Vars
USE MOD_Mesh_Vars          ,ONLY: nSides,SideToElem,nMPIsides_YOUR
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,               ONLY:StartReceiveMPIData,StartSendMPIData,FinishExchangeMPIData
USE MOD_Mesh_Vars,     ONLY:nMPISides,nMPIsides_MINE
#endif /*MPI*/ 

! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER          :: ElemID, locSideID, SideID, igf
#ifdef MPI
INTEGER          :: startbuf,endbuf
REAL,ALLOCATABLE :: P_reshape(:,:,:,:)
#endif /*MPI*/
INTEGER           :: lapack_info
!===================================================================================================================================


SELECT CASE(PrecondType)
CASE(0)
! do nothing
CASE(1)
  IF(.NOT.ALLOCATED(Precond)) ALLOCATE(Precond(nGP_face,nGP_face,1:nSides))
  Precond = 0.
  DO SideID=1,nSides
    !master element
    locSideID = SideToElem(S2E_LOC_SIDE_ID,SideID)
    IF(locSideID.NE.-1)THEN
      ElemID    = SideToElem(S2E_ELEM_ID,SideID)  
      Precond(:,:,SideID) = Precond(:,:,SideID)+Smat(:,:,locSideID,locSideID,ElemID)
    END IF !locSideID.NE.-1
    ! neighbour element
    locSideID = SideToElem(S2E_NB_LOC_SIDE_ID,SideID)
    IF(locSideID.NE.-1)THEN
      ElemID    = SideToElem(S2E_NB_ELEM_ID,SideID)
      Precond(:,:,SideID) = Precond(:,:,SideID)+Smat(:,:,locSideID,locSideID,ElemID)
    END IF !locSideID.NE.-1
    DO igf=1,nGP_face
      Precond(igf,igf,SideID)=Precond(igf,igf,SideID)-Fdiag(igf,SideID)
    END DO
  END DO ! SideID=1,nSides
#ifdef MPI
  startbuf=nSides-nMPISides+1
  ALLOCATE(P_reshape(nGP_face,0:PP_N,0:PP_N,startbuf:nSides))
  endbuf=nSides-nMPISides+nMPISides_MINE
  P_reshape=RESHAPE(Precond(:,:,startbuf:nSides),(/nGP_face,PP_N+1,PP_N+1,nSides-startbuf+1/))
  CALL StartReceiveMPIData(nGP_face,P_reshape,startbuf,nSides, RecRequest_U,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   nGP_face,P_reshape,startbuf,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(                    SendRequest_U,RecRequest_U,SendID=2) ! Send YOUR - receive MINE
  IF(nMPISides_MINE.GT.0)THEN
    Precond(:,:,startbuf:endbuf)=Precond(:,:,startbuf:endbuf) &
                                +RESHAPE(P_reshape(:,:,:,startbuf:endbuf),(/nGP_face,nGP_face,endbuf-startbuf+1/))
  END IF !nMPIsides_MINE>0
  DEALLOCATE(P_reshape)
  IF(nMPISides_YOUR.GT.0) Precond(:,:,nSides-nMPIsides_YOUR+1:nSides )=0. !set send buf to zero
#endif /*MPI*/
  DO SideID=1,nSides-nMPIsides_YOUR
    ! do choleski and store into Precond
    CALL DPOTRF('U',nGP_face,Precond(:,:,SideID),nGP_face,lapack_info) 
    IF (lapack_info .NE. 0) THEN
      STOP 'MATRIX INVERSION FAILED!'
    END IF
  END DO ! SideID=1,nSides

CASE(2)
  IF(.NOT.ALLOCATED(InvPrecondDiag)) ALLOCATE(InvPrecondDiag(nGP_face,1:nSides))
  InvPrecondDiag = 0.
  DO SideID=1,nSides
    !master element
    locSideID = SideToElem(S2E_LOC_SIDE_ID,SideID)
    IF(locSideID.NE.-1)THEN
      ElemID    = SideToElem(S2E_ELEM_ID,SideID)  
      DO igf = 1, nGP_face
        InvPrecondDiag(igf,SideID) = InvPrecondDiag(igf,SideID)+ &
                              Smat(igf,igf,locSideID,locSideID,ElemID)
      END DO ! igf
    END IF !locSideID.NE.-1
    ! neighbour element
    locSideID = SideToElem(S2E_NB_LOC_SIDE_ID,SideID)
    IF(locSideID.NE.-1)THEN
      ElemID    = SideToElem(S2E_NB_ELEM_ID,SideID)
      DO igf = 1, nGP_face
        InvPrecondDiag(igf,SideID) = InvPrecondDiag(igf,SideID)+ &
                              Smat(igf,igf,locSideID,locSideID,ElemID)
      END DO ! igf
    END IF !locSideID.NE.-1
    DO igf=1,nGP_face
      InvPrecondDiag(igf,SideID)=InvPrecondDiag(igf,SideID)-Fdiag(igf,SideID)
    END DO
  END DO ! SideID=1,nSides
#ifdef MPI
  startbuf=nSides-nMPISides+1
  ALLOCATE(P_reshape(1,0:PP_N,0:PP_N,startbuf:nSides))
  endbuf=nSides-nMPISides+nMPISides_MINE
  P_reshape=RESHAPE(InvPrecondDiag(:,startbuf:nSides),(/1,PP_N+1,PP_N+1,nSides-startbuf+1/))
  CALL StartReceiveMPIData(1,P_reshape,startbuf,nSides, RecRequest_U,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,P_reshape,startbuf,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(             SendRequest_U,RecRequest_U,SendID=2) ! Send YOUR - receive MINE
IF(nMPISides_MINE.GT.0)THEN
    InvPrecondDiag(:,startbuf:endbuf)=InvPrecondDiag(:,startbuf:endbuf) &
                                +RESHAPE(P_reshape(:,:,:,startbuf:endbuf),(/nGP_face,endbuf-startbuf+1/))
  END IF !nMPIsides_MINE>0
  DEALLOCATE(P_reshape)
  IF(nMPISides_YOUR.GT.0) InvPrecondDiag(:,nSides-nMPIsides_YOUR+1:nSides )=0. !set send buf to zero
#endif /*MPI*/
  !inverse of the preconditioner matrix
  DO SideID=1,nSides-nMPIsides_YOUR
    InvPrecondDiag(:,SideID)=1./InvPrecondDiag(:,SideID)
  END DO !1,nSides-nMPIsides_YOUR
END SELECT
END SUBROUTINE BuildPrecond


SUBROUTINE PostProcessGradient(u_in,lambda_in,q_out)
!===================================================================================================================================
! Build a block-diagonal preconditioner for the lambda system 
!===================================================================================================================================
! MODULES
USE MOD_Preproc
USE MOD_HDG_Vars
USE MOD_Mesh_Vars,ONLY:nSides,ElemToSide,Metrics_ftilde,Metrics_gTilde,Metrics_hTilde,sJ
USE MOD_Mesh_Vars,ONLY:VolToSideA
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)  :: u_in(0:PP_N,0:PP_N,0:PP_N,PP_nElems)
REAL,INTENT(IN)  :: lambda_in(0:PP_N,0:PP_N,nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT) :: q_out(3,0:PP_N,0:PP_N,0:PP_N,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER          :: iElem 
INTEGER          :: SideID(6),Flip(6)
INTEGER          :: q,g1,g2,g3,gdx(3),jdx(3),jDir
REAL             :: aCon(3,3),q_loc 
!===================================================================================================================================
q_out=0.
DO iElem=1,PP_nElems
  SideID(:)=ElemToSide(E2S_SIDE_ID,:,iElem)
  Flip(:)  =ElemToSide(E2S_FLIP,:,iElem)

  ! Loop over the Gauss points with indexes (g1,g2,g3); for each
  ! point, compute all the i,j contributions in the local matrices.
  DO g3=0,PP_N
    DO g2=0,PP_N
      DO g1=0,PP_N
        ! IF q is the flux, compute  K a^J
        !ASSOCIATE( JaCon1 => Metrics_fTilde(:,g1,g2,g3,iElem) , &
        !           JaCon2 => Metrics_gTilde(:,g1,g2,g3,iElem) , &
        !           JaCon3 => Metrics_hTilde(:,g1,g2,g3,iElem) , &
        !           chi    =>      chitens(:,:,g1,g2,g3,iElem) )
        !  aCon(:,1)=sJ(g1,g2,g3,iElem)*MATMUL(chi,JaCon1(:))
        !  aCon(:,2)=sJ(g1,g2,g3,iElem)*MATMUL(chi,JaCon2(:))
        !  aCon(:,3)=sJ(g1,g2,g3,iElem)*MATMUL(chi,JaCon3(:))
        !END ASSOCIATE
        ! If q is the gradient gradu_I=-K^{-1} q 
        aCon(:,1)=sJ(g1,g2,g3,iElem)*Metrics_fTilde(:,g1,g2,g3,iElem)
        aCon(:,2)=sJ(g1,g2,g3,iElem)*Metrics_gTilde(:,g1,g2,g3,iElem)
        aCon(:,3)=sJ(g1,g2,g3,iElem)*Metrics_hTilde(:,g1,g2,g3,iElem)

        gdx=(/g1,g2,g3/) 
        !---------------------------------------------------------------
        ! q =- K^{-1} ( -A^{-1} B^T *u - A^{-1}C^T *lambda )
        DO jDir=1,3
          q_loc=0.
          jdx = gdx 
          DO q=0,PP_N
            jdx(jDir)=q
            q_loc=q_loc + Domega(q,gdx(jDir))*U_in(jdx(1),jdx(2),jdx(3),iElem)
          END DO !q
          ASSOCIATE(mLocSide=>dirPm2iSide(1,jDir), & 
                    pLocSide=>dirPm2iSide(2,jDir) )
          ! X direction
          ASSOCIATE(p_m => VolToSideA(1,g1,g2,g3,Flip(mLocSide),mLocSide), &
                    q_m => VolToSideA(2,g1,g2,g3,Flip(mLocSide),mLocSide), &
                    p_p => VolToSideA(1,g1,g2,g3,Flip(pLocSide),pLocSide), &
                    q_p => VolToSideA(2,g1,g2,g3,Flip(pLocSide),pLocSide) )
          q_loc = q_loc - ( Lomega_m(gdx(jDir))*lambda_in(p_m,q_m,SideID(mLocSide)) &
                           +Lomega_p(gdx(jDir))*lambda_in(p_p,q_p,SideID(pLocSide)))
          END ASSOCIATE
          END ASSOCIATE
          q_out(:,g1,g2,g3,iElem)=q_out(:,g1,g2,g3,iElem)+aCon(:,jDir)*q_loc
        END DO !jDir

        !---------------------------------------------------------------
      END DO !g1
    END DO !g2
  END DO !g3

END DO !iElem

END SUBROUTINE PostProcessGradient
#endif /* PP_HDG*/
END MODULE MOD_Elem_Mat
