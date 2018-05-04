#include "boltzplatz.h"

MODULE MOD_Newton
!===================================================================================================================================
! Contains routines for the fully implicit scheme
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------

#if IMPA
INTERFACE ImplicitNorm
  MODULE PROCEDURE ImplicitNorm
END INTERFACE

INTERFACE FullNewton
  MODULE PROCEDURE FullNewton
END INTERFACE

PUBLIC::ImplicitNorm,FullNewton
#endif 
!===================================================================================================================================

CONTAINS

#if IMPA
SUBROUTINE ImplicitNorm(t,coeff,R,Norm_R,Delta_Norm_R,Delta_Norm_Rel,First) 
!===================================================================================================================================
! The error-norm of the fully implicit scheme is computed
! use same norm as in maxtrix-vector source; initial norm of linearsolver 
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_DG_Vars,                 ONLY:U
#ifndef PP_HDG
USE MOD_LinearSolver_Vars,       ONLY:ImplicitSource,LinSolverRHS,mass
USE MOD_DG_Vars,                 ONLY:Ut
USE MOD_DG,                      ONLY:DGTimeDerivative_weakForm
USE MOD_Equation,                ONLY:CalcSource
USE MOD_Equation_Vars,           ONLY:DoParabolicDamping,fDamping
USE MOD_TimeDisc_Vars,           ONLY:sdtCFLOne
#else /* HDG */
USE MOD_Equation,                ONLY:CalcSourceHDG
USE MOD_LinearSolver_Vars,       ONLY:ImplicitSource
#endif /*DG*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
REAL,INTENT(IN)            :: t
REAL,INTENT(IN)            :: coeff
LOGICAL,INTENT(IN),OPTIONAL:: First
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
REAL,INTENT(INOUT)         :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL,INTENT(OUT)           :: Norm_R
REAL,INTENT(OUT)           :: Delta_Norm_R
REAL,INTENT(OUT)           :: Delta_Norm_Rel
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                       :: X,DeltaX,DeltaX_Rel
INTEGER                    :: iElem, i,j,k,iVar
REAL                       :: rTmp(1:8), locMass
REAL                       :: rRel
#ifdef MPI
REAL                       :: NormArray(3), GlobalNormArray(3)
#endif /*MPI*/
!===================================================================================================================================

Norm_R         =0.
Delta_Norm_R   =0.
Delta_Norm_Rel =0.
#ifndef PP_HDG
! compute error-norm-version1, non-optimized
CALL DGTimeDerivative_weakForm(t, t, 0,doSource=.FALSE.)
ImplicitSource=0.
CALL CalcSource(t,1.,ImplicitSource)

IF(DoParabolicDamping)THEN
  rTmp(1:6)=1.0
  rTmp( 7 )=1.0-(fDamping-1.0)*coeff*sdTCFLOne
  rTmp( 8 )=1.0-(fDamping-1.0)*coeff*sdTCFLOne
ELSE
  rTmp(1:8)=1.0
END IF

DO iElem=1,PP_nElems
  DO k=0,PP_N
    DO j=0,PP_N
      DO i=0,PP_N
        locMass=mass(1,i,j,k,iElem)
        DO iVar=1,8
          X                   =locMass*( LinSolverRHS(iVar,i,j,k,iElem)           &
                                       - rTmp(iVar)*U(iVar,i,j,k,iElem)           &
                                       +     coeff*Ut(iVar,i,j,k,iElem)           &
                                       + coeff*ImplicitSource(iVar,i,j,k,iElem)   )
          Norm_R              = Norm_R + X*X
          DeltaX              = X-R(iVar,i,j,k,iElem)
          Delta_Norm_R        = Delta_Norm_R+DeltaX*DeltaX
          IF(.NOT.PRESENT(FIRST))THEN
            IF(ABS(X).GT.1e-14)THEN
              rRel                = DeltaX / X
              Delta_Norm_Rel      = Delta_Norm_Rel + rRel*rRel
            END IF
          END IF
          R(iVar,i,j,k,iElem) = X
        END DO ! iVar=1,PP_nVar
      END DO ! i=0,PP_N
    END DO ! j=0,PP_N
  END DO ! k=0,PP_N
END DO ! iElem=1,PP_nElems
#else /*HDG*/
DO iElem=1,PP_nElems
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    CALL CalcSourceHDG(i,j,k,iElem,ImplicitSource(1:PP_nVar,i,j,k,iElem))
  END DO; END DO; END DO !i,j,k    
END DO !iElem 
DO iElem=1,PP_nElems
  DO k=0,PP_N
    DO j=0,PP_N
      DO i=0,PP_N
        DO iVar=1,PP_nVar
          !DeltaX=U(iVar,i,j,k,iElem)+ImplicitSource(iVar,i,j,k,iElem)
          X                   = ImplicitSource(iVar,i,j,k,iElem)
          Norm_R              = Norm_R + X*X
          DeltaX              = X-R(iVar,i,j,k,iElem)
          Delta_Norm_R        = Delta_Norm_R+DeltaX*DeltaX
          IF(.NOT.PRESENT(FIRST))THEN
            IF(ABS(X).GT.1e-14)THEN
              rRel                = DeltaX / X
              Delta_Norm_Rel      = Delta_Norm_Rel + rRel*rRel
            END IF
          END IF
          R(iVar,i,j,k,iElem) = X
        END DO ! iVar=1,PP_nVar
      END DO ! i=0,PP_N
    END DO ! j=0,PP_N
  END DO ! k=0,PP_N
END DO ! iElem=1,PP_nElems
#endif /*DG*/

#ifdef MPI
NormArray(1)=Norm_R
NormArray(2)=Delta_Norm_R
NormArray(3)=Delta_Norm_Rel
CALL MPI_ALLREDUCE(NormArray,GlobalNormArray,3,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,iError)
Norm_R         = SQRT(GlobalNormArray(1))
Delta_Norm_R   = SQRT(GlobalNormArray(2))
Delta_Norm_Rel = SQRT(GlobalNormArray(3))
#else
Norm_R         = SQRT(Norm_R)
Delta_Norm_R   = SQRT(Delta_Norm_R)
Delta_Norm_Rel = SQRT(Delta_Norm_Rel)
#endif

END SUBROUTINE ImplicitNorm


SUBROUTINE FullNewton(t,tStage,coeff)
!===================================================================================================================================
! Full Newton with particles and field 
! Newton:
! Init: Implicit particle step and Norm_R0
!       1) Implicit field solver
!       2) ParticleNewton
!       3) Compute Norm_R
! EisenStat-Walker is from 
! Kelly - Iterative Methods for Linear and Nonlinear Equations, p. 105 ff
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_Globals_Vars,            ONLY:EpsMach
USE MOD_TimeDisc_Vars,           ONLY:iStage,ESDIRK_a,dt
#ifndef PP_HDG
USE MOD_LinearSolver,            ONLY:LinearSolver
USE MOD_LinearSolver_Vars,       ONLY:FieldStage,nDOFGlobalMPI_inv
USE MOD_LinearOperator,          ONLY:EvalResidual
USE MOD_Predictor,               ONLY:Predictor,PredictorType
#else
USE MOD_HDG,                     ONLY:HDG
USE MOD_HDG_Vars,                ONLY:EpsCG,useRelativeAbortCrit
#endif /*PP_HDG*/
USE MOD_DG_Vars,                 ONLY:U
USE MOD_LinearSolver_Vars,       ONLY:ImplicitSource, eps_LinearSolver
USE MOD_LinearSolver_Vars,       ONLY:maxFullNewtonIter,totalFullNewtonIter,totalIterLinearSolver
USE MOD_LinearSolver_Vars,       ONLY:Eps2_FullNewton,FullEisenstatWalker,FullgammaEW,DoPrintConvInfo,Eps_FullNewton,fulletamax
#ifdef PARTICLES
USE MOD_LinearSolver_Vars,       ONLY:DoFullNewton,DoFieldUpdate,PartNewtonLinTolerance
USE MOD_LinearSolver_Vars,       ONLY:PartRelaxationFac,PartRelaxationFac0,DoPartRelaxation,AdaptIterRelaxation0
USE MOD_Particle_Tracking,       ONLY:ParticleTracing,ParticleRefTracking
USE MOD_Particle_Tracking_vars,  ONLY:DoRefMapping
USE MOD_LinearSolver_Vars,       ONLY:Eps2PartNewton,UpdateInIter
USE MOD_Particle_Vars,           ONLY:PartIsImplicit
USE MOD_Particle_Vars,           ONLY:PartStateN,PartStage
USE MOD_Particle_Vars,           ONLY:PartState, LastPartPos, DelayTime, PEM, PDM !,StagePartPos
USE MOD_Part_RHS,                ONLY:PartVeloToImp
USE MOD_PICInterpolation,        ONLY:InterpolateFieldToSingleParticle
USE MOD_Part_MPFtools,           ONLY:StartParticleMerge
USE MOD_Particle_Analyze_Vars,   ONLY:DoVerifyCharge
USE MOD_PIC_Analyze,             ONLY:VerifyDepositedCharge
USE MOD_PICDepo,                 ONLY:Deposition
USE MOD_ParticleSolver,          ONLY:ParticleNewton
USE MOD_part_tools,              ONLY:UpdateNextFreePosition
#ifdef MPI
USE MOD_Particle_MPI,            ONLY:IRecvNbOfParticles, MPIParticleSend,MPIParticleRecv,SendNbOfparticles
USE MOD_Particle_MPI_Vars,       ONLY:PartMPIExchange
USE MOD_LoadBalance_Vars,        ONLY:tcurrent
#endif /*MPI*/
#endif /*PARTICLES*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
!----------------------------------------------------------------------------------------------------------------------------------!
REAL,INTENT(IN)            :: t
REAL,INTENT(INOUT)         :: tStage
REAL,INTENT(INOUT)         :: coeff
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                       :: Norm_R0,Norm_R,Norm_Rold, Norm_Diff,Norm_Diff_old, Delta_Norm_R0,Delta_Norm_Rel0 
REAL                       :: Delta_Norm_R, Delta_Norm_Rel
REAL                       :: etaA,etaB,etaC,etaMax,taut
INTEGER                    :: nFullNewtonIter
#ifdef PARTICLES
INTEGER                    :: iPart,iCounter
REAL                       :: tmpFac, relToleranceOld
INTEGER                    :: AdaptIterRelaxation
#ifdef MPI
! load balance
REAL                       :: tLBStart,tLBEnd
#endif /*MPI*/
#endif /*PARTICLES*/
REAL                       :: relTolerance,relTolerancePart,Criterion
LOGICAL                    :: IsConverged
#ifdef PP_HDG
INTEGER(KIND=8)            :: iter=0
#else
REAL                       :: Norm_R0_linSolver
#endif /*PP_HDG*/
REAL                       :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                       :: Rold(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                       :: Uold(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                       :: DeltaU(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                       :: Lambda ! Armijo rule
INTEGER                    :: nArmijo, nMaxArmijo=10
!===================================================================================================================================
!===================================================================================================================================

#ifdef PARTICLES
IF (t.GE.DelayTime) THEN
  IF(FullEisenstatWalker.GT.1)THEN
    relTolerancePart=0.998
  ELSE
    relTolerancePart=eps2PartNewton
  END IF
END IF

#ifdef MPI
  ! open receive buffer for number of particles
  CALL IRecvNbofParticles()
  ! here: could use deposition as hiding, not done yet
  IF(DoPartRelaxation)THEN
#ifdef MPI
    tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
    IF(DoRefMapping)THEN
      ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
      CALL ParticleRefTracking(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
    ELSE
      ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
      CALL ParticleTracing(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
    END IF
#ifdef MPI
  tLBEnd = LOCALTIME() ! LB Time End
  tCurrent(LB_TRACK)=tCurrent(LB_TRACK)+tLBEnd-tLBStart
#endif /*MPI*/
  END IF
  DO iPart=1,PDM%ParticleVecLength
    IF(PartIsImplicit(iPart))THEN
      IF(.NOT.PDM%ParticleInside(iPart)) PartisImplicit(iPart)=.FALSE.
    END IF
  END DO

  ! send number of particles
  CALL SendNbOfParticles(doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
  ! finish communication of number of particles and send particles
  CALL MPIParticleSend()
  ! finish communication
  CALL MPIParticleRecv()
  ! ALWAYS require
  PartMPIExchange%nMPIParticles=0
#endif /*MPI*/
  ! map particle from gamma v to v
#ifdef MPI
  tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
  CALL PartVeloToImp(VeloToImp=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
#ifdef MPI
  tLBEnd = LOCALTIME() ! LB Time End
  tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
  tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
  ! compute particle source terms on field solver of implicit particles :)
  CALL Deposition(doInnerParts=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
  CALL Deposition(doInnerParts=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
  ! map particle from v to gamma v
#ifdef MPI
  tLBEnd = LOCALTIME() ! LB Time End
  tCurrent(LB_DEPOSITION)=tCurrent(LB_DEPOSITION)+tLBEnd-tLBStart
  tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
  CALL PartVeloToImp(VeloToImp=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
#ifdef MPI
  tLBEnd = LOCALTIME() ! LB Time End
  tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
#endif /*MPI*/
!END IF
#endif /*PARTICLES*/

R=0.
#ifndef PP_HDG
! compute norm for Newton, which can be different than the first norm for the 
! linear solver
CALL ImplicitNorm(tStage,coeff,R,Norm_R0,Delta_Norm_R0,Delta_Norm_Rel0,First=.TRUE.)
IF(PredictorType.GT.0)THEN
  ! initial norm for first step of linear solver
  CALL EvalResidual(t,Coeff,Norm_R0_linSolver) 
  ! compute predictor
  CALL Predictor(iStage,dt,FieldStage)
END IF
#else
CALL ImplicitNorm(tStage,coeff,R,Norm_R0,Delta_Norm_R0,Delta_Norm_Rel0,First=.TRUE.)
#endif

Norm_R=Norm_R0
!Norm_Diff=HUGE(1.0)
!Norm_Diff_old=HUGE(1.0)
IF(DoPrintConvInfo.AND.MPIRoot)THEN
  WRITE(UNIT_stdOut,'(A18,E24.12)') ' Norm_R0:         ',Norm_R0
  WRITE(UNIT_stdOut,'(A18,E24.12)') ' Delta_Norm_R0:   ',Delta_Norm_R0
  WRITE(UNIT_stdOut,'(A18,E24.12)') ' Delta_Norm_Rel0: ',Delta_Norm_Rel0
END IF
IF(FullEisenstatWalker.GT.0)THEN
  etaMax=fulletamax !0.9999
  taut  =epsMach+eps_FullNewton*Norm_R0
END IF

nFullNewtonIter=0
IsConverged=.FALSE.
DO WHILE ((nFullNewtonIter.LE.maxFullNewtonIter).AND.(.NOT.IsConverged))
  nFullNewtonIter = nFullNewtonIter+1
  IF(DoPrintConvInfo)THEN
    SWRITE(UNIT_stdOut,'(A20)') '--------------------'
    SWRITE(UNIT_stdOut,'(A12,I10)') ' Iteration:', nFullNewtonIter
  END IF
  IF(FullEisenstatWalker.GT.0)THEN
    ! to enforce quadratic convergence, the tolerance of the linearsolver has to be reduced in a 
    ! quadratic approach. this quadratic degrease can be to strong for the newton for the particles,
    ! hence, this decrease should be still linear (cause the particle newton is a outer iteration)
    IF(nFullNewtonIter.EQ.1)THEN
      relTolerance=etaMax
#ifdef PARTICLES
      relToleranceOld=relTolerance
#endif /*PARTICLES*/
    ELSE
#ifdef PARTICLES
      relToleranceOld=relTolerance
#endif /*PARTICLES*/
      etaA=FullgammaEW*Norm_R*Norm_R/(Norm_Rold*Norm_Rold) ! here the square
      !SWRITE(*,*) 'etaA ', etaA
      etaB=MIN(etaMax,etaA)
      !SWRITE(*,*) 'etaB ', etaB
      Criterion  =FullGammaEW*relTolerance*relTolerance    ! here the square
      !SWRITE(*,*) 'criterion ', Criterion
      IF(DoPrintConvInfo)THEN
        SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-Criterion     :', Criterion
      END IF
      IF(Criterion.LT.0.1)THEN
        etaC=MIN(etaMax,etaA)
      ELSE
        etaC=MIN(etaMax,MAX(etaA,Criterion))
      END IF
      relTolerance=MIN(etaMax,MAX(etaC,0.5*taut/Norm_R))
      IF(DoPrintConvInfo)THEN
        SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-eteC          :', etaC
        SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-eteC          :', etaC
        SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-limit         :', 0.5*taut/Norm_R
        SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-tolerance     :', relTolerance
      END IF
    END IF
  ELSE
    relTolerance=eps_LinearSolver
  END IF

#ifdef PARTICLES
  IF (t.GE.DelayTime) THEN
    ! now, we have an initial guess for the field  can compute the first particle movement
    IF(FullEisenstatWalker.GT.1)THEN
      IF(PartNewtonLinTolerance)THEN
        etaA=FullgammaEW*Norm_R/(Norm_Rold) ! here the square
        !SWRITE(*,*) 'etaA ', etaA
        etaB=MIN(etaMax,etaA)
        !SWRITE(*,*) 'etaB ', etaB
        Criterion  =FullGammaEW*relToleranceOld    ! here the square
        !SWRITE(*,*) 'criterion ', Criterion
        IF(DoPrintConvInfo)THEN
          SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' EW-Criterion     :', Criterion
        END IF
        IF(Criterion.LT.0.1)THEN
          etaC=MIN(etaMax,etaA)
        ELSE
          etaC=MIN(etaMax,MAX(etaA,Criterion))
        END IF
        relTolerancePart=MIN(etaMax,MAX(etaC,0.5*taut/Norm_R))
      ELSE
        ! Default new tolerance
        relTolerancePart=SQRT(relTolerance) ! eisenstat walker is decreasing quadratic, hence,
                                            ! for a frozen field only linear decrease required
      END IF
    ELSE
      relTolerancePart=SQRT(eps2PartNewton)
    END IF
    !IF(DoFullNewton)THEN
    !  IF(nFullNewtonIter.EQ.1)THEN
    !    CALL ParticleNewton(tstage,coeff,doParticle_In=PartIsImplicit(1:PDM%maxParticleNumber),Opt_In=.TRUE. &
    !                       ,AbortTol_In=relTolerancePart)
    !  ELSE
    !    CALL ParticleNewton(tstage,coeff,doParticle_In=PartIsImplicit(1:PDM%maxParticleNumber),Opt_In=.FALSE. &
    !                       ,AbortTol_In=relTolerancePart)
    !  END IF
    !ELSE
    ! call particle newton. 
    ! LB-Measurement in ParticleNewton
    IF(DoPrintConvInfo)THEN
      SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' PartNewton-Tol   :', relTolerancePart
    END IF
    CALL ParticleNewton(tstage,coeff,doParticle_In=PartIsImplicit(1:PDM%maxParticleNumber),Opt_In=.TRUE. &
                       ,AbortTol_In=relTolerancePart)
    !END IF
    ! particle relaxation betweeen old and new position
    ! this is not needed any more
    IF(DoPartRelaxation)THEN
      SWRITE(UNIT_stdOut,'(A12)') ' relaxation newton:'
      DO iPart=1,PDM%ParticleVecLength
        IF(PartIsImplicit(iPart))THEN  
          ! update the last part pos and element for particle movement
          !LastPartPos(iPart,1)=StagePartPos(iPart,1)
          !LastPartPos(iPart,2)=StagePartPos(iPart,2)
          !LastPartPos(iPart,3)=StagePartPos(iPart,3)
          !PEM%lastElement(iPart)=PEM%StageElement(iPart)
          LastPartPos(iPart,1)=PartState(iPart,1)
          LastPartPos(iPart,2)=PartState(iPart,2)
          LastPartPos(iPart,3)=PartState(iPart,3)
          PEM%lastElement(iPart)=PEM%Element(iPart)
          tmpFac=(1.0-PartRelaxationFac)
          PartState(iPart,1)=PartRelaxationFac*PartState(iPart,1)+tmpFac*PartStateN(iPart,1)
          PartState(iPart,2)=PartRelaxationFac*PartState(iPart,2)+tmpFac*PartStateN(iPart,2)
          PartState(iPart,3)=PartRelaxationFac*PartState(iPart,3)+tmpFac*PartStateN(iPart,3)
          PartState(iPart,4)=PartRelaxationFac*PartState(iPart,4)+tmpFac*PartStateN(iPart,4)
          PartState(iPart,5)=PartRelaxationFac*PartState(iPart,5)+tmpFac*PartStateN(iPart,5)
          PartState(iPart,6)=PartRelaxationFac*PartState(iPart,6)+tmpFac*PartStateN(iPart,6)
          DO iCounter=1,iStage-1
            tmpFac=tmpFac*dt*ESDIRK_a(iStage-1,iCounter)
            PartState(iPart,1) = PartState(iPart,1) + tmpFac*PartStage(iPart,1,iCounter)
            PartState(iPart,2) = PartState(iPart,2) + tmpFac*PartStage(iPart,2,iCounter)
            PartState(iPart,3) = PartState(iPart,3) + tmpFac*PartStage(iPart,3,iCounter)
            PartState(iPart,4) = PartState(iPart,4) + tmpFac*PartStage(iPart,4,iCounter)
            PartState(iPart,5) = PartState(iPart,5) + tmpFac*PartStage(iPart,5,iCounter)
            PartState(iPart,6) = PartState(iPart,6) + tmpFac*PartStage(iPart,6,iCounter)
          END DO
        END IF ! ParticleInside
      END DO ! iPart
    END IF ! PartRelaxationFac>0
    IF(.NOT.DoFullNewton)THEN
      ! move particle, if not already done, here, a reduced list could be again used, but a different list...
#ifdef MPI
      ! open receive buffer for number of particles
      CALL IRecvNbofParticles()
      ! here: could use deposition as hiding, not done yet
      IF(DoPartRelaxation)THEN
        IF(DoRefMapping)THEN
          ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
          CALL ParticleRefTracking(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
        ELSE
          ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
          CALL ParticleTracing(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
        END IF
      END IF
      DO iPart=1,PDM%ParticleVecLength
        IF(PartIsImplicit(iPart))THEN
          IF(.NOT.PDM%ParticleInside(iPart)) PartisImplicit(iPart)=.FALSE.
        END IF
      END DO
      ! send number of particles
      CALL SendNbOfParticles(doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      ! finish communication of number of particles and send particles
      CALL MPIParticleSend()
      ! finish communication
      CALL MPIParticleRecv()
      PartMPIExchange%nMPIParticles=0
#endif /*MPI*/
      ! map particle from gamma v to v
#ifdef MPI
      tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      CALL PartVeloToImp(VeloToImp=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      ! compute particle source terms on field solver of implicit particles :)
#ifdef MPI
      tLBEnd = LOCALTIME() ! LB Time End
      tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
      tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      CALL Deposition(doInnerParts=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      CALL Deposition(doInnerParts=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      IF(DoVerifyCharge) CALL VerifyDepositedCharge()
      ! and map back
#ifdef MPI
      tLBEnd = LOCALTIME() ! LB Time End
      tCurrent(LB_DEPOSITION)=tCurrent(LB_DEPOSITION)+tLBEnd-tLBStart
      tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      CALL PartVeloToImp(VeloToImp=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
#ifdef MPI
      tLBEnd = LOCALTIME() ! LB Time End
      tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
#endif /*MPI*/
    END IF ! .NOT.DoFullNewton
  END IF
#endif /*PARTICLES*/

  ! solve field to new stage 
  ImplicitSource=0.
  ! store old value of U
  Uold=U
#ifdef PARTICLES
  IF(DoFieldUpdate)THEN ! update of field
#endif /*PARTICLES*/
#ifndef PP_HDG
  ! compute R0
  IF(DoPrintConvInfo)THEN
    SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' DGSolver-Tol   :', relTolerance
  END IF
  IF(nFullNewtonIter.EQ.1 .AND. PredictorType.GT.0)THEN
    CALL LinearSolver(tStage,coeff,relTolerance, Norm_R0_linSolver)
  ELSE
    CALL LinearSolver(tStage,coeff,relTolerance )
  END IF
#else
    IF(FullEisenstatWalker.GT.0) THEN
      IF(useRelativeAbortCrit) EpsCG=relTolerance 
    END IF 
    CALL HDG(tStage,U,iter)
#endif /*HDG*/
#ifdef PARTICLES
  END IF
#endif /*PARTICLES*/

  ! Next step is compute norm for normal Newton (DoFullNewton=T) or
  ! optimized scheme. Only the time for the DG-Operator s measured, all other 
  ! operations are neglected
#ifdef PARTICLES
  IF(.NOT.DoFullNewton)THEN 
#endif /*PARTICLES*/
    ! compute norm and field step
    Norm_Rold=Norm_R
    Rold=R
    CALL ImplicitNorm(tStage,coeff,R,Norm_R,Delta_Norm_R,Delta_Norm_Rel)
    IF(nFullNewtonIter.GT.5)THEN
      IF(Norm_R/Norm_Rold.GT.1.0000000)THEN
        ! not changing U -> is equal to post-iteration to decrease norm of particle scheme
        U=Uold
      ELSE
        IF(Norm_R.GT.0.9999*Norm_Rold)THEN
          ! apply Armijo rule
          ! U=Uold+DeltaU
          DeltaU=U-Uold
          lambda=2.
          nArmijo=1
          IF(Norm_R/Norm_Rold.GT.1.)THEN
            DO WHILE ((Norm_R/Norm_Rold.GT.(1.0)).AND.(nArmijo.LE.nMaxArmijo))
              ! update counter
              nArmijo=nArmijo+1
              ! update lambda of Armijo iteration
              lambda=0.1*lambda
              ! recompute new value of U
              U=Uold-lambda*DeltaU
              ! compute new norm
              R=Rold
              CALL ImplicitNorm(tStage,coeff,R,Norm_R,Delta_Norm_R,Delta_Norm_Rel)
              IF(DoPrintConvInfo)THEN
                SWRITE(UNIT_stdOut,'(A20,I4)') ' Armijo-iter:', nArmijo
                SWRITE(UNIT_stdOut,'(A20,E24.12,2x,E24.12)') ' NormR, Norm_Rold :', Norm_R,Norm_Rold
                SWRITE(UNIT_stdOut,'(A20,E24.12,2x,E24.12)') ' NormRrel,  +_rat :', Norm_R/Norm_Rold,(1.0-1e-4*lambda)
                SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_R     :', Delta_Norm_R
                SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_Rel   :', Delta_Norm_Rel
              END IF
            END DO
          ELSE
            !DO WHILE ((Norm_R/Norm_Rold.GT.(1.0-c_inv*lambda)).AND.(nArmijo.LE.nMaxArmijo))
            DO WHILE ((Norm_R/Norm_Rold.GT.1.0).AND.(nArmijo.LE.nMaxArmijo))
              ! update counter
              nArmijo=nArmijo+1
              ! update lambda of Armijo iteration
              lambda=0.1*lambda
              ! recompute new value of U
              U=Uold+lambda*DeltaU
              ! compute new norm
              R=Rold
              CALL ImplicitNorm(tStage,coeff,R,Norm_R,Delta_Norm_R,Delta_Norm_Rel)
              IF(DoPrintConvInfo)THEN
                SWRITE(UNIT_stdOut,'(A20,I4)') ' Armijo-iter:', nArmijo
                SWRITE(UNIT_stdOut,'(A20,E24.12,2x,E24.12)') ' NormR, Norm_Rold :', Norm_R,Norm_Rold
                SWRITE(UNIT_stdOut,'(A20,E24.12,2x,E24.12)') ' NormRrel,  +_rat :', Norm_R/Norm_Rold,(1.0-1e-4*lambda)
                SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_R     :', Delta_Norm_R
                SWRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_Rel   :', Delta_Norm_Rel
              END IF
            END DO
          END IF
          IF(DoPrintConvInfo)THEN
            SWRITE(UNIT_stdOut,'(A12,I4)') ' Armijo-step:', nArmijo
          END IF
        END IF
      END IF
    END IF
#ifdef PARTICLES
  END IF ! .NOT. DoFullNewton
  !IF(DoPrintConvInfo.AND.MPIRoot) WRITE(UNIT_StdOut,'(A,I10,2x,E24.12,2x,E24.12,2x,E24.12)') ' iter,Norm_R,rel,abort' &
  !                                                                ,nFullNewtonIter,Norm_R,Norm_R/Norm_R0,relTolerance

  IF(DoFullNewton)THEN 
    ! for full Newton, update source terms after DG step
    ! and update norm with this information. maybe, we should use the correct norm
    IF (t.GE.DelayTime) THEN
      ! move particle, if not already done, here, a reduced list could be again used, but a different list...
#ifdef MPI
      ! open receive buffer for number of particles
      CALL IRecvNbofParticles()
      ! here: could use deposition as hiding, not done yet
      IF(DoPartRelaxation)THEN
        IF(DoRefMapping)THEN
          ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
          CALL ParticleRefTracking(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
        ELSE
          ! input value: which list:DoPartInNewton or PDM%ParticleInisde?
          CALL ParticleTracing(doParticle_In=PartisImplicit(1:PDM%ParticleVecLength)) 
        END IF
      END IF
      DO iPart=1,PDM%ParticleVecLength
        IF(PartIsImplicit(iPart))THEN
          IF(.NOT.PDM%ParticleInside(iPart)) PartisImplicit(iPart)=.FALSE.
        END IF
      END DO
      ! send number of particles
      CALL SendNbOfParticles(doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      ! finish communication of number of particles and send particles
      CALL MPIParticleSend()
      ! finish communication
      CALL MPIParticleRecv()
      PartMPIExchange%nMPIParticles=0
#endif /*MPI*/
      ! map particle from gamma v to v
#ifdef MPI
      tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      CALL PartVeloToImp(VeloToImp=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
#ifdef MPI
       tLBEnd = LOCALTIME() ! LB Time End
       tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
       tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      ! compute particle source terms on field solver of implicit particles :)
      CALL Deposition(doInnerParts=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      CALL Deposition(doInnerParts=.FALSE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
      IF(DoVerifyCharge) CALL VerifyDepositedCharge()
      ! and map back
#ifdef MPI
       tLBEnd = LOCALTIME() ! LB Time End
       tCurrent(LB_DEPOSITION)=tCurrent(LB_DEPOSITION)+tLBEnd-tLBStart
       tLBStart = LOCALTIME() ! LB Time Start
#endif /*MPI*/
      CALL PartVeloToImp(VeloToImp=.TRUE.,doParticle_In=PartIsImplicit(1:PDM%ParticleVecLength))
#ifdef MPI
      tLBEnd = LOCALTIME() ! LB Time End
      tCurrent(LB_PUSH)=tCurrent(LB_PUSH)+tLBEnd-tLBStart
#endif /*MPI*/
    END IF
    ! update the Norm with all the new information of current state
    CALL ImplicitNorm(tStage,coeff,R,Norm_R,Delta_Norm_R,Delta_Norm_Rel)
  END IF ! DoFullNewton
#endif /*PARTICLES*/

  ! detect convergence, fancy, extended list of convergence detection with wide range of 
  ! parameters
  ! OLD
  ! Norm_Diff_old=Norm_Diff
  ! Norm_Diff=Norm_Rold-Norm_R
  ! ! IF((Norm_R.LT.Norm_R0*Eps_FullNewton).OR.
  ! IF(ABS(Norm_Diff).LT.Norm_R0*eps_FullNewton) IsConverged=.TRUE.
  ! IF(ABS(Norm_Diff).LT.1e-14) IsConverged=.TRUE.
  ! ! IF(Norm_R.LT.1e-14) IsConverged=.TRUE.
  ! ! IF(Delta_Norm_Rel.LT.eps_FullNewton) IsConverged=.TRUE.
  ! ! IF(Delta_Norm_Rel.LT.5.*Norm_R0*SQRT(Eps_FullNewton)) IsConverged=.TRUE.
  ! IF(ABS(Norm_Diff).LT.1e-14) IsConverged=.TRUE.

  ! ! relative norm
  ! IF(Norm_R.LT.Norm_R0*Eps_FullNewton) IsConverged=.TRUE.
  ! ! absolute norm
  ! IF(Norm_R.LT.Eps_FullNewton) IsConverged=.TRUE.
  ! ! some additional norms
  ! IF(Delta_Norm_R.LT.eps_FullNewton) IsConverged=.TRUE.
  ! IF(Delta_Norm_Rel.LT.eps_FullNewton) IsConverged=.TRUE.
  ! IF(Delta_Norm_Rel.LT.5.*Norm_R0*Eps_FullNewton)IsConverged=.TRUE.

  ! absolute norm
  IF(Norm_R*nDOFGlobalMPI_inv.LT.1e-12) IsConverged=.TRUE.
  ! relative norm
  IF(Norm_R.LT.Norm_R0*eps_FullNewton) IsConverged=.TRUE.

  IF(DoPrintConvInfo.AND.MPIRoot)THEN
    WRITE(UNIT_StdOut,'(A20,I0)')               ' Piccardi-iter    ',nFullNewtonIter
    WRITE(UNIT_stdOut,'(A20,E24.12)')           ' Tolerance        ',Eps_FullNewton
    WRITE(UNIT_StdOut,'(A20,E24.15,2x,E24.15)') ' Norm , Norm_0    ',Norm_R, Norm_R0
    WRITE(UNIT_StdOut,'(A20,E24.15)')           ' Norm / Norm_0    ',Norm_R/ Norm_R0
    WRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_R     ',Delta_Norm_R
    WRITE(UNIT_stdOut,'(A20,E24.12)')           ' Delta_Norm_Rel   ',Delta_Norm_Rel
    !WRITE(UNIT_StdOut,'(A20,E24.15)')           ' Norm_Diff        ',Norm_Diff
    !WRITE(UNIT_StdOut,'(A20,E24.15)')           ' Norm_Diff/Norm_0 ',Norm_Diff/Norm_R0
  END IF 

  ! IF(nFullNewtonIter.GT.5)THEN
  !   IF(ALMOSTZERO(Norm_Diff_old+Norm_Diff))THEN
  !     SWRITE(UNIT_StdOut,'(A20)') ' Convergence problem '
  !     SWRITE(UNIT_StdOut,'(A20,I10)')    ' Iteration          ', nFullNewtonIter
  !     SWRITE(UNIT_StdOut,'(A20,E24.15)') ' Old     Norm-Diff: ', Norm_Diff_old
  !     SWRITE(UNIT_StdOut,'(A20,E24.15)') ' Current Norm_Diff: ', Norm_Diff
  !   END IF
  ! END IF

#ifdef PARTICLES
  IF(DoPartRelaxation)THEN
    IF(MOD(nFullNewtonIter,AdaptIterRelaxation).EQ.0)THEN
      IF(Norm_Rold.GT.Norm_R)THEN
        PartRelaxationFac=MAX(PartRelaxationFac*1.55,1.0)
        !PartRelaxationFac=PartRelaxationFac*2
        !IF(PartRelaxationFac.GE.1.0) DoPartRelaxation=.FALSE.
      ELSE
         PartRelaxationFac=MAX(PartRelaxationFac/2,0.001)
      END IF
      AdaptIterRelaxation=MAX(INT(AdaptIterRelaxation*PartRelaxationFac0/PartRelaxationFac),AdaptIterRelaxation0)
    END IF
  END IF ! DoPartRelaxation

  IF((.NOT.IsConverged).AND.(MOD(nFullNewtonIter,UpdateInIter).EQ.0)) CALL UpdateNextFreePosition()
#endif /*PARTICLES*/
END DO ! funny pseudo Newton for all implicit

!IF(PartRelaxationFac0.NE.0) DoPartRelaxation=.TRUE.

totalFullNewtonIter=TotalFullNewtonIter+nFullNewtonIter
!IF(nFullNewtonIter.GE.maxFullNewtonIter)THEN
!  SWRITE(UNIT_StdOut,'(A)') " Implicit scheme is not converged!"
!  SWRITE(UNIT_StdOut,'(A,E20.14,5x,E20.14)') ' NormDiff and NormDiff/Norm_R0: ',Norm_Diff, Norm_Diff/Norm_R0
!  SWRITE(UNIT_StdOut,'(A,E20.14,5x,E20.14)') ' Norm_R/Norm_R0               : ',Norm_R/Norm_R0
!  IF(MPIRoot) CALL abort(&
! __STAMP__&
!   ,' Outer-Newton of semi-fully implicit scheme is running into infinity.',nFullNewtonIter,Norm_R/Norm_R0)
!END IF

IF(DoPrintConvInfo.AND.MPIRoot) WRITE(*,*) 'TotalIterlinearsolver',TotalIterlinearSolver

END SUBROUTINE FullNewton
#endif

END MODULE MOD_Newton
