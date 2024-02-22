program test

  implicit none
  integer :: exit_code
  
  exit_code = scalarboundaryinterp_3d_gpu_constant()
  stop exit_code

contains
integer function scalarboundaryinterp_3d_gpu_constant() result(r)
  use SELF_Constants
  use SELF_Lagrange
  use SELF_Data
  use iso_c_binding
  use hipfort_hipblas

  implicit none

  integer,parameter :: controlDegree = 7
  integer,parameter :: targetDegree = 16
  integer,parameter :: nvar = 1
  integer,parameter :: nelem = 100
#ifdef DOUBLE_PRECISION
  real(prec),parameter :: tolerance = 10.0_prec**(-7)
#else
  real(prec),parameter :: tolerance = 10.0_prec**(-3)
#endif
  type(Scalar3D) :: f
  type(Lagrange),target :: interp
  type(c_ptr) :: handle

  call hipblasCheck(hipblasCreate(handle))

  ! Create an interpolant
  call interp % Init(N=controlDegree, &
                     controlNodeType=GAUSS, &
                     M=targetDegree, &
                     targetNodeType=UNIFORM)

  ! Initialize scalars
  call f % Init(interp,nvar,nelem)

  ! Set the source scalar (on the control grid) to a non-zero constant
  f % interior  = 1.0_prec

  call f % updatedevice()

  call f % BoundaryInterp(handle)

  call hipcheck(hipdevicesynchronize())

  ! Calculate diff from exact
  f % boundary  = abs(f % boundary  - 1.0_prec)

  if (maxval(f % boundary ) <= tolerance) then
    r = 0
  else
    r = 1
  end if

  call f % free()
  call interp % free()
  call hipblasCheck(hipblasDestroy(handle))

end function scalarboundaryinterp_3d_gpu_constant
end program test
