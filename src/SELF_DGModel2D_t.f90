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

module SELF_DGModel2D_t

  use SELF_SupportRoutines
  use SELF_Metadata
  use SELF_Geometry_2D
  use SELF_Mesh_2D
  use SELF_MappedScalar_2D
  use SELF_MappedVector_2D
  use SELF_HDF5
  use HDF5
  use FEQParse
  use SELF_Model

  implicit none

  type,extends(Model) :: DGModel2D_t
    type(MappedScalar2D)   :: solution
    type(MappedVector2D)   :: solutionGradient
    type(MappedVector2D)   :: flux
    type(MappedScalar2D)   :: source
    type(MappedScalar2D)   :: fluxDivergence
    type(MappedScalar2D)   :: dSdt
    type(MappedScalar2D)   :: workSol
    type(Mesh2D),pointer   :: mesh
    type(SEMQuad),pointer  :: geometry

  contains

    procedure :: Init => Init_DGModel2D_t
    procedure :: SetMetadata => SetMetadata_DGModel2D_t
    procedure :: Free => Free_DGModel2D_t

    procedure :: CalculateEntropy => CalculateEntropy_DGModel2D_t
    procedure :: BoundaryFlux => BoundaryFlux_DGModel2D_t
    procedure :: FluxMethod => fluxmethod_DGModel2D_t
    procedure :: SourceMethod => sourcemethod_DGModel2D_t
    procedure :: SetBoundaryCondition => setboundarycondition_DGModel2D_t
    procedure :: SetGradientBoundaryCondition => setgradientboundarycondition_DGModel2D_t
    procedure :: ReportMetrics => ReportMetrics_DGModel2D_t

    procedure :: UpdateSolution => UpdateSolution_DGModel2D_t

    procedure :: UpdateGRK2 => UpdateGRK2_DGModel2D_t
    procedure :: UpdateGRK3 => UpdateGRK3_DGModel2D_t
    procedure :: UpdateGRK4 => UpdateGRK4_DGModel2D_t

    procedure :: CalculateSolutionGradient => CalculateSolutionGradient_DGModel2D_t
    procedure :: CalculateTendency => CalculateTendency_DGModel2D_t

    generic :: SetSolution => SetSolutionFromChar_DGModel2D_t, &
      SetSolutionFromEqn_DGModel2D_t
    procedure,private :: SetSolutionFromChar_DGModel2D_t
    procedure,private :: SetSolutionFromEqn_DGModel2D_t

    procedure :: ReadModel => Read_DGModel2D_t
    procedure :: WriteModel => Write_DGModel2D_t
    procedure :: WriteTecplot => WriteTecplot_DGModel2D_t

  endtype DGModel2D_t

contains

  subroutine Init_DGModel2D_t(this,mesh,geometry)
    implicit none
    class(DGModel2D_t),intent(out) :: this
    type(Mesh2D),intent(in),target :: mesh
    type(SEMQuad),intent(in),target :: geometry
    ! Local
    integer :: ivar
    character(LEN=3) :: ivarChar
    character(LEN=25) :: varname

    this%mesh => mesh
    this%geometry => geometry
    call this%SetNumberOfVariables()

    call this%solution%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%workSol%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%dSdt%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%solutionGradient%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%flux%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%source%Init(geometry%x%interp,this%nvar,this%mesh%nElem)
    call this%fluxDivergence%Init(geometry%x%interp,this%nvar,this%mesh%nElem)

    call this%solution%AssociateGeometry(geometry)
    call this%solutionGradient%AssociateGeometry(geometry)
    call this%flux%AssociateGeometry(geometry)
    call this%fluxDivergence%AssociateGeometry(geometry)

    call this%AdditionalInit()

    call this%SetMetadata()

  endsubroutine Init_DGModel2D_t

  subroutine SetMetadata_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: ivar
    character(LEN=3) :: ivarChar
    character(LEN=25) :: varname

    do ivar = 1,this%nvar
      write(ivarChar,'(I3.3)') ivar
      varname = "solution"//trim(ivarChar)
      call this%solution%SetName(ivar,varname)
      call this%solution%SetUnits(ivar,"[null]")
    enddo

  endsubroutine SetMetadata_DGModel2D_t

  subroutine Free_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this

    call this%solution%Free()
    call this%workSol%Free()
    call this%dSdt%Free()
    call this%solutionGradient%Free()
    call this%flux%Free()
    call this%source%Free()
    call this%fluxDivergence%Free()
    call this%AdditionalFree()

  endsubroutine Free_DGModel2D_t

  subroutine ReportMetrics_DGModel2D_t(this)
    !! Base method for reporting the entropy of a model
    !! to stdout. Only override this procedure if additional
    !! reporting is needed. Alternatively, if you think
    !! additional reporting would be valuable for all models,
    !! open a pull request with modifications to this base
    !! method.
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    character(len=20) :: modelTime
    character(len=20) :: minv,maxv
    character(len=:),allocatable :: str
    integer :: ivar

    ! Copy the time and entropy to a string
    write(modelTime,"(ES16.7E3)") this%t

    do ivar = 1,this%nvar
      write(maxv,"(ES16.7E3)") maxval(this%solution%interior(:,:,:,ivar))
      write(minv,"(ES16.7E3)") minval(this%solution%interior(:,:,:,ivar))

      ! Write the output to STDOUT
      open(output_unit,ENCODING='utf-8')
      write(output_unit,'(1x, A," : ")',ADVANCE='no') __FILE__
      str = 'tᵢ ='//trim(modelTime)
      write(output_unit,'(A)',ADVANCE='no') str
      str = '  |  min('//trim(this%solution%meta(ivar)%name)// &
            '), max('//trim(this%solution%meta(ivar)%name)//') = '// &
            minv//" , "//maxv
      write(output_unit,'(A)',ADVANCE='yes') str
    enddo

    call this%ReportUserMetrics()

  endsubroutine ReportMetrics_DGModel2D_t

  subroutine SetSolutionFromEqn_DGModel2D_t(this,eqn)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    type(EquationParser),intent(in) :: eqn(1:this%solution%nVar)
    ! Local
    integer :: iVar

    ! Copy the equation parser
    do iVar = 1,this%solution%nVar
      call this%solution%SetEquation(ivar,eqn(iVar)%equation)
    enddo

    call this%solution%SetInteriorFromEquation(this%geometry,this%t)

    call this%solution%BoundaryInterp()

  endsubroutine SetSolutionFromEqn_DGModel2D_t

  subroutine SetSolutionFromChar_DGModel2D_t(this,eqnChar)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    character(*),intent(in) :: eqnChar(1:this%solution%nVar)
    ! Local
    integer :: iVar

    do iVar = 1,this%solution%nVar
      call this%solution%SetEquation(ivar,trim(eqnChar(iVar)))
    enddo

    call this%solution%SetInteriorFromEquation(this%geometry,this%t)

    call this%solution%BoundaryInterp()

  endsubroutine SetSolutionFromChar_DGModel2D_t

  subroutine UpdateSolution_DGModel2D_t(this,dt)
    !! Computes a solution update as , where dt is either provided through the interface
    !! or taken as the Model's stored time step size (model % dt)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    real(prec),optional,intent(in) :: dt
    ! Local
    real(prec) :: dtLoc
    integer :: i,j,iEl,iVar

    if(present(dt)) then
      dtLoc = dt
    else
      dtLoc = this%dt
    endif

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem,ivar=1:this%solution%nVar)

      this%solution%interior(i,j,iEl,iVar) = &
        this%solution%interior(i,j,iEl,iVar)+ &
        dtLoc*this%dSdt%interior(i,j,iEl,iVar)

    enddo

  endsubroutine UpdateSolution_DGModel2D_t

  subroutine UpdateGRK2_DGModel2D_t(this,m)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    integer,intent(in) :: m
    ! Local
    integer :: i,j,iEl,iVar

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem,ivar=1:this%solution%nVar)

      this%workSol%interior(i,j,iEl,iVar) = rk2_a(m)* &
                                            this%workSol%interior(i,j,iEl,iVar)+ &
                                            this%dSdt%interior(i,j,iEl,iVar)

      this%solution%interior(i,j,iEl,iVar) = &
        this%solution%interior(i,j,iEl,iVar)+ &
        rk2_g(m)*this%dt*this%workSol%interior(i,j,iEl,iVar)

    enddo

  endsubroutine UpdateGRK2_DGModel2D_t

  subroutine UpdateGRK3_DGModel2D_t(this,m)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    integer,intent(in) :: m
    ! Local
    integer :: i,j,iEl,iVar

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem,ivar=1:this%solution%nVar)

      this%workSol%interior(i,j,iEl,iVar) = rk3_a(m)* &
                                            this%workSol%interior(i,j,iEl,iVar)+ &
                                            this%dSdt%interior(i,j,iEl,iVar)

      this%solution%interior(i,j,iEl,iVar) = &
        this%solution%interior(i,j,iEl,iVar)+ &
        rk3_g(m)*this%dt*this%workSol%interior(i,j,iEl,iVar)

    enddo

  endsubroutine UpdateGRK3_DGModel2D_t

  subroutine UpdateGRK4_DGModel2D_t(this,m)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    integer,intent(in) :: m
    ! Local
    integer :: i,j,iEl,iVar

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem,ivar=1:this%solution%nVar)

      this%workSol%interior(i,j,iEl,iVar) = rk4_a(m)* &
                                            this%workSol%interior(i,j,iEl,iVar)+ &
                                            this%dSdt%interior(i,j,iEl,iVar)

      this%solution%interior(i,j,iEl,iVar) = &
        this%solution%interior(i,j,iEl,iVar)+ &
        rk4_g(m)*this%dt*this%workSol%interior(i,j,iEl,iVar)

    enddo

  endsubroutine UpdateGRK4_DGModel2D_t

  subroutine CalculateSolutionGradient_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this

    call this%solution%AverageSides()

    call this%solution%MappedDGGradient(this%solutionGradient%interior)

    ! interpolate the solutiongradient to the element boundaries
    call this%solutionGradient%BoundaryInterp()

    ! perform the side exchange to populate the
    ! solutionGradient % extBoundary attribute
    call this%solutionGradient%SideExchange(this%mesh)

  endsubroutine CalculateSolutionGradient_DGModel2D_t

  subroutine CalculateEntropy_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: iel,i,j,ierror
    real(prec) :: e,jac
    real(prec) :: s(1:this%nvar)

    e = 0.0_prec
    do iel = 1,this%geometry%nelem
      do j = 1,this%solution%interp%N+1
        do i = 1,this%solution%interp%N+1
          jac = abs(this%geometry%J%interior(i,j,iel,1))
          s = this%solution%interior(i,j,iel,1:this%nvar)
          e = e+this%entropy_func(s)*jac
        enddo
      enddo
    enddo

    if(this%mesh%decomp%mpiEnabled) then
      call mpi_allreduce(e, &
                         this%entropy, &
                         1, &
                         this%mesh%decomp%mpiPrec, &
                         MPI_SUM, &
                         this%mesh%decomp%mpiComm, &
                         iError)
    else
      this%entropy = e
    endif

  endsubroutine CalculateEntropy_DGModel2D_t

  subroutine fluxmethod_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: iel
    integer :: i
    integer :: j
    real(prec) :: s(1:this%nvar),dsdx(1:this%nvar,1:2)

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem)

      s = this%solution%interior(i,j,iel,1:this%nvar)
      dsdx = this%solutionGradient%interior(i,j,iel,1:this%nvar,1:2)
      this%flux%interior(i,j,iel,1:this%nvar,1:2) = this%flux2d(s,dsdx)

    enddo

  endsubroutine fluxmethod_DGModel2D_t

  subroutine BoundaryFlux_DGModel2D_t(this)
    ! this method uses an linear upwind solver for the
    ! advective flux and the bassi-rebay method for the
    ! diffusive fluxes
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: iel
    integer :: j
    integer :: i
    real(prec) :: sL(1:this%nvar),sR(1:this%nvar)
    real(prec) :: dsdx(1:this%nvar,1:2)
    real(prec) :: nhat(1:2),nmag

    do concurrent(i=1:this%solution%N+1,j=1:4, &
                  iel=1:this%mesh%nElem)

      ! Get the boundary normals on cell edges from the mesh geometry
      nhat = this%geometry%nHat%boundary(i,j,iEl,1,1:2)
      sL = this%solution%boundary(i,j,iel,1:this%nvar) ! interior solution
      sR = this%solution%extboundary(i,j,iel,1:this%nvar) ! exterior solution
      dsdx = this%solutiongradient%avgboundary(i,j,iel,1:this%nvar,1:2)
      nmag = this%geometry%nScale%boundary(i,j,iEl,1)

      this%flux%boundaryNormal(i,j,iEl,1:this%nvar) = this%riemannflux2d(sL,sR,dsdx,nhat)*nmag

    enddo

  endsubroutine BoundaryFlux_DGModel2D_t

  subroutine sourcemethod_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: iel
    integer :: i
    integer :: j
    real(prec) :: s(1:this%nvar),dsdx(1:this%nvar,1:2)

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem)

      s = this%solution%interior(i,j,iel,1:this%nvar)
      dsdx = this%solutionGradient%interior(i,j,iel,1:this%nvar,1:2)
      this%source%interior(i,j,iel,1:this%nvar) = this%source2d(s,dsdx)

    enddo

  endsubroutine sourcemethod_DGModel2D_t

  subroutine setboundarycondition_DGModel2D_t(this)
    !! Boundary conditions for the solution are set to
    !! 0 for the external state to provide radiation type
    !! boundary conditions.
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! local
    integer :: i,iEl,j,e2,bcid
    real(prec) :: nhat(1:2),x(1:2)

    do concurrent(j=1:4,iel=1:this%mesh%nElem)

      bcid = this%mesh%sideInfo(5,j,iEl) ! Boundary Condition ID
      e2 = this%mesh%sideInfo(3,j,iEl) ! Neighboring Element ID

      if(e2 == 0) then
        if(bcid == SELF_BC_PRESCRIBED) then

          do i = 1,this%solution%interp%N+1 ! Loop over quadrature points
            x = this%geometry%x%boundary(i,j,iEl,1,1:2)

            this%solution%extBoundary(i,j,iEl,1:this%nvar) = &
              this%hbc2d_Prescribed(x,this%t)
          enddo

        elseif(bcid == SELF_BC_RADIATION) then

          do i = 1,this%solution%interp%N+1 ! Loop over quadrature points
            nhat = this%geometry%nhat%boundary(i,j,iEl,1,1:2)

            this%solution%extBoundary(i,j,iEl,1:this%nvar) = &
              this%hbc2d_Radiation(this%solution%boundary(i,j,iEl,1:this%nvar),nhat)
          enddo

        elseif(bcid == SELF_BC_NONORMALFLOW) then

          do i = 1,this%solution%interp%N+1 ! Loop over quadrature points
            nhat = this%geometry%nhat%boundary(i,j,iEl,1,1:2)

            this%solution%extBoundary(i,j,iEl,1:this%nvar) = &
              this%hbc2d_NoNormalFlow(this%solution%boundary(i,j,iEl,1:this%nvar),nhat)
          enddo

        endif
      endif

    enddo

  endsubroutine setboundarycondition_DGModel2D_t

  subroutine setgradientboundarycondition_DGModel2D_t(this)
    !! Boundary conditions for the solution are set to
    !! 0 for the external state to provide radiation type
    !! boundary conditions.
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! local
    integer :: i,iEl,j,e2,bcid
    real(prec) :: dsdx(1:this%nvar,1:2)
    real(prec) :: nhat(1:2),x(1:2)

    do concurrent(j=1:4,iel=1:this%mesh%nElem)

      bcid = this%mesh%sideInfo(5,j,iEl) ! Boundary Condition ID
      e2 = this%mesh%sideInfo(3,j,iEl) ! Neighboring Element ID

      if(e2 == 0) then
        if(bcid == SELF_BC_PRESCRIBED) then

          do i = 1,this%solutiongradient%interp%N+1 ! Loop over quadrature points
            x = this%geometry%x%boundary(i,j,iEl,1,1:2)

            this%solutiongradient%extBoundary(i,j,iEl,1:this%nvar,1:2) = &
              this%pbc2d_Prescribed(x,this%t)
          enddo

        elseif(bcid == SELF_BC_RADIATION) then

          do i = 1,this%solutiongradient%interp%N+1 ! Loop over quadrature points
            nhat = this%geometry%nhat%boundary(i,j,iEl,1,1:2)

            dsdx = this%solutiongradient%boundary(i,j,iEl,1:this%nvar,1:2)

            this%solutiongradient%extBoundary(i,j,iEl,1:this%nvar,1:2) = &
              this%pbc2d_Radiation(dsdx,nhat)
          enddo

        elseif(bcid == SELF_BC_NONORMALFLOW) then

          do i = 1,this%solutiongradient%interp%N+1 ! Loop over quadrature points
            nhat = this%geometry%nhat%boundary(i,j,iEl,1,1:2)

            dsdx = this%solutiongradient%boundary(i,j,iEl,1:this%nvar,1:2)

            this%solutiongradient%extBoundary(i,j,iEl,1:this%nvar,1:2) = &
              this%pbc2d_NoNormalFlow(dsdx,nhat)
          enddo

        endif
      endif

    enddo

  endsubroutine setgradientboundarycondition_DGModel2D_t

  subroutine CalculateTendency_DGModel2D_t(this)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    ! Local
    integer :: i,j,iEl,iVar

    call this%solution%BoundaryInterp()
    call this%solution%SideExchange(this%mesh)

    call this%PreTendency() ! User-supplied
    call this%SetBoundaryCondition() ! User-supplied

    if(this%gradient_enabled) then
      call this%CalculateSolutionGradient()
      call this%SetGradientBoundaryCondition() ! User-supplied
      call this%solutionGradient%AverageSides()
    endif

    call this%SourceMethod() ! User supplied
    call this%BoundaryFlux() ! User supplied
    call this%FluxMethod() ! User supplied

    call this%flux%MappedDGDivergence(this%fluxDivergence%interior)

    do concurrent(i=1:this%solution%N+1,j=1:this%solution%N+1, &
                  iel=1:this%mesh%nElem,ivar=1:this%solution%nVar)

      this%dSdt%interior(i,j,iEl,iVar) = &
        this%source%interior(i,j,iEl,iVar)- &
        this%fluxDivergence%interior(i,j,iEl,iVar)

    enddo

  endsubroutine CalculateTendency_DGModel2D_t

  subroutine Write_DGModel2D_t(this,fileName)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    character(*),optional,intent(in) :: fileName
    ! Local
    integer(HID_T) :: fileId
    character(LEN=self_FileNameLength) :: pickupFile
    character(13) :: timeStampString

    if(present(filename)) then
      pickupFile = filename
    else
      write(timeStampString,'(I13.13)') this%ioIterate
      pickupFile = 'solution.'//timeStampString//'.h5'
    endif

    print*,__FILE__//" : Writing pickup file : "//trim(pickupFile)
    call this%solution%UpdateHost()

    if(this%mesh%decomp%mpiEnabled) then

      call Open_HDF5(pickupFile,H5F_ACC_TRUNC_F,fileId,this%mesh%decomp%mpiComm)

      ! Write the interpolant to the file
      call this%solution%interp%WriteHDF5(fileId)

      ! In this section, we write the solution and geometry on the control (quadrature) grid
      ! which can be used for model pickup runs or post-processing
      ! Write the model state to file
      call CreateGroup_HDF5(fileId,'/controlgrid')
      print*," offset, nglobal_elem : ",this%mesh%decomp%offsetElem(this%mesh%decomp%rankId+1),this%mesh%decomp%nElem
      call this%solution%WriteHDF5(fileId,'/controlgrid/solution', &
                                   this%mesh%decomp%offsetElem(this%mesh%decomp%rankId+1),this%mesh%decomp%nElem)

      ! Write the geometry to file
      call this%geometry%x%WriteHDF5(fileId,'/controlgrid/geometry', &
                                     this%mesh%decomp%offsetElem(this%mesh%decomp%rankId+1),this%mesh%decomp%nElem)

      ! -- END : writing solution on control grid -- !

      call Close_HDF5(fileId)

    else

      call Open_HDF5(pickupFile,H5F_ACC_TRUNC_F,fileId)

      ! Write the interpolant to the file
      call this%solution%interp%WriteHDF5(fileId)

      ! In this section, we write the solution and geometry on the control (quadrature) grid
      ! which can be used for model pickup runs or post-processing

      ! Write the model state to file
      call CreateGroup_HDF5(fileId,'/controlgrid')
      call this%solution%WriteHDF5(fileId,'/controlgrid/solution')

      ! Write the geometry to file
      call this%geometry%x%WriteHDF5(fileId,'/controlgrid/geometry')
      ! -- END : writing solution on control grid -- !

      call Close_HDF5(fileId)

    endif

  endsubroutine Write_DGModel2D_t

  subroutine Read_DGModel2D_t(this,fileName)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    character(*),intent(in) :: fileName
    ! Local
    integer(HID_T) :: fileId
    integer(HID_T) :: solOffset(1:3)
    integer :: firstElem
    integer :: N,ivar

    if(this%mesh%decomp%mpiEnabled) then
      call Open_HDF5(fileName,H5F_ACC_RDWR_F,fileId, &
                     this%mesh%decomp%mpiComm)
    else
      call Open_HDF5(fileName,H5F_ACC_RDWR_F,fileId)
    endif

    if(this%mesh%decomp%mpiEnabled) then
      firstElem = this%mesh%decomp%offsetElem(this%mesh%decomp%rankId+1)
      solOffset(1:3) = (/0,0,firstElem/)
      do ivar = 1,this%solution%nvar
        call ReadArray_HDF5(fileId, &
                            '/controlgrid/solution/'//trim(this%solution%meta(ivar)%name), &
                            this%solution%interior(:,:,:,ivar),solOffset)
      enddo
    else
      do ivar = 1,this%solution%nvar
        call ReadArray_HDF5(fileId, &
                            '/controlgrid/solution/'//trim(this%solution%meta(ivar)%name), &
                            this%solution%interior(:,:,:,ivar))
      enddo
    endif

    call Close_HDF5(fileId)

  endsubroutine Read_DGModel2D_t

  subroutine WriteTecplot_DGModel2D_t(this,filename)
    implicit none
    class(DGModel2D_t),intent(inout) :: this
    character(*),intent(in),optional :: filename
    ! Local
    character(8) :: zoneID
    integer :: fUnit
    integer :: iEl,i,j,iVar
    character(LEN=self_FileNameLength) :: tecFile
    character(LEN=self_TecplotHeaderLength) :: tecHeader
    character(LEN=self_FormatLength) :: fmat
    character(13) :: timeStampString
    character(5) :: rankString
    type(Scalar2D) :: solution
    type(Scalar2D) :: dsdt
    type(Vector2D) :: solutionGradient
    type(Vector2D) :: x
    type(Lagrange),target :: interp

    if(present(filename)) then
      tecFile = filename
    else
      write(timeStampString,'(I13.13)') this%ioIterate

      if(this%mesh%decomp%mpiEnabled) then
        write(rankString,'(I5.5)') this%mesh%decomp%rankId
        tecFile = 'solution.'//rankString//'.'//timeStampString//'.tec'
      else
        tecFile = 'solution.'//timeStampString//'.tec'
      endif

    endif

    ! Create an interpolant for the uniform grid
    call interp%Init(this%solution%interp%M, &
                     this%solution%interp%targetNodeType, &
                     this%solution%interp%N, &
                     this%solution%interp%controlNodeType)

    call solution%Init(interp, &
                       this%solution%nVar,this%solution%nElem)

    call dsdt%Init(interp, &
                   this%solution%nVar,this%solution%nElem)

    call solutionGradient%Init(interp, &
                               this%solution%nVar,this%solution%nElem)

    call x%Init(interp,1,this%solution%nElem)

    call this%solution%UpdateHost()
    call this%solutionGradient%UpdateHost()
    call this%dsdt%UpdateHost()

    ! Map the mesh positions to the target grid
    call this%geometry%x%GridInterp(x%interior)

    ! Map the solution to the target grid
    call this%solution%GridInterp(solution%interior)
    call this%dsdt%GridInterp(dsdt%interior)

    ! Map the solution to the target grid
    call this%solutionGradient%GridInterp(solutionGradient%interior)

    open(UNIT=NEWUNIT(fUnit), &
         FILE=trim(tecFile), &
         FORM='formatted', &
         STATUS='replace')

    tecHeader = 'VARIABLES = "X", "Y"'
    do iVar = 1,this%solution%nVar
      tecHeader = trim(tecHeader)//', "'//trim(this%solution%meta(iVar)%name)//'"'
    enddo

    do iVar = 1,this%solution%nVar
      tecHeader = trim(tecHeader)//', "d/dx('//trim(this%solution%meta(iVar)%name)//')"'
    enddo

    do iVar = 1,this%solution%nVar
      tecHeader = trim(tecHeader)//', "d/dy('//trim(this%solution%meta(iVar)%name)//')"'
    enddo

    do iVar = 1,this%solution%nVar
      tecHeader = trim(tecHeader)//', "d/dt('//trim(this%solution%meta(iVar)%name)//')"'
    enddo

    write(fUnit,*) trim(tecHeader)

    ! Create format statement
    write(fmat,*) 4*this%solution%nvar+2
    fmat = '('//trim(fmat)//'(ES16.7E3,1x))'

    do iEl = 1,this%solution%nElem

      ! TO DO :: Get the global element ID
      write(zoneID,'(I8.8)') iEl
      write(fUnit,*) 'ZONE T="el'//trim(zoneID)//'", I=',this%solution%interp%M+1, &
        ', J=',this%solution%interp%M+1

      do j = 1,this%solution%interp%M+1
        do i = 1,this%solution%interp%M+1

          write(fUnit,fmat) x%interior(i,j,iEl,1,1), &
            x%interior(i,j,iEl,1,2), &
            solution%interior(i,j,iEl,1:this%solution%nvar), &
            solutionGradient%interior(i,j,iEl,1:this%solution%nvar,1), &
            solutionGradient%interior(i,j,iEl,1:this%solution%nvar,2), &
            dsdt%interior(i,j,iEl,1:this%solution%nvar)

        enddo
      enddo

    enddo

    close(UNIT=fUnit)

    call x%Free()
    call solution%Free()
    call dsdt%Free()
    call interp%Free()

  endsubroutine WriteTecplot_DGModel2D_t

endmodule SELF_DGModel2D_t
