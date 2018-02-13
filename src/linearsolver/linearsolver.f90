#include "boltzplatz.h"

MODULE MOD_LinearSolver
!===================================================================================================================================
! Contains routines to compute the riemann (Advection, Diffusion) for a given Face
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

#ifndef PP_HDG
INTERFACE LinearSolver
  MODULE PROCEDURE LinearSolver
!  MODULE PROCEDURE LinearSolver_GMRES_P
!  MODULE PROCEDURE LinearSolver_StabBiCGSTAB  
!  MODULE PROCEDURE LinearSolver_StabBiCGSTAB_P
!  MODULE PROCEDURE LinearSolver_BiCGSTAB_P
!  MODULE PROCEDURE LinearSolver_BiCGSTAB_PM
!  MODULE PROCEDURE LinearSolver_BiCGSTAB
END INTERFACE

PUBLIC:: LinearSolver
#endif /*NOT HDG*/

PUBLIC:: InitLinearSolver, FinalizeLinearSolver
PUBLIC:: DefineParametersLinearSolver
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for Linear solver
!==================================================================================================================================
SUBROUTINE DefineParametersLinearSolver()
! MODULES
USE MOD_ReadInTools ,ONLY: prms,addStrListEntry
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("Linear Solver")

CALL prms%CreateRealOption(     'EpsNewton'   , 'TODO-DEFINE-PARAMETER', '0.001')
CALL prms%CreateIntOption(      'nNewtonIter' , 'TODO-DEFINE-PARAMETER', '20')
CALL prms%CreateLogicalOption(  'EisenstatWalker' , 'TODO-DEFINE-PARAMETER', '.FALSE.')
CALL prms%CreateRealOption(     'gammaEW'   , 'TODO-DEFINE-PARAMETER', '0.9')
CALL prms%CreateIntOption(      'nRestarts' , 'TODO-DEFINE-PARAMETER', '1')
CALL prms%CreateRealOption(     'eps_LinearSolver'   , 'TODO-DEFINE-PARAMETER', '1e-3')
CALL prms%CreateIntOption(      'maxIter_LinearSolver' , 'TODO-DEFINE-PARAMETER', '60')
CALL prms%CreateIntOption(      'nKDim' , 'TODO-DEFINE-PARAMETER', '25')
CALL prms%CreateIntOption(      'maxFullNewtonIter' , 'TODO-DEFINE-PARAMETER', '100')
CALL prms%CreateRealOption(     'eps_FullNewton'   , 'TODO-DEFINE-PARAMETER', '1e-3')
CALL prms%CreateIntOption(      'FullEisenstatWalker' , 'TODO-DEFINE-PARAMETER', '0')
CALL prms%CreateRealOption(     'FullgammaEW'   , 'TODO-DEFINE-PARAMETER', '0.9')

CALL prms%CreateLogicalOption(  'DoPrintConvInfo' , 'TODO-DEFINE-PARAMETER', '.FALSE.')
CALL prms%CreateLogicalOption(  'DoFieldUpdate' , 'TODO-DEFINE-PARAMETER', '.TRUE.')
CALL prms%CreateRealOption(     'PartNewtonRelaxation'   , 'TODO-DEFINE-PARAMETER', '1.')
CALL prms%CreateLogicalOption(  'DoUpdateInStage' , 'TODO-DEFINE-PARAMETER', '.FALSE.')
CALL prms%CreateIntOption(      'UpdateInIter' , 'TODO-DEFINE-PARAMETER', '-1')
CALL prms%CreateRealOption(     'PartRelaxationFac'   , 'TODO-DEFINE-PARAMETER', '0.0')
CALL prms%CreateIntOption(      'AdaptIterRelaxation0' , 'TODO-DEFINE-PARAMETER', '2')
CALL prms%CreateLogicalOption(  'withmass' , 'TODO-DEFINE-PARAMETER', '.FALSE.')
CALL prms%CreateIntOption(      'LinSolver' , 'TODO-DEFINE-PARAMETER', '2')
CALL prms%CreateIntOption(      'ldim' , 'TODO-DEFINE-PARAMETER', '1')

CALL prms%CreateIntOption(      'Predictor' , 'TODO-DEFINE-PARAMETER', '0')

CALL prms%CreateIntOption(      'PrecondType' , 'TODO-DEFINE-PARAMETER', '0')
CALL prms%CreateIntOption(      'PrecondMethod' , 'TODO-DEFINE-PARAMETER', '0')
CALL prms%CreateIntOption(      'DebugMatrix' , 'TODO-DEFINE-PARAMETER', '0')

CALL prms%SetSection("Linear Solver Particle")

CALL prms%CreateRealOption(     'EpsPartNewton'   , 'TODO-DEFINE-PARAMETER', '0.001')
CALL prms%CreateRealOption(     'EpsPartLinSolver'   , 'TODO-DEFINE-PARAMETER', '0.0')
CALL prms%CreateIntOption(      'nPartNewtonIter' , 'TODO-DEFINE-PARAMETER', '20')
CALL prms%CreateIntOption(      'FreezePartInNewton' , 'TODO-DEFINE-PARAMETER', '1')
CALL prms%CreateRealOption(     'PartgammaEW'   , 'TODO-DEFINE-PARAMETER', '0.9')
CALL prms%CreateRealOption(     'scaleps'   , 'TODO-DEFINE-PARAMETER', '1.')
CALL prms%CreateLogicalOption(  'DoFullNewton' , 'TODO-DEFINE-PARAMETER', '.FALSE.')
CALL prms%CreateIntOption(      'Part-ImplicitMethod' , 'TODO-DEFINE-PARAMETER', '1')

END SUBROUTINE DefineParametersLinearSolver

SUBROUTINE InitLinearSolver()
!===================================================================================================================================
! Allocate global variable 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_LinearSolver_Vars
USE MOD_ReadInTools,          ONLY:GETINT,GETREAL,GETLOGICAL
USE MOD_Mesh_Vars,            ONLY:MeshInitIsDone
USE MOD_Interpolation_Vars,   ONLY:InterpolationInitIsDone
#ifndef PP_HDG
USE MOD_Interpolation_Vars,   ONLY:wGP
USE MOD_Mesh_Vars,            ONLY:sJ
USE MOD_Precond,              ONLY:InitPrecond
USE MOD_TimeDisc_Vars,        ONLY:nRKStages
#endif /*NOT HDG*/
USE MOD_Predictor,            ONLY:InitPredictor
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
#ifndef PP_HDG
INTEGER    :: i,j,k,iElem
#endif
!===================================================================================================================================

IF((.NOT.InterpolationInitIsDone).OR.(.NOT.MeshInitIsDone).OR.LinearSolverInitIsDone)THEN
   CALL abort(&
__STAMP__&
,'InitImplicit not ready to be called or already called.',999,999.)
END IF
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT LINEAR SOLVER...'

#ifndef PP_HDG
nGP2D=(PP_N+1)**2
nGP3D=nGP2D*(PP_N+1)
nDOFLine=PP_nVar*(PP_N+1)
nDOFside=PP_nVar*nGP2D
nDOFelem=PP_nVar*nGP3D
nDOFGlobal=nDOFelem*PP_nElems
#endif /*NOT HDG*/


ALLOCATE(ImplicitSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems))
ImplicitSource=0.
ALLOCATE(LinSolverRHS  (1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems))
LinSolverRHS=0.

!#if (PP_TimeDiscMethod==100)
!  ALLOCATE(FieldSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1))
!#endif
!#if (PP_TimeDiscMethod==102)
!  ALLOCATE(FieldSource(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:6))
!#endif 

#if (PP_TimeDiscMethod==104)
!ALLOCATE(Q(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems)) LinSolverRHS
! the time derivative computed at the actual Newton iteration value "xk"
ALLOCATE(R_Xk(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems))
ALLOCATE(Xk(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems))
Eps2Newton =GETREAL('EpsNewton','0.001')
Eps2Newton =Eps2Newton**2
nNewtonIter=GETINT('nNewtonIter','20')
EisenstatWalker=GETLOGICAL('EisenstatWalker','.FALSE.')
gammaEW=GETREAL('gammaEW','0.9')
#endif

#ifndef PP_HDG
nDofGlobalMPI=nDofGlobal
#ifdef MPI
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,nDofGlobalMPI,1,MPI_INTEGER,MPI_SUM,MPI_COMM_WORLD,iError)
#endif
#endif /*NOT HDG*/

nRestarts             = GETINT('nRestarts','1')
eps_LinearSolver      = GETREAL('eps_LinearSolver','1e-3')
epsTilde_LinearSolver = eps_LinearSolver!GETREAL('epsTilde_LinearSolver')
eps2_LinearSolver     = eps_LinearSolver *eps_LinearSolver 
maxIter_LinearSolver  = GETINT('maxIter_LinearSolver','60')

nKDim=GETINT('nKDim','25')
nInnerIter=0
totalIterLinearSolver = 0

#if (PP_TimeDiscMethod==120) || (PP_TimeDiscMethod==121) ||(PP_TimeDiscMethod==122)
maxFullNewtonIter    = GETINT('maxFullNewtonIter','100')
TotalFullNewtonIter  = 0
Eps_FullNewton       = GETREAL('eps_FullNewton','1e-3')
Eps2_FullNewton      = Eps_FullNewton*Eps_FullNewton
FullEisenstatWalker  = GETINT('FullEisenstatWalker','0')
FullgammaEW          = GETREAL('FullgammaEW','0.9')
DoPrintConvInfo      = GETLOGICAL('DoPrintConvInfo','F')
#ifndef PP_HDG
ALLOCATE(FieldStage(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:nRKStages-1))
#endif
#ifdef PARTICLES
DoFieldUpdate        = GETLOGICAL('DoFieldUpdate','.TRUE.')
! allocate explicit particle source
#if (PP_TimeDiscMethod==120) || (PP_TimeDiscMethod==121) || (PP_TimeDiscMethod==122) 
ALLOCATE(ExplicitPartSource(1:4,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems))
ExplicitPartSource=0.
PartNewtonRelaxation= GETREAL('PartNewtonRelaxation','1.')
#endif
! flag to enforce updatenextfree position in all rk stages
DoUpdateInStage =  GETLOGICAL('DoUpdateInStage','.FALSE.')
! UpdateNextFreePosition in each interation
UpdateInIter         = GETINT('UpdateInIter','-1')
PartRelaxationFac    = GETREAL('PartRelaxationFac','0.0')
PartRelaxationFac0   = PartRelaxationFac
DoPartRelaxation=.TRUE.
IF(ALMOSTZERO(PartRelaxationFac))THEN
  DoPartRelaxation=.FALSE.
ELSE
  AdaptIterRelaxation0 = GETINT('AdaptIterRelaxation0','2')
END IF
IF(UpdateInIter.EQ.-1) UpdateInIter=HUGE(1)
#endif /*PARTICLES*/
#endif

#ifndef PP_HDG
ALLOCATE(Mass(PP_nVar,0:PP_N,0:PP_N,0:PP_N,PP_nElems))
DO iElem=1,PP_nElems
  DO k=0,PP_N
    DO j=0,PP_N
      DO i=0,PP_N
        Mass(1:PP_nVar,i,j,k,iElem)=wGP(i)*wGP(j)*wGP(k) /sJ(i,j,k,iElem)
      END DO ! i
    END DO ! j
  END DO !k
END DO ! iElem=1,PP_nElems
IF(.NOT.GETLOGICAL('withmass','F')) mass=1.

LinSolver= GETINT('LinSolver','2')
SELECT CASE(LinSolver)
CASE(1)
  SWRITE(*,*) ' Linear solver: CGS with right preconditioner'
CASE(2)
  SWRITE(*,*) ' Linear solver: BiCGSTAB with right preconditioner'
CASE(3)
  SWRITE(*,*) ' Linear solver: stabilized BiCGSTAB with right preconditioner'
CASE(4)
  SWRITE(*,*) ' Linear solver: GMRES with right preconditioner'
CASE(5)
  SWRITE(*,*) ' Linear solver: BiCGSTAB with left and right preconditioner'
CASE(6)
  SWRITE(*,*) ' Linear solver: BiCGSTAB with left preconditioner'
CASE(7)
  SWRITE(*,*) ' Linear solver: BiCGSTAB(l)'
  ldim  = GETINT('ldim','1')
  maxIter_LinearSolver=maxIter_LinearSolver/ldim+1
  SWRITE(*,'(A,I4)') ' New number of max. Iterations: ', maxIter_LinearSolver
CASE DEFAULT
  CALL abort(&
__STAMP__ &
,'WRONG TYPE OF LINEAR SOLVER:',LinSolver,999.)
END SELECT
#endif /*NOT HDG*/
! init predictor
CALL InitPredictor()

#ifndef PP_HDG
! init preconditoner
CALL InitPrecond()
#endif /*NOT HDG*/

LinearSolverInitIsDone=.TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT LINEAR SOLVER DONE!'

END SUBROUTINE InitLinearSolver

#ifndef PP_HDG
SUBROUTINE LinearSolver(t,Coeff,relTolerance,Norm_R0)
!==================================================================================================================================
! Selection between different linear solvers
!==================================================================================================================================
! MODULES
USE MOD_LinearSolver_Vars              ,ONLY: LinSolver
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(INOUT)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL    :: relTolerance
REAL,INTENT(IN),OPTIONAL    :: Norm_R0
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================

IF(PRESENT(relTolerance).AND.PRESENT(Norm_R0))THEN
  SELECT CASE(LinSolver)
  CASE(1)
   CALL LinearSolver_CGS(t,Coeff,relTolerance,Norm_R0)
  CASE(2)
   CALL LinearSolver_BiCGSTAB_PM(t,Coeff,relTolerance,Norm_R0)
  CASE(3)
   CALL LinearSolver_StabBiCGSTAB_P(t,Coeff,relTolerance,Norm_R0)
  CASE(4)
   CALL LinearSolver_GMRES_P(t,Coeff,relTolerance,Norm_R0)
  CASE(5)
   CALL LinearSolver_BiCGSTAB_LRP(t,Coeff,relTolerance,Norm_R0)
  CASE(6)
   CALL LinearSolver_BiCGSTAB_LP(t,Coeff,relTolerance,Norm_R0)
  CASE(7)
   CALL LinearSolver_BiCGSTABl(t,Coeff,relTolerance,Norm_R0)
  END SELECT
ELSE IF(PRESENT(Norm_R0))THEN
  SELECT CASE(LinSolver)
  CASE(1)
   CALL LinearSolver_CGS(t,Coeff,Norm_R0)
  CASE(2)
   CALL LinearSolver_BiCGSTAB_PM(t,Coeff,Norm_R0)
  CASE(3)
   CALL LinearSolver_StabBiCGSTAB_P(t,Coeff,Norm_R0)
  CASE(4)
   CALL LinearSolver_GMRES_P(t,Coeff,Norm_R0)
  CASE(5)
   CALL LinearSolver_BiCGSTAB_LRP(t,Coeff,Norm_R0)
  CASE(6)
   CALL LinearSolver_BiCGSTAB_LP(t,Coeff,Norm_R0)
  CASE(7)
   CALL LinearSolver_BiCGSTABl(t,Coeff,Norm_R0)
  END SELECT
ELSE
  SELECT CASE(LinSolver)
  CASE(1)
   CALL LinearSolver_CGS(t,Coeff)
  CASE(2)
   CALL LinearSolver_BiCGSTAB_PM(t,Coeff)
  CASE(3)
   CALL LinearSolver_StabBiCGSTAB_P(t,Coeff)
  CASE(4)
   CALL LinearSolver_GMRES_P(t,Coeff)
  CASE(5)
   CALL LinearSolver_BiCGSTAB_LRP(t,Coeff)
  CASE(6)
   CALL LinearSolver_BiCGSTAB_LP(t,Coeff)
  CASE(7)
   CALL LinearSolver_BiCGSTABl(t,Coeff)
  END SELECT
END IF

END SUBROUTINE LinearSolver


SUBROUTINE LinearSolver_CGS(t,Coeff,relTolerance,Norm_R0_in)
!==================================================================================================================================
! Solves Linear system Ax=b using CGS
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
!==================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY:U
USE MOD_LinearSolver_Vars,    ONLY:eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
USE MOD_LinearSolver_Vars,    ONLY:ImplicitSource,nRestarts
USE MOD_LinearOperator,       ONLY:MatrixVector, VectorDotProduct,MatrixVectorSource
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Q(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Tvec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: sigma,alpha,beta,Norm_R,Norm_R0
REAL                     :: AbortCrit
INTEGER                  :: iterLinSolver,Restart
! preconditioner
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: TvecQt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!==================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!    = dt*Source^n+1  + dt*DG_Operator U^n 
!    = dt*Ut + dt*Source^n+1

! store here for later use
Un   = U ! here, n stands for U^n
Uold = U
Restart=0
nInnerIter = 0
! LinSolverRHS and X0 = U
! always required, because of predictor
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

! Init
P=R0
R=R0
Tvec=R0

IF(PRESENT(relTolerance))THEN
  AbortCrit = Norm_R0*relTolerance
ELSE
  AbortCrit = Norm_R0*eps_LinearSolver
END IF

DO WHILE (Restart.LT.nRestarts) ! maximum number of trials with CGS
  DO iterLinSolver=1, maxIter_LinearSolver
    ! Preconditioner
    CALL Preconditioner(P,Pt)
    CALL MatrixVector(t,coeff,Pt,V)
    CALL VectorDotProduct(V,R0,alpha) ! sig,alpha turned compared to BiCGSTAB ! caution
    CALL VectorDotProduct(R,R0,sigma)
    alpha = sigma / alpha
    Q=Tvec - alpha*V
    ! Preconditioner
    TvecQt=Tvec+Q
    CALL Preconditioner(TvecQt,TvecQt)
    CALL MatrixVector(t,coeff,TvecQt,V) ! we are using V because it is not needed again
    Un=Un+alpha*TvecQt
    ! R_j+1=R_j + alpha A(uj+qj)
    R = R - alpha*V
    CALL VectorDotProduct(R,R0,beta)
    beta = beta/sigma
    Tvec = R+beta*Q
    P    = Tvec+beta*(Q+beta*P)
    CALL VectorDotProduct(R,R,Norm_R)
    Norm_R=SQRT(Norm_R)
    ! test if success
    IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12))THEN
      U=Un
      nInnerIter=nInnerIter+iterLinSolver
      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
#ifdef DLINANALYZE
      CALL CPU_TIME(tE)
      ! Debug Ausgabe, Anzahl der Iterationen...
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in CGS        : ',tE-tS
      SWRITE(UNIT_stdOut,'(A23,E16.8)')   ' Norm_R0            : ',Norm_R0
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
      RETURN
    ENDIF
  END DO ! iterLinSolver
  ! restart with new U
  ! LinSolverRHS and X0 = U
  !  U              = 0.5*(Uold+Un)
  ImplicitSource = 0.
  U             = Un
  ! LinSolverRHS and X0 = U
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
  ! compute  A*U^n
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
  P   = R0
  R   = R0
  Tvec= R0
  nInnerIter=nInnerIter+iterLinSolver
  Restart = Restart + 1
END DO ! while chance < 2 

SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
IF(MPIROOT) CALL abort(&
__STAMP__ &
,'CGS NOT CONVERGED WITH RESTARTS AND CGS ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))
END SUBROUTINE LinearSolver_CGS


SUBROUTINE LinearSolver_BiCGStab_PM(t,Coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Solves Linear system Ax=b using BiCGStab with right preconditioner P_r
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY:U
USE MOD_LinearSolver_Vars,    ONLY:eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
USE MOD_LinearSolver_Vars,    ONLY:ImplicitSource,nRestarts
USE MOD_LinearOperator,       ONLY:MatrixVector,  VectorDotProduct,MatrixVectorSource
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: S(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: TVec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Norm_R,Norm_T2, Norm_R0
INTEGER                  :: iterLinSolver,Restart
REAL                     :: alpha,sigma,omega,beta
REAL                     :: AbortCrit
! preconditioner
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: St(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
#ifdef DLINANALYZE
REAL                     :: tS,tE,tStart,tend
REAL                     :: tDG, tPrecond
#endif /* DLINANALYZE */
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!    = dt*Source^n+1  + dt*DG_Operator U^n 
!    = dt*Ut + dt*Source^n+1

#ifdef DLINANALYZE
tPrecond=0.
tDG=0.
CALL CPU_TIME(tS)
#endif /* DLINANALYZE */

! store here for later use
Un   = U ! here, n stands for U^n
Uold = U
Restart=0
nInnerIter = 0
! LinSolverRHS and X0 = U
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
CALL VectorDotProduct(R0,R0,alpha)

! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  Norm_R0=SQRT(alpha)
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

P  = R0
R  = R0
IF(PRESENT(relTolerance))THEN
  AbortCrit = Norm_R0*relTolerance
ELSE
  AbortCrit = Norm_R0*eps_LinearSolver
END IF


DO WHILE (Restart.LT.nRestarts)  ! maximum of two trials with BiCGStab inner interation
  DO iterLinSolver = 1, maxIter_LinearSolver  ! two trials with half of iterations
    ! Preconditioner
#ifdef DLINANALYZE
        CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    CALL Preconditioner(P,Pt)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tPrecond=tPrecond+tend-tStart
    ! matrix vector
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    CALL MatrixVector(t,coeff,Pt,V)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tDG=tDG+tend-tStart
#endif /* DLINANALYZE */
    CALL VectorDotProduct(V,R0,sigma)
    !CALL VectorDotProduct(R,R0,alpha)

    alpha=alpha/sigma
    S = R - alpha*V

#ifdef DLINANALYZE
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    ! Preconditioner
    CALL Preconditioner(S,St)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tPrecond=tPrecond+tend-tStart
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    ! matrix vector
    CALL MatrixVector(t,coeff,St,TVec)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tDG=tDG+tend-tStart
#endif /* DLINANALYZE */

    CALL VectorDotProduct(TVec,TVec,Norm_T2)
    CALL VectorDotProduct(TVec,S,omega)
    omega=omega/Norm_T2

    Un=Un+alpha*Pt+omega*St
    R=S-omega*TVec
    CALL VectorDotProduct(R,R0,alpha)
    beta=alpha/(omega*sigma)
    P=R+beta*(P-omega*V)
    CALL VectorDotProduct(R,R,Norm_R)
    Norm_R=SQRT(Norm_R)
    ! test if success
    IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
      U=Un
      nInnerIter=nInnerIter+iterLinSolver
      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
#ifdef DLINANALYZE
      CALL CPU_TIME(tE)
      ! Debug Ausgabe, Anzahl der Iterationen...
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in BiCGSTAB   : ',tE-tS
      SWRITE(UNIT_stdOut,'(A23,E16.8)')   ' Norm_R0            : ',Norm_R0
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
      RETURN
    ENDIF
  END DO ! iterLinSolver
  ! restart with new U
  ! LinSolverRHS and X0 = U
!  U              = 0.5*(Uold+Un)
  ImplicitSource = 0.
  U             = Un
  ! LinSolverRHS and X0 = U
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
  ! compute  A*U^n
  CALL VectorDotProduct(R0,R0,Norm_R0)
  alpha=Norm_R0
  Norm_R0=SQRT(Norm_R0)
  P  = R0
  R  = R0
  nInnerIter=nInnerIter+iterLinSolver
  Restart = Restart + 1
END DO ! while chance < 2 

SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
IF(MPIRoot) CALL abort(&
__STAMP__ &
,'BiCGSTAB NOT CONVERGED WITH RESTARTS AND BiCGSTAB ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))

END SUBROUTINE LinearSolver_BiCGSTAB_PM


SUBROUTINE LinearSolver_StabBiCGSTAB_P(t,Coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Solves Linear system Ax=b using stabilized BiCGStab 
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,                 ONLY: U
USE MOD_LinearSolver_Vars,       ONLY: eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver
USE MOD_LinearSolver_Vars,       ONLY: LinSolverRHS,ImplicitSource
USE MOD_LinearOperator,          ONLY: MatrixVector, MatrixVectorSource, VectorDotProduct
USE MOD_ApplyPreconditioner,     ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                  :: iter
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: S(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: TVec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: sigma,alpha,Norm_T2,omega,beta,Norm_R,Norm_S,Norm_R0
REAL                     :: AbortCrit,AbortCrit2
INTEGER                  :: chance
! preconditioner
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: St(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: tS,tE,tStart,tend
REAL                     :: tDG
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n -( I - dt*DG_Operator ) U^n
!    = dt*DG_Operator U^n 
!    = dt * Ut


! store here for later use
CALL CPU_TIME(tS)
Un   = U ! here, n stands for U^n
Uold = U
chance=0
DO WHILE (chance.LT.2)  ! maximum of two trials with BiCGStab inner interation
  ! init and get first error norm
  ! Compute A*U^n
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff * DG_Operator(Un)
  CALL VectorDotProduct(R0,R0,alpha)
  IF(chance.GT.0) THEN
    Norm_R0=SQRT(alpha)
  ELSE
    ! compute  A*U^n
    IF(PRESENT(Norm_R0_in))THEN
      Norm_R0=Norm_R0_in
    ELSE
      Norm_R0=SQRT(alpha)
    END IF
    ! absolute tolerance check, if initial solution already matches old solution or 
    ! RHS is zero. Maybe it is here better to use relTolerance?
    IF(Norm_R0.LT.1e-14) RETURN
  END IF
  P=R0
  R=R0
  IF(PRESENT(relTolerance))THEN
    AbortCrit = Norm_R0*relTolerance
  ELSE
    AbortCrit = Norm_R0*eps_LinearSolver
  END IF
  AbortCrit2 = AbortCrit*AbortCrit
  
  DO iter=1,maxIter_LinearSolver
    ! Preconditioner
    CALL CPU_TIME(tStart)
    CALL Preconditioner(P,Pt)
    CALL CPU_TIME(tend)
    ! matrix vector
    CALL CPU_TIME(tStart)
    CALL MatrixVector(t,coeff,Pt,V)
    CALL CPU_TIME(tend)
    tDG=tDG+tend-tStart
    CALL VectorDotProduct(V,R0,sigma) 
!    CALL VectorDotProduct(V,V,Norm_V) 
!    Norm_V = SQRT(Norm_V)
!    AbortCrit2 = epsTilde_LinearSolver*Norm_V*Norm_R0
!    IF((sigma.GT.AbortCrit2).AND.(iter.GT.10)) THEN
      alpha=alpha/sigma
      S = R - alpha*V
      CALL VectorDotProduct(S,S,Norm_S)
      !Norm_S = SQRT(Norm_S)
      !IF((Norm_S.GT.AbortCrit).OR.(Norm_S.GT.1e-12))THEN
      IF((Norm_S.GT.AbortCrit2).OR.(Norm_S.GT.1e-12))THEN
        ! Preconditioner
        CALL CPU_TIME(tStart)
        CALL Preconditioner(S,St)
        CALL CPU_TIME(tend)
        ! matrix vector
        CALL CPU_TIME(tStart)
        CALL MatrixVector(t,coeff,St,TVec)
        CALL CPU_TIME(tend)
        tDG=tDG+tend-tStart
        CALL VectorDotProduct(TVec,TVec,Norm_T2)
        CALL VectorDotProduct(TVec,S,omega)
        omega=omega/Norm_T2
        ! new un or target variable
        Un=Un+alpha*Pt+omega*St
        R=S-omega*TVec
        CALL VectorDotProduct(R,R0,alpha)
        beta=alpha/(omega*sigma)
        P=R+beta*(P-omega*V)
        CALL VectorDotProduct(R,R,Norm_R)
        Norm_R=SQRT(Norm_R)
        IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
          U=Un 
          totalIterLinearSolver=totalIterLinearSolver+iter
          CALL CPU_TIME(tE)
          ! Debug Ausgabe, Anzahl der Iterationen...
          SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',iter
          SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' T in STABBiCGSTAB  : ',tE-tS
          SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
          SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
          RETURN
        ENDIF ! Norm_R < AbortCrit
      ELSE ! Norm_S .LT. 1e-12
        Un=Un+alpha*Pt
        R=S
        CALL VectorDotProduct(R,R,Norm_R)
        Norm_R=SQRT(Norm_R)
        CALL VectorDotProduct(R,R0,alpha)
        IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
          U=Un
          totalIterLinearSolver=totalIterLinearSolver+iter
          ! Debug Ausgabe, Anzahl der Iterationen...
          CALL CPU_TIME(tE)
          ! Debug Ausgabe, Anzahl der Iterationen...
          SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',iter
          SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' T in STABBiCGSTAB  : ',tE-tS
          SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
          SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
          RETURN
        ENDIF ! Norm_R < AbortCrit
      END IF ! Norm_S
!    ELSE
!      SWRITE(*,*) 'Sigma crit killed us!!'
!      U = Un
!      totalIterLinearSolver=totalIterLinearSolver+iter
!    END IF ! Norm_Sigma
  END DO !iter
 ! restart with new U 
  Un   = 0.5*(Uold+Un)
  Uold = U
  LinSolverRHS = U
  ImplicitSource = 0.
  totalIterLinearSolver=totalIterLinearSolver+iter
  chance = chance+1
  SWRITE(*,*) 'No convergence during first half of iterations.'
  SWRITE(*,*) 'Iter,t,Norm_R,Norm_R0',iter,t,Norm_R,Norm_R0

END DO ! while

SWRITE(*,*)'Norm_R        : ',Norm_R
SWRITE(*,*)'Norm_R0       : ',Norm_R0
IF(MPIRoot) CALL abort(&
__STAMP__ &
,'StabBiCGSTAB_P NOT CONVERGED WITH RESTARTS AND BiCGSTAB ITERATIONS:',chance,REAL(iter))

END SUBROUTINE LinearSolver_StabBiCGSTAB_P


SUBROUTINE LinearSolver_GMRES_P(t,coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Uses matrix free to solve the linear system
! Attention: We use DeltaX=0 as our initial guess   ! why not Un??
!            X0 is allready stored in U
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY: U
USE MOD_LinearSolver_Vars,    ONLY: ImplicitSource
USE MOD_LinearSolver_Vars,    ONLY: eps_LinearSolver,TotalIterLinearSolver
USE MOD_LinearSolver_Vars,    ONLY: nKDim,nRestarts,nInnerIter
USE MOD_LinearOperator,       ONLY: MatrixVector, MatrixVectorSource, VectorDotProduct
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:nKDim)
REAL                     :: W(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Gam(1:nKDim+1),C(1:nKDim),S(1:nKDim),H(1:nKDim+1,1:nKDim+1),Alp(1:nKDim+1)
REAL                     :: Resu,Temp,Bet,Norm_R, Norm_R0
REAL                     :: AbortCrit
INTEGER                  :: Restart
INTEGER                  :: m,nn,o
! preconditoner + Vt
REAL                     :: Vt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,1:nKDim)
#ifdef DLINANALYZE
REAL                     :: tS,tE, tS2,tE2,t1,t2
real                     :: tstart,tend,tPrecond,tDG
#endif /* DLINANALYZE */
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n -( I - dt*DG_Operator ) U^n
!    = dt*DG_Operator U^n 
!    = dt * Ut

#ifdef DLINANALYZE
! time measurement
CALL CPU_TIME(tS)
! start GMRES
tPrecond=0.
tDG=0.
#endif /* DLINANALYZE */

Restart=0
nInnerIter=0
Un=U 

! compute starting residual 
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
CALL VectorDotProduct(R0,R0,Norm_R)
Norm_R=SQRT(Norm_R) ! Norm_r is already computed

! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  Norm_R0=Norm_R
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

! define relative abort criteria, Norm_R0 is computed outside
IF(PRESENT(relTolerance))THEN
  AbortCrit = Norm_R0*relTolerance
ELSE
  AbortCrit = Norm_R0*eps_LinearSolver
END IF

! GMRES(m)  inner loop
V(:,:,:,:,:,1)=R0/Norm_R
Gam(1)=Norm_R

DO WHILE (Restart<nRestarts)
  DO m=1,nKDim
    nInnerIter=nInnerIter+1
    ! Preconditioner
#ifdef DLINANALYZE
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    CALL Preconditioner(V(:,:,:,:,:,m),Vt(:,:,:,:,:,m))
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tPrecond=tPrecond+tend-tStart
    CALL CPU_TIME(tStart)
#endif /* DLINANALYZE */
    ! matrix vector
    CALL MatrixVector(t,coeff,Vt(:,:,:,:,:,m),W)
#ifdef DLINANALYZE
    CALL CPU_TIME(tend)
    tDG=tDG+tend-tStart
#endif /* DLINANALYZE */
    ! Gram-Schmidt
    DO nn=1,m
      CALL VectorDotProduct(V(:,:,:,:,:,nn),W,H(nn,m))
      W=W-H(nn,m)*V(:,:,:,:,:,nn)
    END DO !nn
    CALL VectorDotProduct(W,W,Resu)
    H(m+1,m)=SQRT(Resu)
    ! Givens Rotation
    DO nn=1,m-1
      Temp     =   C(nn)*H(nn,m) + S(nn)*H(nn+1,m)
      H(nn+1,m) = - S(nn)*H(nn,m) + C(nn)*H(nn+1,m)
      H(nn,m)   =   Temp
    END DO !nn
    Bet=SQRT(H(m,m)*H(m,m)+H(m+1,m)*H(m+1,m))
    S(m)=H(m+1,m)/Bet
    C(m)=H(m,m)/Bet 
    H(m,m)=Bet
    Gam(m+1)=-S(m)*Gam(m)
    Gam(m)=C(m)*Gam(m)
    IF ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim)) THEN !converge or max Krylov reached
      DO nn=m,1,-1
         Alp(nn)=Gam(nn) 
         DO o=nn+1,m
           Alp(nn)=Alp(nn) - H(nn,o)*Alp(o)
         END DO !o
         Alp(nn)=Alp(nn)/H(nn,nn)
      END DO !nn
      DO nn=1,m
        Un=Un+Alp(nn)*Vt(:,:,:,:,:,nn)
      END DO !nn
      IF (ABS(Gam(m+1)).LE.AbortCrit) THEN !converged
        totalIterLinearSolver=totalIterLinearSolver+nInnerIter
        U=Un
#ifdef DLINANALYZE
        CALL CPU_TIME(tE)
        SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
        SWRITE(UNIT_stdOut,'(A22,I5)')      ' nRestarts          : ',Restart
        SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in GMRES      : ',tE-tS
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Gam(1)
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Gam(m+1)
        SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
        RETURN
      END IF  ! converged
    ELSE ! no convergence, next iteration   ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim)) 
      V(:,:,:,:,:,m+1)=W/H(m+1,m)
    END IF ! ((ABS(Gam(m+1)).LE.AbortCrit) .OR. (m.EQ.nKDim))
  END DO ! m 
  ! Restart needed
  Restart=Restart+1
  ! new settings for source
  U=Un
  ImplicitSource = 0.
  ! does not change LinSolverRHS
! start residuum berrechnen
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
  ! GMRES(m)  inner loop
  V(:,:,:,:,:,1)=R0/Norm_R0
  Gam(1)=Norm_R0
END DO ! Restart

IF(MPIRoot) CALL abort(&
__STAMP__ &
,'GMRES_M NOT CONVERGED WITH RESTARTS AND GMRES ITERATIONS:',Restart,REAL(nInnerIter))

END SUBROUTINE LinearSolver_GMRES_P


SUBROUTINE LinearSolver_BiCGStab_LRP(t,Coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Solves Linear system Ax=b using BiCGStab with left and right preconditioners
! left preconditioner is right preconditioner
! alogrithm from Meister, p. 228 with direct residual control for left preconditoned algorithm
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY:U
USE MOD_LinearSolver_Vars,    ONLY:eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
USE MOD_LinearSolver_Vars,    ONLY:ImplicitSource,nRestarts
USE MOD_LinearOperator,       ONLY:MatrixVector, MatrixVectorSource, VectorDotProduct
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: S(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: TVec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Norm_R0,Norm_R,Norm_T2,Norm_Rn
INTEGER                  :: iterLinSolver,Restart
REAL                     :: alpha,sigma,omega,beta
REAL                     :: AbortCrit
! preconditioner
REAL                     :: deltaX(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Rt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0t(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Vt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Tvect(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: St(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!    = dt*Source^n+1  + dt*DG_Operator U^n 
!    = dt*Ut + dt*Source^n+1

! store here for later use
Un   = U ! here, n stands for U^n
deltaX = 0.
Uold = U
Restart=0
nInnerIter = 0
! LinSolverRHS and X0 = U
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output

! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

R = R0
IF(PRESENT(relTolerance))THEN
  AbortCrit = (Norm_R0)*relTolerance
ELSE
  AbortCrit = (Norm_R0)*eps_LinearSolver
END IF

! left precondtioning of residuum
CALL Preconditioner(R0,R0t)

! compute preconditoned R0
Pt = R0t
Rt = R0t
CALL VectorDotProduct(R0t,R0t,Norm_R0)
Norm_R = Norm_R0


DO WHILE (Restart.LT.nRestarts)  ! maximum of two trials with BiCGStab inner interation
  DO iterLinSolver = 1, maxIter_LinearSolver  ! two trials with half of iterations
    ! Preconditioner
    ! right preconditioner before Maxtrix-Vector
    CALL Preconditioner(Pt,V)
    CALL MatrixVector(t,coeff,V,V) ! or V,Vt and V=Vt
    ! left preconditioner
    CALL Preconditioner(V,Vt)

    ! compute preconditioned alpha
    CALL VectorDotProduct(Rt,R0t,alpha)
    CALL VectorDotProduct(Vt,R0t,sigma)
    alpha=alpha/sigma
    S = R - alpha*V ! requires to save v 
    ! left preconditoner
    !CALL Preconditioner(S,St)
    ! or does not require the application of the preconditioner, Meister,p.227,EQ.5.9.3
    St = Rt - alpha*Vt

    ! next Matrix Vector
    ! right precondtioner
    CALL Preconditioner(St,Tvec) 
    CALL MatrixVector(t,coeff,Tvec,TVec) ! or Tvec,Tvect;  Tvec=TvecT
    ! left preconditioner
    CALL Preconditioner(Tvec,Tvect)

    ! compute omega
    CALL VectorDotProduct(TVect,TVect,Norm_T2)
    CALL VectorDotProduct(TVect,St,omega)
    omega=omega/Norm_T2

    ! change of x
    deltaX=deltaX+alpha*Pt+omega*St

    ! compute new residuum
    R =S -omega*Tvec ! requires to store Tvec and Tvect
    Rt=St-omega*Tvect

    CALL VectorDotProduct(Rt,R0t,Norm_RN)
    beta=alpha*Norm_RN/(omega*Norm_R)
    Pt = Rt+ beta*(Pt-omega*Vt)

    CALL VectorDotProduct(R,R,Norm_R)
    Norm_R=SQRT(Norm_R)
    ! test if success
    IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
      CALL Preconditioner(deltaX,deltaX)
      U=Un+deltaX
      nInnerIter=nInnerIter+iterLinSolver
      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
#ifdef DLINANALYZE
      CALL CPU_TIME(tE)
      ! Debug Ausgabe, Anzahl der Iterationen...
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in BiCGSTAB   : ',tE-tS
      SWRITE(UNIT_stdOut,'(A23,E16.8)')   ' Norm_R0            : ',Norm_R0
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
      RETURN
    ENDIF
    Norm_R = Norm_RN
  END DO ! iterLinSolver
  CALL Preconditioner(deltaX,deltaX)
  U=Un+deltaX
  deltaX = 0.
  Uold = U

  ! restart with new U
  ImplicitSource = 0.
  ! LinSolverRHS and X0 = U
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
  R = R0
  ! left precondtioning of residuum
  CALL Preconditioner(R0,R0t)
  ! compute preconditoned R0
  Pt = R0t
  Rt = R0t
  CALL VectorDotProduct(R0t,R0t,Norm_R0)
  Norm_R = Norm_R0
  nInnerIter=nInnerIter+iterLinSolver
  Restart = Restart + 1
END DO ! while chance < 2 

SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
IF(MPIRoot) CALL abort(&
__STAMP__ &
,'BiCGSTAB NOT CONVERGED WITH RESTARTS AND BiCGSTAB ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))

END SUBROUTINE LinearSolver_BiCGSTAB_LRP


SUBROUTINE LinearSolver_BiCGStab_LP(t,Coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Solves Linear system Ax=b using BiCGStab with left and right preconditioners
! left preconditioner is right preconditioner
! alogrithm from Meister, p. 228 with direct residual control for left preconditoned algorithm
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY:U
USE MOD_LinearSolver_Vars,    ONLY:eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
USE MOD_LinearSolver_Vars,    ONLY:ImplicitSource,nRestarts
!USE MOD_LinearSolver_Vars,    ONLY:LinSolverRHS,ImplicitSource,nRestarts
USE MOD_LinearOperator,       ONLY:MatrixVector, MatrixVectorSource, VectorDotProduct
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: UOld(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: V(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: S(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: TVec(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Norm_R0,Norm_R,Norm_T2,Norm_Rn
INTEGER                  :: iterLinSolver,Restart
REAL                     :: alpha,sigma,omega,beta
REAL                     :: AbortCrit
! preconditioner
!REAL                     :: deltaX(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Rt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: R0t(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Vt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Tvect(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: St(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!    = dt*Source^n+1  + dt*DG_Operator U^n 
!    = dt*Ut + dt*Source^n+1

! store here for later use
Un   = U ! here, n stands for U^n
Uold = U
Restart=0
nInnerIter = 0
! LinSolverRHS and X0 = U
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output

! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

R = R0
IF(PRESENT(relTolerance))THEN
  AbortCrit = SQRT(Norm_R0)*relTolerance
ELSE
  AbortCrit = SQRT(Norm_R0)*eps_LinearSolver
END IF

! left precondtioning of residuum
CALL Preconditioner(R0,R0t)

! compute preconditoned R0
Pt = R0t
Rt = R0t
CALL VectorDotProduct(R0t,R0t,Norm_R0)
Norm_R = Norm_R0


DO WHILE (Restart.LT.nRestarts)  ! maximum of two trials with BiCGStab inner interation
  DO iterLinSolver = 1, maxIter_LinearSolver  ! two trials with half of iterations
    ! Preconditioner
    CALL MatrixVector(t,coeff,Pt,V) ! or V,Vt and V=Vt
    ! left preconditioner
    CALL Preconditioner(V,Vt)

    ! compute preconditioned alpha
    CALL VectorDotProduct(Rt,R0t,alpha)
    CALL VectorDotProduct(Vt,R0t,sigma)
    alpha=alpha/sigma
    S = R - alpha*V ! requires to save v 
    ! left preconditoner
    !CALL Preconditioner(S,St)
    ! or does not require the application of the preconditioner, Meister,p.227,EQ.5.9.3
    St = Rt - alpha*Vt

    ! next Matrix Vector
    CALL MatrixVector(t,coeff,St,TVec) ! or Tvec,Tvect;  Tvec=TvecT
    ! left preconditioner
    CALL Preconditioner(Tvec,Tvect)

    ! compute omega
    CALL VectorDotProduct(TVect,TVect,Norm_T2)
    CALL VectorDotProduct(TVect,St,omega)
    omega=omega/Norm_T2

    ! change of x
    Un=Un+alpha*Pt+omega*St

    ! compute new residuum
    R =S -omega*Tvec ! requires to store Tvec and Tvect
    Rt=St-omega*Tvect

    CALL VectorDotProduct(Rt,R0t,Norm_RN)
    beta=alpha*Norm_RN/(omega*Norm_R)
    Pt = Rt+ beta*(Pt-omega*Vt)

    CALL VectorDotProduct(R,R,Norm_R)
    Norm_R=SQRT(Norm_R)
    ! test if success
    IF((Norm_R.LE.AbortCrit).OR.(Norm_R.LT.1.E-12)) THEN
      U=Un
      nInnerIter=nInnerIter+iterLinSolver
      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
#ifdef DLINANALYZE
      CALL CPU_TIME(tE)
      ! Debug Ausgabe, Anzahl der Iterationen...
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      SWRITE(UNIT_stdOut,'(A22,F16.9)')   ' Time in BiCGSTAB   : ',tE-tS
      SWRITE(UNIT_stdOut,'(A23,E16.8)')   ' Norm_R0            : ',Norm_R0
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
      SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Ratio Precond/DG   : ',tPrecond/tDG
#endif /* DLINANALYZE */
      RETURN
    ENDIF
    Norm_R = Norm_RN
  END DO ! iterLinSolver
  U=Un
  Uold = U

  ! restart with new U
  ImplicitSource = 0.
  ! LinSolverRHS and X0 = U
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output
  R = R0
  ! left precondtioning of residuum
  CALL Preconditioner(R0,R0t)
  ! compute preconditoned R0
  Pt = R0t
  Rt = R0t
  CALL VectorDotProduct(R0t,R0t,Norm_R0)
  Norm_R = Norm_R0
  nInnerIter=nInnerIter+iterLinSolver
  Restart = Restart + 1
END DO ! while chance < 2 

SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
IF(MPIRoot) CALL abort(&
__STAMP__ &
,'BiCGSTAB NOT CONVERGED WITH RESTARTS AND BiCGSTAB ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))

END SUBROUTINE LinearSolver_BiCGSTAB_LP


SUBROUTINE LinearSolver_BiCGSTABl(t,Coeff,relTolerance,Norm_R0_in)
!===================================================================================================================================
! Solves Linear system Ax=b using BiCGStab(l) with right preconditioner P_r
! Matrix A = I - Coeff*R
! Attention: Vector x is U^n+1, initial guess set to U^n 
! Attention: Vector b is U^n 
! Sleijpen 1993: BiCGSTAB(l) for linear equations involving unsymmetric matrices with complex spectrum
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals
USE MOD_DG_Vars,              ONLY:U
USE MOD_LinearSolver_Vars,    ONLY:eps_LinearSolver,maxIter_LinearSolver,totalIterLinearSolver,nInnerIter
USE MOD_LinearSolver_Vars,    ONLY:ImplicitSource,nRestarts,ldim
USE MOD_LinearOperator,       ONLY:MatrixVector, MatrixVectorSource, VectorDotProduct
USE MOD_ApplyPreconditioner,  ONLY:Preconditioner
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)          :: t,Coeff
REAL,INTENT(IN),OPTIONAL :: relTolerance
REAL,INTENT(IN),OPTIONAL :: Norm_R0_in
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                     :: Un(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: deltaX(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: P(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,0:ldim)
REAL                     :: R(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems,0:ldim)
REAL                     :: R0(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: sigma(0:ldim),tau(1:ldim,1:ldim)
REAL                     :: phi(0:ldim),phis(0:ldim),phiss(0:ldim)
INTEGER                  :: iterLinSolver,Restart
INTEGER                  :: m,nn
REAL                     :: alpha,omega,beta
REAL                     :: Norm_R, Norm_R0, Norm_Abort
REAL                     :: AbortCrit
! preconditioner
REAL                     :: Pt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
REAL                     :: Rt(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!===================================================================================================================================

! U^n+1 = U^n + dt * DG_Operator U^n+1 + Sources^n+1
! (I - dt*DG_Operator) U^n+1 = U^n + dt*Sources^n+1
!       A                x   = b
! 
! Residuum
! for initial guess, x0 is set to U^n
! R0 = b - A x0
!    = U^n + dt*Sources^n+1 -( I - dt*DG_Operator ) U^n
!    = dt*Source^n+1  + dt*DG_Operator U^n 
!    = dt*Ut + dt*Source^n+1

! store here for later use
Un   = U ! here, n stands for U^n
Restart=0
nInnerIter = 0
deltaX=0.0d0
! LinSolverRHS and X0 = U
CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output

! compute  A*U^n
IF(PRESENT(Norm_R0_in))THEN
  Norm_R0=Norm_R0_in
ELSE
  CALL VectorDotProduct(R0,R0,Norm_R0)
  Norm_R0=SQRT(Norm_R0)
END IF
! absolute tolerance check, if initial solution already matches old solution or 
! RHS is zero. Maybe it is here better to use relTolerance?
IF(Norm_R0.LT.1e-14) RETURN

IF(PRESENT(relTolerance))THEN
  AbortCrit = Norm_R0*relTolerance
ELSE
  AbortCrit = Norm_R0*eps_LinearSolver
END IF
! starting direction accoring to old paper
P(:,:,:,:,:,0) = 0.
R(:,:,:,:,:,0) = R0
Norm_R0=1.0d0
alpha=0.0d0
omega=1.0d0


DO WHILE(Restart.LT.nRestarts)
  DO iterLinSolver=1,maxIter_LinearSolver
    Norm_R0= - omega* Norm_R0
    ! Bi-CG Part
    DO nn=0, ldim-1
      CALL VectorDotProduct(R(:,:,:,:,:,nn),R0,Norm_R)
      beta=alpha*Norm_R/Norm_R0
      Norm_R0=Norm_R
      DO m=0,nn
        P(:,:,:,:,:,m) = R(:,:,:,:,:,m) - beta * P(:,:,:,:,:,m)
      END DO ! m
      ! Preconditioner
      CALL Preconditioner(P(:,:,:,:,:,nn),Pt)
      ! matrix vector
      CALL MatrixVector(t,coeff,Pt,P(:,:,:,:,:,nn+1))
      CALL VectorDotProduct(P(:,:,:,:,:,nn+1),R0,phi(nn))
      alpha=Norm_R0/phi(nn)
      DO m=0,nn
        R(:,:,:,:,:,m) = R(:,:,:,:,:,m) - alpha * P(:,:,:,:,:,m+1)
      END DO ! m
      ! Preconditioner
      CALL Preconditioner(R(:,:,:,:,:,nn),Rt)
      ! matrix vector
      CALL MatrixVector(t,coeff,Rt,R(:,:,:,:,:,nn+1))
      deltaX=deltaX+alpha*P(:,:,:,:,:,0)
    END DO ! nn
    ! mod. G.-S.
    DO nn=1, ldim
      DO m=1,nn-1
        CALL VectorDotProduct(R(:,:,:,:,:,nn),R(:,:,:,:,:,m),tau(m,nn))
        tau(m,nn) = 1.0d0/sigma(m) * tau(m,nn)
        R(:,:,:,:,:,nn) = R(:,:,:,:,:,nn) - tau(m,nn) * R(:,:,:,:,:,m)
      END DO ! m
      CALL VectorDotProduct(R(:,:,:,:,:,nn),R(:,:,:,:,:,nn),sigma(nn))
      CALL VectorDotProduct(R(:,:,:,:,:,nn),R(:,:,:,:,:,0),phis(nn))
      phis(nn) = phis(nn)/sigma(nn)
    END DO ! nn
    phi(ldim) = phis(ldim)
    omega=phi(ldim)
    DO nn=ldim-1,1,-1
      phi(nn) = phis(nn)
      DO m=nn+1,ldim
        phi(nn) = phi(nn)-tau(nn,m)*phi(m)
      END DO ! m
    END DO ! nn
    DO nn=1,ldim-1
      phiss(nn) = phi(nn+1)
      DO m=nn+1,ldim-1
        phiss(nn)=phiss(nn) + tau(nn,m)*phi(m+1)
      END DO ! m
    END DO !  nn
    ! update
    deltaX = deltaX+phi(1)*R(:,:,:,:,:,0)
    R(:,:,:,:,:,0) = R(:,:,:,:,:,0) - phis(ldim)*R(:,:,:,:,:,ldim)
    P(:,:,:,:,:,0) = P(:,:,:,:,:,0) - phi (ldim)*P(:,:,:,:,:,ldim)
    DO nn=1,ldim-1
      P(:,:,:,:,:,0) = P(:,:,:,:,:,0) - phi (nn)*P(:,:,:,:,:,nn)
      deltaX = deltaX+phiss(nn)*R(:,:,:,:,:,nn)
      R(:,:,:,:,:,0) = R(:,:,:,:,:,0) - phis(nn)*R(:,:,:,:,:,nn)
    END DO ! nn
    CALL VectorDotProduct(R(:,:,:,:,:,0),R(:,:,:,:,:,0),Norm_Abort)
    Norm_Abort=SQRT(Norm_Abort)
    IF((Norm_Abort.LE.AbortCrit).OR.(Norm_Abort.LT.1.E-12)) THEN
      ! invert preconditioner
      CALL Preconditioner(deltaX,U)
      U=U+Un
      nInnerIter=nInnerIter+iterLinSolver*ldim
      totalIterLinearSolver=totalIterLinearSolver+nInnerIter
      !SWRITE(UNIT_stdOut,'(A22,I5)')      ' Iter LinSolver     : ',nInnerIter
      !SWRITE(UNIT_stdOut,'(A22,I5)')      ' Restarts           : ',Restart
      RETURN
    END IF
  END DO ! iterLinearSolver
  ! restart with new U
  ! LinSolverRHS and X0 = U
!  U              = 0.5*(Uold+Un)
  CALL Preconditioner(deltaX,U)
  U=U+Un
  ImplicitSource = 0.
  ! LinSolverRHS and X0 = U
  CALL MatrixVectorSource(t,Coeff,R0) ! coeff*Ut+Source^n+1 ! only output

  ! starting direction accoring to old paper
  P(:,:,:,:,:,0) = 0.
  R(:,:,:,:,:,0) = R0
  Norm_R0=1.
  alpha=0.
  omega=1.
  nInnerIter=nInnerIter+iterLinSolver*ldim
  Restart = Restart + 1
END DO ! while chance < 2 

SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R0            : ',Norm_R0
SWRITE(UNIT_stdOut,'(A22,E16.8)')   ' Norm_R             : ',Norm_R
IF(MPIRoot) CALL abort(&
__STAMP__ &
,'BiCGSTAB(l) NOT CONVERGED WITH RESTARTS AND BiCGSTAB ITERATIONS:',Restart,REAL(nInnerIter+iterLinSolver))

END SUBROUTINE LinearSolver_BiCGSTABl
#endif /*NOT HDG*/

SUBROUTINE FinalizeLinearSolver()
!===================================================================================================================================
! Deallocate global variable U (solution) and Ut (dg time derivative).
!===================================================================================================================================
! MODULES
USE MOD_LinearSolver_Vars,ONLY:LinearSolverInitIsDone,ImplicitSource,LinSolverRHS
#if (PP_TimeDiscMethod==120) || (PP_TimeDiscMethod==121) || (PP_TimeDiscMethod==122) 
#ifdef PARTICLES
USE MOD_ParticleSolver,       ONLY:FinalizePartSolver
USE MOD_LinearSolver_Vars,ONLY:ExplicitPartSource
#endif /*PARTICLES*/
#endif
USE MOD_Predictor    ,ONLY:FinalizePredictor
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
!===================================================================================================================================

LinearSolverInitIsDone = .FALSE.
SDEALLOCATE(ImplicitSource)
SDEALLOCATE(LinSolverRHS)
CALL FinalizePredictor
#if (PP_TimeDiscMethod==120) || (PP_TimeDiscMethod==121) || (PP_TimeDiscMethod==122) 
#ifdef PARTICLES
SDEALLOCATE(ExplicitPartSource)
CALL FinalizePartSolver()
#endif /*PARTICLES*/
#endif
!SDEALLOCATE(FieldSource)
END SUBROUTINE FinalizeLinearSolver

END MODULE MOD_LinearSolver
