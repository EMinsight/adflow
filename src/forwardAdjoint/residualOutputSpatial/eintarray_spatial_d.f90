   !        Generated by TAPENADE     (INRIA, Tropics team)
   !  Tapenade 3.4 (r3375) - 10 Feb 2010 15:08
   !
   !  Differentiation of eintarray in forward (tangent) mode:
   !   variations   of useful results: eint
   !   with respect to varying inputs: cv0 *cptrange *cpeint *(*cptempfit.constants)
   !                *cptempfit.eint0 cvn rgas tref gammaconstant k
   !                p rho
   !      ==================================================================
   SUBROUTINE EINTARRAY_SPATIAL_D(rho, rhod, p, pd, k, kd, eint, eintd, &
   &  correctfork, kk)
   USE CPCURVEFITS
   USE INPUTPHYSICS
   USE CONSTANTS
   USE FLOWVARREFSTATE
   IMPLICIT NONE
   !
   !      ******************************************************************
   !      *                                                                *
   !      * EintArray computes the internal energy per unit mass from the  *
   !      * given density and pressure (and possibly turbulent energy) for *
   !      * the given kk elements of the arrays.                           *
   !      * For a calorically and thermally perfect gas the well-known     *
   !      * expression is used; for only a thermally perfect gas, cp is a  *
   !      * function of temperature, curve fits are used and a more        *
   !      * complex expression is obtained.                                *
   !      *                                                                *
   !      ******************************************************************
   !
   !
   !      Subroutine arguments.
   !
   REAL(kind=realtype), DIMENSION(*), INTENT(IN) :: rho, p, k
   REAL(kind=realtype), DIMENSION(*), INTENT(IN) :: rhod, pd, kd
   REAL(kind=realtype), DIMENSION(*), INTENT(OUT) :: eint
   REAL(kind=realtype), DIMENSION(*), INTENT(OUT) :: eintd
   LOGICAL, INTENT(IN) :: correctfork
   INTEGER(kind=inttype), INTENT(IN) :: kk
   !
   !      Local parameter.
   !
   REAL(kind=realtype), PARAMETER :: twothird=two*third
   !
   !      Local variables.
   !
   INTEGER(kind=inttype) :: i, nn, mm, ii, start
   REAL(kind=realtype) :: ovgm1, factk, pp, t, t2, scale
   REAL(kind=realtype) :: ppd, td, t2d
   INTRINSIC LOG
   !
   !      ******************************************************************
   !      *                                                                *
   !      * Begin execution                                                *
   !      *                                                                *
   !      ******************************************************************
   !
   ! Determine the cp model used in the computation.
   SELECT CASE  (cpmodel) 
   CASE (cpconstant) 
   ! Abbreviate 1/(gamma -1) a bit easier.
   ovgm1 = one/(gammaconstant-one)
   !eintd = 0.0
   ! Loop over the number of elements of the array and compute
   ! the total energy.
   DO i=1,kk
   eintd(i) = (ovgm1*pd(i)*rho(i)-ovgm1*p(i)*rhod(i))/rho(i)**2
   eint(i) = ovgm1*p(i)/rho(i)
   END DO
   ! Second step. Correct the energy in case a turbulent kinetic
   ! energy is present.
   IF (correctfork) THEN
   factk = ovgm1*(five*third-gammaconstant)
   DO i=1,kk
   eintd(i) = eintd(i) - factk*kd(i)
   eint(i) = eint(i) - factk*k(i)
   END DO
   END IF
   CASE (cptempcurvefits) 
   !        ================================================================
   ! Cp as function of the temperature is given via curve fits.
   ! Store a scale factor to compute the nonDimensional
   ! internal energy.
   scale = rgas/tref
   !eintd = 0.0
   ! Loop over the number of elements of the array
   DO i=1,kk
   ! Compute the dimensional temperature.
   ppd = pd(i)
   pp = p(i)
   IF (correctfork) THEN
   ppd = ppd - twothird*(rhod(i)*k(i)+rho(i)*kd(i))
   pp = pp - twothird*rho(i)*k(i)
   END IF
   td = (tref*ppd*rgas*rho(i)-tref*pp*rgas*rhod(i))/(rgas*rho(i))**2
   t = tref*pp/(rgas*rho(i))
   ! Determine the case we are having here.
   IF (t .LE. cptrange(0)) THEN
   ! Temperature is less than the smallest temperature
   ! in the curve fits. Use extrapolation using
   ! constant cv.
   eintd(i) = scale*cv0*td
   eint(i) = scale*(cpeint(0)+cv0*(t-cptrange(0)))
   ELSE IF (t .GE. cptrange(cpnparts)) THEN
   ! Temperature is larger than the largest temperature
   ! in the curve fits. Use extrapolation using
   ! constant cv.
   eintd(i) = scale*cvn*td
   eint(i) = scale*(cpeint(cpnparts)+cvn*(t-cptrange(cpnparts)))
   ELSE
   ! Temperature is in the curve fit range.
   ! First find the valid range.
   ii = cpnparts
   start = 1
   interval:DO 
   ! Next guess for the interval.
   nn = start + ii/2
   ! Determine the situation we are having here.
   IF (t .GT. cptrange(nn)) THEN
   ! Temperature is larger than the upper boundary of
   ! the current interval. Update the lower boundary.
   start = nn + 1
   ii = ii - 1
   ELSE IF (t .GE. cptrange(nn-1)) THEN
   GOTO 100
   END IF
   ! This is the correct range. Exit the do-loop.
   ! Modify ii for the next branch to search.
   ii = ii/2
   END DO interval
   ! Nn contains the correct curve fit interval.
   ! Integrate cv to compute eint.
   100    eintd(i) = -td
   eint(i) = cptempfit(nn)%eint0 - t
   DO ii=1,cptempfit(nn)%nterm
   IF (cptempfit(nn)%exponents(ii) .EQ. -1_intType) THEN
   eintd(i) = eintd(i) + cptempfit(nn)%constants(ii)*td/t
   eint(i) = eint(i) + cptempfit(nn)%constants(ii)*LOG(t)
   ELSE
   mm = cptempfit(nn)%exponents(ii) + 1
   IF (t .GT. 0.0 .OR. (t .LT. 0.0 .AND. mm .EQ. INT(mm))) THEN
   t2d = mm*t**(mm-1)*td
   ELSE IF (t .EQ. 0.0 .AND. mm .EQ. 1.0) THEN
   t2d = td
   ELSE
   t2d = 0.0
   END IF
   t2 = t**mm
   eintd(i) = eintd(i) + cptempfit(nn)%constants(ii)*t2d/mm
   eint(i) = eint(i) + cptempfit(nn)%constants(ii)*t2/mm
   END IF
   END DO
   eintd(i) = scale*eintd(i)
   eint(i) = scale*eint(i)
   END IF
   ! Add the turbulent energy if needed.
   IF (correctfork) THEN
   eintd(i) = eintd(i) + kd(i)
   eint(i) = eint(i) + k(i)
   END IF
   END DO
   CASE DEFAULT
   !eintd = 0.0
   END SELECT
   END SUBROUTINE EINTARRAY_SPATIAL_D
