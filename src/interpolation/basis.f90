#include "boltzplatz.h"

MODULE MOD_Basis
!===================================================================================================================================
! Add comments please!
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
SAVE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part
! ----------------------------------------------------------------------------------------------------------------------------------
! Public Part
! ----------------------------------------------------------------------------------------------------------------------------------
INTERFACE INV
   MODULE PROCEDURE INV
END INTERFACE

INTERFACE BuildLegendreVdm
   MODULE PROCEDURE BuildLegendreVdm
END INTERFACE

!#ifdef PARTICLES
INTERFACE BuildBezierVdm
   MODULE PROCEDURE BuildBezierVdm
END INTERFACE

INTERFACE BuildBezierDMat
   MODULE PROCEDURE BuildBezierDMat
END INTERFACE

INTERFACE DeCasteljauInterpolation
   MODULE PROCEDURE DeCasteljauInterpolation
END INTERFACE

INTERFACE BernSteinPolynomial
   MODULE PROCEDURE BernSteinPolynomial
END INTERFACE

INTERFACE ComputeBernSteinCoeff
   MODULE PROCEDURE ComputeBernSteinCoeff
END INTERFACE
!#endif /*PARTICLES*/

INTERFACE InitializeVandermonde
   MODULE PROCEDURE InitializeVandermonde
END INTERFACE

INTERFACE ChebyshevGaussNodesAndWeights
   MODULE PROCEDURE ChebyshevGaussNodesAndWeights
END INTERFACE

INTERFACE ChebyGaussLobNodesAndWeights
   MODULE PROCEDURE ChebyGaussLobNodesAndWeights
END INTERFACE

INTERFACE LegendreGaussNodesAndWeights
   MODULE PROCEDURE LegendreGaussNodesAndWeights
END INTERFACE

INTERFACE LegGaussLobNodesAndWeights
   MODULE PROCEDURE LegGaussLobNodesAndWeights
END INTERFACE

INTERFACE PolynomialDerivativeMatrix
   MODULE PROCEDURE PolynomialDerivativeMatrix
END INTERFACE

INTERFACE BarycentricWeights 
   MODULE PROCEDURE BarycentricWeights
END INTERFACE

INTERFACE LagrangeInterpolationPolys
   MODULE PROCEDURE LagrangeInterpolationPolys
END INTERFACE

INTERFACE GetInverse
   MODULE PROCEDURE GetInverse
END INTERFACE

PUBLIC::INV
PUBLIC::BuildLegendreVdm
!#ifdef PARTICLES
PUBLIC::BuildBezierVdm
PUBLIC::BuildBezierDMat
PUBLIC::DeCasteljauInterpolation
PUBLIC::BernSteinPolynomial
PUBLIC::ComputeBernSteinCoeff
!#endif /*PARTICLES*/
PUBLIC::InitializeVandermonde
PUBLIC::LegGaussLobNodesAndWeights
PUBLIC::LegendreGaussNodesAndWeights
PUBLIC::ChebyshevGaussNodesAndWeights
PUBLIC::ChebyGaussLobNodesAndWeights
PUBLIC::PolynomialDerivativeMatrix
PUBLIC::BarycentricWeights
PUBLIC::LagrangeInterpolationPolys
PUBLIC::GetInverse


!===================================================================================================================================


CONTAINS

FUNCTION INV(A) RESULT(AINV)
!===================================================================================================================================
! Computes matrix inverse using lapack
!===================================================================================================================================
! MODULES
USE MOD_Globals
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)  :: A(:,:)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL             :: AINV(SIZE(A,1),SIZE(A,2))
!-----------------------------------------------------------------------------------------------------------------------------------
! External procedures defined in LAPACK
EXTERNAL DGETRF
EXTERNAL DGETRI
! LOCAL VARIABLES 
REAL    :: work(SIZE(A,1))  ! work array for lapack
INTEGER :: ipiv(SIZE(A,1))  ! pivot indices
INTEGER :: n,info
!===================================================================================================================================
! Store A in Ainv to prevent it from being overwritten by LAPACK
Ainv = A
n = size(A,1)

! DGETRF computes an LU factorization of a general M-by-N matrix A
! using partial pivoting with row interchanges.
CALL DGETRF(n, n, Ainv, n, ipiv, info)

IF(info.NE.0)THEN
    CALL abort(&
    __STAMP__&
    ,' Matrix is numerically singular!')
END IF

! DGETRI computes the inverse of a matrix using the LU factorization
! computed by DGETRF.
CALL DGETRI(n, Ainv, n, ipiv, work, n, info)

IF(info.NE.0)THEN
    CALL abort(&
    __STAMP__&
    ,' Matrix inversion failed!')
END IF
END FUNCTION INV

!#ifdef PARTICLES
SUBROUTINE ComputeBernSteinCoeff(N_In,NChooseK)
!===================================================================================================================================
! required for deposition
! build a 1D Vandermonde matrix using the Bezier basis functions of degree N_In
! todo: replace numerical recipes function gaussj() for calculation the inverse of V 
! by a BLAS routine for better matrix conditioning
!===================================================================================================================================
! MODULES
!USE nr,                        ONLY : gaussj
USE MOD_PreProc
USE MOD_Globals,                ONLY:abort
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In
!REAL,INTENT(IN)    :: xi_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)    :: NchooseK(0:N_In,0:N_In) 
!REAL,INTENT(OUT)   :: Vdm_Bezier(0:N_In,0:N_In),sVdm_Bezier(0:N_In,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: i,j!,errorflag
!REAL               :: Vector(3)
!REAL               :: Matrix(0:N_In,0:N_In)
!===================================================================================================================================
! store the coefficients
!ALLOCATE(NchooseK(0:N_In,0:N_In))
NchooseK(:,:) = 0.

!Vandermonde on xi_In
DO i=0,N_In
  DO j=0,N_In
!    CALL BernsteinPolynomial(N_In,j,xi_in(i),Vdm_BernSteinN_GaussN(i,j)) 
    ! array with binomial coeffs for bezier clipping
    IF(i.GE.j)THEN!only calculate LU (for n >= k, else 0)
      NchooseK(i,j)=REAL(CHOOSE(i,j))
    ELSE
      NchooseK(i,j)=0.
    END IF
  END DO !i
END DO !j

END SUBROUTINE ComputeBernSteinCoeff


SUBROUTINE BuildBezierVdm(N_In,xi_In,Vdm_Bezier,sVdm_Bezier)
!===================================================================================================================================
! build a 1D Vandermonde matrix using the Bezier basis functions of degree N_In
! todo: replace numerical recipes function gaussj() for calculation the inverse of V 
! by a BLAS routine for better matrix conditioning
!===================================================================================================================================
! MODULES
!USE nr,                        ONLY : gaussj
USE MOD_Globals,                ONLY: abort
USE MOD_PreProc
USE MOD_Particle_Surfaces_Vars, ONLY: arrayNchooseK,FacNchooseK,BezierElevation,ElevationMatrix
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In
REAL,INTENT(IN)    :: xi_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: Vdm_Bezier(0:N_In,0:N_In),sVdm_Bezier(0:N_In,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: i,j, errorflag,IPIV(1:N_in+1),jStart,jEnd
REAL               :: dummy,eps 
REAL               :: dummy_vec(0:N_In)
!===================================================================================================================================
! set NPartCurved to N_In (NGeo)
!IF(NPartCurved.NE.N_In)THEN
!  print*,"NPartCurved is not equal NGeo: Setting NPartCurved=NGeo=",N_In
!  !NPartCurved = N_In !CHANGETAG creates problems with supersampled intersection calculation
!END IF
! store the coefficients
ALLOCATE(arrayNchooseK(0:N_In,0:N_In))
ALLOCATE(FacNchooseK(0:N_In,0:N_In))
FacNchooseK(:,:) = 0.

ALLOCATE(ElevationMatrix(0:N_In+BezierElevation,0:N_In))
ElevationMatrix(:,:) = 0.


!Vandermonde on xi_In
DO i=0,N_In
  DO j=0,N_In
    ! 1.) evaluate the berstein polynomial at xi_in -> build vandermonde
    CALL BernsteinPolynomial(N_In,j,xi_in(i),Vdm_Bezier(i,j)) 
    ! 2.) build array with binomial coeffs for bezier clipping
    IF(i.GE.j)THEN!only calculate LU (for n >= k, else 0)
      arrayNchooseK(i,j)=REAL(CHOOSE(i,j))
      FacNchooseK(i,j) = (1.0/(2.0**REAL(i)))*ArrayNchooseK(i,j)
    ELSE
      arrayNchooseK(i,j)=0.
    END IF
  END DO !i
END DO !j

! 3.) build array with binomial coeffs (fractions) for elevation
IF(N_In+BezierElevation.GE.171) CALL Abort(__STAMP__,&
  'Bezier elevation to polynomial degrees greater/equal 171 is forbiddon! exit.',171,REAL(N_In+BezierElevation))
ElevationMatrix(0,0) = 1.
ElevationMatrix(N_In+BezierElevation,N_In) = 1.
!print*,"BezierElevation",N_In,'+',BezierElevation
!print*,0," eps= ",0.
DO i=1,N_In+BezierElevation-1 ! from 0+1 to p_new-1 -> remove the edge points
  jStart = MAX(0,i-BezierElevation)
  jEnd   = MIN(N_In,i)
  DO j=jStart,jEnd 
    !ElevationMatrix(i,j)=REAL(CHOOSE(N_In,j))*REAL(CHOOSE(BezierElevation,i-j)) / REAL(CHOOSE(N_In+BezierElevation,i))
    ElevationMatrix(i,j)=CHOOSE_large(N_In,j)*CHOOSE_large(BezierElevation,i-j) / CHOOSE_large(N_In+BezierElevation,i)
  END DO
  eps=ABS(SUM(ElevationMatrix(i,:))-1.0)
  !print*,i," eps= ",eps
  !print*,"------- next ------"
  IF(eps>1e-12) CALL Abort(&
    __STAMP__,&
    'The line of the elevation matrix does not sum to unity! 1-1=',0,eps)
END DO
!print*,N_In+BezierElevation," eps= ",0.
!STOP
! debug
 !print*,"BezierElevation",N_In,'+',BezierElevation
 !DO i=0,N_In+BezierElevation
  !write(*,"(I8,10F10.4)") i,ElevationMatrix(i,:)
  !write(*,"(I3)", ADVANCE = "NO")    i
  !write(*,"(12F10.4)", ADVANCE = "NO") ElevationMatrix(i,:)
  !write(*,"(F13.4)")                  SUM(ElevationMatrix(i,:))
 !END DO
 !STOP

!print*,arrayNchooseK !CHANGETAG
!Inverse of the Vandermonde
dummy_vec=0.
!print*,dummy_vec
!print*,SIZE(sVdm_Bezier),SIZE(dummy_vec)
!print*,"CALL gaussj(sVdm_Bezier,dummy_vec)"
!CALL gaussj(sVdm_Bezier,dummy_vec)
!CALL gaussj(Matrix,Vector)

!DO i=0,N_In
  !print*,Vdm_Bezier(i,:)
!END DO
! Invert A: Caution!!! From now on A=A^(-1) 
sVdm_Bezier=Vdm_Bezier
CALL DGETRF(N_In+1,N_In+1,sVdm_Bezier,N_In+1,IPIV,errorflag)
IF (errorflag .NE. 0) CALL Abort(__STAMP__, &
               'LU factorisation of matrix crashed',999,999.)
CALL DGETRI(N_In+1,sVdm_Bezier,N_In+1,IPIV,dummy_vec,N_In+1,errorflag)
IF (errorflag .NE. 0) CALL Abort(__STAMP__, &
               'Solver crashed',999,999.)
!print*,"Matrix inverted"
!DO i=0,N_In
  !print*,sVdm_Bezier(i,:)
!END DO
!Matrix=MATMUL(sVdm_Bezier,Vdm_Bezier)
!print*,"A^-1*A"
!DO i=0,N_In
  !print*,Matrix(i,:)
!END DO
!print*,"(ABS(MATMUL(sVdm_Bezier,Vdm_Bezier))"
!print*,ABS(MATMUL(sVdm_Bezier,Vdm_Bezier))
!print*,"SUM: (ABS(MATMUL(sVdm_Bezier,Vdm_Bezier))"
!print*,SUM(ABS(MATMUL(sVdm_Bezier,Vdm_Bezier)))
!print*,"(N_In+1)"
!print*,(N_In+1)
!check (Vdm_Bezier)^(-1)*Vdm_Bezier := I 
dummy=SUM(ABS(MATMUL(sVdm_Bezier,Vdm_Bezier)))-REAL(N_In+1)
!print*,dummy,PP_RealTolerance
!read*
IF(ABS(dummy).GT.1.E-13) CALL abort(__STAMP__,&
'problems in Bezier Vandermonde: check (Vdm_Bezier)^(-1)*Vdm_Bezier := I has a value of',999,dummy)
END SUBROUTINE BuildBezierVdm


SUBROUTINE BuildBezierDMat(N_In,xi_In,DMat)
!===================================================================================================================================
! build a 1D D matrix using the Bezier basis functions of degree N_In
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Particle_Surfaces_Vars, ONLY: FacNchooseK
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In
REAL,INTENT(IN)    :: xi_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: DMat(0:N_In,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: i,j
REAL               :: XiPlus,XiMinus
!REAL               :: rtmp1,rtmp2
!===================================================================================================================================

DMat=0.
! for j=0
! (n over 0) (t+1)^0 (1-t)^n
DO i=0,N_in
  DMat(i,0) = -facNchooseK(N_in,0)*REAL(N_in)*(1-Xi_In(i))**(N_in-1)
END DO ! i=0,N_in
! for j=N_in
DO i=0,N_in
  DMat(i,N_in) = facNchooseK(N_in,N_in)*REAL(N_in)*(Xi_In(i)+1)**(N_in-1)
END DO ! i=0,N_in

! all inner values
DO j=1,N_in-1
  DO i=0,N_in
    XiPlus  =Xi_In(i)+1.0
    XiMinus =1.0-Xi_In(i)
    DMat(i,j) =facNchooseK(N_In,j)*(REAL(j)  *(XiPlus**(j-1))*XiMinus**(N_in-j)   &
                                   -REAL(N_in-j)*(XiPlus**j    )*XiMinus**(N_in-j-1) )
  END DO ! i=0,N_in
END DO ! j=0,N_in

! via diff, compare wiki, farin, etc
! caution, a 1/2 is missing in facNchooseK .oO
! DMat=0.
! DO j=0,N_in
!   DO i=0,N_in
!     XiPlus  =Xi_In(i)+1.0
!     XiMinus =1.0-Xi_In(i)
!     IF((j-1).EQ.-1)THEN
!       rTmp1=0.
!     ELSE
!       rTmp1=0.5*facNchooseK(N_in-1,j-1)*XiPlus**(j-1)*XiMinus**(N_in-j)
!     END IF
!     IF((j).EQ.N_In)THEN
!       rTmp2=0.
!     ELSE
!       rTmp2=0.5*facNchooseK(N_in-1,j)*XiPlus**(j)*XiMinus**(N_in-1-j)
!     END IF
!     DMat(i,j) = N_in*(rtmp1-rtmp2)
!   END DO ! i=0,N_in
! END DO ! j=0,N_in

END SUBROUTINE BuildBezierDmat


SUBROUTINE DeCasteljauInterpolation(N_In,xi_In,SideID,xPoint)
!===================================================================================================================================
! Computes a point in a Bezier-Surface by using the DeCasteljau alogrithm
!===================================================================================================================================
! MODULES
!USE nr,                        ONLY : gaussj
USE MOD_Globals,                ONLY: abort
USE MOD_PreProc
USE MOD_Particle_Surfaces_Vars,  ONLY:BezierControlPoints3D
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN)                 :: N_In
INTEGER,INTENT(IN)                 :: SideID
REAL,INTENT(IN)                    :: xi_In(1:2)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                   :: xPoint(1:3)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
REAL,DIMENSION(3,0:N_In,0:N_In)    :: ReducedBezierControlPoints
REAL                               :: MinusXi,Xi,MinusEta,Eta
INTEGER                            :: l,p,q,iDeCasteljau
!===================================================================================================================================


Xi=0.5*(Xi_In(1)+1.)
Eta=0.5*(Xi_in(2)+1.)
MinusXi =1.0-Xi
MinusEta=1.0-Eta

ReducedBezierControlPoints=BezierControlPoints3D(:,:,:,SideID)
l=N_In-1
DO iDeCasteljau=1,N_In
  DO q=0,l
    DO p=0,l
      ReducedBezierControlPoints(:,p,q)=MinusXi*ReducedBezierControlPoints(:,p,q  )  *MinusEta & ! A
                                       +MinusXi*ReducedBezierControlPoints(:,p,q+1)  *Eta      & ! B
                                       +     Xi*ReducedBezierControlPoints(:,p+1,q)  *MinusEta & ! C
                                       +     Xi*ReducedBezierControlPoints(:,p+1,q+1)*Eta        ! D

    END DO
  END DO
  l=l-1
END DO
xPoint=ReducedBezierControlPoints(:,0,0)

END SUBROUTINE DeCasteljauInterpolation


SUBROUTINE BernsteinPolynomial(N_in,j,x,B,NChooseK)
!===================================================================================================================================
!
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)      :: N_in,j ! polynomial degree, (N+1) points and j-th Bernstein polynomial is selected
REAL,INTENT(IN),OPTIONAl:: NChooseK(0:N_in,0:N_in)
REAL,INTENT(IN)         :: x      ! coordinate value in the interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)        :: B      ! B_N(xi)
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
!INTEGER             :: iLegendre
!REAL                :: L_Nm1,L_Nm2 ! L_{N_in-2},L_{N_in-1}
!REAL                :: Lder_Nm1,Lder_Nm2 ! Lder_{N_in-2},Lder_{N_in-1}
!===================================================================================================================================
IF(PRESENT(NChooseK))THEN
  B = (1./(2**N_in))*NCHOOSEK(N_in,j)*((x+1.)**j)*((1.-x)**(N_in-j))
ELSE
  B = (1./(2**N_in))*REAL(CHOOSE(N_in,j))*((x+1.)**j)*((1.-x)**(N_in-j))
END IF

END SUBROUTINE BernsteinPolynomial
!#endif /*PARTICLES*/


FUNCTION GetInverse(dim1,A) RESULT(Ainv)
!============================================================================================================================
! invert a matrix (dependant in LAPACK Routines) 
!============================================================================================================================
! MODULES
USE MOD_Globals
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER, INTENT(IN) :: dim1   !size of matrix a
REAL,INTENT(IN)     :: A(dim1,dim1)
!----------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL                :: Ainv(dim1,dim1)
!----------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: IPIV(dim1),INFO,lwork,i,j
REAL               :: WORK(dim1*dim1) 
!============================================================================================================================
! Store A in Ainv to prevent it from being overwritten by LAPACK
  DO j=1,dim1
    DO i=1,dim1
      Ainv(i,j) = A(i,j)
    END DO
  END DO

  ! DGETRF computes an LU factorization of a general M-by-N matrix A
  ! using partial pivoting with row interchanges.
  CALL DGETRF(dim1, dim1, Ainv, dim1, IPIV, INFO)

  IF (INFO /= 0) THEN
    CALL abort(&
    __STAMP__&
    ,' Matrix is numerically singular!')
  END IF

  ! DGETRI computes the inverse of a matrix using the LU factorization
  ! computed by DGETRF.
  lwork=dim1*dim1
  CALL DGETRI(dim1, Ainv, dim1, IPIV, WORK, lwork , INFO)

  IF (INFO /= 0) THEN
    CALL abort(&
    __STAMP__&
    ,' Matrix inversion failed!')
  END IF
END FUNCTION GetInverse


SUBROUTINE buildLegendreVdm(N_In,xi_In,Vdm_Leg,sVdm_Leg)
!===================================================================================================================================
! build a 1D Vandermonde matrix using the lagrange basis functions of degree
! N_In, evaluated at the interpolation points xi_Out
!===================================================================================================================================
! MODULES
USE MOD_Globals,ONLY:abort
USE MOD_PreProc
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In
REAL,INTENT(IN)    :: xi_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: Vdm_Leg(0:N_In,0:N_In),sVdm_Leg(0:N_In,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: i,j
REAL               :: dummy 
REAL               :: wBary_Loc(0:N_In)
REAL               :: xGauss(0:N_In),wGauss(0:N_In)
!===================================================================================================================================
CALL BarycentricWeights(N_In,xi_in,wBary_loc) 
! Compute first the inverse (by projection)
CALL LegendreGaussNodesAndWeights(N_In,xGauss,wGauss) ! create Gauss points xGP and weights
!Vandermonde on xGauss
DO i=0,N_In
  DO j=0,N_In
    CALL LegendrePolynomialAndDerivative(j,xGauss(i),Vdm_Leg(i,j),dummy) 
  END DO !i
END DO !j
Vdm_Leg=TRANSPOSE(Vdm_Leg)
DO j=0,N_In
  Vdm_Leg(:,j)=Vdm_Leg(:,j)*wGauss(j)
END DO
!evaluate nodal basis (depends on NodeType, for Gauss: unity matrix)
CALL InitializeVandermonde(N_In,N_In,wBary_Loc,xi_In,xGauss,sVdm_Leg)
sVdm_Leg=MATMUL(Vdm_Leg,sVdm_Leg)
!compute the Vandermonde on xGP (Depends on NodeType)
DO i=0,N_In
  DO j=0,N_In
    CALL LegendrePolynomialAndDerivative(j,xi_In(i),Vdm_Leg(i,j),dummy) 
  END DO !i
END DO !j
!check (Vdm_Leg)^(-1)*Vdm_Leg := I 
dummy=SUM((ABS(MATMUL(sVdm_Leg,Vdm_Leg)))-(N_In+1))
IF(dummy.GT. PP_RealTolerance) CALL abort(__STAMP__,&
                                          'problems in MODAL<->NODAL Vandermonde ',999,dummy)

END SUBROUTINE buildLegendreVdm


SUBROUTINE InitializeVandermonde(N_In,N_Out,wBary_In,xi_In,xi_Out,Vdm)
!===================================================================================================================================
! build a 1D Vandermonde matrix using the lagrange basis functions of degree
! N_In, evaluated at the interpolation points xi_Out
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN) :: N_In,N_Out
REAL,INTENT(IN)    :: xi_In(0:N_In)
REAL,INTENT(IN)    :: xi_Out(0:N_Out)
REAL,INTENT(IN)    :: wBary_In(0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)   :: Vdm(0:N_Out,0:N_In)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER            :: iXi
!===================================================================================================================================
DO iXi=0,N_Out
  CALL LagrangeInterpolationPolys(xi_Out(iXi),N_In,xi_In,wBary_In,Vdm(iXi,:)) !l(0:N_In)
END DO
END SUBROUTINE InitializeVandermonde



SUBROUTINE LegendrePolynomialAndDerivative(N_in,x,L,Lder)
!===================================================================================================================================
! algorithm 22, Kopriva
! evaluate the Legendre polynomial L_N and its derivative at position x[-1,1] 
! recursive algorithm using the N_in-1 N_in-2 Legendre polynomials
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in     ! polynomial degree, (N+1) CLpoints 
REAL,INTENT(IN)    :: x      ! coordinate value in the interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)    :: L,Lder  ! L_N(xi), d/dxi L_N(xi)
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER :: iLegendre
REAL    :: L_Nm1,L_Nm2 ! L_{N_in-2},L_{N_in-1}
REAL    :: Lder_Nm1,Lder_Nm2 ! Lder_{N_in-2},Lder_{N_in-1}
!===================================================================================================================================
L = 0.
Lder = 0.
IF(N_in .EQ. 0)THEN
  L=1.
  Lder=0.
ELSEIF(N_in .EQ. 1) THEN
  L=x
  Lder=1.
ELSE ! N_in > 1
  L_Nm2=1.
  L_Nm1=x
  Lder_Nm2=0.
  Lder_Nm1=1.
  DO iLegendre=2,N_in
    L=(REAL(2*iLegendre-1)*x*L_Nm1 - REAL(iLegendre-1)*L_Nm2)/REAL(iLegendre)
    Lder=Lder_Nm2 + REAL(2*iLegendre-1)*L_Nm1
    L_Nm2=L_Nm1
    L_Nm1=L
    Lder_Nm2=Lder_Nm1
    Lder_Nm1=Lder
  END DO !iLegendre=2,N_in
END IF ! N_in
!normalize
L=L*SQRT(REAL(N_in)+0.5)
Lder=Lder*SQRT(REAL(N_in)+0.5)
END SUBROUTINE LegendrePolynomialAndDerivative


SUBROUTINE ChebyshevGaussNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 27, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in       ! polynomial degree, (N_in+1) CLpoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)  ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)  ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP
!===================================================================================================================================
DO iGP=0,N_in
  xGP(iGP)=-cos((2*iGP+1)/(2*REAL(N_in)+2)*ACOS(-1.))
END DO
IF(PRESENT(wGP))THEN
  DO iGP=0,N_in
    wGP(iGP)=ACOS(-1.)/REAL(N_in+1)
  END DO
END IF
END SUBROUTINE ChebyshevGaussNodesAndWeights



SUBROUTINE ChebyGaussLobNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 27, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in       ! polynomial degree, (N_in+1) CLpoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)  ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)  ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP
!===================================================================================================================================
DO iGP=0,N_in
  xGP(iGP)=-COS(iGP/REAL(N_in)*ACOS(-1.))
END DO
IF(PRESENT(wGP))THEN
  DO iGP=0,N_in
    wGP(iGP)=ACOS(-1.)/REAL(N_in)
  END DO
  wGP(0)=wGP(0)*0.5
  wGP(N_in)=wGP(N_in)*0.5
END IF
END SUBROUTINE ChebyGaussLobNodesAndWeights



SUBROUTINE LegendreGaussNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 23, Kopriva
! starting with Chebychev point positions, a Newton method is used to find the roots 
! of the Legendre Polynomial L_(N_in+1), which are the positions of Gausspoints
! uses LegendrePolynomialAndDerivative subroutine
!===================================================================================================================================
!MODULES
USE MOD_Globals
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in              ! polynomial degree, (N_in+1) Gausspoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)       ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)       ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP,iter,nIter
REAL                      :: Tol            ! tolerance for Newton iteration
REAL                      :: L_Np1,Lder_Np1 ! L_{N_in+1},Lder_{N_in+1}
REAL                      :: dx             ! Newton step
REAL                      :: cheb_tmp       ! temporary variable for evaluation of chebychev node positions
!===================================================================================================================================
IF(N_in .EQ. 0) THEN
  xGP=0.
  IF(PRESENT(wGP))wGP=2.
  RETURN
ELSEIF(N_in.EQ.1)THEN
  xGP(0)=-sqrt(1./3.)
  xGP(N_in)=-xGP(0)
  IF(PRESENT(wGP))wGP=1.
  RETURN
ELSE ! N_in>1
  Tol=1.E-15
  nIter=10 
  cheb_tmp=2.*atan(1.)/REAL(N_in+1) ! pi/(2N+2)
  DO iGP=0,(N_in+1)/2-1 !since points are symmetric, only left side is computed
    xGP(iGP)=-cos(cheb_tmp*REAL(2*iGP+1)) !initial guess
    ! Newton iteration
    DO iter=0,nIter
      CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
      dx=-L_Np1/Lder_Np1
      xGP(iGP)=xGP(iGP)+dx
      IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
    END DO ! iter
    IF(iter.GT.nIter) THEN
      SWRITE(*,*) 'maximum iteration steps >10 in Newton iteration for Legendre Gausspoint'
      xGP(iGP)=-cos(cheb_tmp*REAL(2*iGP+1)) !initial guess
      ! Newton iteration
      DO iter=0,nIter
        !SWRITE(*,*)iter,xGP(iGP)    !DEBUG  
        CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
        dx=-L_Np1/Lder_Np1
        xGP(iGP)=xGP(iGP)+dx
        IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
      END DO !iter
      CALL abort(__STAMP__,&
                 'Code stopped!',999,999.)
    END IF ! (iter.GT.nIter)
    CALL LegendrePolynomialAndDerivative(N_in+1,xGP(iGP),L_Np1,Lder_Np1)
    xGP(N_in-iGP)=-xGP(iGP)
    IF(PRESENT(wGP))THEN
      !wGP(iGP)=2./((1.-xGP(iGP)*xGP(iGP))*Lder_Np1*Lder_Np1) !if Legendre not normalized
      wGP(iGP)=(2.*N_in+3)/((1.-xGP(iGP)*xGP(iGP))*Lder_Np1*Lder_Np1)
      wGP(N_in-iGP)=wGP(iGP)
    END IF
  END DO !iGP
END IF ! N_in
IF(mod(N_in,2) .EQ. 0) THEN
  xGP(N_in/2)=0.
  CALL LegendrePolynomialAndDerivative(N_in+1,xGP(N_in/2),L_Np1,Lder_Np1)
  !IF(PRESENT(wGP))wGP(N_in/2)=2./(Lder_Np1*Lder_Np1) !if Legendre not normalized
  IF(PRESENT(wGP))wGP(N_in/2)=(2.*N_in+3)/(Lder_Np1*Lder_Np1)
END IF ! (mod(N_in,2) .EQ. 0)
END SUBROUTINE LegendreGaussNodesAndWeights



SUBROUTINE qAndLEvaluation(N_in,x,q,qder,L)
!===================================================================================================================================
! algorithm 24, Kopriva
! evaluate the polynomial q=L_{N_in+1}-L_{N_in-1} and its derivative at position x[-1,1] 
! recursive algorithm using the N_in-1 N_in-2 Legendre polynomials
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in                               ! polynomial degree
REAL,INTENT(IN)    :: x                               ! coordinate value in the interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: L,q,qder                        ! L_N(xi), d/dxi L_N(xi)
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iLegendre
REAL               :: L_Nm1,L_Nm2                     ! L_{N_in-2},L_{N_in-1}
REAL               :: Lder,Lder_Nm1,Lder_Nm2          ! Lder_{N_in-2},Lder_{N_in-1}
!===================================================================================================================================
L_Nm2=1.
L_Nm1=x
Lder_Nm2=0.
Lder_Nm1=1.
DO iLegendre=2,N_in
  L=(REAL(2*iLegendre-1)*x*L_Nm1 - REAL(iLegendre-1)*L_Nm2)/REAL(iLegendre)
  Lder=Lder_Nm2 + REAL(2*iLegendre-1)*L_Nm1
  L_Nm2=L_Nm1
  L_Nm1=L
  Lder_Nm2=Lder_Nm1
  Lder_Nm1=Lder
END DO ! iLegendre
q=REAL(2*N_in+1)/REAL(N_in+1)*(x*L -L_Nm2) !L_{N_in+1}-L_{N_in-1} !L_Nm2 is L_Nm1, L_Nm1 was overwritten!
qder= REAL(2*N_in+1)*L             !Lder_{N_in+1}-Lder_{N_in-1} 
END SUBROUTINE qAndLEvaluation



SUBROUTINE LegGaussLobNodesAndWeights(N_in,xGP,wGP)
!===================================================================================================================================
! algorithm 25, Kopriva
! starting with initial guess by Parter Relation, a Newton method is used to find the roots 
! of the Legendre Polynomial Lder_(N_in), which are the positions of Gausspoints
! uses qAndLEvaluation subroutine
!===================================================================================================================================
! MODULES
USE MOD_Globals
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN)        :: N_in                ! polynomial degree (N_in+1) Gausspoints 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)          :: xGP(0:N_in)         ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(OUT),OPTIONAL :: wGP(0:N_in)         ! Gausspoint weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP,iter,nIter
REAL                      :: Tol              !tolerance for Newton iteration
REAL                      :: q,qder,L         !q=L_{N_in+1}-L_{N_in-1},qder is derivative, L=L_{N_in}
REAL                      :: dx               !Newton step
REAL                      :: pi,cont1,cont2   !temporary variable for evaluation of parter nodes positions
!===================================================================================================================================
xGP(0)=-1.
xGP(N_in)= 1.
L = 0.0
IF(PRESENT(wGP))THEN
  wGP(0)= 2./REAL(N_in*(N_in+1))
  wGP(N_in)=wGP(0)
END IF
IF(N_in.GT.1)THEN
  Tol=1.E-15
  nIter=10 
  pi=4.*atan(1.)
  cont1=pi/REAL(N_in) ! pi/N_in
  cont2=3./(REAL(8*N_in)*pi) ! 3/(8*N_in*pi)
  DO iGP=1,(N_in+1)/2-1 !since points are symmetric, only left side is computed
    xGP(iGP)=-cos(cont1*(REAL(iGP)+0.25)-cont2/(REAL(iGP)+0.25)) !initial guess
    ! Newton iteration
    DO iter=0,nIter
      CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
      dx=-q/qder
      xGP(iGP)=xGP(iGP)+dx
      IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
    END DO ! iter
    IF(iter.GT.nIter) THEN
      SWRITE(*,*) 'maximum iteration steps >10 in Newton iteration for LGL point:'
      xGP(iGP)=-cos(cont1*(REAL(iGP)+0.25)-cont2/(REAL(iGP)+0.25)) !initial guess
      ! Newton iteration
      DO iter=0,nIter
        SWRITE(*,*)'iter,x^i',iter,xGP(iGP)     !DEBUG 
        CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
        dx=-q/qder
        xGP(iGP)=xGP(iGP)+dx
        IF(abs(dx).LT.Tol*abs(xGP(iGP))) EXIT
      END DO ! iter
      CALL abort(__STAMP__,&
                 'Code stopped!',999,999.)
    END IF ! (iter.GT.nIter)
    CALL qAndLEvaluation(N_in,xGP(iGP),q,qder,L)
    xGP(N_in-iGP)=-xGP(iGP)
    IF(PRESENT(wGP))THEN
      wGP(iGP)=wGP(0)/(L*L)
      wGP(N_in-iGP)=wGP(iGP)
    END IF
  END DO ! iGP
END IF !(N_in.GT.1)
IF(mod(N_in,2) .EQ. 0) THEN
  xGP(N_in/2)=0.
  CALL qAndLEvaluation(N_in,xGP(N_in/2),q,qder,L)
  IF(PRESENT(wGP))wGP(N_in/2)=wGP(0)/(L*L)
END IF ! (mod(N_in,2) .EQ. 0)
END SUBROUTINE LegGaussLobNodesAndWeights



SUBROUTINE BarycentricWeights(N_in,xGP,wBary)
!===================================================================================================================================
! algorithm 30, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in               ! polynomial degree 
REAL,INTENT(IN)    :: xGP(0:N_in)        ! Gausspoint positions for the reference interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: wBary(0:N_in)      ! barycentric weights
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP,jGP
!===================================================================================================================================
wBary(:)=1.
DO iGP=1,N_in
  DO jGP=0,iGP-1
    wBary(jGP)=wBary(jGP)*(xGP(jGP)-xGP(iGP))
    wBary(iGP)=wBary(iGP)*(xGP(iGP)-xGP(jGP))
  END DO ! jGP
END DO ! iGP
wBary(:)=1./wBary(:)
END SUBROUTINE BarycentricWeights



SUBROUTINE PolynomialDerivativeMatrix(N_in,xGP,D)
!===================================================================================================================================
! algorithm 37, Kopriva
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in              ! polynomial degree
REAL,INTENT(IN)    :: xGP(0:N_in)       ! Gausspoint positions for the reference interval [-1,1]
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: D(0:N_in,0:N_in)     ! differentiation Matrix
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER            :: iGP,iLagrange
REAL               :: wBary(0:N_in) 
!===================================================================================================================================
CALL BarycentricWeights(N_in,xGP,wBary)
D(:,:)=0.
DO iLagrange=0,N_in
  DO iGP=0,N_in
    IF(iLagrange.NE.iGP)THEN
      D(iGP,iLagrange)=wBary(iLagrange)/(wBary(iGP)*(xGP(iGP)-xGP(iLagrange)))
      D(iGP,iGP)=D(iGP,iGP)-D(iGP,iLagrange)
    END IF ! (iLagrange.NE.iGP)
  END DO ! iGP
END DO ! iLagrange
END SUBROUTINE PolynomialDerivativeMatrix



FUNCTION ALMOSTEQUAL_UNITY(x,y)
!===================================================================================================================================
! Based on Algorithm 139, Kopriva
! Compares two real numbers
! Depends on PP_RealTolerance
! Takes into account that x,y is located in-between [-1;1]
!===================================================================================================================================
USE MOD_PreProc
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
REAL,INTENT(IN) :: x,y         ! 2 scalar real numbers
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
LOGICAL         :: AlmostEqual_UNITY ! TRUE if |x-y| < 2*PP_RealTolerance
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
!===================================================================================================================================
AlmostEqual_UNITY=.FALSE.
IF((x.EQ.0.).OR.(y.EQ.0.)) THEN
  IF(ABS(x-y).LE.2.*PP_RealTolerance) AlmostEqual_UNITY=.TRUE.
ELSE ! x, y not zero
  IF((ABS(x-y).LE.PP_RealTolerance*ABS(x)).AND.((ABS(x-y).LE.PP_RealTolerance*ABS(y)))) AlmostEqual_UNITY=.TRUE.
END IF ! x,y zero
END FUNCTION ALMOSTEQUAL_UNITY


FUNCTION CHOOSE(N_in,k)
!===================================================================================================================================
! The binomial coefficient ( n  k ) is often read as "n choose k".
!===================================================================================================================================
USE MOD_PreProc
!USE MOD_Mesh_Vars,                ONLY:NGeo
!USE MOD_Particle_Surfaces_Vars,   ONLY:BezierElevation
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in,k   
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
INTEGER(KIND=8)            :: CHOOSE
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
!===================================================================================================================================
IF((k.EQ.0).OR.(N_in.EQ.k))THEN
  CHOOSE = 1
ELSE
  !IF(NGeo+BezierElevation.GE.20)THEN
  IF(N_in.GE.21)THEN
    ! genauer
    !print*,"N_in.GE.21"
    !CHOOSE = INT(CHOOSELARGE(N_in,k),8)
    !PRINT*,CHOOSE
    ! weniger genau
    !CHOOSE = INT(FACTORIALLARGE(REAL(N_in)) / (FACTORIALLARGE(REAL(k)) * FACTORIALLARGE(REAL(N_in-k))),8)
    CHOOSE = INT(FACTORIAL_REAL(N_in) / (FACTORIAL_REAL(k) * FACTORIAL_REAL(N_in-k)))
  ELSE
    !print*,"else"
    CHOOSE = FACTORIAL(N_in) / (FACTORIAL(k) * FACTORIAL(N_in-k))
  END IF
END IF
!IF(CHOOSE.LT.0) CALL abort(__STAMP__,&
  !'CHOOSE is negative. This is not allowed! ',999,REAL(CHOOSE))
END FUNCTION CHOOSE


FUNCTION CHOOSE_large(N_in,k)
!===================================================================================================================================
! The binomial coefficient ( n  k ) is often read as "n choose k".
!===================================================================================================================================
USE MOD_PreProc
!USE MOD_Mesh_Vars,                ONLY:NGeo
!USE MOD_Particle_Surfaces_Vars,   ONLY:BezierElevation
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in,k   
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL(KIND=8)       :: CHOOSE_large
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
!===================================================================================================================================
IF((k.EQ.0).OR.(N_in.EQ.k))THEN
  CHOOSE_large = 1
ELSE
  !IF(NGeo+BezierElevation.GE.20)THEN
  IF(N_in.GE.21)THEN
    ! genauer
    !print*,"N_in.GE.21"
    !CHOOSE_large = INT(CHOOSE_largeLARGE(N_in,k),8)
    !PRINT*,CHOOSE_large
    ! weniger genau
    !CHOOSE_large = INT(FACTORIALLARGE(REAL(N_in)) / (FACTORIALLARGE(REAL(k)) * FACTORIALLARGE(REAL(N_in-k))),8)
    CHOOSE_large = FACTORIAL_REAL(N_in) / (FACTORIAL_REAL(k) * FACTORIAL_REAL(N_in-k))
  ELSE
    !print*,"else"
    CHOOSE_large = FACTORIAL(N_in) / (FACTORIAL(k) * FACTORIAL(N_in-k))
  END IF
END IF
!IF(CHOOSE_large.LT.0) CALL abort(__STAMP__,&
  !'CHOOSE_large is negative. This is not allowed! ',999,REAL(CHOOSE_large))
END FUNCTION CHOOSE_large   


FUNCTION FACTORIAL(N_in)
!===================================================================================================================================
! "In mathematics, the factorial of a non-negative integer n, denoted by n!, is the product of all positive integers less than or
! equal to n."
! CAUTION: THIS FUNCTION CAN ONLY HANDLE FACTORIALS UP TO N_in=20 !
!===================================================================================================================================
USE MOD_Globals
USE MOD_PreProc
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
INTEGER(KIND=8)    :: FACTORIAL
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER(KIND=8)    :: I
!===================================================================================================================================
!print*,"stop"
!stop
IF(N_in.LT.0) CALL abort(__STAMP__,&
  'FACTORIAL of a negative integer number not allowed! ',999,REAL(N_in))
IF(N_in.EQ.0)THEN
  FACTORIAL = 1 !! debug, should be one!!!!
ELSE
  FACTORIAL = PRODUCT((/(I, I = 1, N_in)/))
END IF
IF(FACTORIAL.LT.0) CALL abort(__STAMP__,&
  'FACTORIAL is negative. This is not allowed! ',999,REAL(FACTORIAL))
END FUNCTION FACTORIAL


FUNCTION FACTORIAL_REAL(N_in)
!===================================================================================================================================
! "In mathematics, the factorial of a non-negative integer n, denoted by n!, is the product of all positive integers less than or
! equal to n."
! CAUTION: THIS FUNCTION CAN ONLY HANDLE FACTORIALS UP TO N_in=20 !
!===================================================================================================================================
USE MOD_Globals
USE MOD_PreProc
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER,INTENT(IN) :: N_in 
!-----------------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL(KIND=8)    :: FACTORIAL_REAL
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER         :: I
!===================================================================================================================================
!print*,"stop"
!stop
IF(N_in.LT.0) CALL abort(__STAMP__,&
  'FACTORIAL of a negative integer number not allowed! ',999,REAL(N_in))
FACTORIAL_REAL=1.
DO I=2,N_in
  FACTORIAL_REAL=FACTORIAL_REAL*REAL(I,8)
END DO
IF(FACTORIAL_REAL.LT.0) CALL abort(__STAMP__,&
  'FACTORIAL is negative. This is not allowed! ',999,FACTORIAL_REAL)
END FUNCTION FACTORIAL_REAL


RECURSIVE FUNCTION CHOOSELARGE(N_in,k) RESULT(X)
!===================================================================================================================================
! For large numbers, when NGeo+BezierElevation>18 this function is needed
!===================================================================================================================================
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
!input parameters
INTEGER, INTENT(IN) :: N_in,k
!-----------------------------------------------------------------------------------------------------------------------------------
!local variables
REAL(KIND=8)        :: X
!===================================================================================================================================
!IF(N_in.LT.0) CALL abort(__STAMP__,&
  !'FACTORIAL of a negative integer number not allowed! ',999,REAL(N_in))
IF(k==0)THEN
  X=1.
ELSE IF(N_in==0.AND.k>0)THEN
  X=0.
ELSE
  X=(REAL(N_in,8)/k)*CHOOSELARGE(N_in-1,k-1)
END IF
END FUNCTION CHOOSELARGE


REAL FUNCTION factorialLARGE(x)
implicit none
real, intent(in) :: x
factorialLARGE = gamma(x + 1.0)
END FUNCTION factorialLARGE


SUBROUTINE LagrangeInterpolationPolys(x,N_in,xGP,wBary,L)
!============================================================================================================================
! Algorithm 34, Kopriva
! Computes all Lagrange functions evaluated at position x in [-1;1]
! Uses function ALMOSTEQUAL
!============================================================================================================================
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------
!input parameters
REAL, INTENT(IN)   :: x          ! Coordinate
INTEGER,INTENT(IN) :: N_in          ! polynomial degree
REAL,INTENT(IN)    :: xGP(0:N_in)   ! Gausspoint positions for the reference interval [-1,1]
REAL,INTENT(IN)    :: wBary(0:N_in) ! Barycentric weights
!----------------------------------------------------------------------------------------------------------------------------
!output parameters
REAL,INTENT(OUT)   :: L(0:N_in)     ! Lagrange basis functions evaluated at x
!----------------------------------------------------------------------------------------------------------------------------
!local variables
INTEGER                   :: iGP
LOGICAL                   :: xEqualGP ! is x equal to a Gauss Point
REAL                      :: DummySum
!============================================================================================================================
xEqualGP=.FALSE.
DO iGP=0,N_in
  L(iGP)=0.
  IF(ALMOSTEQUAL_UNITY(x,xGP(iGP))) THEN
    L(iGP)=1.
    xEqualGP=.TRUE.
  END IF ! (ALMOSTEQUAL_UNITY(x,xGP(iGP)))
END DO ! iGP
! if x is equal to a Gauss point, L=(0,....,1,....0)
IF(xEqualGP) RETURN
DummySum=0.
DO iGP=0, N_in
  L(iGP)=wBary(iGP)/(x-xGP(iGP))
  DummySum=DummySum+L(iGP)
END DO

DO iGP=0,N_in
  L(iGP)=L(iGP)/DummySum
END DO
END SUBROUTINE LagrangeInterpolationPolys


END MODULE MOD_Basis

