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

module SELF_Scalar_2D_t

  use SELF_Constants
  use SELF_Lagrange
  use SELF_Metadata
  use FEQParse
  use SELF_HDF5
  use SELF_Data

  use HDF5
  use iso_c_binding

  implicit none

#include "SELF_Macros.h"

  type,extends(SELF_DataObj),public :: Scalar2D_t

    real(prec),pointer,contiguous,dimension(:,:,:,:) :: interior
    real(prec),pointer,contiguous,dimension(:,:,:,:) :: boundary
    real(prec),pointer,contiguous,dimension(:,:,:,:) :: extBoundary
    real(prec),pointer,contiguous,dimension(:,:,:,:) :: avgBoundary
    real(prec),pointer,contiguous,dimension(:,:,:,:) :: boundarynormal

  contains

    procedure,public :: Init => Init_Scalar2D_t
    procedure,public :: Free => Free_Scalar2D_t

    procedure,public :: UpdateHost => UpdateHost_Scalar2D_t
    procedure,public :: UpdateDevice => UpdateDevice_Scalar2D_t

    procedure,public :: BoundaryInterp => BoundaryInterp_Scalar2D_t
    procedure,public :: AverageSides => AverageSides_Scalar2D_t
    generic,public :: GridInterp => GridInterp_Scalar2D_t
    procedure,private :: GridInterp_Scalar2D_t
    generic,public :: Gradient => Gradient_Scalar2D_t
    procedure,private :: Gradient_Scalar2D_t

    generic,public :: WriteHDF5 => WriteHDF5_MPI_Scalar2D_t,WriteHDF5_Scalar2D_t
    procedure,private :: WriteHDF5_MPI_Scalar2D_t
    procedure,private :: WriteHDF5_Scalar2D_t

  endtype Scalar2D_t

contains

  subroutine Init_Scalar2D_t(this,interp,nVar,nElem)
    implicit none
    class(Scalar2D_t),intent(out) :: this
    type(Lagrange),intent(in),target :: interp
    integer,intent(in) :: nVar
    integer,intent(in) :: nElem

    this%interp => interp
    this%nVar = nVar
    this%nElem = nElem
    this%N = interp%N
    this%M = interp%M

    allocate(this%interior(1:interp%N+1,interp%N+1,nelem,nvar), &
             this%boundary(1:interp%N+1,1:4,1:nelem,1:nvar), &
             this%extBoundary(1:interp%N+1,1:4,1:nelem,1:nvar), &
             this%avgBoundary(1:interp%N+1,1:4,1:nelem,1:nvar), &
             this%boundarynormal(1:interp%N+1,1:4,1:nelem,1:2*nvar))

    this%interior = 0.0_prec
    this%boundary = 0.0_prec
    this%extBoundary = 0.0_prec
    this%avgBoundary = 0.0_prec
    this%boundarynormal = 0.0_prec

    allocate(this%meta(1:nVar))
    allocate(this%eqn(1:nVar))

  endsubroutine Init_Scalar2D_t

  subroutine Free_Scalar2D_t(this)
    implicit none
    class(Scalar2D_t),intent(inout) :: this

    this%nVar = 0
    this%nElem = 0
    this%interp => null()
    deallocate(this%interior)
    deallocate(this%boundary)
    deallocate(this%extBoundary)
    deallocate(this%avgBoundary)
    deallocate(this%boundarynormal)
    deallocate(this%meta)
    deallocate(this%eqn)

  endsubroutine Free_Scalar2D_t

  subroutine UpdateHost_Scalar2D_t(this)
    implicit none
    class(Scalar2D_t),intent(inout) :: this

  end subroutine UpdateHost_Scalar2D_t

  subroutine UpdateDevice_Scalar2D_t(this)
    implicit none
    class(Scalar2D_t),intent(inout) :: this
    
  end subroutine UpdateDevice_Scalar2D_t

  subroutine BoundaryInterp_Scalar2D_t(this)
    implicit none
    class(Scalar2D_t),intent(inout) :: this
    ! Local
    integer :: i,ii,iel,ivar
    real(prec) :: fbs,fbe,fbn,fbw

    !$omp target
    !$omp teams loop bind(teams) collapse(3)
    do ivar = 1,this%nvar
      do iel = 1,this%nelem
        do i = 1,this%N+1

          fbs = 0.0_prec
          fbe = 0.0_prec
          fbn = 0.0_prec
          fbw = 0.0_prec
          !$omp loop bind(thread)
          do ii = 1,this%N+1
            fbs = fbs+this%interp%bMatrix(ii,1)*this%interior(i,ii,iel,ivar) ! South
            fbe = fbe+this%interp%bMatrix(ii,2)*this%interior(ii,i,iel,ivar) ! East
            fbn = fbn+this%interp%bMatrix(ii,2)*this%interior(i,ii,iel,ivar) ! North
            fbw = fbw+this%interp%bMatrix(ii,1)*this%interior(ii,i,iel,ivar) ! West
          enddo

          this%boundary(i,1,iel,ivar) = fbs
          this%boundary(i,2,iel,ivar) = fbe
          this%boundary(i,3,iel,ivar) = fbn
          this%boundary(i,4,iel,ivar) = fbw

        enddo
      enddo
    enddo
    !$omp end target

  endsubroutine BoundaryInterp_Scalar2D_t

  subroutine AverageSides_Scalar2D_t(this)
    implicit none
    class(Scalar2D_t),intent(inout) :: this
    ! Local
    integer :: iel
    integer :: iside
    integer :: ivar
    integer :: i

    !$omp target
    !$omp teams loop collapse(4)
    do ivar = 1,this%nVar
      do iel = 1,this%nElem
        do iside = 1,4
          do i = 1,this%interp%N+1
            this%avgBoundary(i,iside,iel,ivar) = 0.5_prec*( &
                                              this%boundary(i,iside,iel,ivar)+ &
                                              this%extBoundary(i,iside,iel,ivar))
          enddo
        enddo
      enddo
    enddo
    !$omp end target

  endsubroutine AverageSides_Scalar2D_t

  subroutine GridInterp_Scalar2D_t(this,f)
    implicit none
    class(Scalar2D_t),intent(in) :: this
    real(prec),intent(inout) :: f(1:this%M+1,1:this%M+1,1:this%nelem,1:this%nvar)
    ! Local
    integer :: i,j,ii,jj,iel,ivar
    real(prec) :: fi,fij

    !$omp target
    !$omp teams loop bind(teams) collapse(4)
    do ivar = 1,this%nvar
      do iel = 1,this%nelem
        do j = 1,this%M+1
          do i = 1,this%M+1

            fij = 0.0_prec
            !$omp loop bind(thread)
            do jj = 1,this%N+1
              fi = 0.0_prec
              !$omp loop bind(thread)
              do ii = 1,this%N+1
                fi = fi+this%interior(ii,jj,iel,ivar)*this%interp%iMatrix(ii,i)
              enddo
              fij = fij+fi*this%interp%iMatrix(jj,j)
            enddo
            f(i,j,iel,ivar) = fij

          enddo
        enddo
      enddo
    enddo
    !$omp end target

    !call self_hipblas_matrixop_dim1_2d(this % iMatrix,f,fInt,this % N,this % M,nvars,nelems,handle)
    !call self_hipblas_matrixop_dim2_2d(this % iMatrix,fInt,fTarget,0.0_c_prec,this % N,this % M,nvars,nelems,handle)

  endsubroutine GridInterp_Scalar2D_t

  subroutine Gradient_Scalar2D_t(this,df)
    implicit none
    class(Scalar2D_t),intent(in) :: this
    real(prec),intent(inout) :: df(1:this%N+1,1:this%N+1,1:this%nelem,1:this%nvar,1:2)
    ! Local
    integer    :: i,j,ii,iel,ivar
    real(prec) :: df1,df2

    !$omp target
    !$omp teams loop bind(teams) collapse(4)
    do ivar = 1,this%nvar
      do iel = 1,this%nelem
        do j = 1,this%N+1
          do i = 1,this%N+1

            df1 = 0.0_prec
            df2 = 0.0_prec
            !$omp loop bind(thread)
            do ii = 1,this%N+1
              df1 = df1+this%interp%dMatrix(ii,i)*this%interior(ii,j,iel,ivar)
              df2 = df2+this%interp%dMatrix(ii,j)*this%interior(i,ii,iel,ivar)
            enddo
            df(i,j,iel,ivar,1) = df1
            df(i,j,iel,ivar,2) = df2

          enddo
        enddo
      enddo
    enddo
    !$omp end target

    ! dfloc(1:,1:,1:,1:) => df(1:,1:,1:,1:,1)
    ! call self_hipblas_matrixop_dim1_2d(this % dMatrix,f,dfloc,this % N,this % N,nvars,nelems,handle)
    ! dfloc(1:,1:,1:,1:) => df(1:,1:,1:,1:,2)
    ! call self_hipblas_matrixop_dim2_2d(this % dMatrix,f,dfloc,0.0_c_prec,this % N,this % N,nvars,nelems,handle)
    ! dfloc => null()

  endsubroutine Gradient_Scalar2D_t

  subroutine WriteHDF5_MPI_Scalar2D_t(this,fileId,group,elemoffset,nglobalelem)
    implicit none
    class(Scalar2D_t),intent(in) :: this
    character(*),intent(in) :: group
    integer(HID_T),intent(in) :: fileId
    integer,intent(in) :: elemoffset
    integer,intent(in) :: nglobalelem
    ! Local
    integer(HID_T) :: offset(1:4)
    integer(HID_T) :: bOffset(1:4)
    integer(HID_T) :: globalDims(1:4)
    integer(HID_T) :: bGlobalDims(1:4)
    integer :: ivar

    offset(1:4) = (/0,0,0,elemoffset/)
    globalDims(1:4) = (/this%interp%N+1, &
                        this%interp%N+1, &
                        this%nVar, &
                        nglobalelem/)

    ! Offsets and dimensions for element boundary data
    bOffset(1:4) = (/0,0,0,elemoffset/)
    bGlobalDims(1:4) = (/this%interp%N+1, &
                         this%nVar, &
                         4, &
                         nglobalelem/)

    call CreateGroup_HDF5(fileId,trim(group))

    do ivar = 1,this%nVar
      call this%meta(ivar)%WriteHDF5(group,ivar,fileId)
    enddo

    call WriteArray_HDF5(fileId,trim(group)//"/interior", &
                         this%interior,offset,globalDims)

    call WriteArray_HDF5(fileId,trim(group)//"/boundary", &
                         this%boundary,bOffset,bGlobalDims)

  endsubroutine WriteHDF5_MPI_Scalar2D_t

  subroutine WriteHDF5_Scalar2D_t(this,fileId,group)
    implicit none
    class(Scalar2D_t),intent(in) :: this
    integer(HID_T),intent(in) :: fileId
    character(*),intent(in) :: group
    ! Local
    integer :: ivar

    call CreateGroup_HDF5(fileId,trim(group))

    do ivar = 1,this%nVar
      call this%meta(ivar)%WriteHDF5(group,ivar,fileId)
    enddo

    call WriteArray_HDF5(fileId,trim(group)//"/interior", &
                         this%interior)

    call WriteArray_HDF5(fileId,trim(group)//"/boundary", &
                         this%boundary)

  endsubroutine WriteHDF5_Scalar2D_t

endmodule SELF_Scalar_2D_t
