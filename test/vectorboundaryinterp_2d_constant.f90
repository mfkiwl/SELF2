! //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// !
!
! Maintainers : support@fluidnumerics.com
! Official Repository : https://github.com/FluidNumerics/self/
!
! Copyright © 2024 Fluid Numerics LLC
!
! Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
!
! 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
!
! 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in
!    the documentation and/or other materials provided with the distribution.
!
! 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from
!    this software without specific prior written permission.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
! LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
! HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
! LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
! THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
! THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
!
! //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// !

program test

  implicit none
  integer :: exit_code

  exit_code = vectorboundaryinterp_2d_constant()
  if(exit_code /= 0) then
    stop exit_code
  endif

contains
  integer function vectorboundaryinterp_2d_constant() result(r)
    use SELF_Constants
    use SELF_Lagrange
    use SELF_Vector_2D

    implicit none

    integer,parameter :: controlDegree = 7
    integer,parameter :: targetDegree = 16
    integer,parameter :: nvar = 4
    integer,parameter :: nelem = 100
#ifdef DOUBLE_PRECISION
    real(prec),parameter :: tolerance = 10.0_prec**(-7)
#else
    real(prec),parameter :: tolerance = 10.0_prec**(-3)
#endif
    type(Vector2D) :: f
    type(Lagrange),target :: interp

    ! Create an interpolant
    call interp%Init(N=controlDegree, &
                     controlNodeType=GAUSS, &
                     M=targetDegree, &
                     targetNodeType=UNIFORM)

    ! Initialize vectors
    call f%Init(interp,nvar,nelem)

    ! Set the source vector (on the control grid) to a non-zero constant
    f%interior = 1.0_prec
    f%boundary = 0.0_prec
    print*,"Backend : "//f%backend
    print*,"Max interior : ",maxval(f%interior)
    ! Interpolate with gpuAccel = .FALSE.
    call f%UpdateDevice()
    call f%BoundaryInterp()
    call f%UpdateHost()

    print*,"Max boundary : ",maxval(f%boundary)
    ! Calculate diff from exact
    f%boundary = abs(f%boundary-1.0_prec)

    if(maxval(f%boundary) <= tolerance) then
      r = 0
    else
      print*,"Max error : ",maxval(f%boundary)
      r = 1
    endif

    call f%free()
    call interp%free()

  endfunction vectorboundaryinterp_2d_constant
endprogram test
