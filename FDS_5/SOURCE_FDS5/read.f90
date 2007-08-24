MODULE READ_INPUT
 
USE PRECISION_PARAMETERS
USE MESH_VARIABLES
USE GLOBAL_CONSTANTS
USE TRAN
USE MESH_POINTERS
USE COMP_FUNCTIONS, ONLY: SECOND,CHECKREAD, SHUTDOWN
USE MEMORY_FUNCTIONS, ONLY: ChkMemErr
USE COMP_FUNCTIONS, ONLY: GET_INPUT_FILE
 
IMPLICIT NONE
PRIVATE
CHARACTER(255), PARAMETER :: readid='$Id$'

PUBLIC READ_DATA

CHARACTER(30) :: LABEL,MB
CHARACTER(100) :: MESSAGE,FYI
CHARACTER(30) :: ID,SURF_DEFAULT,BACKGROUND_SPECIES,EVAC_SURF_DEFAULT
LOGICAL :: SUCCESS,EX,THICKEN_OBSTRUCTIONS,BNDF_DEFAULT,BAD
REAL(EB) :: XB(6),TEXTURE_ORIGIN(3)
REAL(EB) :: PBX,PBY,PBZ,MW_BACKGROUND,HUMIDITY
REAL(EB) :: MU_USER(0:20),K_USER(0:20),D_USER(20),EPSK(0:20),SIG(0:20),MW_MIN,MW_MAX
INTEGER  :: I,J,K,IZERO,IOS
TYPE (MESH_TYPE), POINTER :: M
TYPE(OBSTRUCTION_TYPE), POINTER :: OB
TYPE (VENTS_TYPE), POINTER :: VT
TYPE(SPECIES_TYPE), POINTER :: SS,SS0
TYPE(SURFACE_TYPE), POINTER :: SF
TYPE(MATERIAL_TYPE), POINTER :: ML
TYPE(REACTION_TYPE), POINTER :: RN
 
 
CONTAINS
 
 
SUBROUTINE READ_DATA(MYID)

INTEGER, INTENT(IN) :: MYID

! Create an array of output QUANTITY names that are included in the various NAMELIST groups
 
CALL FIXED_OUTPUT_QUANTITIES

! Get the name of the input file by reading the command line argument

CALL GET_INPUT_FILE

! If no input file is given, just print out the version number and stop

IF (FN_INPUT(1:1)==' ') THEN
   IF (MYID==0) THEN
      WRITE(LU_ERR,'(/A,A)') "Fire Dynamics Simulator, Version ",TRIM(VERSION_STRING)
      WRITE(LU_ERR,'(/A)')  "Consult Users Guide Chapter, Running FDS, for further instructions."
      WRITE(LU_ERR,'(/A)')  "Hit Enter to Escape..."
   ENDIF
   READ(5,*)
   STOP
ENDIF

! Stop FDS if the input file cannot be found in the current directory

INQUIRE(FILE=FN_INPUT,EXIST=EX)
IF (.NOT.EX) THEN
   IF (MYID==0) WRITE(LU_ERR,'(A,A,A)') "ERROR: The file, ", TRIM(FN_INPUT),", does not exist in the current directory"
   STOP
ENDIF

! Open the input file

OPEN(LU_INPUT,FILE=FN_INPUT)

! Read the input file, NAMELIST group by NAMELIST group

CALL READ_DEAD    ! Scan input file looking for old NAMELIST groups, and stop the run if they exist
CALL READ_HEAD
CALL READ_MESH
CALL READ_TRAN
CALL READ_TIME
CALL READ_MISC
CALL READ_RADI
CALL READ_PROP
CALL READ_PART
CALL READ_DEVC
CALL READ_CTRL
CALL READ_TREE
CALL READ_MATL
CALL READ_SURF
CALL READ_OBST
CALL READ_VENT
CALL READ_REAC
CALL READ_SPEC
CALL PROC_SPEC    ! Set up various SPECies constructs
CALL PROC_SURF_1  ! Set up SURFace constructs for species
CALL READ_RAMP    ! Read in all RAMPs, assuming they have all been identified previously
CALL READ_TABLE   ! Read in all TABLs, assuming they have all been identified previously
CALL PROC_MATL    ! Set up various MATeriaL constructs
CALL PROC_SURF_2  ! Set up remaining SURFace constructs
CALL READ_DUMP
CALL READ_CLIP
CALL READ_INIT
CALL READ_ZONE
CALL PROC_WALL    ! Set up grid for 1-D heat transfer in solids
CALL PROC_CTRL    ! Set up various ConTRoL constructs
CALL PROC_PROP    ! Set up various PROPerty constructs
CALL PROC_DEVC    ! Set up various DEViCe constructs
CALL READ_PROF
CALL READ_SLCF
CALL READ_ISOF
CALL READ_BNDF

! Close the input file, and never open it again
 
CLOSE (LU_INPUT)

! Set QUANTITY ambient values
CALL SET_QUANTITIES_AMBIENT
 
END SUBROUTINE READ_DATA



SUBROUTINE READ_DEAD
 
! Look for outdated NAMELIST groups and stop the run if any are found
 
REWIND(LU_INPUT)
CALL CHECKREAD('GRID',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: GRID is no longer a valid NAMELIST group. Read User Guide discussion on MESH.')
REWIND(LU_INPUT)
CALL CHECKREAD('HEAT',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: HEAT is no longer a valid NAMELIST group. Read User Guide discussion on PROP and DEVC.')
REWIND(LU_INPUT)
CALL CHECKREAD('PDIM',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: PDIM is no longer a valid NAMELIST group. Read User Guide discussion on MESH.')
REWIND(LU_INPUT)
CALL CHECKREAD('PIPE',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: PIPE is no longer a valid NAMELIST group. Read User Guide discussion on PROP and DEVC.')
REWIND(LU_INPUT)
CALL CHECKREAD('PL3D',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: PL3D is no longer a valid NAMELIST group. Read User Guide discussion on DUMP.')
REWIND(LU_INPUT)
CALL CHECKREAD('SMOD',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: SMOD is no longer a valid NAMELIST group. Read User Guide discussion on DEVC.')
REWIND(LU_INPUT)
CALL CHECKREAD('SPRK',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: SPRK is no longer a valid NAMELIST group. Read User Guide discussion on PROP and DEVC.')
REWIND(LU_INPUT)
CALL CHECKREAD('THCP',LU_INPUT,IOS)
IF (IOS==0) CALL SHUTDOWN('ERROR: THCP is no longer a valid NAMELIST group. Read User Guide discussion on DEVC.')

REWIND(LU_INPUT)
 
END SUBROUTINE READ_DEAD

 
SUBROUTINE READ_HEAD
 
NAMELIST /HEAD/ TITLE,CHID,FYI
 
CHID    = 'output'
TITLE   = '      '
 
REWIND(LU_INPUT)
HEAD_LOOP: DO
   CALL CHECKREAD('HEAD',LU_INPUT,IOS)
   IF (IOS==1) EXIT HEAD_LOOP
   READ(LU_INPUT,HEAD,END=13,ERR=14,IOSTAT=IOS)
   14 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with HEAD line')
ENDDO HEAD_LOOP
13 REWIND(LU_INPUT)
 
CLOOP: DO I=1,39
   IF (CHID(I:I)=='.') CALL SHUTDOWN('ERROR: No periods allowed in CHID')
   IF (CHID(I:I)==' ') EXIT CLOOP
ENDDO CLOOP
 
INQUIRE(FILE=TRIM(CHID)//'.stop',EXIST=EX)
IF (EX) THEN
   WRITE(MESSAGE,'(A,A,A)') "ERROR: Remove the file, ", TRIM(CHID)//'.stop',", from the current directory"
   CALL SHUTDOWN(MESSAGE)
ENDIF
 
END SUBROUTINE READ_HEAD
 
 
SUBROUTINE READ_MESH

INTEGER :: IJK(3),NM
INTEGER :: IBAR2,JBAR2,KBAR2,POISSON_BC(6),IC,JC,KC,RGB(3)
LOGICAL :: EVACUATION, EVAC_HUMANS
CHARACTER(25) :: COLOR
REAL(EB) :: XB(6)
NAMELIST /MESH/ IJK,FYI,ID,SYNCHRONIZE,EVACUATION,EVAC_HUMANS,POISSON_BC, &
                IBAR2,JBAR2,KBAR2,CYLINDRICAL,XB,RGB,COLOR
TYPE (MESH_TYPE), POINTER :: M
 
NMESHES = 0
 
REWIND(LU_INPUT)
COUNT_MESH_LOOP: DO
   CALL CHECKREAD('MESH',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_MESH_LOOP
   READ(LU_INPUT,MESH,END=15,ERR=16,IOSTAT=IOS)
   NMESHES = NMESHES + 1
   16 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with MESH line.')
ENDDO COUNT_MESH_LOOP
15 CONTINUE


! Allocate parameters associated with the mesh.
 
ALLOCATE(MESHES(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','MESHES',IZERO)
ALLOCATE(MESH_NAME(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','MESH_NAME',IZERO)
ALLOCATE(TUSED(N_TIMERS,NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','TUSED',IZERO)
ALLOCATE(SYNC_TIME_STEP(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','SYNC_TIME_STEP',IZERO)
SYNC_TIME_STEP = .FALSE.
ALLOCATE(INTERPOLATED(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','INTERPOLATED',IZERO)
ALLOCATE(CHANGE_TIME_STEP(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','CHANGE_TIME_STEP',IZERO)
CHANGE_TIME_STEP = .FALSE.
ALLOCATE(EVACUATION_ONLY(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','EVACUATION_ONLY',IZERO)
EVACUATION_ONLY = .FALSE.
ALLOCATE(EVACUATION_GRID(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','EVACUATION_GRID',IZERO)
EVACUATION_GRID = .FALSE.
ALLOCATE(PBC(6,NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','PBC',IZERO)

! Read in the Mesh lines from Input file

REWIND(LU_INPUT)
 
MESH_LOOP: DO NM=1,NMESHES
   IJK(1)=10
   IJK(2)=10
   IJK(3)=10
   IBAR2=1
   JBAR2=1
   KBAR2=1
   TWO_D = .FALSE.
   XB(1) = 0._EB
   XB(2) = 1._EB
   XB(3) = 0._EB
   XB(4) = 1._EB
   XB(5) = 0._EB
   XB(6) = 1._EB
   RGB   = -1
   COLOR = 'null'
   CYLINDRICAL = .FALSE.
   ID = 'null'
   SYNCHRONIZE = .TRUE.
   EVACUATION  = .FALSE.
   EVAC_HUMANS = .FALSE.
   POISSON_BC  = -1
   WRITE(MESH_NAME(NM),'(A,I3)') 'MESH',NM
   CALL CHECKREAD('MESH',LU_INPUT,IOS)
   IF (IOS==1) EXIT MESH_LOOP
   READ(LU_INPUT,MESH)
   M => MESHES(NM)
   M%IBAR = IJK(1)
   M%JBAR = IJK(2)
   M%KBAR = IJK(3)
   M%IBAR2 = IBAR2
   M%JBAR2 = JBAR2
   M%KBAR2 = KBAR2
   M%NEWC = 2*M%IBAR*M%JBAR+2*M%IBAR*M%KBAR+2*M%JBAR*M%KBAR
   IF (SYNCHRONIZE) SYNC_TIME_STEP(NM)  = .TRUE.
   IF (EVACUATION)  EVACUATION_ONLY(NM) = .TRUE.
   IF (EVAC_HUMANS) EVACUATION_GRID(NM) = .TRUE.
   IF (M%JBAR==1) TWO_D = .TRUE.
   IF (TWO_D .AND. M%JBAR/=1) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: IJK(2) must be 1 for all grids in 2D Calculation'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   
   ! Mesh boundary colors
   
   IF (ANY(RGB<0) .AND. COLOR=='null') COLOR = 'BLACK'
   IF (COLOR /= 'null') CALL COLOR2RGB(RGB,COLOR)
   ALLOCATE(M%RGB(3))
   M%RGB = RGB
   
   ! Mesh Geometry and Name
   
   IF (NMESHES > 1 .AND. CYLINDRICAL) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: Cannot use more than 1 MESH when CYLINDRICAL=.TRUE.'
      CALL SHUTDOWN(MESSAGE)
   ENDIF 
   
   IF (ID/='null') MESH_NAME(NM) = ID
   
   ! Kevin's experimental Pressure code
   
   PBC(:,NM) = POISSON_BC(:)
   IF (MOD(M%IBAR,IBAR2)/=0 .OR. MOD(M%JBAR,JBAR2)/=0 .OR. MOD(M%KBAR,KBAR2)/=0) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: IBAR2, JBAR2 or KBAR2 not right'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   ALLOCATE(M%I_LO(IBAR2))
   ALLOCATE(M%I_HI(IBAR2))
   ALLOCATE(M%J_LO(JBAR2))
   ALLOCATE(M%J_HI(JBAR2))
   ALLOCATE(M%K_LO(KBAR2))
   ALLOCATE(M%K_HI(KBAR2))
   DO I=1,IBAR2
      M%I_LO(I) = NINT((I-1)*REAL(M%IBAR,EB)/REAL(IBAR2,EB)) + 1
      M%I_HI(I) = NINT( I   *REAL(M%IBAR,EB)/REAL(IBAR2,EB))
   ENDDO
   DO J=1,JBAR2
      M%J_LO(J) = NINT((J-1)*REAL(M%JBAR,EB)/REAL(JBAR2,EB)) + 1
      M%J_HI(J) = NINT( J   *REAL(M%JBAR,EB)/REAL(JBAR2,EB))
   ENDDO
   DO K=1,KBAR2
      M%K_LO(K) = NINT((K-1)*REAL(M%KBAR,EB)/REAL(KBAR2,EB)) + 1
      M%K_HI(K) = NINT( K   *REAL(M%KBAR,EB)/REAL(KBAR2,EB))
   ENDDO

   ! Process Physical Coordinates

   M%XS    = XB(1)
   M%XF    = XB(2)
   M%YS    = XB(3)
   M%YF    = XB(4)
   M%ZS    = XB(5)
   M%ZF    = XB(6)
   M%DXI   = (M%XF-M%XS)/REAL(M%IBAR,EB)
   M%DETA  = (M%YF-M%YS)/REAL(M%JBAR,EB)
   M%DZETA = (M%ZF-M%ZS)/REAL(M%KBAR,EB)
   M%RDXI  = 1._EB/M%DXI
   M%RDETA = 1._EB/M%DETA
   M%RDZETA= 1._EB/M%DZETA
   M%IBM1  = M%IBAR-1
   M%JBM1  = M%JBAR-1
   M%KBM1  = M%KBAR-1
   M%IBP1  = M%IBAR+1
   M%JBP1  = M%JBAR+1
   M%KBP1  = M%KBAR+1
ENDDO MESH_LOOP
REWIND(LU_INPUT)
 
! Set up coarse grid arrays for Kevin's Pressure Code
 
NCGC = 0
MESH_LOOP_2: DO NM=1,NMESHES
   IF(EVACUATION_ONLY(NM)) CYCLE MESH_LOOP_2
   M=>MESHES(NM)
   ALLOCATE(M%CGI(M%IBAR,M%JBAR,M%KBAR))
   ALLOCATE(M%CGI2(M%IBAR2,M%JBAR2,M%KBAR2))
   DO KC=1,M%KBAR2
      DO JC=1,M%JBAR2
         DO IC=1,M%IBAR2
            NCGC = NCGC+1
            M%CGI2(IC,JC,KC) = NCGC
            M%CGI(M%I_LO(IC):M%I_HI(IC), M%J_LO(JC):M%J_HI(JC), M%K_LO(KC):M%K_HI(KC)) = NCGC
         ENDDO
      ENDDO
   ENDDO
ENDDO MESH_LOOP_2
 
! Start the timing arrays
 
TUSED      = 0._EB
TUSED(1,:) = SECOND()
 
END SUBROUTINE READ_MESH



SUBROUTINE READ_TRAN
USE MATH_FUNCTIONS, ONLY : GAUSSJ
!
! Compute the polynomial transform function for the vertical coordinate
!
REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: A,XX
INTEGER, ALLOCATABLE, DIMENSION(:,:) :: ND
REAL(EB) :: PC,CC,COEF,XI,ETA,ZETA
INTEGER  IEXP,IC,IDERIV,N,K,IERROR,IOS,I,MESH_NUMBER, NIPX,NIPY,NIPZ,NIPXS,NIPYS,NIPZS,NIPXF,NIPYF,NIPZF,NM
TYPE (MESH_TYPE), POINTER :: M
TYPE (TRAN_TYPE), POINTER :: T
NAMELIST /TRNX/ IDERIV,CC,PC,FYI,MESH_NUMBER
NAMELIST /TRNY/ IDERIV,CC,PC,FYI,MESH_NUMBER
NAMELIST /TRNZ/ IDERIV,CC,PC,FYI,MESH_NUMBER
!
! Scan the input file, counting the number of NAMELIST entries
!
ALLOCATE(TRANS(NMESHES))
!
MESH_LOOP: DO NM=1,NMESHES
   M => MESHES(NM)
   T => TRANS(NM)
!
   DO N=1,3
      T%NOC(N) = 0
      TRNLOOP: DO
         SELECT CASE (N)
            CASE(1)
               CALL CHECKREAD('TRNX',LU_INPUT,IOS)
               IF (IOS==1) EXIT TRNLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,NML=TRNX,END=17,ERR=18,IOSTAT=IOS)
               IF (MESH_NUMBER/=NM) CYCLE TRNLOOP
            CASE(2)
               CALL CHECKREAD('TRNY',LU_INPUT,IOS)
               IF (IOS==1) EXIT TRNLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,NML=TRNY,END=17,ERR=18,IOSTAT=IOS)
               IF (MESH_NUMBER/=NM) CYCLE TRNLOOP
            CASE(3)
               CALL CHECKREAD('TRNZ',LU_INPUT,IOS)
               IF (IOS==1) EXIT TRNLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,NML=TRNZ,END=17,ERR=18,IOSTAT=IOS)
               IF (MESH_NUMBER/=NM) CYCLE TRNLOOP
         END SELECT
         T%NOC(N) = T%NOC(N) + 1
         18 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with TRN* line')
      ENDDO TRNLOOP
      17 REWIND(LU_INPUT)
   ENDDO
!
   T%NOCMAX = MAX(T%NOC(1),T%NOC(2),T%NOC(3))
   ALLOCATE(A(T%NOCMAX+1,T%NOCMAX+1))
   ALLOCATE(XX(T%NOCMAX+1,3))
   ALLOCATE(ND(T%NOCMAX+1,3))
   ALLOCATE(T%C1(0:T%NOCMAX+1,3))
   T%C1               = 0._EB
   T%C1(1,1:3)        = 1._EB
   ALLOCATE(T%C2(0:T%NOCMAX+1,3))
   ALLOCATE(T%C3(0:T%NOCMAX+1,3))
   ALLOCATE(T%CCSTORE(T%NOCMAX,3))
   ALLOCATE(T%PCSTORE(T%NOCMAX,3))
   ALLOCATE(T%IDERIVSTORE(T%NOCMAX,3))
!
   T%ITRAN  = 0
!
   DO IC=1,3
      NLOOP:  DO N=1,T%NOC(IC)
         IDERIV = -1
         IF (IC==1) THEN
            LOOP1: DO
               CALL CHECKREAD('TRNX',LU_INPUT,IOS)
               IF (IOS==1) EXIT NLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,TRNX,END=1,ERR=2)
               IF (MESH_NUMBER==NM) EXIT LOOP1
            ENDDO LOOP1
         ENDIF
         IF (IC==2) THEN
            LOOP2: DO
               CALL CHECKREAD('TRNY',LU_INPUT,IOS)
               IF (IOS==1) EXIT NLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,TRNY,END=1,ERR=2)
               IF (MESH_NUMBER==NM) EXIT LOOP2
            ENDDO LOOP2
         ENDIF
         IF (IC==3) THEN
            LOOP3: DO
               CALL CHECKREAD('TRNZ',LU_INPUT,IOS)
               IF (IOS==1) EXIT NLOOP
               MESH_NUMBER = 1
               READ(LU_INPUT,TRNZ,END=1,ERR=2)
               IF (MESH_NUMBER==NM) EXIT LOOP3
            ENDDO LOOP3
         ENDIF
         T%CCSTORE(N,IC) = CC
         T%PCSTORE(N,IC) = PC
         T%IDERIVSTORE(N,IC) = IDERIV
         IF (IDERIV>=0) T%ITRAN(IC) = 1
         IF (IDERIV<0)  T%ITRAN(IC) = 2
      2 CONTINUE
        ENDDO NLOOP
      1 REWIND(LU_INPUT)
   ENDDO 

   ICLOOP: DO IC=1,3

      SELECT CASE (T%ITRAN(IC))

         CASE (1)  ! polynomial transformation
            ND(1,IC)  = 0
            SELECT CASE(IC)
               CASE(1)
                  XX(1,IC)    = M%XF-M%XS
                  T%C1(1,IC)  = M%XF-M%XS
               CASE(2)
                  XX(1,IC)    = M%YF-M%YS
                  T%C1(1,IC)  = M%YF-M%YS
               CASE(3)
                  XX(1,IC)    = M%ZF-M%ZS
                  T%C1(1,IC)  = M%ZF-M%ZS
            END SELECT

            NNLOOP:  DO N=2,T%NOC(IC)+1
               IDERIV = T%IDERIVSTORE(N-1,IC)
               IF (IC==1) CC = T%CCSTORE(N-1,IC)-M%XS
               IF (IC==2) CC = T%CCSTORE(N-1,IC)-M%YS
               IF (IC==3) CC = T%CCSTORE(N-1,IC)-M%ZS
               IF (IC==1 .AND. IDERIV==0) PC = T%PCSTORE(N-1,IC)-M%XS
               IF (IC==2 .AND. IDERIV==0) PC = T%PCSTORE(N-1,IC)-M%YS
               IF (IC==3 .AND. IDERIV==0) PC = T%PCSTORE(N-1,IC)-M%ZS
               IF (IC==1 .AND. IDERIV>0) PC = T%PCSTORE(N-1,IC)
               IF (IC==2 .AND. IDERIV>0) PC = T%PCSTORE(N-1,IC)
               IF (IC==3 .AND. IDERIV>0) PC = T%PCSTORE(N-1,IC)
               ND(N,IC) = IDERIV
               XX(N,IC) = CC
               T%C1(N,IC) = PC
            ENDDO NNLOOP

            DO K=1,T%NOC(IC)+1
               DO N=1,T%NOC(IC)+1
                  COEF = IFAC(K,ND(N,IC))
                  IEXP = K-ND(N,IC)
                  IF (IEXP<0) A(N,K) = 0._EB
                  IF (IEXP==0) A(N,K) = COEF
                  IF (IEXP>0) A(N,K) = COEF*XX(N,IC)**IEXP
               ENDDO
            ENDDO

            IERROR = 0
            CALL GAUSSJ(A,T%NOC(IC)+1,T%NOCMAX+1,T%C1(1:T%NOCMAX+1,IC),1,1,IERROR)
            IF (IERROR/=0)CALL SHUTDOWN('ERROR: Problem with grid transformation')

         CASE (2)  ! linear transformation

            T%C1(0,IC) = 0._EB
            T%C2(0,IC) = 0._EB
            DO N=1,T%NOC(IC)
               IF (IC==1) CC = T%CCSTORE(N,IC)-M%XS
               IF (IC==2) CC = T%CCSTORE(N,IC)-M%YS
               IF (IC==3) CC = T%CCSTORE(N,IC)-M%ZS
               IF (IC==1) PC = T%PCSTORE(N,IC)-M%XS
               IF (IC==2) PC = T%PCSTORE(N,IC)-M%YS
               IF (IC==3) PC = T%PCSTORE(N,IC)-M%ZS
               T%C1(N,IC) = CC
               T%C2(N,IC) = PC
            ENDDO

            SELECT CASE(IC)
               CASE(1)
                  T%C1(T%NOC(1)+1,1) = M%XF-M%XS
                  T%C2(T%NOC(1)+1,1) = M%XF-M%XS
               CASE(2)
                  T%C1(T%NOC(2)+1,2) = M%YF-M%YS
                  T%C2(T%NOC(2)+1,2) = M%YF-M%YS
               CASE(3)
                  T%C1(T%NOC(3)+1,3) = M%ZF-M%ZS
                  T%C2(T%NOC(3)+1,3) = M%ZF-M%ZS
            END SELECT

            DO N=1,T%NOC(IC)+1
               T%C3(N,IC) = (T%C2(N,IC)-T%C2(N-1,IC))/(T%C1(N,IC)-T%C1(N-1,IC))
            ENDDO
      END SELECT
   ENDDO ICLOOP

   DEALLOCATE(A)
   DEALLOCATE(XX)
   DEALLOCATE(ND)
!
! Set up grid stretching arrays
!
   ALLOCATE(M%R(0:M%IBAR),STAT=IZERO)
   CALL ChkMemErr('READ','R',IZERO)
   ALLOCATE(M%RC(0:M%IBAR+1),STAT=IZERO)
   CALL ChkMemErr('READ','RC',IZERO)
   M%RC = 1._EB
   ALLOCATE(M%RRN(0:M%IBP1),STAT=IZERO)
   CALL ChkMemErr('READ','RRN',IZERO)
   M%RRN = 1._EB
   ALLOCATE(M%X(0:M%IBAR),STAT=IZERO)
   CALL ChkMemErr('READ','X',IZERO)
   ALLOCATE(M%XC(0:M%IBP1),STAT=IZERO)
   CALL ChkMemErr('READ','XC',IZERO)
   ALLOCATE(M%HX(0:M%IBP1),STAT=IZERO)
   CALL ChkMemErr('READ','HX',IZERO)
   ALLOCATE(M%DX(0:M%IBP1),STAT=IZERO)
   CALL ChkMemErr('READ','DX',IZERO)
   ALLOCATE(M%RDX(0:M%IBP1),STAT=IZERO)
   CALL ChkMemErr('READ','RDX',IZERO)
   ALLOCATE(M%DXN(0:M%IBAR),STAT=IZERO)
   CALL ChkMemErr('READ','DXN',IZERO)
   ALLOCATE(M%RDXN(0:M%IBAR),STAT=IZERO)
   CALL ChkMemErr('READ','RDXN',IZERO)
   ALLOCATE(M%Y(0:M%JBAR),STAT=IZERO)
   CALL ChkMemErr('READ','Y',IZERO)
   ALLOCATE(M%YC(0:M%JBP1),STAT=IZERO)
   CALL ChkMemErr('READ','YC',IZERO)
   ALLOCATE(M%HY(0:M%JBP1),STAT=IZERO)
   CALL ChkMemErr('READ','HY',IZERO)
   ALLOCATE(M%DY(0:M%JBP1),STAT=IZERO)
   CALL ChkMemErr('READ','DY',IZERO)
   ALLOCATE(M%RDY(0:M%JBP1),STAT=IZERO)
   CALL ChkMemErr('READ','RDY',IZERO)
   ALLOCATE(M%DYN(0:M%JBAR),STAT=IZERO)
   CALL ChkMemErr('READ','DYN',IZERO)
   ALLOCATE(M%RDYN(0:M%JBAR),STAT=IZERO)
   CALL ChkMemErr('READ','RDYN',IZERO)
   ALLOCATE(M%Z(0:M%KBAR),STAT=IZERO)
   CALL ChkMemErr('READ','Z',IZERO)
   ALLOCATE(M%ZC(0:M%KBP1),STAT=IZERO)
   CALL ChkMemErr('READ','ZC',IZERO)
   ALLOCATE(M%HZ(0:M%KBP1),STAT=IZERO)
   CALL ChkMemErr('READ','HZ',IZERO)
   ALLOCATE(M%DZ(0:M%KBP1),STAT=IZERO)
   CALL ChkMemErr('READ','DZ',IZERO)
   ALLOCATE(M%RDZ(0:M%KBP1),STAT=IZERO)
   CALL ChkMemErr('READ','RDZ',IZERO)
   ALLOCATE(M%DZN(0:M%KBAR),STAT=IZERO)
   CALL ChkMemErr('READ','DZN',IZERO)
   ALLOCATE(M%RDZN(0:M%KBAR),STAT=IZERO)
   CALL ChkMemErr('READ','RDZN',IZERO)
!
! Define X grid stretching terms
!
   M%DXMIN = 1000._EB
   DO I=1,M%IBAR
      XI    = (REAL(I,EB)-.5)*M%DXI
      M%HX(I) = GP(XI,1,NM)
      M%DX(I) = M%HX(I)*M%DXI
      M%DXMIN = MIN(M%DXMIN,M%DX(I))
      IF (M%HX(I)<=0._EB) THEN
         WRITE(MESSAGE,'(A,I2)')  'ERROR: x transformation not monotonic, mesh ',NM
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      M%RDX(I) = 1._EB/M%DX(I)
   ENDDO
!
   M%HX(0)    = M%HX(1)
   M%HX(M%IBP1) = M%HX(M%IBAR)
   M%DX(0)    = M%DX(1)
   M%DX(M%IBP1) = M%DX(M%IBAR)
   M%RDX(0)    = 1._EB/M%DX(1)
   M%RDX(M%IBP1) = 1._EB/M%DX(M%IBAR)
!
   DO I=0,M%IBAR
      XI     = I*M%DXI
      M%X(I) = M%XS + G(XI,1,NM)
      IF (CYLINDRICAL) THEN
         M%R(I) = M%X(I)
      ELSE
         M%R(I) = 1._EB
      ENDIF
      M%DXN(I)  = 0.5_EB*(M%DX(I)+M%DX(I+1))
      M%RDXN(I) = 1._EB/M%DXN(I)
   ENDDO
   M%X(0)      = M%XS
   M%X(M%IBAR) = M%XF
!
   DO I=1,M%IBAR
      M%XC(I) = 0.5_EB*(M%X(I)+M%X(I-1))
   ENDDO
   M%XC(0)      = M%XS - 0.5_EB*M%DX(0)
   M%XC(M%IBP1) = M%XF + 0.5_EB*M%DX(M%IBP1)
!
   IF (CYLINDRICAL) THEN  
      DO I=1,M%IBAR
         M%RRN(I) = 2._EB/(M%R(I)+M%R(I-1))
         M%RC(I)  = 0.5_EB*(M%R(I)+M%R(I-1))
      ENDDO
      M%RRN(0)    = M%RRN(1)
      M%RRN(M%IBP1) = M%RRN(M%IBAR)
   ENDIF
!
! Define Y grid stretching terms
!
   M%DYMIN = 1000._EB
   DO J=1,M%JBAR
      ETA   = (REAL(J,EB)-.5)*M%DETA
      M%HY(J) = GP(ETA,2,NM)
      M%DY(J) = M%HY(J)*M%DETA
      M%DYMIN = MIN(M%DYMIN,M%DY(J))
      IF (M%HY(J)<=0._EB) THEN
         WRITE(MESSAGE,'(A,I2)')  'ERROR: y transformation not monotonic, mesh ',NM
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      M%RDY(J) = 1._EB/M%DY(J)
   ENDDO
!
   M%HY(0)    = M%HY(1)
   M%HY(M%JBP1) = M%HY(M%JBAR)
   M%DY(0)    = M%DY(1)
   M%DY(M%JBP1) = M%DY(M%JBAR)
   M%RDY(0)    = 1._EB/M%DY(1)
   M%RDY(M%JBP1) = 1._EB/M%DY(M%JBAR)
!
   DO J=0,M%JBAR
      ETA     = J*M%DETA
      M%Y(J)    = M%YS + G(ETA,2,NM)
      M%DYN(J)  = 0.5_EB*(M%DY(J)+M%DY(J+1))
      M%RDYN(J) = 1._EB/M%DYN(J)
   ENDDO
!
   M%Y(0)      = M%YS
   M%Y(M%JBAR) = M%YF
!
   DO J=1,M%JBAR
      M%YC(J) = 0.5_EB*(M%Y(J)+M%Y(J-1))
   ENDDO
   M%YC(0)      = M%YS - 0.5_EB*M%DY(0)
   M%YC(M%JBP1) = M%YF + 0.5_EB*M%DY(M%JBP1)
!
! Define Z grid stretching terms
!
   M%DZMIN = 1000._EB
   DO K=1,M%KBAR
      ZETA  = (REAL(K,EB)-.5)*M%DZETA
      M%HZ(K) = GP(ZETA,3,NM)
      M%DZ(K) = M%HZ(K)*M%DZETA
      M%DZMIN = MIN(M%DZMIN,M%DZ(K))
      IF (M%HZ(K)<=0._EB) THEN
         WRITE(MESSAGE,'(A,I2)') 'ERROR: z transformation not monotonic, mesh ',NM
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      M%RDZ(K) = 1._EB/M%DZ(K)
   ENDDO
!
   M%HZ(0)    = M%HZ(1)
   M%HZ(M%KBP1) = M%HZ(M%KBAR)
   M%DZ(0)    = M%DZ(1)
   M%DZ(M%KBP1) = M%DZ(M%KBAR)
   M%RDZ(0)    = 1._EB/M%DZ(1)
   M%RDZ(M%KBP1) = 1._EB/M%DZ(M%KBAR)
!
   DO K=0,M%KBAR
      ZETA      = K*M%DZETA
      M%Z(K)    = M%ZS + G(ZETA,3,NM)
      M%DZN(K)  = 0.5_EB*(M%DZ(K)+M%DZ(K+1))
      M%RDZN(K) = 1._EB/M%DZN(K)
   ENDDO
!
   M%Z(0)      = M%ZS
   M%Z(M%KBAR) = M%ZF
!
   DO K=1,M%KBAR
      M%ZC(K) = 0.5_EB*(M%Z(K)+M%Z(K-1))
   ENDDO
   M%ZC(0)      = M%ZS - 0.5_EB*M%DZ(0)
   M%ZC(M%KBP1) = M%ZF + 0.5_EB*M%DZ(M%KBP1)
!
! Set up arrays that will return coordinate positions
!
   NIPX   = 100*M%IBAR
   NIPY   = 100*M%JBAR
   NIPZ   = 100*M%KBAR
   NIPXS  = NINT(NIPX*M%DX(0)/(M%XF-M%XS))
   NIPXF  = NINT(NIPX*M%DX(M%IBP1)/(M%XF-M%XS))
   NIPYS  = NINT(NIPY*M%DY(0)/(M%YF-M%YS))
   NIPYF  = NINT(NIPY*M%DY(M%JBP1)/(M%YF-M%YS))
   NIPZS  = NINT(NIPZ*M%DZ(0)/(M%ZF-M%ZS))
   NIPZF  = NINT(NIPZ*M%DZ(M%KBP1)/(M%ZF-M%ZS))
   M%RDXINT = REAL(NIPX,EB)/(M%XF-M%XS)
   M%RDYINT = REAL(NIPY,EB)/(M%YF-M%YS)
   M%RDZINT = REAL(NIPZ,EB)/(M%ZF-M%ZS)
!
   ALLOCATE(M%CELLSI(-NIPXS:NIPX+NIPXF),STAT=IZERO)
   CALL ChkMemErr('READ','CELLSI',IZERO)
   ALLOCATE(M%CELLSJ(-NIPYS:NIPY+NIPYF),STAT=IZERO)
   CALL ChkMemErr('READ','CELLSJ',IZERO)
   ALLOCATE(M%CELLSK(-NIPZS:NIPZ+NIPZF),STAT=IZERO)
   CALL ChkMemErr('READ','CELLSK',IZERO)
!
   DO I=-NIPXS,NIPX+NIPXF
      M%CELLSI(I) = GINV(REAL(I,EB)/M%RDXINT,1,NM)*M%RDXI
      M%CELLSI(I) = MAX(M%CELLSI(I),-0.9_EB)
      M%CELLSI(I) = MIN(M%CELLSI(I),REAL(M%IBAR)+0.9_EB)
   ENDDO
   DO J=-NIPYS,NIPY+NIPYF
      M%CELLSJ(J) = GINV(REAL(J,EB)/M%RDYINT,2,NM)*M%RDETA
      M%CELLSJ(J) = MAX(M%CELLSJ(J),-0.9_EB)
      M%CELLSJ(J) = MIN(M%CELLSJ(J),REAL(M%JBAR)+0.9_EB)
   ENDDO
   DO K=-NIPZS,NIPZ+NIPZF
      M%CELLSK(K) = GINV(REAL(K,EB)/M%RDZINT,3,NM)*M%RDZETA
      M%CELLSK(K) = MAX(M%CELLSK(K),-0.9_EB)
      M%CELLSK(K) = MIN(M%CELLSK(K),REAL(M%KBAR)+0.9_EB)
   ENDDO
 
ENDDO MESH_LOOP
 
 
CONTAINS
 
INTEGER FUNCTION IFAC(II,N)
INTEGER II,N
IFAC = 1
DO I=II-N+1,II
   IFAC = IFAC*I
ENDDO
END FUNCTION IFAC

END SUBROUTINE READ_TRAN
 
 
SUBROUTINE READ_TIME
 
REAL(EB) :: DT,VEL_CHAR,TWFIN
INTEGER :: NM
NAMELIST /TIME/ DT,T_BEGIN,T_END,TWFIN,FYI,WALL_INCREMENT,SYNCHRONIZE, &
                EVAC_DT_FLOWFIELD,EVAC_DT_STEADY_STATE,TIME_SHRINK_FACTOR
TYPE (MESH_TYPE), POINTER :: M
 
DT                   = -1._EB
EVAC_DT_FLOWFIELD    = 0.01_EB
EVAC_DT_STEADY_STATE = 0.05_EB
SYNCHRONIZE          = .FALSE.
TIME_SHRINK_FACTOR   = 1._EB
T_BEGIN              = 0._EB
T_END                = -9999999_EB
TWFIN                = -99999999._EB
WALL_INCREMENT       = 2
 
REWIND(LU_INPUT)
READ_TIME_LOOP: DO
   CALL CHECKREAD('TIME',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_TIME_LOOP
   READ(LU_INPUT,TIME,END=21,ERR=22,IOSTAT=IOS)
   22 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with TIME line')
   IF (TWFIN > T_END) T_END=TWFIN
ENDDO READ_TIME_LOOP
21 REWIND(LU_INPUT)
 
IF (T_END<=T_BEGIN) SET_UP = .TRUE.
T_END = T_BEGIN + (T_END-T_BEGIN)/TIME_SHRINK_FACTOR
 
IF (SYNCHRONIZE) SYNC_TIME_STEP = .TRUE.
IF (ANY(SYNC_TIME_STEP)) SYNCHRONIZE = .TRUE.
 
MESH_LOOP: DO NM=1,NMESHES
   M=>MESHES(NM)
   IF (DT>0._EB) THEN
      M%DT = DT
   ELSE
      VEL_CHAR = 0.2_EB*SQRT(10._EB*(M%ZF-M%ZS))
      IF (TWO_D) THEN
         M%DT=(M%DXMIN*M%DZMIN)**(1._EB/2._EB)/VEL_CHAR
      ELSE
         M%DT=(M%DXMIN*M%DYMIN*M%DZMIN)**(1._EB/3._EB)/VEL_CHAR
      ENDIF
   ENDIF
   IF (EVACUATION_ONLY(NM)) THEN
      SYNC_TIME_STEP(NM) = .FALSE.
      M%DT = EVAC_DT_FLOWFIELD
   ENDIF
ENDDO MESH_LOOP
 
END SUBROUTINE READ_TIME
 
 
SUBROUTINE READ_MISC
USE MATH_FUNCTIONS, ONLY: GET_RAMP_INDEX
 
REAL(EB) :: X_H2O_TMPA,X_H2O_40_C,C_HORIZONTAL,C_VERTICAL,MW,VISCOSITY,CONDUCTIVITY
CHARACTER(30) :: RAMP_GX,RAMP_GY,RAMP_GZ
NAMELIST /MISC/ PR,SC,TMPA,GVEC,RELAXATION_FACTOR,FYI, &
                CSMAG,RAMP_GX,RAMP_GY,RAMP_GZ,BAROCLINIC, &
                LAPSE_RATE,ISOTHERMAL, &
                P_INF,SURF_DEFAULT,EVAC_SURF_DEFAULT, &
                C_FORCED,C_VERTICAL,C_HORIZONTAL,H_FIXED,RESTART,ASSUMED_GAS_TEMPERATURE, &
                BACKGROUND_SPECIES,MW,LES,DNS, &
                VISCOSITY,CONDUCTIVITY,NOISE, &
                RADIATION,GAMMA,BNDF_DEFAULT, &
                U0,V0,W0,HUMIDITY, &
                POROUS_FLOOR,SUPPRESSION,CO_PRODUCTION, &
                TEXTURE_ORIGIN,NSTRATA, &
                THICKEN_OBSTRUCTIONS, &
                EVAC_PRESSURE_ITERATIONS,EVAC_TIME_ITERATIONS, &
                PRESSURE_CORRECTION,CHECK_POISSON,STRATIFICATION,RESTART_CHID, &
                CFL_MAX,CFL_MIN,VN_MAX,VN_MIN,SOLID_PHASE_ONLY
 
! Physical constants
 
R0      = 8314.472_EB     ! Universal Gas Constant (J/kmol/K) (NIST Physics Constants)
R1      = 1.986257E-03_EB ! Universal Gas Constant (kcal/mol/K)
TMPA    = 20._EB        ! Ambient temperature (C)
GRAV    = 9.80665_EB    ! Acceleration of gravity (m/s**2)
GAMMA   = 1.4_EB        ! Heat capacity ratio for air
P_INF   = 101325._EB    ! Ambient pressure (Pa)
P_STP   = 101325._EB    ! Standard pressure (Pa)
TMPM    = 273.15_EB     ! Melting temperature of water (K)
SIGMA   = 5.67E-8_EB    ! Stefan-Boltzmann constant (W/m**2/K**4)
C_P_W   = 4184._EB           ! Specific Heat of Water (J/kg/K)
H_V_W   = 2259._EB*1000._EB  ! Heat of Vap of Water (J/kg)
MW_AIR  = 28.8_EB        ! g/mol
MW_SOOT = 0.9_EB * 12._EB + 0.1_EB * 1._EB
HUMIDITY= -1._EB                           ! Relative Humidity
RHO_SOOT= 1850._EB                         ! Density of soot particle (kg/m3)
RESTART_CHID = CHID
 
! Empirical heat transfer constants
 
C_VERTICAL   = 1.31_EB  ! Vertical free convection (Holman, Table 7-2)
C_HORIZONTAL = 1.52_EB  ! Horizontal free convection 
C_FORCED     = 0.037_EB ! Forced convection coefficient
H_FIXED                 = -1.      ! Fixed heat transfer coefficient, used for diagnostics
ASSUMED_GAS_TEMPERATURE = -1000.   ! Assumed gas temperature, used for diagnostics
 
! Often used numbers
 
PI      = 4._EB*ATAN(1.0_EB)
RPI     = 1._EB/PI
TWOPI   = 2._EB*PI
PIO2    = PI/2._EB
ONTH    = 1._EB/3._EB
THFO    = 3._EB/4._EB
ONSI    = 1._EB/6._EB
TWTH    = 2._EB/3._EB
FOTH    = 4._EB/3._EB
RFPI    = 1._EB/(4._EB*PI)
 
! Background parameters
 
U0 = 0._EB
V0 = 0._EB
W0 = 0._EB
BACKGROUND_SPECIES = 'AIR'
VISCOSITY = -1._EB
CONDUCTIVITY = -1._EB
MU_USER = -1._EB
K_USER  = -1._EB
MW      = 0._EB   

! Logical constants

RESTART        = .FALSE.
RADIATION      = .TRUE.
SUPPRESSION    = .TRUE.
CO_PRODUCTION  = .FALSE.
CHECK_POISSON  = .FALSE.
BAROCLINIC     = .FALSE.
NOISE          = .TRUE.
ISOTHERMAL     = .FALSE.  
BNDF_DEFAULT   = .TRUE.
LES            = .TRUE.
DNS            = .FALSE.
POROUS_FLOOR   = .TRUE.
PRESSURE_CORRECTION  = .FALSE.
STRATIFICATION = .TRUE.
SOLID_PHASE_ONLY = .FALSE.

TEXTURE_ORIGIN(1) = 0._EB
TEXTURE_ORIGIN(2) = 0._EB
TEXTURE_ORIGIN(3) = 0._EB
 
! EVACuation parameters
 
EVAC_PRESSURE_ITERATIONS = 50
EVAC_TIME_ITERATIONS     = 50
 
! LES parameters
 
CSMAG                = 0.20_EB  ! Smagorinsky constant
PR                   = -1.0_EB  ! Turbulent Prandtl number
SC                   = -1.0_EB  ! Turbulent Schmidt number
 
! Misc
 
RAMP_GX              = 'null'
RAMP_GY              = 'null'
RAMP_GZ              = 'null'
SURF_DEFAULT         = 'INERT'
EVAC_SURF_DEFAULT    = 'INERT'
GVEC(1)              = 0._EB        ! x-component of gravity 
GVEC(2)              = 0._EB        ! y-component of gravity 
GVEC(3)              = -GRAV        ! z-component of gravity 
LAPSE_RATE           = 0._EB       
RELAXATION_FACTOR    = 1.00_EB      ! Relaxation factor for no-flux
NSTRATA              = 7            ! Number bins for drop dist.
THICKEN_OBSTRUCTIONS = .FALSE.
CFL_MAX              = 1.0_EB       ! Stability bounds
CFL_MIN              = 0.8_EB
VN_MAX               = 1.0_EB
VN_MIN               = 0.8_EB
 
REWIND(LU_INPUT)
MISC_LOOP: DO 
   CALL CHECKREAD('MISC',LU_INPUT,IOS)
   IF (IOS==1) EXIT MISC_LOOP
   READ(LU_INPUT,MISC,END=23,ERR=24,IOSTAT=IOS)
   24 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with MISC line')
ENDDO MISC_LOOP
23 REWIND(LU_INPUT)
 
! Temperature conversions

H0    = 0.5_EB*(U0**2+V0**2+W0**2)
TMPA  = TMPA + TMPM
TMPA4 = TMPA**4
 
! Humidity (40% by default, but limited for high temps)
 
IF (HUMIDITY < 0._EB) THEN
   X_H2O_TMPA = MIN( 1._EB , EXP(-(H_V_W*MW_H2O/R0)*(1._EB/TMPA     -1._EB/373.15_EB)) )
   X_H2O_40_C =              EXP(-(H_V_W*MW_H2O/R0)*(1._EB/313.15_EB-1._EB/373.15_EB))
   HUMIDITY = 40._EB*MIN( 1._EB , X_H2O_40_C/X_H2O_TMPA )
ENDIF
 
! Miscellaneous
 
MW_BACKGROUND = MW
MU_USER(0) = VISCOSITY
K_USER(0)  = CONDUCTIVITY
HCH    = C_HORIZONTAL
HCV    = C_VERTICAL
IF (ISOTHERMAL) RADIATION = .FALSE.
C_FORCED = C_FORCED*(1012._EB)*(1.8E-5_EB)**0.2_EB / (0.7_EB)**(2._EB/3._EB)
ASSUMED_GAS_TEMPERATURE = ASSUMED_GAS_TEMPERATURE + TMPM
TEX_ORI = TEXTURE_ORIGIN
 
IF (PRESSURE_CORRECTION) THEN
   SYNCHRONIZE = .TRUE.
   SYNC_TIME_STEP = .TRUE.
ENDIF
 
! Gravity ramp
 
I_RAMP_GX   = 0
I_RAMP_GY   = 0
I_RAMP_GZ   = 0
N_RAMP      = 0
IF (RAMP_GX/='null') CALL GET_RAMP_INDEX(RAMP_GX,'TIME',I_RAMP_GX)
IF (RAMP_GY/='null') CALL GET_RAMP_INDEX(RAMP_GY,'TIME',I_RAMP_GY)
IF (RAMP_GZ/='null') CALL GET_RAMP_INDEX(RAMP_GZ,'TIME',I_RAMP_GZ)
 
! Prandtl and Schmidt numbers
 
IF (DNS) THEN
   BAROCLINIC       = .TRUE.
   LES              = .FALSE.
   IF (PR<0._EB) PR = 0.7_EB
   IF (SC<0._EB) SC = 1.0_EB
ELSE
   IF (PR<0._EB) PR = 0.5_EB
   IF (SC<0._EB) SC = 0.5_EB
ENDIF
 
RSC = 1._EB/SC
RPR = 1._EB/PR
 
! Check for a restart file
 
APPEND = .FALSE.
IF (RESTART .AND. RESTART_CHID == CHID) APPEND = .TRUE.
IF (RESTART) NOISE  = .FALSE.
 
! Min and Max values of species and temperature
 
TMPMIN = TMPM
IF (LAPSE_RATE < 0._EB) TMPMIN = MIN(TMPMIN,TMPA+LAPSE_RATE*MESHES(1)%ZF)
TMPMAX = 3000._EB
YYMIN  = 0._EB
YYMAX  = 1._EB

IF (.NOT. SUPPRESSION .AND. CO_PRODUCTION) THEN
   WRITE(MESSAGE,'(A)')  'Cannot set SUPPRESSION=.FALSE. when CO_PRODUCTION=.TRUE.'
   CALL SHUTDOWN(MESSAGE)
ENDIF 
 
END SUBROUTINE READ_MISC

SUBROUTINE READ_DUMP

! Read parameters associated with output files
 
INTEGER :: N,ND
NAMELIST /DUMP/ RENDER_FILE,SMOKE3D,SMOKE3D_COMPRESSION,FLUSH_FILE_BUFFERS,MASS_FILE, &
                DT_CTRL,DT_PART,DT_MASS,DT_HRR,DT_DEVC,DT_PROF,DT_SLCF,DT_PL3D,DT_ISOF,DT_BNDF, &
                NFRAMES,DT_RESTART,DEBUG,TIMING,COLUMN_DUMP_LIMIT,MAXIMUM_DROPLETS,WRITE_XYZ,PLOT3D_QUANTITY
 
RENDER_FILE          = 'null'
NFRAMES              = 1000 
SMOKE3D              = .TRUE.
IF (TWO_D .OR. N_REACTIONS==0 .OR. SOLID_PHASE_ONLY) SMOKE3D = .FALSE.
SMOKE3D_COMPRESSION  = 'RLE'
DEBUG                = .FALSE.
TIMING               = .FALSE.
FLUSH_FILE_BUFFERS   = .TRUE.
PLOT3D_QUANTITY(1) = 'TEMPERATURE'
PLOT3D_QUANTITY(2) = 'U-VELOCITY'
PLOT3D_QUANTITY(3) = 'V-VELOCITY'
PLOT3D_QUANTITY(4) = 'W-VELOCITY'
PLOT3D_QUANTITY(5) = 'HRRPUV'
IF (ISOTHERMAL) PLOT3D_QUANTITY(5) = 'PRESSURE'
MASS_FILE = .FALSE.
WRITE_XYZ            = .FALSE.
MAXIMUM_DROPLETS        = 500000
COLUMN_DUMP_LIMIT = .TRUE.  ! Limit csv files to 255 columns
 
DT_BNDF = -1.
DT_RESTART = 1000000._EB
DT_DEVC = -1.
DT_HRR  = -1.
DT_ISOF = -1.
DT_MASS = -1.
DT_PART = -1.
DT_PL3D = -1.
DT_PROF = -1.
DT_SLCF = -1.
DT_CTRL = -1.
 
REWIND(LU_INPUT)
DUMP_LOOP: DO 
   CALL CHECKREAD('DUMP',LU_INPUT,IOS)
   IF (IOS==1) EXIT DUMP_LOOP
   READ(LU_INPUT,DUMP,END=23,ERR=24,IOSTAT=IOS)
   24 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with DUMP line')
ENDDO DUMP_LOOP
23 REWIND(LU_INPUT)
IF (DT_BNDF < 0._EB) DT_BNDF = 2._EB * (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_DEVC < 0._EB) DT_DEVC = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_HRR  < 0._EB) DT_HRR  = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_ISOF < 0._EB) DT_ISOF = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_MASS < 0._EB) DT_MASS = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_PART < 0._EB) DT_PART = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_PL3D < 0._EB) DT_PL3D = (T_END - T_BEGIN)/5._EB
IF (DT_PROF < 0._EB) DT_PROF = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_SLCF < 0._EB) DT_SLCF = (T_END - T_BEGIN)/REAL(NFRAMES,EB)
IF (DT_CTRL < 0._EB) DT_CTRL = (T_END - T_BEGIN)/REAL(NFRAMES,EB)

! Check Plot3D QUANTITIES

PLOOP: DO N=1,5
   DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
      IF (PLOT3D_QUANTITY(N)==OUTPUT_QUANTITY(ND)%NAME) THEN
         PLOT3D_QUANTITY_INDEX(N) = ND
         IF (OUTPUT_QUANTITY(ND)%MIXTURE_FRACTION_ONLY .AND. .NOT.MIXTURE_FRACTION) THEN
            WRITE(MESSAGE,'(3A)')  'ERROR: PLOT3D quantity ',TRIM(PLOT3D_QUANTITY(N)), ' not appropriate for non-mixture fraction'
            CALL SHUTDOWN(MESSAGE)
         ENDIF 
         IF (OUTPUT_QUANTITY(ND)%SOLID_PHASE) THEN
            WRITE(MESSAGE,'(3A)') 'ERROR: PLOT3D quantity ',TRIM(PLOT3D_QUANTITY(N)), ' not appropriate for gas phase'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         IF (OUTPUT_QUANTITY(ND)%PART_APPROPRIATE) THEN
            WRITE(MESSAGE,'(3A)')  'ERROR: PLOT3D quantity ',TRIM(PLOT3D_QUANTITY(N)), ' not appropriate as Plot3D'
            CALL SHUTDOWN(MESSAGE)
         ENDIF 
         CYCLE PLOOP
      ENDIF
   ENDDO
   WRITE(MESSAGE,'(3A)') 'ERROR: PLOT3D quantity ', TRIM(PLOT3D_QUANTITY(N)),' not found'
   CALL SHUTDOWN(MESSAGE)
ENDDO PLOOP

END SUBROUTINE READ_DUMP


 
SUBROUTINE READ_SPEC
 
REAL(EB) :: MASS_FRACTION_0,MW, SIGMALJ,EPSILONKLJ,XVAP,VISCOSITY,CONDUCTIVITY,DIFFUSIVITY
INTEGER  :: N_SPEC_READ,N_SPEC_EXTRA,N_MIX,N,NN
LOGICAL  :: ABSORBING
NAMELIST /SPEC/ MASS_FRACTION_0,MW,FYI,ID,SIGMALJ, EPSILONKLJ,CONDUCTIVITY, VISCOSITY,DIFFUSIVITY, ABSORBING
 
! Zero out indices of various species
 
I_WATER   = 0
I_FUEL    = 0
I_PROG_F  = 0
I_PROG_CO = 0
I_CO2     = 0
I_CO      = 0
I_O2      = 0
I_SOOT    = 0
 
! Count SPEC lines and check for errors
 
N_SPECIES = 0
N_SPEC_READ = 0
REWIND(LU_INPUT)
COUNT_SPEC_LOOP: DO
   CALL CHECKREAD('SPEC',LU_INPUT,IOS) 
   IF (IOS==1) EXIT COUNT_SPEC_LOOP
   ID = 'null'
   READ(LU_INPUT,NML=SPEC,END=29,ERR=30,IOSTAT=IOS)
   IF (ID=='null') THEN
      WRITE(MESSAGE,'(A,I2,A)') 'ERROR: Species',N_SPECIES+1, 'needs a name (ID=...)'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   N_SPECIES = N_SPECIES + 1
   N_SPEC_READ = N_SPEC_READ + 1   
   IF (ID=='WATER VAPOR')     I_WATER = N_SPECIES
   IF (ID=='CARBON DIOXIDE')  I_CO2   = N_SPECIES
   IF (ID=='CARBON MONOXIDE') I_CO    = N_SPECIES      
   IF (ID=='OXYGEN')          I_O2    = N_SPECIES            
   IF (ID=='SOOT')            I_SOOT  = N_SPECIES            
   IF (MIXTURE_FRACTION .AND. (ID=='MIXTURE_FRACTION_1' .OR. ID=='MIXTURE_FRACTION2' .OR. &
      (CO_PRODUCTION .AND. ID=='MIXTURE_FRACTION_3'))) N_SPECIES = N_SPECIES - 1
   30 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I2)') 'ERROR: Problem with SPECies number',N_SPECIES+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_SPEC_LOOP
29 REWIND(LU_INPUT)
N_SPEC_EXTRA = N_SPECIES 
! Add other "SPECies" to the list
 
N_MIX = 0
DO N=1,N_REACTIONS
   IF (REACTION(N)%MODE==MIXTURE_FRACTION_REACTION) THEN
      N_MIX  = N_MIX  + 1
      N_SPECIES = N_SPECIES + 1
      IF (N_MIX==1) THEN
         I_FUEL = N_SPECIES
      ELSEIF (N_MIX== 2) THEN
         IF(CO_PRODUCTION) THEN 
            I_PROG_CO = N_SPECIES
         ELSE
            I_PROG_F = N_SPECIES
         ENDIF
      ELSEIF (N_MIX==3) THEN
         I_PROG_F = N_SPECIES
      ENDIF
      YYMIN(N_MIX)  = 0.0_EB
      YYMIN(I_FUEL) = 0.0_EB
   ENDIF
ENDDO
 
IF (WATER_EVAPORATION .AND. I_WATER==0) THEN
   N_SPECIES  = N_SPECIES + 1
   I_WATER = N_SPECIES
ENDIF
 
! Allocate species-related arrays
 
ALLOCATE(SPECIES(0:N_SPECIES),STAT=IZERO)
CALL ChkMemErr('READ','SPECIES',IZERO)
SPECIES(:)%YY0 = 0._EB
SPECIES(:)%MW  = 0._EB
SPECIES(0)%MW  = MW_BACKGROUND
SPECIES(0)%NAME= BACKGROUND_SPECIES
EPSK           = 0._EB
SIG            = 0._EB
SPECIES(:)%ABSORBING=.FALSE.
SPECIES(:)%MODE=GAS_SPECIES
 
N_MIX=0
NN=N_SPEC_EXTRA
DO N=1,N_REACTIONS
   IF (REACTION(N)%MODE==MIXTURE_FRACTION_REACTION) THEN
      NN    = NN + 1
      N_MIX = N_MIX + 1
      SPECIES(NN)%MODE = MIXTURE_FRACTION_SPECIES
      SPECIES(NN)%REAC_INDEX    = N
      SPECIES(NN)%ABSORBING=.TRUE.
      IF (N_REACTIONS > 1) WRITE(SPECIES(NN)%NAME,'(A,I1.1)') 'MIXTURE_FRACTION_',N_MIX
      IF (N_REACTIONS ==1) WRITE(SPECIES(NN)%NAME,'(A)'     ) 'MIXTURE_FRACTION'
   ENDIF
ENDDO
 
! Initialize initial WATER VAPOR mass fraction, if necessary
 
IF (I_WATER>0) THEN
   XVAP  = MIN(1._EB,EXP(2259.E3_EB*MW_H2O/R0*(1._EB/373.15_EB-1._EB/ MIN(TMPA,373.15_EB))))
   SPECIES(I_WATER)%MODE = GAS_SPECIES
   SPECIES(I_WATER)%NAME = 'WATER VAPOR'
   SPECIES(I_WATER)%YY0 =HUMIDITY*0.01_EB*XVAP/(MW_AIR/MW_H2O+(1._EB-MW_AIR/MW_H2O)*XVAP)
ENDIF
IF (I_SOOT>0) SPECIES(I_SOOT)%MODE=AEROSOL_SPECIES
 
! Read SPEC lines from input file
 
REWIND(LU_INPUT)
SPEC_LOOP: DO N=1,N_SPEC_READ
 
   CONDUCTIVITY    = -1._EB
   DIFFUSIVITY     = -1._EB
   EPSILONKLJ      = 0._EB
   MASS_FRACTION_0 = -1._EB
   MW              = 0._EB
   SIGMALJ         = 0._EB
   VISCOSITY       = -1._EB
   ABSORBING       = .FALSE.
   ID              = 'null'
 
   CALL CHECKREAD('SPEC',LU_INPUT,IOS)
   READ(LU_INPUT,NML=SPEC)
   IF (MIXTURE_FRACTION) THEN
      SELECT CASE(ID)
         CASE('MIXTURE_FRACTION_1')
            NN = I_FUEL
         CASE('MIXTURE_FRACTION2')
            IF (CO_PRODUCTION) THEN
               NN = I_PROG_CO
            ELSE
               NN = I_PROG_F
            ENDIF
         CASE('MIXTURE_FRACTION_3')
            IF (CO_PRODUCTION) THEN
               NN = I_PROG_CO
            ELSE
               NN = N
            ENDIF
         CASE DEFAULT
            NN = N
      END SELECT
   ENDIF
   SS => SPECIES(NN) 
   MU_USER(NN) = VISCOSITY
   K_USER(NN)  = CONDUCTIVITY
   D_USER(NN)  = DIFFUSIVITY
   EPSK(NN)    = EPSILONKLJ
   SIG(NN)     = SIGMALJ
   SS%MW        = MW
   SS%ABSORBING = ABSORBING
   IF (MASS_FRACTION_0 < 0._EB) THEN
      IF (N/=I_WATER)  SS%YY0 = 0._EB
   ELSE
      SS%YY0 = MASS_FRACTION_0
   ENDIF
   IF (ID/='null') SS%NAME = ID
 
ENDDO SPEC_LOOP

END SUBROUTINE READ_SPEC
 
 
SUBROUTINE READ_REAC
 
CHARACTER(30) :: FUEL,OXIDIZER
LOGICAL :: IDEAL
INTEGER :: NN,N_REAC_READ
REAL(EB) :: Y_O2_INFTY,Y_F_INLET, &
            H2_YIELD,SOOT_YIELD,CO_YIELD, Y_F_LFL,X_O2_LL,EPUMO2,BOF, SOOT_H_FRACTION,&
            CRITICAL_FLAME_TEMPERATURE,HEAT_OF_COMBUSTION,NU(1:20),E,N_S(1:20),C,H,N,O,OTHER,MW_OTHER, &
            FUEL_HEAT_OF_FORMATION,MAXIMUM_VISIBILITY 
NAMELIST /REAC/ E,BOF,HEAT_OF_COMBUSTION,FYI,FUEL,OXIDIZER,EPUMO2,ID, N_S,&
                Y_O2_INFTY,Y_F_INLET,HRRPUA_SHEET, &
                H2_YIELD,SOOT_YIELD,CO_YIELD,Y_F_LFL,X_O2_LL,CRITICAL_FLAME_TEMPERATURE,NU,SOOT_H_FRACTION, &
                C,H,N,O,OTHER,MW_OTHER,IDEAL,MASS_EXTINCTION_COEFFICIENT,VISIBILITY_FACTOR,MAXIMUM_VISIBILITY
 
N_REACTIONS = 0
REWIND(LU_INPUT)
 
COUNT_REAC_LOOP: DO
   ID   = 'null'
   FUEL = 'null'      
   CALL CHECKREAD('REAC',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_REAC_LOOP
   READ(LU_INPUT,REAC,ERR=434,IOSTAT=IOS)
   N_REACTIONS = N_REACTIONS + 1
   IF (FUEL=='null') THEN
      MIXTURE_FRACTION = .TRUE.
   ENDIF
   IF (FUEL/='null' .AND. MIXTURE_FRACTION) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: cannot use both finite rate REAC and mixture fraction REAC'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   IF (MIXTURE_FRACTION .AND. N_REACTIONS > 1) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: can not have more than one reaction when using mixture fraction'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   434 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with REAC ',N_REACTIONS+1
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_REAC_LOOP
 
IF (FUEL_EVAPORATION) MIXTURE_FRACTION = .TRUE.
IF (MIXTURE_FRACTION .AND. N_REACTIONS==0) N_REACTIONS = 1

IF (N_REACTIONS==0) RETURN

IF (MIXTURE_FRACTION) THEN
   N_REAC_READ = 1
ELSE
   N_REAC_READ = N_REACTIONS
ENDIF

IF (MIXTURE_FRACTION .AND.      CO_PRODUCTION) N_REACTIONS = 3
IF (MIXTURE_FRACTION .AND. .NOT.CO_PRODUCTION) N_REACTIONS = 2
ALLOCATE(REACTION(N_REACTIONS),STAT=IZERO)
CALL ChkMemErr('READ','REACTION',IZERO)

! Read the input file looking for REAC lines
 
REWIND(LU_INPUT)
READ_REACTION_LOOP: DO NN=1,N_REAC_READ
   RN => REACTION(NN)
   CALL CHECKREAD('REAC',LU_INPUT,IOS) 
   CALL SET_REAC_DEFAULTS
   IF (IOS==0) READ(LU_INPUT,REAC)
   RN%BOF                = BOF
   RN%E                  = E*1000._EB
   RN%EPUMO2             = EPUMO2*1000._EB
   RN%FUEL               = FUEL        
   RN%HEAT_OF_COMBUSTION = HEAT_OF_COMBUSTION*1000._EB
   IF (FUEL=='null') THEN
      RN%MODE = MIXTURE_FRACTION_REACTION
   ELSE
      RN%MODE = FINITE_RATE_REACTION
   ENDIF
   RN%N(:)               = N_S(:)
   RN%NAME               = ID
   RN%NU(:)              = NU(:)
   RN%OXIDIZER           = OXIDIZER
ENDDO READ_REACTION_LOOP

SET_MIXTURE_FRACTION: IF (MIXTURE_FRACTION) THEN
   !Set reaction variable constants
   REACTION%MW_OTHER        = MW_OTHER
   REACTION%MW_FUEL         = C * MW_C + H * MW_H + O * MW_O + N * MW_N + OTHER * MW_OTHER
   IF (H==0._EB) THEN
      REACTION%SOOT_H_FRACTION = 0._EB
   ELSE
      REACTION%SOOT_H_FRACTION = SOOT_H_FRACTION
   ENDIF
   REACTION%Y_O2_INFTY      = Y_O2_INFTY
   REACTION%Y_O2_LL         = X_O2_LL*MW_O2/ (X_O2_LL*MW_O2+(1._EB-X_O2_LL)*MW_N2)
   REACTION%Y_F_LFL         = Y_F_LFL
   REACTION%CRIT_FLAME_TMP  = CRITICAL_FLAME_TEMPERATURE + TMPM
   REACTION%Y_F_INLET       = Y_F_INLET
   REACTION%MODE            = MIXTURE_FRACTION_REACTION
   REACTION%NAME            = ID
   MW_SOOT                  = MW_C * (1._EB - SOOT_H_FRACTION) + MW_H * SOOT_H_FRACTION   
   
   SET_THREE_PARAMETER: IF (CO_PRODUCTION) THEN !Set reaction variables for three parameter mixture fraction 

      !Set reaction variables for complete reaction
      RN => REACTION(2) 
      RN%IDEAL      = IDEAL
      IF (RN%IDEAL) THEN
         !Compute fuel heat of formation
         RN%NU_O2 = C + 0.5_EB * H - 0.5_EB * O
         IF (HEAT_OF_COMBUSTION < 0._EB) HEAT_OF_COMBUSTION = EPUMO2*(MW_O2*RN%NU_O2)/RN%MW_FUEL
         FUEL_HEAT_OF_FORMATION =  HEAT_OF_COMBUSTION * RN%MW_FUEL - &
                                   (C * CO2_HEAT_OF_FORMATION + 0.5_EB * H * H2O_HEAT_OF_FORMATION)
      ENDIF
      RN%CO_YIELD   = CO_YIELD
      RN%SOOT_YIELD = SOOT_YIELD
      RN%H2_YIELD   = H2_YIELD
      RN%NU_H2      = H2_YIELD * RN%MW_FUEL / MW_H2
      RN%NU_SOOT    = SOOT_YIELD * RN%MW_FUEL / MW_SOOT
      RN%NU_CO      = CO_YIELD * RN%MW_FUEL / MW_CO
      RN%NU_CO2     = C - RN%NU_CO - RN%NU_SOOT * (1._EB - SOOT_H_FRACTION)
      IF (RN%NU_CO2 < 0._EB) THEN
         WRITE(MESSAGE,'(A)') 'Values for SOOT_YIELD, CO_YIELD, and SOOT_H_FRACTION result in negative CO2 yield'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      RN%NU_H2O     = 0.5_EB * H - RN%NU_H2 - 0.5_EB * RN%NU_SOOT * SOOT_H_FRACTION
      IF (RN%NU_H2O < 0._EB) THEN
         WRITE(MESSAGE,'(A)') 'Values for SOOT_YIELD, H2_YIELD, and SOOT_H_FRACTION result in negative H2O yield'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      RN%NU_O2      = RN%NU_CO2 + 0.5_EB * (RN%NU_CO + RN%NU_H2O - O)
      RN%NU_N2      = 0.5_EB * N
      RN%NU_OTHER   = OTHER
      RN%BOF        = 2.53E12_EB
      RN%E          = 199547._EB*1000._EB
      RN%O2_F_RATIO    = (MW_O2*RN%NU_O2)/RN%MW_FUEL
      IF (.NOT. RN%IDEAL) THEN
         IF(HEAT_OF_COMBUSTION < 0._EB) HEAT_OF_COMBUSTION = EPUMO2*RN%O2_F_RATIO
         RN%HEAT_OF_COMBUSTION = HEAT_OF_COMBUSTION*1000._EB
      ELSE
         ! Correct heat of combustion for minor products of combustion
         RN%HEAT_OF_COMBUSTION = (FUEL_HEAT_OF_FORMATION + RN%NU_CO2 * CO2_HEAT_OF_FORMATION + &
                                                         RN%NU_CO  * CO_HEAT_OF_FORMATION + &
                                                         RN%NU_H2O * H2O_HEAT_OF_FORMATION) * 1000._EB /RN%MW_FUEL
      ENDIF
      
      ! Set reaction variables for incomplete reaction

      RN => REACTION(1)
      RN%IDEAL              = .TRUE.
      RN%CO_YIELD           = 0._EB
      RN%H2_YIELD           = H2_YIELD
      RN%SOOT_YIELD         = SOOT_YIELD
      RN%NU_H2              = H2_YIELD * RN%MW_FUEL / MW_H2
      RN%NU_SOOT            = SOOT_YIELD * RN%MW_FUEL / MW_SOOT
      RN%NU_CO              = C - RN%NU_SOOT * (1._EB - SOOT_H_FRACTION)
      RN%NU_CO2             = 0._EB
      IF (RN%NU_CO2 < 0._EB) THEN
         WRITE(MESSAGE,'(A)') 'Values for SOOT_YIELD, CO_YIELD, and SOOT_H_FRACTION result in negative CO2 yield'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      RN%NU_H2O             = 0.5_EB * H - RN%NU_H2 - 0.5_EB * RN%NU_SOOT * SOOT_H_FRACTION
      IF (RN%NU_H2O < 0._EB) THEN
         WRITE(MESSAGE,'(A)') 'Values for SOOT_YIELD, H2_YIELD, and SOOT_H_FRACTION result in negative H2O yield'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      RN%NU_O2              = RN%NU_CO2 + 0.5_EB * (RN%NU_CO + RN%NU_H2O - O)
      RN%NU_N2              = 0.5_EB * N
      RN%NU_OTHER           = OTHER
      RN%O2_F_RATIO    = (MW_O2*RN%NU_O2)/RN%MW_FUEL      
      RN%HEAT_OF_COMBUSTION = REACTION(2)%HEAT_OF_COMBUSTION - 1.E3_EB * REACTION(2)%NU_CO2 /RN%MW_FUEL * &
                             (CO2_HEAT_OF_FORMATION - CO_HEAT_OF_FORMATION)
      NN = 3
      
   ELSE SET_THREE_PARAMETER !Set reaction variables for two parameter mixture fraction 
   
      !Set reaction variables for complete reaction
      RN => REACTION(1) 
      RN%IDEAL      = IDEAL
      IF (RN%IDEAL) THEN
         !Compute fuel heat of formation
         RN%NU_O2 = C + 0.5_EB * H - 0.5_EB * O
         IF (HEAT_OF_COMBUSTION < 0._EB) HEAT_OF_COMBUSTION = EPUMO2*(MW_O2*RN%NU_O2)/RN%MW_FUEL
         FUEL_HEAT_OF_FORMATION =  HEAT_OF_COMBUSTION * RN%MW_FUEL - &
                                   (C * CO2_HEAT_OF_FORMATION + 0.5_EB * H * H2O_HEAT_OF_FORMATION)
      ENDIF
      RN%CO_YIELD   = CO_YIELD
      RN%SOOT_YIELD = SOOT_YIELD
      RN%H2_YIELD   = H2_YIELD
      RN%NU_H2      = H2_YIELD * RN%MW_FUEL / MW_H2
      RN%NU_SOOT    = SOOT_YIELD * RN%MW_FUEL / MW_SOOT
      RN%NU_CO      = CO_YIELD * RN%MW_FUEL / MW_CO
      RN%NU_CO2     = C - RN%NU_CO - RN%NU_SOOT * (1._EB - SOOT_H_FRACTION)
      RN%NU_H2O     = 0.5_EB * H - RN%NU_H2 - 0.5_EB * RN%NU_SOOT * SOOT_H_FRACTION
      RN%NU_O2      = RN%NU_CO2 + 0.5_EB * (RN%NU_CO + RN%NU_H2O - O)
      RN%NU_N2      = 0.5_EB * N
      RN%NU_OTHER   = OTHER
      RN%O2_F_RATIO    = (MW_O2*RN%NU_O2)/RN%MW_FUEL      
      IF (.NOT. RN%IDEAL) THEN
         IF(HEAT_OF_COMBUSTION < 0._EB) HEAT_OF_COMBUSTION = EPUMO2*RN%O2_F_RATIO
         RN%HEAT_OF_COMBUSTION = HEAT_OF_COMBUSTION*1000._EB
      ELSE
         !Correct heat of combustion for minor products of combustion
         RN%HEAT_OF_COMBUSTION = (FUEL_HEAT_OF_FORMATION + RN%NU_CO2 * CO2_HEAT_OF_FORMATION + &
                                                         RN%NU_CO  * CO_HEAT_OF_FORMATION + &
                                                         RN%NU_H2O * H2O_HEAT_OF_FORMATION) * 1000._EB /RN%MW_FUEL
      ENDIF
      NN = 2
   ENDIF SET_THREE_PARAMETER
   
   !Set reaction variables for extinction reaction   

   RN => REACTION(NN)
   RN%CO_YIELD           = 0._EB
   RN%NU_CO              = 0._EB
   RN%NU_CO2             = 0._EB
   RN%NU_H2              = 0._EB
   RN%NU_H2O             = 0._EB
   RN%NU_O2              = 0._EB
   RN%NU_N2              = 0._EB   
   RN%NU_OTHER           = 0._EB      
   RN%NU_SOOT            = 0._EB
   RN%SOOT_YIELD         = 0._EB
   RN%H2_YIELD           = 0._EB   
   RN%HEAT_OF_COMBUSTION = 0._EB   
   RN%EPUMO2             = 0._EB      
   RN%IDEAL              = .TRUE.
ENDIF SET_MIXTURE_FRACTION

! Set the lower limit of the extinction coefficient

EC_LL = VISIBILITY_FACTOR/MAXIMUM_VISIBILITY

CONTAINS
 

SUBROUTINE SET_REAC_DEFAULTS
 
BOF                         = 0._EB       ! cm**3/mol-s
CO_YIELD                    = 0._EB
CRITICAL_FLAME_TEMPERATURE  = 1427._EB    ! C
E                           = 0._EB       ! kJ/kmol
EPUMO2                      = 13100._EB   ! kJ/kg
FUEL                        = 'null'
H2_YIELD                    = 0._EB
HEAT_OF_COMBUSTION          = -1._EB
HRRPUA_SHEET                = 200._EB     ! kW/m2
ID                          = 'null'
Y_F_INLET                   = 1._EB
N_S                         = -999._EB
NU                          = 0._EB
OXIDIZER                    = 'null'
IF (LES) SOOT_YIELD         = 0.01_EB
IF (DNS) SOOT_YIELD         = 0.0_EB
SOOT_H_FRACTION             = 0.1_EB
X_O2_LL                     = 0.15_EB    ! %
Y_F_LFL                     = 0.0_EB 
Y_F_INLET                   = 1._EB
Y_O2_INFTY                  = 0.23_EB
IDEAL                       = .FALSE.
C                           = 3._EB
H                           = 8._EB
O                           = 0._EB
N                           = 0._EB
OTHER                       = 0._EB
MW_OTHER                    = 28_EB        ! Nitrogen MW
MASS_EXTINCTION_COEFFICIENT = 8700._EB     ! m2/kg
MAXIMUM_VISIBILITY          = 30._EB       ! m
VISIBILITY_FACTOR           = 3._EB
 
END SUBROUTINE SET_REAC_DEFAULTS
 
END SUBROUTINE READ_REAC
 
 
SUBROUTINE PROC_SPEC
 
REAL(EB) :: EPSIJ,SIGMA2,AMW,OMEGA,TSTAR,MU_N,K_N,D_N0,TE,WGT,EPSK_N,SIG_N,MW_N, &
            CP_N2,CP_F,CP_CO2,CP_O2,CP_H2O,CP_CO,CP_H2,RSUM_DILUENTS,YSUM_DILUENTS
INTEGER :: IPC,NN,ITMP,IYY,N
CHARACTER(30) :: STATE_SPECIES(10)
TYPE(PARTICLE_CLASS_TYPE), POINTER :: PC
LOGICAL :: ABSORBING

! Compute state relations for mixture fraction model
 
IF (MIXTURE_FRACTION) THEN
    CALL STATE_RELATIONSHIPS
   ! For mixture fraction model, get the fuel heat of combustion
   IF (CO_PRODUCTION) THEN
      RN => REACTION(2)
   ELSE
      RN => REACTION(1)   
   ENDIF
   DO IPC=1,N_PART
      PC=>PARTICLE_CLASS(IPC)
      IF (PC%HEAT_OF_COMBUSTION > 0._EB) PC%ADJUST_EVAPORATION = PC%HEAT_OF_COMBUSTION/RN%HEAT_OF_COMBUSTION
   ENDDO
ENDIF

 
! Get gas properties
 
DO N=0,N_SPECIES
   ABSORBING = .FALSE.
   CALL GAS_PROPS(SPECIES(N)%NAME,SIG(N),EPSK(N),SPECIES(N)%MW,ABSORBING)
   IF (ABSORBING) SPECIES(N)%ABSORBING = .TRUE.
ENDDO
 
! Compute the initial value of R0/MW_AVG
 
SS0 => SPECIES(0)
 
SS0%YY0 = 1._EB
DO N=1,N_SPECIES
   SS => SPECIES(N)
   IF (SS%MODE==GAS_SPECIES) SS0%YY0 = SS0%YY0 - SS%YY0
ENDDO
 
RSUM0  = SS0%YY0*R0/SS0%MW
SS0%RCON = R0/SS0%MW
IF (MIXTURE_FRACTION) THEN
   RCON_MF(FUEL_INDEX) = R0/REACTION(1)%MW_FUEL
   RCON_MF(O2_INDEX) = R0/MW_O2
   RCON_MF(N2_INDEX) = R0/MW_N2
   RCON_MF(H2O_INDEX) = R0/MW_H2O
   RCON_MF(CO2_INDEX) = R0/MW_CO2
   RCON_MF(CO_INDEX) = R0/MW_CO
   RCON_MF(H2_INDEX) = R0/MW_H2
   RCON_MF(SOOT_INDEX) = R0/MW_SOOT
   RSUM0 = SPECIES(I_FUEL)%RSUM_MF(0)
   SS0%MW = SPECIES(I_FUEL)%MW_MF(0)
   SS0%RCON = SPECIES(I_FUEL)%RSUM_MF(0)   
ENDIF

MW_MIN = SS0%MW
MW_MAX = SS0%MW
 
N_SPEC_DILUENTS = 0
RSUM_DILUENTS = 0._EB
YSUM_DILUENTS = 0._EB
SPECIES_LOOP_0: DO N=1,N_SPECIES
   SS  => SPECIES(N)
   SS%RCON = R0/SS%MW
   IF (SS%MODE==GAS_SPECIES) THEN
      N_SPEC_DILUENTS = N_SPEC_DILUENTS + 1
      MW_MIN = MIN(MW_MIN,SS%MW)
      MW_MAX = MAX(MW_MAX,SS%MW)
      YSUM_DILUENTS = YSUM_DILUENTS + SS%YY0
      RSUM_DILUENTS = RSUM_DILUENTS + SS%YY0*R0/SS%MW
   ELSE
      DO I=0,10000
         MW_MIN = MIN(MW_MIN,SS%MW_MF(I))
         MW_MAX = MAX(MW_MAX,SS%MW_MF(I))
      ENDDO
   ENDIF
ENDDO SPECIES_LOOP_0

IF (MIXTURE_FRACTION) THEN
   RSUM0 = RSUM0 * (1._EB-YSUM_DILUENTS) +RSUM_DILUENTS
ELSE
   RSUM0 = RSUM0 + RSUM_DILUENTS
ENDIF
 
! Compute background density from other background quantities
 
RHOA = P_INF/(TMPA*RSUM0)
 
! Compute constant-temperature specific heats
 
CP_GAMMA = SS0%RCON*GAMMA/(GAMMA-1._EB)
CPOPR = CP_GAMMA/PR
 
! Compute variable-temperature specific heats for specific species
 
SPECIES_LOOP: DO N=0,N_SPECIES
 
   SS => SPECIES(N)
   SS%H_G(0) = 0.

   T_LOOP: DO J=1,500
      TE  = MAX(0.01_EB*J,0.301_EB)
      CP_O2 = 0.926844_EB+0.191789_EB*TE-0.0370788_EB*TE**2+0.00299313_EB*TE**3- 0.00686447_EB/TE**2
      CP_N2 = 0.931857_EB+0.293529_EB*TE-0.0705765_EB*TE**2+0.00568836_EB*TE**3+ 0.001589693_EB/TE**2
      IF (J<=120) THEN   ! Ethylene
         CP_F  = -0.2218014_EB + 6.402844_EB*TE - 3.922632_EB*TE**2 + 0.9894420_EB*TE**3 + 0.01095625_EB/TE**2
      ELSE
         CP_F  = 3.698278_EB+0.4768264_EB*TE-0.0912667_EB*TE**2+0.006062326_EB*TE**3- 0.9078017_EB/TE**2
      ENDIF
      IF (J<=120) THEN
         CP_CO2 = 0.568122_EB+1.25425_EB*TE-0.765713_EB*TE**2+0.180645_EB*TE**3- 0.00310541_EB/TE**2
      ELSE
         CP_CO2 = 1.32196_EB+0.0618199_EB*TE-0.0111884_EB*TE**2+0.00082818_EB*TE**3- 0.146529_EB/TE**2
      ENDIF
      IF (J<=50) THEN
         CP_H2O = 1.95657565_EB
      ELSEIF (50 < J .AND. J <=170) THEN
         CP_H2O = 1.67178_EB+0.379583_EB*TE+0.377413_EB*TE**2-0.140804_EB*TE**3+ 0.00456328_EB/TE**2
      ELSE
         CP_H2O = 2.33135_EB+0.479003_EB*TE-0.00833212_EB*TE**2+0.00545106_EB*TE**3- 0.619869_EB/TE**2
      ENDIF
      IF (J<=130) THEN
         CP_CO = 0.913128_EB+0.217719_EB*TE+0.144809_EB*TE**2-0.0954036_EB*TE**3+ 0.00467932_EB/TE**2
      ELSE
         CP_CO = 1.255382_EB+0.046432_EB*TE-0.00735432_EB*TE**2+0.00483928_EB*TE**3- 0.1172421_EB/TE**2
      ENDIF
      IF (J<=100) THEN
         CP_H2 = 16.53309_EB-5.681708_EB*TE+5.716408_EB*TE**2-1.386437_EB*TE**3- 0.079279_EB/TE**2
      ELSEIF (J > 100 .AND. J <= 250) THEN
         CP_H2 = 9.281542_EB+6.1286785_EB*TE-1.429893_EB*TE**2+0.134119_EB*TE**3+ 0.988995_EB/TE**2
      ELSE
         CP_H2 = 21.70678_EB-2.14654_EB*TE+0.636214_EB*TE**2-0.048438_EB*TE**3-10.266931_EB/TE**2            
      ENDIF
      SELECT CASE (SPECIES(N)%MODE)
         CASE (MIXTURE_FRACTION_SPECIES)
            Z_LOOP: DO I=0,100
               IYY = 100*I
               SS%CP_MF(I,J) = ( SS%Y_MF(IYY,FUEL_INDEX)*CP_F  + SS%Y_MF(IYY,O2_INDEX)*CP_O2  + &
                                (SS%Y_MF(IYY,N2_INDEX)         + SS%Y_MF(IYY,OTHER_INDEX))*CP_N2  +  &
                                 SS%Y_MF(IYY,H2O_INDEX)*CP_H2O + SS%Y_MF(IYY,CO2_INDEX)*CP_CO2 +  &
                                 SS%Y_MF(IYY,CO_INDEX)*CP_CO   + SS%Y_MF(IYY,H2_INDEX)*CP_H2)*1000._EB
               SS%RCP_MF(I,J) = 1._EB/SS%CP_MF(I,J)
            ENDDO Z_LOOP
            SS%CP_MF2(FUEL_INDEX,J)  = CP_F*1000._EB
            SS%CP_MF2(O2_INDEX,J)    = CP_O2*1000._EB
            SS%CP_MF2(N2_INDEX,J)    = CP_N2*1000._EB
            SS%CP_MF2(OTHER_INDEX,J) = CP_N2*1000._EB
            SS%CP_MF2(H2O_INDEX,J)   = CP_H2O*1000._EB
            SS%CP_MF2(CO2_INDEX,J)   = CP_CO2*1000._EB
            SS%CP_MF2(CO_INDEX,J)    = CP_CO*1000._EB
            SS%CP_MF2(SOOT_INDEX,J)  = 904._EB !cp carbon
            SS%CP_MF2(H2_INDEX,J)    = CP_H2*1000._EB
            SS%RCP_MF2(:,J)          = 1._EB/SS%CP_MF2(:,J)               

         CASE (GAS_SPECIES)
            SELECT CASE(SPECIES(N)%NAME)
               CASE DEFAULT
                  SS%CP(J) = SS%RCON*GAMMA/(GAMMA-1._EB)
               CASE('AIR')
                  SS%CP(J) = (0.77_EB*CP_N2+0.23_EB*CP_O2)*1000._EB
               CASE('NITROGEN')
                  SS%CP(J) = CP_N2 *1000._EB
               CASE('OXYGEN')
                  SS%CP(J) = CP_O2 *1000._EB
               CASE('METHANE')
                  SS%CP(J) = CP_F  *1000._EB
               CASE('CARBON DIOXIDE')
                  SS%CP(J) = CP_CO2*1000._EB
               CASE('WATER VAPOR')
                  SS%CP(J) = CP_H2O*1000._EB
               CASE('CARBON MONOXIDE')
                  SS%CP(J) = CP_CO*1000._EB
               CASE('HYDROGEN')
                  SS%CP(J) = CP_H2*1000._EB
            END SELECT
            SS%H_G(J) = SS%H_G(J-1) + SS%CP(J)*10._EB  ! J/kg
            SS%RCP(J) = 1._EB/SS%CP(J)
      END SELECT
   ENDDO T_LOOP
ENDDO SPECIES_LOOP

! For finite rate reaction, set parameters
 
FINITE_RATE_REACTION_LOOP: DO NN=1,N_REACTIONS
   RN => REACTION(NN)
   IF (RN%MODE/=FINITE_RATE_REACTION)  CYCLE FINITE_RATE_REACTION_LOOP
   DO N=1,N_SPECIES
      IF (RN%FUEL    ==SPECIES(N)%NAME) THEN
         RN%I_FUEL     = N
         IF (RN%N(N) /=-999._EB) THEN
            RN%N_F        = RN%N(N)
         ELSE
            RN%N_F        = 1._EB         
         ENDIF
      ENDIF
      IF (RN%OXIDIZER==SPECIES(N)%NAME) THEN
         RN%I_OXIDIZER = N
         IF (RN%N(N) /=-999._EB) THEN
            RN%N_O        = RN%N(N)
         ELSE
            RN%N_O        = 1._EB         
         ENDIF
      ENDIF
   ENDDO
   IF (NN==1) I_FUEL = RN%I_FUEL
   RN%MW_FUEL = SPECIES(RN%I_FUEL)%MW
   IF (RN%NU(RN%I_FUEL)     == 0._EB) RN%NU(RN%I_FUEL)     = -1._EB
   IF (RN%NU(RN%I_FUEL)     >  0._EB) RN%NU(RN%I_FUEL)     = -RN%NU(RN%I_FUEL)
   IF (RN%NU(RN%I_OXIDIZER) >  0._EB) RN%NU(RN%I_OXIDIZER) = -RN%NU(RN%I_OXIDIZER)
   IF (RN%NU(RN%I_OXIDIZER) == 0._EB) THEN
      WRITE(MESSAGE,'(A)')  'ERROR: Specify a stoichiometric coefficient for oxidizer'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   RN%O2_F_RATIO = SPECIES(RN%I_OXIDIZER)%MW*RN%NU(RN%I_OXIDIZER)/(SPECIES(RN%I_FUEL)%MW*RN%NU(RN%I_FUEL))
   RN%EPUMO2     = RN%HEAT_OF_COMBUSTION/RN%O2_F_RATIO
ENDDO FINITE_RATE_REACTION_LOOP
 
! Compute viscosity, thermal conductivity for species 0 to N_SPECIES. Diffusivity for species 1 to N_SPECIES. 
! These terms are used for DNS, and as the lower limits in LES calcs (via SPECIES(0)).
! Source: Poling, Prausnitz and O'Connell. Properties of Gases and Liquids, 5th ed, 2000.
 
SPECIES_LOOP_2: DO N=0,N_SPECIES
!
   SS  => SPECIES(N)
   SS0 => SPECIES(0)
!
   SPEC_MODEIF: IF (SPECIES(N)%MODE==GAS_SPECIES) THEN
!
      SIGMA2 = SIG(N)**2
      DO ITMP=1,500
         TSTAR = ITMP*10/EPSK(N)
         OMEGA = 1.16145_EB*TSTAR**(-0.14874_EB) +  0.52487_EB*EXP(-0.77320_EB*TSTAR) + 2.16178_EB*EXP(-2.43787_EB*TSTAR)
         MU_N = 26.69E-7_EB*(SS%MW*ITMP*10)**0.5_EB/(SIGMA2*OMEGA)
         IF (MU_USER(N)>=0._EB) MU_N = MU_USER(N)*(ITMP*10/TMPA)**0.75_EB
         K_N = MU_N*SS%CP(ITMP)/PR
         IF (K_USER(N)>=0._EB)  K_N = K_USER(N)*(ITMP*10/TMPA)**0.75_EB
         SS%MU(ITMP) = MU_N
         SS%K(ITMP)  = K_N
      ENDDO
      IF (N>0) THEN
         SIGMA2 = (0.5_EB*(SIG(N)+SIG(0)))**2
         EPSIJ  = SQRT(EPSK(N)*EPSK(0))
         AMW    = SQRT( (SS%MW+SS0%MW)/(2._EB*SS%MW*SS0%MW) )
         DO ITMP=1,500
            TSTAR = ITMP*10/EPSIJ
            OMEGA = 1.06036_EB/TSTAR**(0.15610_EB) + 0.19300_EB/EXP(0.47635_EB*TSTAR) + 1.03587_EB/EXP(1.52996_EB*TSTAR) +&
                  1.76474_EB/EXP(3.89411_EB*TSTAR)
            D_N0 = 0.00266E-4_EB*AMW*(10*ITMP)**1.5_EB/(SIGMA2*OMEGA)
            IF (D_USER(N)>=0._EB) D_N0 = D_USER(N)*(ITMP*10/TMPA)**1.75_EB
            SS%D(ITMP) = D_N0
         ENDDO
      ENDIF
 
   ELSE SPEC_MODEIF
      STATE_SPECIES(1) = 'METHANE'
!     STATE_SPECIES(1) = 'ETHYLENE'
      STATE_SPECIES(2) = 'OXYGEN'
      STATE_SPECIES(3) = 'NITROGEN'
      STATE_SPECIES(4) = 'WATER VAPOR'
      STATE_SPECIES(5) = 'CARBON DIOXIDE'
      STATE_SPECIES(6) = 'CARBON MONOXIDE'
      STATE_SPECIES(7) = 'HYDROGEN'
      STATE_SPECIES(8) = 'CARBON MONOXIDE'
      STATE_SPECIES(9) = 'NITROGEN'
      SS%D_MF  = 0._EB
      SS%MU_MF = 0._EB
      SS%K_MF  = 0._EB
      SUB_SPECIES_LOOP: DO NN=1,9
         SIG_N = -1._EB
         EPSK_N = -1._EB 
         MW_N = -.1_EB
         CALL GAS_PROPS(STATE_SPECIES(NN),SIG_N,EPSK_N,MW_N,ABSORBING)
         SIGMA2 = SIG_N**2
         DO ITMP=1,500
            TSTAR = ITMP*10/EPSK_N
            OMEGA = 1.16145_EB*TSTAR**(-0.14874_EB) + 0.52487_EB*EXP(-0.77320_EB*TSTAR) + 2.16178_EB*EXP(-2.43787_EB*TSTAR)
            MU_N = 26.69E-7_EB*(MW_N*ITMP*10)**0.5_EB/(SIGMA2*OMEGA)
            DO IYY=0,100
               K_N  = MU_N*SS%CP_MF(IYY,ITMP)/PR
               WGT  = SS%Y_MF(100*IYY,NN)*SS%MW_MF(100*IYY)/MW_N
               SS%MU_MF(IYY,ITMP) = SS%MU_MF(IYY,ITMP) + WGT*MU_N
               SS%K_MF(IYY,ITMP)  = SS%K_MF(IYY,ITMP)  + WGT*K_N
            ENDDO
            SS%MU_MF2(NN,ITMP) = MU_N
            SS%K_MF2(NN,ITMP)  = MU_N*SS%CP_MF2(NN,ITMP)/PR
         ENDDO
         SIGMA2 = (0.5_EB*(SIG_N+SIG(0)))**2
         EPSIJ  = SQRT(EPSK_N*EPSK(0))
         AMW    = SQRT( (MW_N+SS0%MW)/(2._EB*MW_N*SS0%MW) )
         DO ITMP=1,500
            TSTAR = ITMP*10/EPSIJ
            OMEGA = 1.06036_EB/TSTAR**(0.15610_EB) + 0.19300_EB/EXP(0.47635_EB*TSTAR) + 1.03587_EB/EXP(1.52996_EB*TSTAR) + &
                    1.76474_EB/EXP(3.89411_EB*TSTAR)
            D_N0 = 0.00266E-4_EB*AMW*(10*ITMP)**1.5_EB/(SIGMA2*OMEGA)
            DO IYY=0,100
               SS%D_MF(IYY,ITMP) = SS%D_MF(IYY,ITMP) + SS%Y_MF(100*IYY,NN)*D_N0
            ENDDO
            SS%D_MF2(NN,ITMP) = D_N0
         ENDDO
      ENDDO SUB_SPECIES_LOOP
   ENDIF SPEC_MODEIF
 
ENDDO SPECIES_LOOP_2
 
! Define all possible output quantities
 
CALL SPECIES_OUTPUT_QUANTITIES
 
CONTAINS
  
 
SUBROUTINE GAS_PROPS(GAS_NAME,SIGMA,EPSOK,MW,ABSORBING)
 
! Molecular weight (g/mol) and Lennard-Jones properties
 
REAL(EB) SIGMA,EPSOK,MW,SIGMAIN,EPSOKIN,MWIN
CHARACTER(30) GAS_NAME
LOGICAL ABSORBING
 
SIGMAIN = SIGMA
EPSOKIN = EPSOK
MWIN    = MW
 
SELECT CASE(GAS_NAME)
   CASE('AIR')             
      SIGMA=3.711_EB 
      EPSOK= 78.6_EB  
      MW=28.8_EB
   CASE('CARBON MONOXIDE') 
      SIGMA=3.690_EB 
      EPSOK= 91.7_EB  
      MW=28._EB
      ABSORBING = .TRUE.
   CASE('CARBON DIOXIDE')  
      SIGMA=3.941_EB 
      EPSOK=195.2_EB  
      MW=44._EB
      ABSORBING = .TRUE.      
   CASE('ETHYLENE')        
      SIGMA=4.163_EB 
      EPSOK=224.7_EB 
      MW=28._EB
      ABSORBING = .TRUE.
   CASE('HELIUM')          
      SIGMA=2.551_EB 
      EPSOK= 10.22_EB 
      MW= 4._EB
   CASE('HYDROGEN')        
      SIGMA=2.827_EB 
      EPSOK= 59.7_EB
      MW= 2._EB
   CASE('METHANE')         
      SIGMA=3.758_EB 
      EPSOK=148.6_EB  
      MW=16._EB
      ABSORBING = .TRUE.
   CASE('NITROGEN')        
      SIGMA=3.798_EB 
      EPSOK= 71.4_EB  
      MW=28._EB
   CASE('OXYGEN')          
      SIGMA=3.467_EB 
      EPSOK=106.7_EB  
      MW=32._EB
   CASE('PROPANE')         
      SIGMA=5.118_EB 
      EPSOK=237.1_EB  
      MW=44._EB
      ABSORBING = .TRUE.
   CASE('WATER VAPOR')     
      SIGMA=2.641_EB 
      EPSOK=809.1_EB  
      MW=18._EB
      ABSORBING = .TRUE.
   CASE DEFAULT            
      SIGMA=3.711_EB 
      EPSOK= 78.6_EB
      MW=28.8_EB
END SELECT  
 
IF (SIGMAIN>0._EB) SIGMA = SIGMAIN
IF (EPSOKIN>0._EB) EPSOK = EPSOKIN
IF (MWIN   >0._EB) MW    = MWIN 
 
IF (GAS_NAME=='MIXTURE_FRACTION') MW = REACTION(1)%MW_FUEL
 
END SUBROUTINE GAS_PROPS
 
 
SUBROUTINE STATE_RELATIONSHIPS
 
! Calculate state relations, SPECIES(N)%Y_MF, and average molecular weight, SPECIES(N)%MW_MF, for major species tied to MIX_FRAC
! Y_MF(0:10000,I): I=1-Fuel,2-O2,3-N2,4-H2O,5-CO2,6-CO,7-H2,8-SOOT
 
REAL(EB) :: TOTAL_MASS,FUEL_BURNED,ZZ,DZZ,FUEL_TO_CO2
INTEGER :: N,REAC_INDEX(1:N_REACTIONS)

!Calc heat of formation if ideal heat of combustion data was input on REAC
REAC_INDEX = 0._EB
DO N = 1, N_SPECIES
   IF (SPECIES(N)%MODE==MIXTURE_FRACTION_SPECIES) REAC_INDEX(SPECIES(N)%REAC_INDEX) = N
ENDDO

REACTION_LOOP: DO N=1,N_REACTIONS
   RN => REACTION(N)
   SS => SPECIES(REAC_INDEX(N))

  ! Miscellaneous constants
 
   RN%Y_N2_INFTY = 1._EB-RN%Y_O2_INFTY  ! Assumes that air is made up of only oxygen and nitrogen
   RN%Y_N2_INLET = 1._EB-RN%Y_F_INLET   ! Assumes that the fuel is only diluted by nitrogen
   RN%Z_F_CONS = RN%NU_O2 * MW_O2/RN%MW_FUEL * (1._EB + RN%Y_N2_INFTY/RN%Y_O2_INFTY)
 
! Stoichiometric value of mixture fraction
 
   RN%Z_F = RN%Y_O2_INFTY/(RN%Y_O2_INFTY+RN%Y_F_INLET*RN%O2_F_RATIO)
 
! Compute Y_MF and MW_MF
   SS%Z_MAX = 0._EB
   SS%Y_MF(10000,:) = 0._EB
   SS%Y_MF(10000,FUEL_INDEX) = RN%Y_F_INLET
   SS%Y_MF(10000,N2_INDEX) = RN%Y_N2_INLET
   SS%MW_MF(10000) = 1/(RN%Y_F_INLET/RN%MW_FUEL+RN%Y_N2_INLET/MW_N2)
   DZZ = 1.E-4_EB
 
   Z_LOOP: DO I=0,9999
 
      ZZ=REAL(I,EB)*DZZ
      IF (RN%NU_O2 == 0) THEN
         SS%Y_MF(I,FUEL_INDEX)    =  ZZ*RN%Y_F_INLET
      ELSE
         SS%Y_MF(I,FUEL_INDEX)    =  ZZ*RN%Y_F_INLET - MIN( ZZ*RN%Y_F_INLET , (1._EB-ZZ)*RN%Y_O2_INFTY/RN%O2_F_RATIO )
      ENDIF
      SS%Y_MF(I,FUEL_INDEX)  = MAX(0._EB,SS%Y_MF(I,FUEL_INDEX))
      FUEL_BURNED            = ZZ * RN%Y_F_INLET - SS%Y_MF(I,FUEL_INDEX)
      SS%Y_MF(I,O2_INDEX)    = MAX(0._EB,(1._EB - ZZ) * RN%Y_O2_INFTY - FUEL_BURNED * RN%O2_F_RATIO)
      SS%Y_MF(I,N2_INDEX)    = RN%Y_N2_INFTY * (1._EB - ZZ) + ZZ * RN%Y_N2_INLET + FUEL_BURNED / RN%MW_FUEL * RN%NU_N2 * MW_N2
      SS%Y_MF(I,H2O_INDEX)   = FUEL_BURNED / RN%MW_FUEL * RN%NU_H2O   * MW_H2O 
      SS%Y_MF(I,CO2_INDEX)   = FUEL_BURNED / RN%MW_FUEL * RN%NU_CO2   * MW_CO2
      SS%Y_MF(I,CO_INDEX)    = FUEL_BURNED / RN%MW_FUEL * RN%NU_CO    * MW_CO              
      SS%Y_MF(I,H2_INDEX)    = FUEL_BURNED / RN%MW_FUEL * RN%NU_H2    * MW_H2  
      SS%Y_MF(I,SOOT_INDEX)  = FUEL_BURNED / RN%MW_FUEL * RN%NU_SOOT  * MW_SOOT  
      SS%Y_MF(I,OTHER_INDEX) = FUEL_BURNED / RN%MW_FUEL * RN%NU_OTHER * RN%MW_OTHER
      TOTAL_MASS             = SUM(SS%Y_MF(I,:))  
      SS%Y_MF(I,OTHER_INDEX) = SS%Y_MF(I,OTHER_INDEX) + 1._EB - TOTAL_MASS        
 
! Compute average molecular weight.
 
      SS%MW_MF(I) = 1._EB/(SS%Y_MF(I,FUEL_INDEX)/RN%MW_FUEL + SS%Y_MF(I,O2_INDEX)/MW_O2     + SS%Y_MF(I,N2_INDEX)/MW_N2   + &
                           SS%Y_MF(I,H2O_INDEX)/MW_H2O      + SS%Y_MF(I,CO2_INDEX)/MW_CO2   + SS%Y_MF(I,CO_INDEX)/MW_CO   + &
                           SS%Y_MF(I,H2_INDEX)/MW_H2        + SS%Y_MF(I,SOOT_INDEX)/MW_SOOT + SS%Y_MF(I,OTHER_INDEX)/RN%MW_OTHER)
   ENDDO Z_LOOP
 
   SS%RSUM_MF = R0/SS%MW_MF
 
ENDDO REACTION_LOOP
 
Y_CORR_O2   = 0._EB
Y_CORR_FUEL = 0._EB
IF (CO_PRODUCTION) THEN
   YYMAX(I_PROG_CO) = REACTION(1)%Z_F
   RN => REACTION(1)
   FUEL_TO_CO2 = REACTION(1)%MW_FUEL/(REACTION(1)%NU_CO*MW_CO2)   
   DO I=0,10000
      SPECIES(I_PROG_CO)%Z_MAX(I) = SPECIES(I_PROG_CO)%Y_MF(I,CO2_INDEX) * FUEL_TO_CO2
      ZZ=REAL(I,EB)*DZZ
      IF (ZZ > REACTION(2)%Z_F .AND. ZZ <REACTION(1)%Z_F) THEN
         Y_CORR_O2(I,FUEL_INDEX)   = -(            RN%MW_FUEL/ (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,O2_INDEX)     = -(RN%NU_O2*      MW_O2/   (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,H2O_INDEX)    =  (RN%NU_H2O*     MW_H2O/  (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,CO2_INDEX)    =  (RN%NU_CO2*     MW_CO2/  (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,CO_INDEX)     =  (RN%NU_CO*      MW_CO/   (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,H2_INDEX)     =  (RN%NU_H2*      MW_H2/   (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,SOOT_INDEX)   =  (RN%NU_SOOT*    MW_SOOT/ (RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)
         Y_CORR_O2(I,OTHER_INDEX)  =  (RN%NU_OTHER*RN%MW_OTHER/(RN%NU_O2*MW_O2))*SPECIES(I_FUEL)%Y_MF(I,O2_INDEX)      
         MW_MF_CORR_O2(I) = 1._EB/ &
                  (Y_CORR_O2(I,FUEL_INDEX)/RN%MW_FUEL + Y_CORR_O2(I,O2_INDEX)/MW_O2     + Y_CORR_O2(I,N2_INDEX)/MW_N2 + &
                  Y_CORR_O2(I,H2O_INDEX)/MW_H2O      + Y_CORR_O2(I,CO2_INDEX)/MW_CO2   + Y_CORR_O2(I,CO_INDEX)/MW_CO + &
                  Y_CORR_O2(I,H2_INDEX)/MW_H2        + Y_CORR_O2(I,SOOT_INDEX)/MW_SOOT + Y_CORR_O2(I,OTHER_INDEX)/RN%MW_OTHER)
         Y_CORR_FUEL(I,FUEL_INDEX)  = -(            RN%MW_FUEL/ (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,O2_INDEX)    = -(RN%NU_O2*      MW_O2/   (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,H2O_INDEX)   =  (RN%NU_H2O*     MW_H2O/  (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,CO2_INDEX)   =  (RN%NU_CO2*     MW_CO2/  (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,CO_INDEX)    =  (RN%NU_CO*      MW_CO/   (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,H2_INDEX)    =  (RN%NU_H2*      MW_H2/   (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,SOOT_INDEX)  =  (RN%NU_SOOT*    MW_SOOT/ (RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         Y_CORR_FUEL(I,OTHER_INDEX) =  (RN%NU_OTHER*RN%MW_OTHER/(RN%MW_FUEL))*SPECIES(I_PROG_CO)%Y_MF(I,FUEL_INDEX)
         MW_MF_CORR_FUEL(I) = 1._EB/ &
                  (Y_CORR_FUEL(I,FUEL_INDEX)/RN%MW_FUEL + Y_CORR_FUEL(I,O2_INDEX)/MW_O2     + Y_CORR_FUEL(I,N2_INDEX)/MW_N2 + &
                  Y_CORR_FUEL(I,H2O_INDEX)/MW_H2O      + Y_CORR_FUEL(I,CO2_INDEX)/MW_CO2   + Y_CORR_FUEL(I,CO_INDEX)/MW_CO + &
                  Y_CORR_FUEL(I,H2_INDEX)/MW_H2        + Y_CORR_FUEL(I,SOOT_INDEX)/MW_SOOT + Y_CORR_FUEL(I,OTHER_INDEX)/RN%MW_OTHER)
      ELSE
         Y_CORR_O2(I,FUEL_INDEX)   = 0._EB
         Y_CORR_O2(I,O2_INDEX)     = 0._EB
         Y_CORR_O2(I,H2O_INDEX)    = 0._EB
         Y_CORR_O2(I,CO2_INDEX)    = 0._EB
         Y_CORR_O2(I,CO_INDEX)     = 0._EB
         Y_CORR_O2(I,H2_INDEX)     = 0._EB
         Y_CORR_O2(I,SOOT_INDEX)   = 0._EB
         Y_CORR_O2(I,OTHER_INDEX)  = 0._EB
         MW_MF_CORR_O2(I) = MW_AIR
         Y_CORR_FUEL(I,FUEL_INDEX)  = 0._EB
         Y_CORR_FUEL(I,O2_INDEX)    = 0._EB
         Y_CORR_FUEL(I,H2O_INDEX)   = 0._EB
         Y_CORR_FUEL(I,CO2_INDEX)   = 0._EB
         Y_CORR_FUEL(I,CO_INDEX)    = 0._EB
         Y_CORR_FUEL(I,H2_INDEX)    = 0._EB
         Y_CORR_FUEL(I,SOOT_INDEX)  = 0._EB
         Y_CORR_FUEL(I,OTHER_INDEX) = 0._EB
         MW_MF_CORR_FUEL(I) = MW_AIR
      ENDIF
   ENDDO
ENDIF
YYMAX(I_PROG_F) = REACTION(1)%Z_F
IF (CO_PRODUCTION) THEN
   REACTION(3)%Z_F=1._EB   
ELSE
   REACTION(2)%Z_F=1._EB
ENDIF

END SUBROUTINE STATE_RELATIONSHIPS
 
END SUBROUTINE PROC_SPEC
 
 
SUBROUTINE READ_PART
USE DEVICE_VARIABLES, ONLY : PROPERTY_TYPE, PROPERTY, N_PROP
USE RADCONS, ONLY : NDG,NUMBER_SPECTRAL_BANDS 
INTEGER :: NUMBER_INITIAL_DROPLETS,SAMPLING_FACTOR,DROPLETS_PER_SECOND,N,NN,NNN,IPC,RGB(3)
REAL(EB) :: SPECIFIC_HEAT,VAPORIZATION_TEMPERATURE,DUMMY, MELTING_TEMPERATURE,MASS_PER_VOLUME,DIAMETER, &
            GAMMA_D,AGE,INITIAL_TEMPERATURE,HEAT_OF_COMBUSTION,HEAT_OF_VAPORIZATION,DENSITY,DT_INSERT, &
            VERTICAL_VELOCITY,HORIZONTAL_VELOCITY,MAXIMUM_DIAMETER,MINIMUM_DIAMETER
CHARACTER(30) :: SPEC_ID,QUANTITIES(10)
CHARACTER(25) :: COLOR
LOGICAL :: MASSLESS,STATIC,FUEL,WATER,TREE,MONODISPERSE
TYPE(PARTICLE_CLASS_TYPE), POINTER :: PC
TYPE(PROPERTY_TYPE), POINTER :: PY
NAMELIST /PART/ NUMBER_INITIAL_DROPLETS,FYI,DROPLETS_PER_SECOND,MASS_PER_VOLUME, &
                SAMPLING_FACTOR,ID,STATIC,MASSLESS,FUEL,WATER,TREE, &
                DENSITY,VAPORIZATION_TEMPERATURE,SPECIFIC_HEAT,HEAT_OF_VAPORIZATION, &
                MELTING_TEMPERATURE,DIAMETER,MAXIMUM_DIAMETER,MINIMUM_DIAMETER,GAMMA_D,HEAT_OF_COMBUSTION, &
                AGE,SPEC_ID,INITIAL_TEMPERATURE,XB,RGB,QUANTITIES,DT_INSERT,COLOR, &
                VERTICAL_VELOCITY,HORIZONTAL_VELOCITY,GAMMA,MONODISPERSE

! Determine total number of PART lines in the input file
 
REWIND(LU_INPUT)
N_PART = 0
N_EVAP_INDICIES = 0
COUNT_PART_LOOP: DO
   CALL CHECKREAD('PART',LU_INPUT,IOS) 
   IF (IOS==1) EXIT COUNT_PART_LOOP
   READ(LU_INPUT,PART,END=219,ERR=220,IOSTAT=IOS)
   N_PART = N_PART + 1
   220 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with PART line')
ENDDO COUNT_PART_LOOP
219 REWIND(LU_INPUT)
 
! Allocate the derived type array to hold information about the particle classes

ALLOCATE(PARTICLE_CLASS(N_PART),STAT=IZERO)
CALL ChkMemErr('READ','PARTICLE_CLASS',IZERO) 

READ_PART_LOOP: DO N=1,N_PART
 
   PC=>PARTICLE_CLASS(N)
   DENSITY                  = 1000._EB     ! kg/m3
   DT_INSERT                = 0.05_EB      ! s
   MASS_PER_VOLUME          = 1._EB        ! kg/m3
   VAPORIZATION_TEMPERATURE = 100.0_EB     ! C
   INITIAL_TEMPERATURE      = TMPA - TMPM  ! C
   MELTING_TEMPERATURE      = TMPM - TMPM  ! C
   SPECIFIC_HEAT            = 4.184_EB     ! kJ/kg-K
   HEAT_OF_VAPORIZATION     = 2259._EB     ! kJ/kg
   HEAT_OF_COMBUSTION       = -1._EB       ! kJ/kg
   DROPLETS_PER_SECOND      = 1000
   GAMMA                    = 1.4          !Specific heat ratio
   DIAMETER                 = 500._EB      ! microns
   MAXIMUM_DIAMETER         = 1.E9_EB      ! microns, meant to be infinitely large and not used
   MINIMUM_DIAMETER         =  20._EB      ! microns, below which the droplet evaporates in one time step
   MONODISPERSE             = .FALSE.
   GAMMA_D                  = 2.4_EB
   AGE                      = 1.E6_EB      ! s
   ID                       = 'null'
   QUANTITIES               = 'null'
   RGB                      = -1
   SPEC_ID                  = 'null'
   COLOR                    = 'null'
   SAMPLING_FACTOR          = -1      
   NUMBER_INITIAL_DROPLETS  = 0
   XB                       = 0._EB
   FUEL                     = .FALSE.
   WATER                    = .FALSE.
   STATIC                   = .FALSE.
   MASSLESS                 = .FALSE.
   TREE                     = .FALSE.
   VERTICAL_VELOCITY        = 0.5_EB
   HORIZONTAL_VELOCITY      = 0.2_EB
 
   ! Read the PART line from the input file or set up special PARTICLE_CLASS class for water droplets or tracers
 
   CALL CHECKREAD('PART',LU_INPUT,IOS) 
   IF (IOS==1) EXIT READ_PART_LOOP
   READ(LU_INPUT,PART)

   IF (ANY(RGB<0) .AND. COLOR=='null') THEN
      COLOR = 'BLACK'
      IF (WATER) COLOR = 'BLUE'
      IF (TREE)  COLOR = 'GREEN'
      IF (FUEL)  COLOR = 'YELLOW'
   ENDIF
   IF (COLOR /= 'null') CALL COLOR2RGB(RGB,COLOR)

   ! Miscellaneous consequences of input parameters

   IF (TREE)                                    STATIC                  = .TRUE.
   IF (MASSLESS)                                DIAMETER                = 0._EB
   IF (FUEL)                                    SPEC_ID                 = 'MIXTURE_FRACTION_1'
   IF (WATER)                                   SPEC_ID                 = 'WATER VAPOR'
   IF (FUEL)                                    FUEL_EVAPORATION        = .TRUE.
   IF (WATER)                                   WATER_EVAPORATION       = .TRUE.
   IF (WATER)                                   GAMMA                   = 1.32_EB
   IF (SAMPLING_FACTOR<=0 .AND.      MASSLESS)  SAMPLING_FACTOR         = 1
   IF (SAMPLING_FACTOR<=0 .AND. .NOT.MASSLESS)  SAMPLING_FACTOR         = 10
   IF (NUMBER_INITIAL_DROPLETS>0 .AND. RESTART) NUMBER_INITIAL_DROPLETS =  0

   PC%QUANTITIES = QUANTITIES
   ! Set up arrays in case the domain is to be seeded with droplets/particles

   IF (NUMBER_INITIAL_DROPLETS>0) DROPLET_FILE  = .TRUE.
   IF (NUMBER_INITIAL_DROPLETS>0) THEN
      DO I=1,5,2
         IF (XB(I)>XB(I+1)) THEN
            DUMMY   = XB(I)
            XB(I)   = XB(I+1)
            XB(I+1) = DUMMY
         ENDIF
      ENDDO
   ENDIF
   PC%X1 = XB(1)
   PC%X2 = XB(2)
   PC%Y1 = XB(3)
   PC%Y2 = XB(4)
   PC%Z1 = XB(5)
   PC%Z2 = XB(6)
   PC%GAMMA_VAP = GAMMA
   PC%N_INITIAL = NUMBER_INITIAL_DROPLETS
 
   ! Arrays for particle size distribution

   IF (DIAMETER > 0._EB) THEN
      ALLOCATE(PC%CDF(0:NDC),STAT=IZERO)
      CALL ChkMemErr('READ','CDF',IZERO)
      ALLOCATE(PC%R_CDF(0:NDC),STAT=IZERO)
      CALL ChkMemErr('READ','R_CDF',IZERO)
      ALLOCATE(PC%IL_CDF(NSTRATA),STAT=IZERO)
      CALL ChkMemErr('READ','IL_CDF',IZERO)
      ALLOCATE(PC%IU_CDF(NSTRATA),STAT=IZERO)
      CALL ChkMemErr('READ','IU_CDF',IZERO)
      ALLOCATE(PC%W_CDF(NSTRATA),STAT=IZERO)
      CALL ChkMemErr('READ','W_CDF',IZERO)
   ENDIF
   ALLOCATE(PC%INSERT_CLOCK(NMESHES),STAT=IZERO)
   CALL ChkMemErr('READ','INSERT_CLOCK',IZERO)
   PC%INSERT_CLOCK = T_BEGIN
   
   ! Assign property data to PARTICLE_CLASS class
 
   PC%CLASS_NAME         = ID
   PC%DT_INSERT          = DT_INSERT
   PC%N_INSERT           = DROPLETS_PER_SECOND*DT_INSERT
   PC%SAMPLING           = SAMPLING_FACTOR
   PC%RGB                = RGB
   PC%DIAMETER           = DIAMETER*1.E-6_EB
   PC%MAXIMUM_DIAMETER   = MAXIMUM_DIAMETER*1.E-6_EB
   PC%MINIMUM_DIAMETER   = MINIMUM_DIAMETER*1.E-6_EB
   PC%MONODISPERSE       = MONODISPERSE
   PC%GAMMA              = GAMMA_D
   PC%SIGMA              = 1.15_EB/GAMMA_D
   PC%TMP_INITIAL        = INITIAL_TEMPERATURE + TMPM
   PC%C_P                = SPECIFIC_HEAT*1000._EB
   PC%H_V                = HEAT_OF_VAPORIZATION*1000._EB
   PC%HEAT_OF_COMBUSTION = HEAT_OF_COMBUSTION*1000._EB
   PC%TMP_V              = VAPORIZATION_TEMPERATURE + TMPM
   PC%DENSITY            = DENSITY
   PC%FTPR               = FOTH*PI*DENSITY
   PC%MASS_PER_VOLUME    = MASS_PER_VOLUME
   PC%TMP_MELT           = MELTING_TEMPERATURE + TMPM
   PC%MASSLESS           = MASSLESS
   PC%LIFETIME           = AGE
   PC%TREE               = TREE
   PC%FUEL               = FUEL
   PC%WATER              = WATER
   PC%STATIC             = STATIC
   PC%SPECIES            = SPEC_ID
   PC%SPECIES_INDEX      = 0       ! SPECies have not yet been read in
   PC%ADJUST_EVAPORATION = 1._EB   ! If H_O_C>0. this parameter will have to be reset later
   PC%VERTICAL_VELOCITY  = VERTICAL_VELOCITY
   PC%HORIZONTAL_VELOCITY= HORIZONTAL_VELOCITY
  
ENDDO READ_PART_LOOP

IF (FUEL_EVAPORATION .OR. WATER_EVAPORATION) EVAPORATION=.TRUE.

! Assign PART_INDEX to Device PROPERTY array

DO N=1,N_PROP
   PY => PROPERTY(N)
   PY%PART_INDEX = 0
   IF (PY%PART_ID/='null') THEN
      DO IPC=1,N_PART
         PC=>PARTICLE_CLASS(IPC)
         IF (PC%CLASS_NAME==PY%PART_ID) PY%PART_INDEX = IPC
      ENDDO
      IF (PY%PART_INDEX==0) THEN
         WRITE(MESSAGE,'(A,I4,A)') 'ERROR: PART_ID for PROP ' ,N,' not found'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      DROPLET_FILE=.TRUE.
   ENDIF
ENDDO

PLOOP2: DO IPC=1,N_PART
   PC=>PARTICLE_CLASS(IPC)
   DO N=1,IPC-1
      IF ( N/=IPC .AND. PC%CLASS_NAME==PARTICLE_CLASS(N)%CLASS_NAME) THEN
         PC%EVAP_INDEX = PARTICLE_CLASS(N)%EVAP_INDEX
         CYCLE PLOOP2
      ENDIF
   ENDDO

   ! Allocate radiation arrays

   PC%EVAP_INDEX = 0
   IF (PC%FUEL .OR. PC%WATER) THEN
      ALLOCATE(PC%WQABS(0:NDG,1:NUMBER_SPECTRAL_BANDS))
      PC%WQABS = 0._EB
      CALL ChkMemErr('INIT','WQABS',IZERO)
      ALLOCATE(PC%WQSCA(0:NDG,1:NUMBER_SPECTRAL_BANDS))
      CALL ChkMemErr('INIT','WQSCA',IZERO)
      PC%WQSCA = 0._EB
      ALLOCATE(PC%KWR(0:NDG))
      CALL ChkMemErr('INIT','KWR',IZERO)
      PC%KWR = 0._EB
      N_EVAP_INDICIES = N_EVAP_INDICIES + 1
      PC%EVAP_INDEX = N_EVAP_INDICIES
   ENDIF
ENDDO PLOOP2

CALL PARTICLE_OUTPUT_QUANTITIES

! Determine output quantities

DO N=1,N_PART
   PC=>PARTICLE_CLASS(N)
   PC%N_QUANTITIES = 0
   IF (ANY(PC%QUANTITIES/='null')) THEN
      QUANTITIES_LOOP: DO NN=1,10
         IF (PC%QUANTITIES(NN)=='null') CYCLE QUANTITIES_LOOP
         DO NNN=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
            IF (PC%QUANTITIES(NN)==OUTPUT_QUANTITY(NNN)%NAME .AND. OUTPUT_QUANTITY(NNN)%PART_APPROPRIATE) THEN
               PC%N_QUANTITIES = PC%N_QUANTITIES + 1
               PC%QUANTITIES_INDEX(PC%N_QUANTITIES) = NNN
               CYCLE QUANTITIES_LOOP
            ENDIF
         ENDDO
         WRITE(MESSAGE,'(A)') 'ERROR: '//TRIM(PC%QUANTITIES(NN))//' is not a particle output quantity'
         CALL SHUTDOWN(MESSAGE)
      ENDDO QUANTITIES_LOOP
   ENDIF
ENDDO 

END SUBROUTINE READ_PART
 
 
SUBROUTINE READ_TREE
 
INTEGER :: IPC,N_TREES_0,NM,NN,N
REAL(EB) :: CANOPY_WIDTH,CANOPY_BASE_HEIGHT,TREE_HEIGHT,XYZ(3)
CHARACTER(30) :: PART_ID
TYPE(PARTICLE_CLASS_TYPE), POINTER :: PC
NAMELIST /TREE/ XYZ,CANOPY_WIDTH,CANOPY_BASE_HEIGHT, TREE_HEIGHT,PART_ID

! Read the TREE lines to determine how many cone shaped trees
! there will be

N_TREES = 0
REWIND(LU_INPUT)
COUNT_TREE_LOOP: DO
   CALL CHECKREAD('TREE',LU_INPUT,IOS) 
   IF (IOS==1) EXIT COUNT_TREE_LOOP
   READ(LU_INPUT,NML=TREE,END=11,ERR=12,IOSTAT=IOS)
   N_TREES = N_TREES + 1
   12 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with TREE line')
ENDDO COUNT_TREE_LOOP
11 REWIND(LU_INPUT)
!
! Sequentially read the CONE_TREE namelist to get shape and size
! parameters for each tree.
!
IF (N_TREES==0) RETURN
!
ALLOCATE(CANOPY_W(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','CANOPY_W',IZERO)
ALLOCATE(CANOPY_B_H(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','CANOPY_B_H',IZERO)
ALLOCATE(TREE_H(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','TREE_H',IZERO)
ALLOCATE(X_TREE(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','X_TREE',IZERO)
ALLOCATE(Y_TREE(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','Y_TREE',IZERO)
ALLOCATE(Z_TREE(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','Z_TREE',IZERO)
ALLOCATE(TREE_PARTICLE_CLASS(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','TREE_PARTICLE_CLASS',IZERO)
ALLOCATE(TREE_MESH(N_TREES),STAT=IZERO)
CALL ChkMemErr('READ','TREE_MESH',IZERO)
!
N_TREES_0 = N_TREES
N = 0
!
CONE_LOOP: DO NN=1,N_TREES_0
   N = N + 1
!
   PART_ID = 'null'
!
   CALL CHECKREAD('TREE',LU_INPUT,IOS)
   IF (IOS==1) EXIT CONE_LOOP
   READ(LU_INPUT,TREE,END=25,IOSTAT=IOS)
!
   MESH_LOOP: DO NM=1,NMESHES
      IF (.NOT.EVACUATION_ONLY(NM)) THEN
         IF (XYZ(1)>=MESHES(NM)%XS .AND. XYZ(1)<=MESHES(NM)%XF .AND. &
             XYZ(2)>=MESHES(NM)%YS .AND. XYZ(2)<=MESHES(NM)%YF .AND. &
             XYZ(3)>=MESHES(NM)%ZS .AND. XYZ(3)<=MESHES(NM)%ZF) THEN
            TREE_MESH(N) = NM
            EXIT MESH_LOOP
         ENDIF
      ENDIF !EVACUATION_ONLY
      IF (NM==NMESHES) THEN
         N    = N-1
         N_TREES = N_TREES - 1
         CYCLE CONE_LOOP
      ENDIF
   ENDDO MESH_LOOP
!
   IF (PART_ID=='null') CALL SHUTDOWN('ERROR: Specify PART_ID of tree')
!
   CANOPY_W(N)   = CANOPY_WIDTH
   CANOPY_B_H(N) = CANOPY_BASE_HEIGHT
   TREE_H(N)     = TREE_HEIGHT
   X_TREE(N) = XYZ(1)
   Y_TREE(N) = XYZ(2)
   Z_TREE(N) = XYZ(3)
!
   DO IPC=1,N_PART
      PC=>PARTICLE_CLASS(IPC)
      IF (PC%CLASS_NAME==PART_ID) TREE_PARTICLE_CLASS(N) = IPC
   ENDDO
   DROPLET_FILE=.TRUE.
!
ENDDO CONE_LOOP
25 REWIND(LU_INPUT)
!
END SUBROUTINE READ_TREE
 
 
SUBROUTINE READ_PROP
USE DEVICE_VARIABLES
USE MATH_FUNCTIONS, ONLY : GET_RAMP_INDEX,GET_TABLE_INDEX
REAL(EB) :: ACTIVATION_OBSCURATION,ACTIVATION_TEMPERATURE,ALPHA_C,ALPHA_E,BETA_C,BETA_E, &
            BEAD_DIAMETER,BEAD_EMISSIVITY,C_FACTOR,CHARACTERISTIC_VELOCITY, &
            DROPLET_VELOCITY,FLOW_RATE,FLOW_TAU,GAUGE_TEMPERATURE,INITIAL_TEMPERATURE,K_FACTOR,LENGTH,SPRAY_ANGLE(2), &
            OFFSET,OPERATING_PRESSURE,RTI
INTEGER :: N            
EQUIVALENCE(LENGTH,ALPHA_C)
CHARACTER(30) :: SMOKEVIEW_ID,QUANTITY,PART_ID,FLOW_RAMP,SPRAY_PATTERN_TABLE
TYPE (PROPERTY_TYPE), POINTER :: PY

NAMELIST /PROP/ ACTIVATION_OBSCURATION,ACTIVATION_TEMPERATURE,ALPHA_C,ALPHA_E,BETA_C,BETA_E, &
                BEAD_DIAMETER,BEAD_EMISSIVITY,C_FACTOR,CHARACTERISTIC_VELOCITY, &
                DROPLET_VELOCITY,FLOW_RATE,FLOW_RAMP,FLOW_TAU,ID,GAUGE_TEMPERATURE,INITIAL_TEMPERATURE,K_FACTOR,LENGTH,OFFSET, &
                OPERATING_PRESSURE,PART_ID,QUANTITY,RTI,SPRAY_ANGLE,SMOKEVIEW_ID,SPRAY_PATTERN_TABLE

! Count the PROP lines in the input file
N_PROP=0
REWIND(LU_INPUT)
COUNT_PROP_LOOP: DO
   CALL CHECKREAD('PROP',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_PROP_LOOP
   READ(LU_INPUT,PROP,ERR=34,IOSTAT=IOS)
   N_PROP = N_PROP + 1
   34 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with PROP number', N_PROP+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_PROP_LOOP
 
! Allocate the PROPERTY derived types
 
ALLOCATE(PROPERTY(0:N_PROP),STAT=IZERO)
CALL ChkMemErr('READ','PROPERTY',IZERO) 
 
! Read the PROP lines in the order listed in the input file
 
REWIND(LU_INPUT)

READ_PROP_LOOP: DO N=0,N_PROP
 
   CALL CHECKREAD('PROP',LU_INPUT,IOS)  ! Look for PROP lines in the input file
   CALL SET_PROP_DEFAULTS          ! Reset PROP NAMELIST parameters to default values 
   IF (N > 0) READ(LU_INPUT,PROP) 

   ! Pack PROP parameters into the appropriate property derived types
   PY => PROPERTY(N)
   PY%ACTIVATION_OBSCURATION   = ACTIVATION_OBSCURATION
   PY%ACTIVATION_TEMPERATURE   = ACTIVATION_TEMPERATURE   ! NOTE: Act_Temp remains in degrees C. It is just a SETPOINT.
   PY%ALPHA_C                  = ALPHA_C
   PY%ALPHA_E                  = ALPHA_E
   PY%BETA_C                   = BETA_C
   PY%BETA_E                   = BETA_E
   PY%BEAD_DIAMETER            = BEAD_DIAMETER
   PY%BEAD_EMISSIVITY          = BEAD_EMISSIVITY
   PY%C_FACTOR                 = C_FACTOR
   PY%CHARACTERISTIC_VELOCITY  = CHARACTERISTIC_VELOCITY
   PY%DROPLET_VELOCITY         = DROPLET_VELOCITY
   IF (FLOW_RAMP /= 'null') THEN
      CALL GET_RAMP_INDEX(FLOW_RAMP,'TIME',PY%FLOW_RAMP_INDEX)
   ELSE
      PY%FLOW_RAMP_INDEX = 0
   ENDIF 
   IF (PART_ID/='null' .AND. SPRAY_PATTERN_TABLE /= 'null') THEN
      CALL GET_TABLE_INDEX(SPRAY_PATTERN_TABLE,SPRAY_PATTERN,PY%SPRAY_PATTERN_INDEX)
      PY%TABLE_ID = SPRAY_PATTERN_TABLE
   ELSE
      PY%SPRAY_PATTERN_INDEX = 0
   ENDIF 
   IF (FLOW_TAU /= 0._EB) THEN
      PY%FLOW_TAU = FLOW_TAU 
      IF (FLOW_TAU > 0._EB) PY%FLOW_RAMP_INDEX = TANH_RAMP 
      IF (FLOW_TAU < 0._EB) PY%FLOW_RAMP_INDEX = TSQR_RAMP
   ENDIF 
   IF (FLOW_RATE > 0._EB) THEN
      PY%FLOW_RATE             = FLOW_RATE
   ELSE
      PY%FLOW_RATE             = K_FACTOR*SQRT(OPERATING_PRESSURE)
   ENDIF
   PY%GAUGE_TEMPERATURE        = GAUGE_TEMPERATURE + TMPM
   PY%ID                       = ID
   PY%INITIAL_TEMPERATURE      = INITIAL_TEMPERATURE + TMPM
   PY%K_FACTOR                 = K_FACTOR
   PY%OFFSET                   = OFFSET
   PY%OPERATING_PRESSURE       = OPERATING_PRESSURE
   PY%PART_ID                  = PART_ID
   PY%QUANTITY                 = QUANTITY
   PY%RTI                      = RTI
   IF (SMOKEVIEW_ID /= 'null') THEN
      PY%SMOKEVIEW_ID          = SMOKEVIEW_ID
   ELSE
      SELECT CASE(QUANTITY)
         CASE DEFAULT
            PY%SMOKEVIEW_ID = 'sensor'
         CASE('SPRINKLER LINK TEMPERATURE')
            PY%SMOKEVIEW_ID = 'sprinkler_pendent'
         CASE('LINK TEMPERATURE')
            PY%SMOKEVIEW_ID = 'heat_detector'
         CASE('spot obscuration')
            PY%SMOKEVIEW_ID = 'smoke_detector'
      END SELECT
   ENDIF
   IF (PY%PART_ID/='null' .AND. PY%SMOKEVIEW_ID == 'null' ) PY%SMOKEVIEW_ID = 'nozzle'
   PY%SPRAY_ANGLE(1)           = SPRAY_ANGLE(1)*PI/180._EB
   PY%SPRAY_ANGLE(2)           = SPRAY_ANGLE(2)*PI/180._EB

ENDDO READ_PROP_LOOP
 
 
CONTAINS

 
SUBROUTINE SET_PROP_DEFAULTS
 
ACTIVATION_OBSCURATION   = 3.28_EB     ! %/m
ACTIVATION_TEMPERATURE   = 74.0_EB     ! C
ALPHA_C                  = 1.8_EB      ! m, Heskestad Length Scale
ALPHA_E                  = 0.0_EB
BETA_C                   = -1.0_EB
BETA_E                   = -1.0_EB
BEAD_DIAMETER            = 0.001       ! m
BEAD_EMISSIVITY          = 0.85_EB
C_FACTOR                 = 0.0_EB
CHARACTERISTIC_VELOCITY  = 1.0_EB      ! m/s
DROPLET_VELOCITY         = 5._EB       ! m/s
FLOW_RATE                = -1.         ! L/min
FLOW_RAMP                = 'null'
FLOW_TAU                 = 0._EB
GAUGE_TEMPERATURE        = TMPA - TMPM
INITIAL_TEMPERATURE      = TMPA - TMPM
ID                       = 'null'
K_FACTOR                 = 1.0_EB      ! L/min/atm**0.5
OFFSET                   = 0.05_EB     ! m
OPERATING_PRESSURE       = 1.0_EB      ! atm
PART_ID                  = 'null'
QUANTITY                 = 'null'
RTI                      = 100._EB     ! (ms)**0.5
SMOKEVIEW_ID             = 'null' 
SPRAY_ANGLE(1)           = 60._EB      ! degrees
SPRAY_ANGLE(2)           = 75._EB      ! degrees
SPRAY_PATTERN_TABLE      = 'null'
END SUBROUTINE SET_PROP_DEFAULTS
 
END SUBROUTINE READ_PROP
 
SUBROUTINE PROC_PROP
USE DEVICE_VARIABLES
REAL(EB) :: TOTAL_FLOWRATE, SUBTOTAL_FLOWRATE
INTEGER :: N,NN
TYPE (PROPERTY_TYPE), POINTER :: PY
TYPE (TABLES_TYPE),  POINTER :: TA

PROP_LOOP: DO N=0,N_PROP
   PY => PROPERTY(N)
    !Set up spinkler distributrion if needed
   IF (PY%SPRAY_PATTERN_INDEX>0) THEN
      TA => TABLES(PY%SPRAY_PATTERN_INDEX)
      ALLOCATE(PY%TABLE_ROW(1:TA%NUMBER_ROWS))
      TOTAL_FLOWRATE=0._EB
      SUBTOTAL_FLOWRATE=0._EB
      DO NN=1,TA%NUMBER_ROWS
         TOTAL_FLOWRATE = TOTAL_FLOWRATE + TA%TABLE_DATA(NN,6)
      ENDDO
      DO NN=1,TA%NUMBER_ROWS
         TA%TABLE_DATA(NN,1) = TA%TABLE_DATA(NN,1) * PI/180._EB
         TA%TABLE_DATA(NN,2) = TA%TABLE_DATA(NN,2) * PI/180._EB
         TA%TABLE_DATA(NN,3) = TA%TABLE_DATA(NN,3) * PI/180._EB
         TA%TABLE_DATA(NN,4) = TA%TABLE_DATA(NN,4) * PI/180._EB
         SUBTOTAL_FLOWRATE = SUBTOTAL_FLOWRATE + TA%TABLE_DATA(NN,6)
         PY%TABLE_ROW(NN) = SUBTOTAL_FLOWRATE/TOTAL_FLOWRATE
      ENDDO
      PY%TABLE_ROW(TA%NUMBER_ROWS) = 1._EB
   END IF
 
ENDDO PROP_LOOP

END SUBROUTINE PROC_PROP

SUBROUTINE READ_MATL
USE MATH_FUNCTIONS, ONLY : GET_RAMP_INDEX
CHARACTER(30) :: CONDUCTIVITY_RAMP,SPECIFIC_HEAT_RAMP
REAL(EB) :: EMISSIVITY,CONDUCTIVITY,SPECIFIC_HEAT,DENSITY,HEAT_OF_COMBUSTION,REFERENCE_RATE,ABSORPTION_COEFFICIENT
REAL(EB), DIMENSION(1:MAX_REACTIONS) :: A,E,HEAT_OF_REACTION,NU_FUEL,NU_WATER,NU_RESIDUE,N_S,N_T,&
                                        REFERENCE_TEMPERATURE,IGNITION_TEMPERATURE,BOILING_TEMPERATURE
CHARACTER(30), DIMENSION(1:MAX_REACTIONS) :: RESIDUE
INTEGER :: N,NN,NNN,IOS,NR,N_REACTIONS
NAMELIST /MATL/ ID,FYI,SPECIFIC_HEAT,CONDUCTIVITY,CONDUCTIVITY_RAMP,SPECIFIC_HEAT_RAMP, &
                REFERENCE_TEMPERATURE, REFERENCE_RATE, IGNITION_TEMPERATURE, &
                EMISSIVITY,HEAT_OF_REACTION,DENSITY,RESIDUE, &
                HEAT_OF_COMBUSTION,A,E,NU_FUEL,NU_WATER,NU_RESIDUE,N_S,N_T,N_REACTIONS,&
                ABSORPTION_COEFFICIENT, BOILING_TEMPERATURE

! Count the MATL lines in the input file
 
REWIND(LU_INPUT)
N_MATL = 0
COUNT_MATL_LOOP: DO
   CALL CHECKREAD('MATL',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_MATL_LOOP
   READ(LU_INPUT,MATL,ERR=34,IOSTAT=IOS)
   N_MATL = N_MATL + 1
   MATL_NAME(N_MATL) = ID
   34 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with MATL number', N_MATL+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_MATL_LOOP
 
! Allocate the MATERIAL derived type
 
ALLOCATE(MATERIAL(1:N_MATL),STAT=IZERO)
CALL ChkMemErr('READ','MATERIAL',IZERO) 
 
! Read the MATL lines in the order listed in the input file
 
REWIND(LU_INPUT)
 
READ_MATL_LOOP: DO N=1,N_MATL
 
   ML => MATERIAL(N)
   CALL CHECKREAD('MATL',LU_INPUT,IOS)
   CALL SET_MATL_DEFAULTS
   READ(LU_INPUT,MATL) 

   ! Do some error checking on the inputs

   IF (ANY(IGNITION_TEMPERATURE>-TMPM) .AND. N_REACTIONS==0) THEN
      WRITE(MESSAGE,'(A,I2,A)') 'ERROR: Problem with MATL number ',N,'. IGNITION_TEMPERATURE used, but N_REACTIONS=0' 
      CALL SHUTDOWN(MESSAGE)
   ENDIF
 
   ! Pack MATL parameters into the MATERIAL derived type
 
   ML%A(:)                 = A(:)
   ML%ADJUST_BURN_RATE     = 1._EB
   ML%C_S                  = 1000._EB*SPECIFIC_HEAT/TIME_SHRINK_FACTOR
   ML%E(:)                 = 1000._EB*E(:)
   ML%EMISSIVITY           = EMISSIVITY
   ML%HEAT_OF_COMBUSTION   = 1000._EB*HEAT_OF_COMBUSTION
   ML%H_R(:)               = 1000._EB*HEAT_OF_REACTION(:)
   ML%KAPPA_S              = ABSORPTION_COEFFICIENT
   ML%K_S                  = CONDUCTIVITY
   ML%N_REACTIONS          = N_REACTIONS
   ML%N_S(:)               = N_S(:)
   ML%N_T(:)               = N_T(:)
   ML%NU_FUEL(:)           = NU_FUEL(:)
   ML%NU_RESIDUE(:)        = NU_RESIDUE(:)
   ML%NU_WATER(:)          = NU_WATER(:)
   ML%RAMP_C_S             = SPECIFIC_HEAT_RAMP
   ML%RAMP_K_S             = CONDUCTIVITY_RAMP
   ML%RHO_S                = DENSITY
   ML%RESIDUE_MATL_NAME(:) = RESIDUE(:)
   ML%TMP_BOIL(:)          = BOILING_TEMPERATURE(:) + TMPM
   ML%TMP_IGN(:)           = IGNITION_TEMPERATURE(:) + TMPM
   ML%TMP_REF(:)           = REFERENCE_TEMPERATURE(:) + TMPM
 
   ! Additional logic

   IF (ANY(BOILING_TEMPERATURE<5000._EB)) THEN
      ML%PYROLYSIS_MODEL = PYROLYSIS_LIQUID
      ML%N_REACTIONS = 1
      IF (ML%NU_FUEL(1)==0._EB) ML%NU_FUEL(1) = 1._EB
   ELSE
      ML%PYROLYSIS_MODEL = PYROLYSIS_SOLID
      IF (N_REACTIONS==0) ML%PYROLYSIS_MODEL = PYROLYSIS_NONE
   ENDIF

   DO NN=1,ML%N_REACTIONS
      IF (NU_FUEL(NN) > 0._EB) MIXTURE_FRACTION = .TRUE.
   ENDDO

   IF (ML%RAMP_K_S/='null') THEN
      CALL GET_RAMP_INDEX(ML%RAMP_K_S,'TEMPERATURE',NR)
      ML%K_S = -NR
   ENDIF

   IF (ML%RAMP_C_S/='null') THEN
      CALL GET_RAMP_INDEX(ML%RAMP_C_S,'TEMPERATURE',NR)
      ML%C_S = -NR
   ENDIF

   DO NN=1,ML%N_REACTIONS
      IF (ML%TMP_REF(NN) > 0._EB  .AND. ML%E(NN)< 0._EB) ML%E(NN) = -LOG(REFERENCE_RATE/ML%A(NN))*R0*ML%TMP_REF(NN)
   ENDDO
 
ENDDO READ_MATL_LOOP
 
! Assign a material index to the RESIDUEs

DO N=1,N_MATL
   ML => MATERIAL(N)
   ML%RESIDUE_MATL_INDEX = 0
   DO NN=1,ML%N_REACTIONS
      DO NNN=1,N_MATL
         IF (MATL_NAME(NNN)==ML%RESIDUE_MATL_NAME(NN)) ML%RESIDUE_MATL_INDEX(NN) = NNN
      ENDDO
      IF (ML%RESIDUE_MATL_INDEX(NN)==0 .AND. ML%NU_RESIDUE(NN)>0._EB) THEN
         WRITE(MESSAGE,'(5A)') 'ERROR: Residue material ', TRIM(ML%RESIDUE_MATL_NAME(NN)),' of ', &
            TRIM(MATL_NAME(N)), ' is not defined.'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDDO
ENDDO

!Check for duplicate names
IF (N_MATL>1) THEN
   DO N=1,N_MATL-1
      DO NN=N+1,N_MATL
         IF(MATL_NAME(N)==MATL_NAME(NN)) THEN
            WRITE(MESSAGE,'(A,A)') 'Duplicate material name: ',TRIM(MATL_NAME(N))
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDDO
   ENDDO
ENDIF
CONTAINS
 
SUBROUTINE SET_MATL_DEFAULTS
 
A                      = 1.E13_EB    ! 1/s
ABSORPTION_COEFFICIENT = 5.0E4_EB    ! 1/m, corresponds to 99.3% drop within 1E-4 m distance.
BOILING_TEMPERATURE    = 5000._EB    ! C
CONDUCTIVITY           = 0.1_EB      ! W/m/K
CONDUCTIVITY_RAMP      = 'null'
DENSITY                = 500._EB     ! kg/m3
E                      = -1._EB      ! kJ/kmol
EMISSIVITY             = 0.9_EB
HEAT_OF_COMBUSTION     = -1._EB      ! kJ/kg
HEAT_OF_REACTION       = 0._EB       ! kJ/kg
ID                     = 'null'
IGNITION_TEMPERATURE   = -TMPM       ! 0 K
N_REACTIONS            = 0
N_S                    = 1._EB
N_T                    = 0._EB
NU_FUEL                = 0._EB
NU_RESIDUE             = 0._EB
NU_WATER               = 0._EB
REFERENCE_TEMPERATURE  = -1000._EB
REFERENCE_RATE         = 0.1_EB
RESIDUE                = 'null'
SPECIFIC_HEAT          = 1.0_EB      ! kJ/kg/K
SPECIFIC_HEAT_RAMP     = 'null'
 
END SUBROUTINE SET_MATL_DEFAULTS
 
END SUBROUTINE READ_MATL

SUBROUTINE PROC_MATL
USE MATH_FUNCTIONS
INTEGER N, I, J, NTEMP,NR,ITMP
REAL(EB) TEMP, C_ML, C_RES, C_FUEL, C_WATER, H_T, NU_SUM
TYPE(MATERIAL_TYPE), POINTER :: MLR

NTEMP = 2000

PROC_MATL_LOOP: DO N=1,N_MATL
   ML => MATERIAL(N)
   ALLOCATE(ML%Q_ARRAY(1:ML%N_REACTIONS,0:NTEMP),STAT=IZERO)
   ! Energy term Q in solid phase energy equation contains the 
   ! change of sensible enthaly (H_T) plus the difference of latent (chemical)
   ! heats (heat of reaction). 
   DO J = 1,ML%N_REACTIONS
      NU_SUM = ML%NU_RESIDUE(J) + ML%NU_FUEL(J) + ML%NU_WATER(J)
      NU_SUM = MIN(1.0_EB, NU_SUM)
      H_T = 0._EB
      ! Integrate H_T from ambient temperature to 2000.
      DO I = 0,NTEMP
         TEMP = TMPA+REAL(I,EB)     ! I = MIN(2000,MAX(0,NINT(TEMP-TMPA)))
         IF (ML%C_S>0._EB) THEN
            C_ML = ML%C_S
         ELSE
            NR     = -NINT(ML%C_S)
            C_ML = EVALUATE_RAMP(TEMP,0._EB,NR)*1000._EB
         ENDIF
         C_RES = 0._EB
         IF (ML%NU_RESIDUE(J)>0._EB) THEN
            MLR => MATERIAL(ML%RESIDUE_MATL_INDEX(J))
            IF (MLR%C_S>0._EB) THEN
               C_RES = MLR%C_S
            ELSE
               NR      = -NINT(MLR%C_S)
               C_RES = EVALUATE_RAMP(TEMP,0._EB,NR)*1000._EB
            ENDIF
         ENDIF
         ITMP = 0.1_EB*TEMP
         C_FUEL = SPECIES(I_FUEL)%CP_MF(0,ITMP)
         C_WATER = 2080._EB
         H_T = H_T + (NU_SUM*C_ML-ML%NU_RESIDUE(J)*C_RES-ML%NU_FUEL(J)*C_FUEL-ML%NU_WATER(J)*C_WATER)
         ML%Q_ARRAY(J,I) = ML%H_R(J) - H_T
      ENDDO
   ENDDO   
   
   ! Adjust burn rate if heat of combustion is different from the gas phase reaction value
   
   IF (N_REACTIONS > 0) THEN
      IF (CO_PRODUCTION) THEN
         RN => REACTION(2)         
      ELSE
         RN => REACTION(1)
      ENDIF
      IF (ML%HEAT_OF_COMBUSTION>0._EB .AND. RN%HEAT_OF_COMBUSTION>0._EB)  &
          ML%ADJUST_BURN_RATE = ML%HEAT_OF_COMBUSTION/(RN%Y_F_INLET*RN%HEAT_OF_COMBUSTION)
   ENDIF
   
ENDDO PROC_MATL_LOOP
END SUBROUTINE PROC_MATL


SUBROUTINE READ_SURF
 
USE MATH_FUNCTIONS, ONLY : GET_RAMP_INDEX
CHARACTER(30) :: PART_ID,RAMP_MF(0:20),RAMP_Q,RAMP_V,RAMP_T,MATL_ID(MAX_LAYERS,MAX_MATERIALS),&
                 PROFILE,BACKING,GEOMETRY,NAME_LIST(MAX_MATERIALS)
LOGICAL :: ADIABATIC,BURN_AWAY,SHRINK,POROUS
CHARACTER(60) :: TEXTURE_MAP
CHARACTER(25) :: COLOR
REAL(EB) :: TAU_Q,TAU_V,TAU_T,TAU_MF(0:20),HRRPUA,MLRPUA,TEXTURE_WIDTH,TEXTURE_HEIGHT,VEL_T(2), &
            E_COEFFICIENT,VOLUME_FLUX,TMP_FRONT,TMP_INNER,THICKNESS(MAX_LAYERS),VEL,SLIP_FACTOR, &
            MASS_FLUX(0:20),MASS_FRACTION(0:20), Z0,PLE,CONVECTIVE_HEAT_FLUX,PARTICLE_MASS_FLUX, &
            TRANSPARENCY,EXTERNAL_FLUX,TMP_BACK,MASS_FLUX_TOTAL,STRETCH_FACTOR,&
            MATL_MASS_FRACTION(MAX_LAYERS,MAX_MATERIALS),EMISSIVITY,CELL_SIZE_FACTOR,MAX_PRESSURE,&
            IGNITION_TEMPERATURE,HEAT_OF_VAPORIZATION
INTEGER :: NPPC,N,IOS,NL,NN,NNN,N_LIST,N_LIST2,INDEX_LIST(MAX_MATERIALS_TOTAL),LEAK_PATH(2),DUCT_PATH(2),RGB(3),NR
NAMELIST /SURF/ SLIP_FACTOR,TMP_FRONT,TMP_INNER,THICKNESS,MASS_FRACTION,VEL,VEL_T,NPPC, &
                E_COEFFICIENT,CONVECTIVE_HEAT_FLUX,TAU_Q,TAU_V,TAU_T,RAMP_Q,RAMP_T,TAU_MF, &
                RAMP_MF,PART_ID,RAMP_V,VOLUME_FLUX, PROFILE,PLE,Z0,ID,MASS_FLUX,PARTICLE_MASS_FLUX, &
                FYI,MATL_ID,BACKING,TMP_BACK,HRRPUA,MLRPUA,SHRINK,CELL_SIZE_FACTOR, &
                TEXTURE_MAP,TEXTURE_WIDTH,TEXTURE_HEIGHT,RGB,TRANSPARENCY, BURN_AWAY,LEAK_PATH,DUCT_PATH,ADIABATIC, &
                EXTERNAL_FLUX,MASS_FLUX_TOTAL,GEOMETRY,STRETCH_FACTOR,MATL_MASS_FRACTION,EMISSIVITY,COLOR,POROUS,MAX_PRESSURE,&
                IGNITION_TEMPERATURE,HEAT_OF_VAPORIZATION
             
! Count the SURF lines in the input file

REWIND(LU_INPUT)
N_SURF = 0
COUNT_SURF_LOOP: DO
   CALL CHECKREAD('SURF',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_SURF_LOOP
   READ(LU_INPUT,SURF,ERR=34,IOSTAT=IOS)
   N_SURF = N_SURF + 1
   SURF_NAME(N_SURF) = ID
   34 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with SURF number', N_SURF+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_SURF_LOOP

! Add three extra surface types to the list that has already been compiled
 
N_SURF                             = N_SURF + 3
OPEN_SURF_INDEX                    = N_SURF - 2
MIRROR_SURF_INDEX                  = N_SURF - 1
INTERPOLATED_SURF_INDEX            = N_SURF
INERT_SURF_INDEX                   = 0
SURF_NAME(INERT_SURF_INDEX)        = 'INERT'
SURF_NAME(OPEN_SURF_INDEX)         = 'OPEN'
SURF_NAME(MIRROR_SURF_INDEX)       = 'MIRROR'
SURF_NAME(INTERPOLATED_SURF_INDEX) = 'INTERPOLATED'
 
! Check if SURF_DEFAULT exists

CALL CHECK_SURF_NAME(SURF_DEFAULT,EX)
IF (.NOT.EX) THEN
   WRITE(MESSAGE,'(A)') 'ERROR: SURF_DEFAULT not found'
   CALL SHUTDOWN(MESSAGE)
ENDIF

! Add evacuation boundary type if necessary

CALL CHECK_SURF_NAME(EVAC_SURF_DEFAULT,EX)
IF (.NOT.EX) THEN
   WRITE(MESSAGE,'(A)') 'ERROR: EVAC_SURF_DEFAULT not found'
   CALL SHUTDOWN(MESSAGE)
ENDIF

! Allocate the SURFACE derived type
 
ALLOCATE(SURFACE(0:N_SURF),STAT=IZERO)
CALL ChkMemErr('READ','SURFACE',IZERO) 
 
! Read the SURF lines
 
REWIND(LU_INPUT)
READ_SURF_LOOP: DO N=0,N_SURF
 
   SF => SURFACE(N)
   CALL SET_SURF_DEFAULTS
 
   READ_LOOP: DO
      IF (SURF_NAME(N)=='INERT')        EXIT READ_LOOP
      IF (SURF_NAME(N)=='OPEN')         EXIT READ_LOOP
      IF (SURF_NAME(N)=='MIRROR')       EXIT READ_LOOP
      IF (SURF_NAME(N)=='INTERPOLATED') EXIT READ_LOOP
      CALL CHECKREAD('SURF',LU_INPUT,IOS)
      CALL SET_SURF_DEFAULTS
      READ(LU_INPUT,SURF) 
      EXIT READ_LOOP
   ENDDO READ_LOOP

   ! Check SURF parameters for potential problems

   IF (THICKNESS(1)>0._EB .AND. MATL_ID(1,1)=='null') THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))// ' must have a MATL_ID'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   
   IF (THICKNESS(1)>0._EB .AND. N_MATL==0) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: No MATL lines specified'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   
   ! Identify the default SURF 

   IF (ID==SURF_DEFAULT) DEFAULT_SURF_INDEX = N

   ! Pack SURF parameters into the SURFACE derived type
 
   SF                      => SURFACE(N)
   SF%ADIABATIC            = ADIABATIC
   SELECT CASE(BACKING)
      CASE('VOID')
         SF%BACKING        = VOID
      CASE('INSULATED')
         SF%BACKING        = INSULATED
      CASE('EXPOSED')
         SF%BACKING        = EXPOSED
   END SELECT
   SF%BURN_AWAY            = BURN_AWAY
   SF%CELL_SIZE_FACTOR     = CELL_SIZE_FACTOR
   SF%CONVECTIVE_HEAT_FLUX = 1000._EB*CONVECTIVE_HEAT_FLUX
   SF%DUCT_PATH            = DUCT_PATH
   SF%E_COEFFICIENT        = E_COEFFICIENT
   SF%EMISSIVITY           = EMISSIVITY   
   SF%EXTERNAL_FLUX        = 1000._EB*EXTERNAL_FLUX
   SELECT CASE(GEOMETRY)
      CASE('CARTESIAN')
         SF%GEOMETRY       = SURF_CARTESIAN      
      CASE('CYLINDRICAL')
         SF%GEOMETRY       = SURF_CYLINDRICAL
         SF%BACKING        = INSULATED
      CASE('SPHERICAL')
         SF%GEOMETRY       = SURF_SPHERICAL
         SF%BACKING        = INSULATED
   END SELECT
   SF%H_V                  = 1000._EB*HEAT_OF_VAPORIZATION
   SF%HRRPUA               = 1000._EB*HRRPUA
   SF%MLRPUA               = MLRPUA
   SF%LEAK_PATH            = LEAK_PATH
   SF%MASS_FLUX(:)         = MASS_FLUX(:)
   SF%MASS_FRACTION(:)     = MASS_FRACTION(:)
   SF%MAX_PRESSURE         = MAX_PRESSURE
   SF%SHRINK               = .FALSE.
   SF%NPPC                 = NPPC
   SF%PARTICLE_MASS_FLUX   = PARTICLE_MASS_FLUX
   SF%PART_ID              = PART_ID
   SF%PLE                  = PLE
   SF%POROUS               = POROUS
   SELECT CASE (PROFILE)
      CASE('null')
         SF%PROFILE        = 0
      CASE('ATMOSPHERIC')
         SF%PROFILE        = ATMOSPHERIC
      CASE('PARABOLIC')
         SF%PROFILE        = PARABOLIC
      CASE('1D-PARABOLIC')
         SF%PROFILE        = ONED_PARABOLIC
   END SELECT
   SF%RAMP_MF              = RAMP_MF
   SF%RAMP_Q               = RAMP_Q 
   SF%RAMP_V               = RAMP_V  
   SF%RAMP_T               = RAMP_T  
   IF (COLOR/='null') THEN
      IF (COLOR=='INVISIBLE') THEN
         TRANSPARENCY = 0._EB
      ELSE
         CALL COLOR2RGB(RGB,COLOR)
      ENDIF
   ENDIF
   SF%RGB                  = RGB
   SF%TRANSPARENCY         = TRANSPARENCY
   SF%STRETCH_FACTOR       = STRETCH_FACTOR
   SF%STRETCH_FACTOR       = MAX(1.0_EB,SF%STRETCH_FACTOR)
   SF%TAU(0:)              = TAU_MF(0:)
   SF%TAU(TIME_HEAT)       = TAU_Q
   SF%TAU(TIME_VELO)       = TAU_V
   SF%TAU(TIME_TEMP)       = TAU_T
   SF%TEXTURE_MAP          = TEXTURE_MAP
   SF%TEXTURE_WIDTH        = TEXTURE_WIDTH
   SF%TEXTURE_HEIGHT       = TEXTURE_HEIGHT
   SF%TMP_IGN              = IGNITION_TEMPERATURE + TMPM
   SF%SLIP_FACTOR          = SLIP_FACTOR
   SF%VEL                  = VEL
   SF%VEL_T                = VEL_T
   SF%VOLUME_FLUX          = VOLUME_FLUX
   SF%Z0                   = Z0
   SF%MASS_FLUX_TOTAL      = MASS_FLUX_TOTAL

   IF (SF%HRRPUA>0._EB .OR. SF%MLRPUA>0._EB) MIXTURE_FRACTION=.TRUE.
   
   ! Count the number of layers for the surface, and compile a LIST of all material names and indices
   SF%N_LAYERS = 0
   N_LIST = 0
   NAME_LIST = 'null'
   SF%THICKNESS  = 0._EB
   SF%SURFACE_DENSITY  = 0._EB
   SF%LAYER_MATL_INDEX = 0
   SF%LAYER_DENSITY    = 0._EB
   INDEX_LIST = -1
   COUNT_LAYERS: DO NL=1,MAX_LAYERS
      IF (THICKNESS(NL) < 0._EB) EXIT COUNT_LAYERS
      SF%N_LAYERS = SF%N_LAYERS + 1
      SF%LAYER_THICKNESS(NL) = THICKNESS(NL)
      SF%N_LAYER_MATL(NL) = 0
      IF (NL==1) SF%EMISSIVITY = 0._EB
      COUNT_LAYER_MATL: DO NN=1,MAX_MATERIALS
         IF (MATL_ID(NL,NN) == 'null') CYCLE COUNT_LAYER_MATL
         N_LIST = N_LIST + 1
         NAME_LIST(N_LIST) = MATL_ID(NL,NN)
         SF%N_LAYER_MATL(NL) = SF%N_LAYER_MATL(NL) + 1
         SF%LAYER_MATL_NAME(NL,NN) = MATL_ID(NL,NN)
         SF%LAYER_MATL_FRAC(NL,NN) = MATL_MASS_FRACTION(NL,NN)
         DO NNN=1,N_MATL
            IF (MATL_NAME(NNN)==NAME_LIST(N_LIST)) THEN
               INDEX_LIST(N_LIST) = NNN
               SF%LAYER_MATL_INDEX(NL,NN) = NNN
               SF%LAYER_DENSITY(NL) = SF%LAYER_DENSITY(NL)+SF%LAYER_MATL_FRAC(NL,NN)/MATERIAL(NNN)%RHO_S
               IF (NL==1) SF%EMISSIVITY = SF%EMISSIVITY + &
                  MATERIAL(NNN)%EMISSIVITY*SF%LAYER_MATL_FRAC(NL,NN)/MATERIAL(NNN)%RHO_S ! volume based
            ENDIF
         ENDDO
         IF (INDEX_LIST(N_LIST)<0) THEN
            WRITE(MESSAGE,'(A,A,A,A,A)') 'MATL: ',TRIM(NAME_LIST(N_LIST)),', on SURF: ',TRIM(SURF_NAME(N)),', does not exist'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDDO COUNT_LAYER_MATL
      IF (SF%LAYER_DENSITY(NL) > 0._EB) SF%LAYER_DENSITY(NL) = 1./SF%LAYER_DENSITY(NL)
      IF (NL==1) SF%EMISSIVITY = SF%EMISSIVITY*SF%LAYER_DENSITY(NL)
      SF%THICKNESS = SF%THICKNESS + SF%LAYER_THICKNESS(NL)
   ENDDO COUNT_LAYERS

   ! Add residue materials

   DO I = 1,MAX_STEPS    ! repeat the residue loop to find chained reactions - allows MAX_STEPS steps
      N_LIST2 = N_LIST
      DO NN = 1,N_LIST2
         ML=>MATERIAL(INDEX_LIST(NN))
         ADD_REAC_MATL: DO NNN=1,ML%N_REACTIONS
            IF (ML%RESIDUE_MATL_NAME(NNN) == 'null') CYCLE ADD_REAC_MATL
            IF (ANY(NAME_LIST==ML%RESIDUE_MATL_NAME(NNN))) CYCLE ADD_REAC_MATL
            N_LIST = N_LIST + 1
            IF (N_LIST.GT.MAX_MATERIALS_TOTAL) CALL SHUTDOWN('ERROR: Too many materials in the surface.')
            NAME_LIST (N_LIST) = ML%RESIDUE_MATL_NAME(NNN)
            INDEX_LIST(N_LIST) = ML%RESIDUE_MATL_INDEX(NNN)
         ENDDO ADD_REAC_MATL
      ENDDO
   ENDDO

   ! Eliminate multiply counted materials from the list

   N_LIST2 = N_LIST
   WEED_MATL_LIST: DO NN=1,N_LIST
      DO NNN=1,NN-1
         IF (NAME_LIST(NNN)==NAME_LIST(NN)) THEN
            NAME_LIST(NN)  = 'null'
            INDEX_LIST(NN) = 0 
            N_LIST2 = N_LIST2-1
            CYCLE WEED_MATL_LIST
         ENDIF
      ENDDO
   ENDDO WEED_MATL_LIST

   ! Allocate parameters indexed by layer

   SF%N_MATL     = N_LIST2
   SF%THERMALLY_THICK = .FALSE.
   IF (SF%N_LAYERS > 0) THEN
      SF%THERMALLY_THICK = .TRUE.
      SF%TMP_INNER                    = TMP_INNER + TMPM
      SF%TMP_FRONT                    = TMP_INNER + TMPM
      SF%TMP_BACK                     = TMP_BACK  + TMPM
      ALLOCATE(SF%N_LAYER_CELLS(SF%N_LAYERS))            ! The number of cells in each layer
      ALLOCATE(SF%MIN_DIFFUSIVITY(SF%N_LAYERS))          ! The smallest diffusivity of materials in each layer
      ALLOCATE(SF%MATL_NAME(SF%N_MATL))                  ! The list of all material names associated with the surface
      ALLOCATE(SF%MATL_INDEX(SF%N_MATL))                 ! The list of all material indices associated with the surface
      ALLOCATE(SF%RESIDUE_INDEX(SF%N_MATL,MAX_REACTIONS))! Each material associated with the surface has a RESIDUE
   ELSE
      SF%TMP_FRONT                  = TMP_FRONT + TMPM
      SF%TMP_INNER                  = SF%TMP_FRONT
      SF%TMP_BACK                   = SF%TMP_FRONT
   ENDIF
   TMPMIN        = MIN(TMPMIN,SF%TMP_FRONT,SF%TMP_INNER,SF%TMP_BACK)

   ! Store the names and indices of all materials associated with the surface

   NNN = 0
   DO NN=1,N_LIST
      IF (NAME_LIST(NN)/='null') THEN
         NNN = NNN + 1
         SF%MATL_NAME(NNN)  = NAME_LIST(NN)
         SF%MATL_INDEX(NNN) = INDEX_LIST(NN)
      ENDIF
   ENDDO

   ! Store the RESIDUE indices and detect (possibly) shrinking surfaces

   DO NN=1,SF%N_MATL
      ML => MATERIAL(SF%MATL_INDEX(NN))
      DO J=1,ML%N_REACTIONS
         DO NNN=1,SF%N_MATL
            IF (ML%RESIDUE_MATL_INDEX(J)==SF%MATL_INDEX(NNN)) SF%RESIDUE_INDEX(NN,J) = NNN
         ENDDO
         IF (ML%NU_RESIDUE(J).EQ.0._EB) SF%SHRINK = .TRUE.
      ENDDO
      IF (ML%PYROLYSIS_MODEL==PYROLYSIS_LIQUID) SF%SHRINK = .TRUE.
   ENDDO
   IF (.NOT. SHRINK ) SF%SHRINK = SHRINK

   ! Thermal boundary conditions

   SF%THERMAL_BC_INDEX = SPECIFIED_TEMPERATURE
   IF (SF%ADIABATIC)                   SF%THERMAL_BC_INDEX = ADIABATIC_INDEX
   IF (SF%CONVECTIVE_HEAT_FLUX/=0._EB) SF%THERMAL_BC_INDEX = SPECIFIED_HEAT_FLUX
   IF (SF%THERMALLY_THICK)             SF%THERMAL_BC_INDEX = THERMALLY_THICK
   IF (SF%PROFILE==ATMOSPHERIC)        SF%THERMAL_BC_INDEX = ZERO_GRADIENT

   ! Ramps

   IF (SF%RAMP_Q/='null') THEN
      CALL GET_RAMP_INDEX(SF%RAMP_Q,'TIME',NR)
      SF%RAMP_INDEX(TIME_HEAT) = NR
   ELSE
      IF (SF%TAU(TIME_HEAT) > 0._EB) SF%RAMP_INDEX(TIME_HEAT) = TANH_RAMP
      IF (SF%TAU(TIME_HEAT) < 0._EB) SF%RAMP_INDEX(TIME_HEAT) = TSQR_RAMP
   ENDIF

   IF (SF%RAMP_V/='null') THEN
      CALL GET_RAMP_INDEX(SF%RAMP_V,'TIME',NR)
      SF%RAMP_INDEX(TIME_VELO) = NR
   ELSE
      IF (SF%TAU(TIME_VELO) > 0._EB) SF%RAMP_INDEX(TIME_VELO) = TANH_RAMP
      IF (SF%TAU(TIME_VELO) < 0._EB) SF%RAMP_INDEX(TIME_VELO) = TSQR_RAMP
   ENDIF

   IF (SF%RAMP_T/='null') THEN
      CALL GET_RAMP_INDEX(SF%RAMP_T,'TIME',NR)
      SF%RAMP_INDEX(TIME_TEMP) = NR
   ELSE
      IF (SF%TAU(TIME_TEMP) > 0._EB) SF%RAMP_INDEX(TIME_TEMP) = TANH_RAMP
      IF (SF%TAU(TIME_TEMP) < 0._EB) SF%RAMP_INDEX(TIME_TEMP) = TSQR_RAMP
   ENDIF

ENDDO READ_SURF_LOOP
 
 
CONTAINS
 
SUBROUTINE SET_SURF_DEFAULTS
 
ADIABATIC               = .FALSE.
BACKING                 = 'VOID'
BURN_AWAY               = .FALSE.
CELL_SIZE_FACTOR        = 1.0
COLOR                   = 'null'
CONVECTIVE_HEAT_FLUX    = 0._EB
DUCT_PATH               = 0 
E_COEFFICIENT           = 0._EB
EMISSIVITY              = 0.9_EB
EXTERNAL_FLUX           = 0._EB
GEOMETRY                = 'CARTESIAN'
HEAT_OF_VAPORIZATION    = 0._EB
HRRPUA                  = 0._EB
IGNITION_TEMPERATURE    = 5000._EB
ID                      = 'null'
LEAK_PATH               = -1 
MASS_FLUX               = 0._EB
MASS_FRACTION           = -1._EB
MATL_ID                 = 'null'
MATL_MASS_FRACTION      = 0._EB
MATL_MASS_FRACTION(:,1) = 1._EB
MAX_PRESSURE            = 1.E12_EB
MLRPUA                  = 0._EB
NPPC                    = 1
PARTICLE_MASS_FLUX      = 0._EB
PART_ID                 = 'null'
PLE                     = 0.3_EB
POROUS                  = .FALSE.
PROFILE                 = 'null'
RAMP_MF                 = 'null'
RAMP_Q                  = 'null'
RAMP_V                  = 'null'
RAMP_T                  = 'null'
RGB(1)                  = 255 
RGB(2)                  = 204
RGB(3)                  = 102
TRANSPARENCY            = 1._EB
SHRINK                  = .TRUE.
STRETCH_FACTOR          = 2._EB
TAU_MF                  =  1._EB
TAU_Q                   = 1._EB
TAU_V                   = 1._EB
TAU_T                   = 1._EB
TEXTURE_MAP             = 'null'
TEXTURE_WIDTH           = 1._EB
TEXTURE_HEIGHT          = 1._EB
THICKNESS               = -1._EB
TMP_BACK                = TMPA-TMPM
TMP_FRONT               = TMPA-TMPM 
TMP_INNER               = TMPA-TMPM
IF (LES) SLIP_FACTOR    =  0.5_EB    ! Half slip
IF (DNS) SLIP_FACTOR    = -1.0_EB    ! No slip
VEL_T                   = -999._EB
VEL                     = -999._EB
MASS_FLUX_TOTAL         = -999._EB
VOLUME_FLUX             = -999._EB
Z0                      = 10._EB

 
END SUBROUTINE SET_SURF_DEFAULTS
 
END SUBROUTINE READ_SURF
 
SUBROUTINE PROC_SURF_1
USE MATH_FUNCTIONS, ONLY : GET_RAMP_INDEX
! Go through the SURF types and process
INTEGER :: N,NSPC,NR
 
PROCESS_SURF_LOOP: DO N=0,N_SURF
 
   SF => SURFACE(N)
 
   !Get MF ramps
   DO NSPC=0,N_SPECIES
      IF (SF%RAMP_MF(NSPC)/='null') THEN
         CALL GET_RAMP_INDEX(SF%RAMP_MF(NSPC),'TIME',NR)
         SF%RAMP_INDEX(NSPC) = NR
      ELSE
         IF (SF%TAU(NSPC) > 0._EB) SF%RAMP_INDEX(NSPC) = TANH_RAMP 
         IF (SF%TAU(NSPC) < 0._EB) SF%RAMP_INDEX(NSPC) = TSQR_RAMP 
      ENDIF
   ENDDO 
   
ENDDO PROCESS_SURF_LOOP   
 
END SUBROUTINE PROC_SURF_1

SUBROUTINE PROC_SURF_2
! Go through the SURF types and process
 
INTEGER :: IPC,N,NN,NNN,NL,NSPC
REAL(EB) :: ADJUSTED_LAYER_DENSITY
LOGICAL :: BURNING,BLOWING,SUCKING
TYPE(PARTICLE_CLASS_TYPE), POINTER :: PC
 
PROCESS_SURF_LOOP: DO N=0,N_SURF
 
   SF => SURFACE(N)
   IF (SF%THERMALLY_THICK) ML => MATERIAL(SF%LAYER_MATL_INDEX(1,1))
   
   ! Particle Information
 
   SF%PART_INDEX = 0
   IF (SF%PART_ID/='null') THEN
      DO IPC=1,N_PART
         PC=>PARTICLE_CLASS(IPC)
         IF (PC%CLASS_NAME==SF%PART_ID)  SF%PART_INDEX = IPC
      ENDDO
      DROPLET_FILE=.TRUE.
   ENDIF

  ! Determine if the surface is combustible/burning
 
   SF%PYROLYSIS_MODEL = PYROLYSIS_NONE
   BURNING  = .FALSE.
   BLOWING  = .FALSE.
   SUCKING  = .FALSE.
   IF (SF%N_LAYERS > 0) THEN
      DO NN=1,SF%N_MATL
         ML => MATERIAL(SF%MATL_INDEX(NN))
         IF (ML%PYROLYSIS_MODEL/=PYROLYSIS_NONE) THEN
            SF%PYROLYSIS_MODEL = PYROLYSIS_MATERIAL
            IF (ANY(ML%NU_FUEL>0._EB))  THEN
               BURNING = .TRUE.
               SF%TAU(TIME_HEAT) = 0._EB
            ENDIF
         ENDIF
      ENDDO   
   ENDIF
   IF (SF%HRRPUA>0._EB .OR. SF%MLRPUA>0._EB) THEN
      BURNING = .TRUE.
      SF%PYROLYSIS_MODEL = PYROLYSIS_SPECIFIED
   ENDIF

   IF (SF%VEL<0._EB .AND. SF%VEL/=-999._EB)                 BLOWING = .TRUE.
   IF (SF%VEL>0._EB .AND. SF%VEL/=-999._EB)                 SUCKING = .TRUE.
   IF (SF%VOLUME_FLUX<0._EB .AND. SF%VOLUME_FLUX/=-999._EB) BLOWING = .TRUE.
   IF (SF%VOLUME_FLUX>0._EB .AND. SF%VOLUME_FLUX/=-999._EB) SUCKING = .TRUE.

   IF (BURNING .AND. (BLOWING .OR. SUCKING)) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))//' cannot have a specified velocity or volume flux'
      CALL SHUTDOWN(MESSAGE)
      ENDIF
 
   ! set predefined HRRPUA

   BURNING_IF: IF (BURNING) THEN
      IF (SF%HRRPUA>0._EB) THEN
         IF (CO_PRODUCTION) THEN
            RN => REACTION(2)         
         ELSE
            RN => REACTION(1)
         ENDIF
         SF%MASS_FLUX(I_FUEL) = SF%HRRPUA/ (RN%HEAT_OF_COMBUSTION*RN%Y_F_INLET)
      ENDIF
      IF (SF%MLRPUA>0._EB) SF%MASS_FLUX(I_FUEL) = SF%MLRPUA
      SF%TAU(I_FUEL)        = SF%TAU(TIME_HEAT)
      SF%RAMP_MF(I_FUEL)    = SF%RAMP_Q
      SF%RAMP_INDEX(I_FUEL) = SF%RAMP_INDEX(TIME_HEAT) 
   ENDIF BURNING_IF

   ! Compute surface density

   SF%SURFACE_DENSITY = 0._EB
   DO NL=1,SF%N_LAYERS
      ADJUSTED_LAYER_DENSITY = 0._EB
      DO NN=1,SF%N_LAYER_MATL(NL)
         NNN = SF%LAYER_MATL_INDEX(NL,NN)
         ADJUSTED_LAYER_DENSITY = ADJUSTED_LAYER_DENSITY + &
            SF%LAYER_MATL_FRAC(NL,NN)/(MATERIAL(NNN)%ADJUST_BURN_RATE*MATERIAL(NNN)%RHO_S)
      ENDDO
      IF (ADJUSTED_LAYER_DENSITY > 0._EB) ADJUSTED_LAYER_DENSITY = 1./ADJUSTED_LAYER_DENSITY
      SF%SURFACE_DENSITY = SF%SURFACE_DENSITY + SF%LAYER_THICKNESS(NL)*ADJUSTED_LAYER_DENSITY
   ENDDO

   ! Ignition Time

   SF%T_IGN = T_BEGIN 
   IF (SF%TMP_IGN<5000._EB)                    SF%T_IGN = T_END
   IF (SF%PYROLYSIS_MODEL==PYROLYSIS_MATERIAL) SF%T_IGN = T_END

   ! Species Arrays and Method of Mass Transfer (SPECIES_BC_INDEX)
 
   SF%SPECIES_BC_INDEX = NO_MASS_FLUX

   IF (ANY(SF%MASS_FRACTION>=0._EB) .AND. (ANY(SF%MASS_FLUX/=0._EB).OR.BURNING)) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))//' cannot specify mass fraction with mass flux and/or burning'
      CALL SHUTDOWN(MESSAGE)
      ENDIF
   IF (ANY(SF%MASS_FRACTION>=0._EB) .AND. SUCKING) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))//' cannot specify both mass fraction and outflow velocity'
      CALL SHUTDOWN(MESSAGE)
      ENDIF
   IF (ANY(SF%LEAK_PATH>=0) .AND. (BLOWING .OR. SUCKING)) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))//' cannot leak and blow at the same time'
      CALL SHUTDOWN(MESSAGE)
      ENDIF
   IF (ANY(SF%MASS_FLUX/=0._EB) .AND. (BLOWING .OR. SUCKING)) THEN
      WRITE(MESSAGE,'(A)') 'ERROR: SURF '//TRIM(SURF_NAME(N))//' cannot have both a mass flux and specified velocity'
      CALL SHUTDOWN(MESSAGE)
      ENDIF

   IF (BLOWING .OR. SUCKING)                      SF%SPECIES_BC_INDEX = SPECIFIED_MASS_FRACTION
   IF (ANY(SF%MASS_FRACTION>=0._EB))              SF%SPECIES_BC_INDEX = SPECIFIED_MASS_FRACTION
   IF (ANY(SF%MASS_FLUX    /=0._EB) .OR. &
       SF%PYROLYSIS_MODEL==PYROLYSIS_MATERIAL) SF%SPECIES_BC_INDEX = SPECIFIED_MASS_FLUX

   IF (SF%SPECIES_BC_INDEX==SPECIFIED_MASS_FRACTION) THEN
      SPECIES_LOOP: DO NSPC=0,N_SPECIES
         IF (SF%MASS_FRACTION(NSPC)<0._EB) SF%MASS_FRACTION(NSPC) = 0._EB
      ENDDO SPECIES_LOOP
   ENDIF
 
  
   ! Miscellaneous Surface Info
 
   IF (SF%VEL_T(1)/=-999._EB) SF%SLIP_FACTOR = 2._EB  ! Special index to indicate that tangential velocity is specified

   SF%SURF_TYPE = 0
   IF (SF%TEXTURE_MAP/='null') SF%SURF_TYPE = 1
   IF (N==OPEN_SURF_INDEX) THEN
      SF%SLIP_FACTOR = 1._EB 
      SF%THERMAL_BC_INDEX = ZERO_GRADIENT
      SF%SPECIES_BC_INDEX = NO_MASS_FLUX
      SF%SURF_TYPE = 2
   ENDIF
   IF (N==MIRROR_SURF_INDEX) THEN
      SF%SLIP_FACTOR = 1.
      SF%THERMAL_BC_INDEX = ADIABATIC_INDEX
      SF%SPECIES_BC_INDEX = NO_MASS_FLUX
      SF%SURF_TYPE = -2
      SF%EMISSIVITY = 0._EB
   ENDIF
   IF (N==INTERPOLATED_SURF_INDEX) THEN
      SF%SLIP_FACTOR = 1.
      SF%THERMAL_BC_INDEX = INTERPOLATED_BC
      SF%SPECIES_BC_INDEX = INTERPOLATED_BC
   ENDIF
 
ENDDO PROCESS_SURF_LOOP
 
END SUBROUTINE PROC_SURF_2



SUBROUTINE PROC_WALL

! Set up 1-D grids and arrays for thermally-thick calcs

USE GEOMETRY_FUNCTIONS
USE MATH_FUNCTIONS, ONLY: EVALUATE_RAMP

INTEGER :: IBC,N,NL,NWP_MAX
REAL(EB) :: K_S_0,C_S_0,SMALLEST_CELL_SIZE(MAX_LAYERS)

! Calculate ambient temperature thermal DIFFUSIVITY for each MATERIAL, to be used in determining number of solid cells

DO N=1,N_MATL
   ML => MATERIAL(N)
   IF (ML%K_S>0._EB) THEN
      K_S_0 = ML%K_S
   ELSE
      K_S_0 = EVALUATE_RAMP(TMPA,0._EB,-NINT(ML%K_S))
   ENDIF
   IF (ML%C_S>0._EB) THEN
      C_S_0 = ML%C_S
   ELSE
      C_S_0 = EVALUATE_RAMP(TMPA,0._EB,-NINT(ML%C_S))*1000._EB
   ENDIF
   ML%DIFFUSIVITY = K_S_0/(C_S_0*ML%RHO_S)
ENDDO

NWP_MAX = 0  ! For some utility arrays, need to know the greatest number of points of all surface types
 
! Loop through all surfaces, looking for those that are thermally-thick (have layers).
! Compute smallest cell size for each layer such that internal cells double in size.
! Each layer should have an odd number of cells.

SURF_GRID_LOOP: DO IBC=0,N_SURF

   SF => SURFACE(IBC)
   IF (SF%THERMAL_BC_INDEX /= THERMALLY_THICK) CYCLE SURF_GRID_LOOP

   ! Compute number of points per layer, and then sum up to get total points for the surface

   SF%N_CELLS = 0
   DO NL=1,SF%N_LAYERS
      SF%MIN_DIFFUSIVITY(NL) = 1000000._EB
      DO N = 1,SF%N_LAYER_MATL(NL) 
         ML => MATERIAL(SF%LAYER_MATL_INDEX(NL,N))
         SF%MIN_DIFFUSIVITY(NL) = MIN(SF%MIN_DIFFUSIVITY(NL),ML%DIFFUSIVITY)
      ENDDO
      CALL GET_N_LAYER_CELLS(SF%MIN_DIFFUSIVITY(NL),SF%LAYER_THICKNESS(NL),SF%STRETCH_FACTOR, &
                             SF%CELL_SIZE_FACTOR,SF%N_LAYER_CELLS(NL),SMALLEST_CELL_SIZE(NL))
      SF%N_CELLS = SF%N_CELLS + SF%N_LAYER_CELLS(NL)
   ENDDO

! Allocate arrays to hold x_s, 1/dx_s (center to center, RDXN), 1/dx_s (edge to edge, RDX)

   NWP_MAX = MAX(NWP_MAX,SF%N_CELLS)
   ALLOCATE(SF%DX(1:SF%N_CELLS))
   ALLOCATE(SF%RDX(0:SF%N_CELLS+1))
   ALLOCATE(SF%RDXN(0:SF%N_CELLS))
   ALLOCATE(SF%DX_WGT(0:SF%N_CELLS))
   ALLOCATE(SF%X_S(0:SF%N_CELLS))
   ALLOCATE(SF%LAYER_INDEX(0:SF%N_CELLS+1))

! Compute node coordinates 

   CALL GET_WALL_NODE_COORDINATES(SF%N_CELLS,SF%N_LAYERS,SF%N_LAYER_CELLS, &
         SMALLEST_CELL_SIZE(1:SF%N_LAYERS),SF%STRETCH_FACTOR,SF%X_S)

   CALL GET_WALL_NODE_WEIGHTS(SF%N_CELLS,SF%N_LAYERS,SF%N_LAYER_CELLS,SF%THICKNESS,SF%GEOMETRY, &
         SF%X_S,SF%DX,SF%RDX,SF%RDXN,SF%DX_WGT,SF%DXF,SF%DXB,SF%LAYER_INDEX)

! Determine if surface has internal radiation

   SF%INTERNAL_RADIATION = .FALSE.
   DO NL=1,SF%N_LAYERS
   DO N =1,SF%N_LAYER_MATL(NL)
      ML => MATERIAL(SF%LAYER_MATL_INDEX(NL,N))
      IF (ML%KAPPA_S<5.0E4_EB) SF%INTERNAL_RADIATION = .TRUE.
   ENDDO
   ENDDO
 
ENDDO SURF_GRID_LOOP
 
ALLOCATE(AAS(NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','AAS',IZERO)
ALLOCATE(CCS(NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','CCS',IZERO)
ALLOCATE(BBS(NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','BBS',IZERO)
ALLOCATE(DDS(NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','DDS',IZERO)
ALLOCATE(DDT(NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','DDT',IZERO)
ALLOCATE(K_S(0:NWP_MAX+1),STAT=IZERO)
CALL ChkMemErr('INIT','K_S',IZERO)
ALLOCATE(C_S(0:NWP_MAX+1),STAT=IZERO)
CALL ChkMemErr('INIT','C_S',IZERO)
ALLOCATE(Q_S(1:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','Q_S',IZERO)
ALLOCATE(RHO_S(0:NWP_MAX+1),STAT=IZERO)
CALL ChkMemErr('INIT','RHO_S',IZERO)
ALLOCATE(RHOCBAR(1:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','RHOCBAR',IZERO)
ALLOCATE(KAPPA_S(1:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','KAPPA_S',IZERO)
ALLOCATE(X_S_NEW(0:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','X_S_NEW',IZERO)
ALLOCATE(DX_S(1:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','DX_S',IZERO)
ALLOCATE(RDX_S(0:NWP_MAX+1),STAT=IZERO)
CALL ChkMemErr('INIT','RDX_S',IZERO)
ALLOCATE(RDXN_S(0:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','RDXN_S',IZERO)
ALLOCATE(DX_WGT_S(0:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','DX_WGT_S',IZERO)
ALLOCATE(LAYER_INDEX(0:NWP_MAX+1),STAT=IZERO)
CALL ChkMemErr('INIT','LAYER_INDEX',IZERO)
ALLOCATE(INT_WGT(1:NWP_MAX,1:NWP_MAX),STAT=IZERO)
CALL ChkMemErr('INIT','INT_WGT',IZERO)

END SUBROUTINE PROC_WALL


SUBROUTINE READ_RADI
USE RADCONS
NAMELIST /RADI/ TIME_STEP_INCREMENT,NUMBER_RADIATION_ANGLES,ANGLE_INCREMENT,KAPPA0, &
                WIDE_BAND_MODEL,CH4_BANDS,PATH_LENGTH,NMIEANG,RADTMP,RADIATIVE_FRACTION

IF (LES) RADIATIVE_FRACTION = 0.35_EB
IF (DNS) RADIATIVE_FRACTION = 0.00_EB
NUMBER_RADIATION_ANGLES = 100
TIME_STEP_INCREMENT     = 3
IF (TWO_D) THEN
   NUMBER_RADIATION_ANGLES = 50
   TIME_STEP_INCREMENT     = 2
ENDIF
 
KAPPA0          =   0._EB
RADTMP          = 900._EB
WIDE_BAND_MODEL = .FALSE.
CH4_BANDS       = .FALSE.
NMIEANG         = 15
PATH_LENGTH     = -1.0_EB ! calculate path based on the geometry
ANGLE_INCREMENT = -1
 
REWIND(LU_INPUT)
READ_LOOP: DO
   CALL CHECKREAD('RADI',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_LOOP
   READ(LU_INPUT,RADI,END=23,ERR=24,IOSTAT=IOS)
   24 IF (IOS>0) THEN
      CALL SHUTDOWN(' ERROR: Problem with RADI line')
   ENDIF
ENDDO READ_LOOP
23 REWIND(LU_INPUT)

RADTMP = RADTMP + TMPM

IF (WIDE_BAND_MODEL) THEN
   IF (CH4_BANDS) THEN
      NUMBER_SPECTRAL_BANDS = 9
   ELSE
      NUMBER_SPECTRAL_BANDS = 6
   ENDIF
   TIME_STEP_INCREMENT=MAX(1,TIME_STEP_INCREMENT)
   ANGLE_INCREMENT = 1
   UIIDIM=NUMBER_SPECTRAL_BANDS
ELSE
   NUMBER_SPECTRAL_BANDS = 1
   IF (ANGLE_INCREMENT < 0) ANGLE_INCREMENT = MAX(1,MIN(5,NUMBER_RADIATION_ANGLES/15))
   UIIDIM = ANGLE_INCREMENT
ENDIF

END SUBROUTINE READ_RADI


SUBROUTINE READ_CLIP

INTEGER  :: N 
REAL(EB) :: MINIMUM_DENSITY,MAXIMUM_DENSITY,MINIMUM_MASS_FRACTION(20),MAXIMUM_MASS_FRACTION(20), &
            MINIMUM_TEMPERATURE,MAXIMUM_TEMPERATURE
NAMELIST /CLIP/ MINIMUM_DENSITY,MAXIMUM_DENSITY,FYI,MINIMUM_MASS_FRACTION,MAXIMUM_MASS_FRACTION, &
                MINIMUM_TEMPERATURE,MAXIMUM_TEMPERATURE
 
! Check for user-defined mins and maxes.
 
MINIMUM_DENSITY       = -999._EB
MAXIMUM_DENSITY       = -999._EB
MINIMUM_TEMPERATURE   = -999._EB
MAXIMUM_TEMPERATURE   = -999._EB
MINIMUM_MASS_FRACTION = -999._EB
MAXIMUM_MASS_FRACTION = -999._EB
 
REWIND(LU_INPUT)
CLIP_LOOP: DO
   CALL CHECKREAD('CLIP',LU_INPUT,IOS) 
   IF (IOS==1) EXIT CLIP_LOOP
   READ(LU_INPUT,CLIP,END=431,ERR=432,IOSTAT=IOS)
   432 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with CLIP line')
ENDDO CLIP_LOOP
431 REWIND(LU_INPUT)
 
IF (MINIMUM_TEMPERATURE>-TMPM) TMPMIN = MINIMUM_TEMPERATURE + TMPM
IF (MAXIMUM_TEMPERATURE>-TMPM) TMPMAX = MAXIMUM_TEMPERATURE + TMPM
IF (MINIMUM_DENSITY>0._EB) THEN
   RHOMIN = MINIMUM_DENSITY
ELSE
   RHOMIN = 0.1_EB*RHOA
ENDIF
IF (MAXIMUM_DENSITY>0._EB) THEN
   RHOMAX = MAXIMUM_DENSITY
ELSE
   RHOMAX = 3.0_EB*P_INF*MW_MAX/(R0*(TMPMIN+1._EB))  ! The 1 added to TMPMIN is to prevent a divide by zero error
ENDIF
DO N=1,N_SPECIES
   IF (MINIMUM_MASS_FRACTION(N)>-1._EB) YYMIN(N) = MINIMUM_MASS_FRACTION(N)
   IF (MAXIMUM_MASS_FRACTION(N)>-1._EB) YYMAX(N) = MAXIMUM_MASS_FRACTION(N)
ENDDO
 
END SUBROUTINE READ_CLIP
 
 
SUBROUTINE READ_RAMP
 
REAL(EB) :: T,F,TM
INTEGER  :: I,II,NN,N,NUMBER_INTERPOLATION_POINTS
CHARACTER(30) :: DEVC_ID,CTRL_ID
TYPE(RAMPS_TYPE), POINTER :: RP
NAMELIST /RAMP/ T,F,ID,FYI,NUMBER_INTERPOLATION_POINTS,DEVC_ID,CTRL_ID
 
IF (N_RAMP==0) RETURN

ALLOCATE(RAMPS(N_RAMP),STAT=IZERO)
CALL ChkMemErr('READ','RAMPS',IZERO)

! Count the number of points in each ramp
 
REWIND(LU_INPUT)
COUNT_RAMP_POINTS: DO N=1,N_RAMP
   RP => RAMPS(N)
   REWIND(LU_INPUT)
   RP%NUMBER_DATA_POINTS = 0
   SEARCH_LOOP: DO
      CALL CHECKREAD('RAMP',LU_INPUT,IOS)
      IF (IOS==1) EXIT SEARCH_LOOP
      READ(LU_INPUT,NML=RAMP,ERR=56,IOSTAT=IOS)
      IF (ID/=RAMP_ID(N)) CYCLE SEARCH_LOOP
      RP%NUMBER_DATA_POINTS = RP%NUMBER_DATA_POINTS + 1
      56 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with RAMP '//TRIM(RAMP_ID(N)) )
   ENDDO SEARCH_LOOP
   IF (RP%NUMBER_DATA_POINTS==0) THEN
      WRITE(MESSAGE,'(A,A,A)') 'ERROR: RAMP ',TRIM(RAMP_ID(N)), ' not found'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_RAMP_POINTS

! Read the ramp functions
READ_RAMP_LOOP: DO N=1,N_RAMP
   RP => RAMPS(N)
   RP%DEVC_ID = 'null'
   RP%CTRL_ID = 'null'
   ALLOCATE(RP%INDEPENDENT_DATA(1:RP%NUMBER_DATA_POINTS))
   ALLOCATE(RP%DEPENDENT_DATA(1:RP%NUMBER_DATA_POINTS))
   REWIND(LU_INPUT)
   NN = 0
   NUMBER_INTERPOLATION_POINTS=5000
   SEARCH_LOOP2: DO 
      DEVC_ID = 'null'
      CTRL_ID = 'null'
      CALL CHECKREAD('RAMP',LU_INPUT,IOS) 
      IF (IOS==1) EXIT SEARCH_LOOP2
      READ(LU_INPUT,RAMP)
      IF (ID/=RAMP_ID(N)) CYCLE SEARCH_LOOP2
      IF (DEVC_ID  /='null') RP%DEVC_ID  = DEVC_ID
      IF (CTRL_ID /='null') RP%CTRL_ID = CTRL_ID      
      IF (RAMP_TYPE(N)=='TEMPERATURE') T = T + TMPM
      IF (RAMP_TYPE(N)=='TIME')        T = T_BEGIN + (T-T_BEGIN)/TIME_SHRINK_FACTOR
      NN = NN+1
      RP%INDEPENDENT_DATA(NN) = T
      IF (NN>1) THEN
         IF (T<=RP%INDEPENDENT_DATA(NN-1)) THEN
            WRITE(MESSAGE,'(A,A,A)') 'ERROR: RAMP ',TRIM(RAMP_ID(N)), ' variable T must be monotonically increasing'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDIF
      RP%DEPENDENT_DATA(NN) = F
      RP%NUMBER_INTERPOLATION_POINTS = NUMBER_INTERPOLATION_POINTS
   ENDDO SEARCH_LOOP2
   RP%T_MIN = MINVAL(RP%INDEPENDENT_DATA)
   RP%T_MAX = MAXVAL(RP%INDEPENDENT_DATA)
   RP%SPAN = RP%T_MAX - RP%T_MIN
ENDDO READ_RAMP_LOOP
 
! Set up interpolated ramp values in INTERPOLATED_DATA and get control or device index
 
DO N=1,N_RAMP
   RP => RAMPS(N)
   RP%DT = RP%SPAN/REAL(RP%NUMBER_INTERPOLATION_POINTS,EB)   
   ALLOCATE(RAMPS(N)%INTERPOLATED_DATA(0:RP%NUMBER_INTERPOLATION_POINTS))
   RAMPS(N)%INTERPOLATED_DATA(0) = RP%DEPENDENT_DATA(1)
   DO I=1,RP%NUMBER_INTERPOLATION_POINTS-1
      TM = RP%INDEPENDENT_DATA(1) + REAL(I,EB)*RP%DT
      TLOOP: DO II=1,RP%NUMBER_DATA_POINTS-1
         IF (TM>=RP%INDEPENDENT_DATA(II) .AND. TM<RP%INDEPENDENT_DATA(II+1)) THEN
            RP%INTERPOLATED_DATA(I) = RP%DEPENDENT_DATA(II) +  (TM-RP%INDEPENDENT_DATA(II)) * &
                          (RP%DEPENDENT_DATA(II+1)-RP%DEPENDENT_DATA(II))/(RP%INDEPENDENT_DATA(II+1)-RP%INDEPENDENT_DATA(II))
            EXIT TLOOP
         ENDIF
      ENDDO TLOOP
   ENDDO
   RP%INTERPOLATED_DATA(RP%NUMBER_INTERPOLATION_POINTS) = RP%DEPENDENT_DATA(RP%NUMBER_DATA_POINTS)

   !Get Device or Control Index

   CALL SEARCH_CONTROLLER('RAMP',CTRL_ID,DEVC_ID,RP%DEVC_INDEX,RP%CTRL_INDEX,N)
       
ENDDO

END SUBROUTINE READ_RAMP
 
SUBROUTINE READ_TABLE
 
REAL(EB) :: TABLE_DATA(6)
INTEGER  :: NN,N
TYPE(TABLES_TYPE), POINTER :: TA
NAMELIST /TABL/ ID,FYI,TABLE_DATA
 
IF (N_TABLE==0) RETURN

ALLOCATE(TABLES(N_TABLE),STAT=IZERO)
CALL ChkMemErr('READ','TABLES',IZERO)

! Count the number of points in each ramp
 
REWIND(LU_INPUT)
COUNT_TABLE_POINTS: DO N=1,N_TABLE
   TA => TABLES(N)
   REWIND(LU_INPUT)
   TA%NUMBER_ROWS = 0
   SELECT CASE (TABLE_TYPE(N))
      CASE (SPRAY_PATTERN)
         TA%NUMBER_COLUMNS = 6
   END SELECT
   SEARCH_LOOP: DO
      CALL CHECKREAD('TABL',LU_INPUT,IOS)
      IF (IOS==1) EXIT SEARCH_LOOP
      TABLE_DATA = -999._EB
      READ(LU_INPUT,NML=TABL,ERR=56,IOSTAT=IOS)
      IF (ID/=TABLE_ID(N)) CYCLE SEARCH_LOOP
      TA%NUMBER_ROWS = TA%NUMBER_ROWS + 1
      SELECT CASE(TABLE_TYPE(N))
         CASE (SPRAY_PATTERN)
            MESSAGE='null'
            IF (TABLE_DATA(1)<0. .OR.           TABLE_DATA(1)>180) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad 1st lattitude'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
            IF (TABLE_DATA(2)<TABLE_DATA(1).OR. TABLE_DATA(2)>180) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad 2nd lattitude'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
            IF (TABLE_DATA(3)<-180. .OR.        TABLE_DATA(3)>360) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad 1st longitude'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
            IF (TABLE_DATA(4)<TABLE_DATA(3).OR. TABLE_DATA(4)>360) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad 2nd longitude'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
            IF (TABLE_DATA(5)<0) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad velocity'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
            IF (TABLE_DATA(6)<0) THEN
               WRITE(MESSAGE,'(A,I5,A,A,A)') 'Row ',TA%NUMBER_ROWS,' of ',TRIM(TABLE_ID(N)),' has a bad mass flow'
               CALL SHUTDOWN(MESSAGE)
            ENDIF
      END SELECT
         
      56 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with TABLE '//TRIM(TABLE_ID(N)) )
   ENDDO SEARCH_LOOP
   IF (TA%NUMBER_ROWS==0) THEN
      WRITE(MESSAGE,'(A,A,A)') 'ERROR: TABLE ',TRIM(TABLE_ID(N)), ' not found'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_TABLE_POINTS

! Read the TABLE functions
READ_TABLE_LOOP: DO N=1,N_TABLE
   TA => TABLES(N)
   ALLOCATE(TA%TABLE_DATA(TA%NUMBER_ROWS,TA%NUMBER_COLUMNS),STAT=IZERO)
   CALL ChkMemErr('READ','TA%TABLE_DATA',IZERO)
   REWIND(LU_INPUT)
   NN = 0
   SEARCH_LOOP2: DO 
      CALL CHECKREAD('TABL',LU_INPUT,IOS) 
      IF (IOS==1) EXIT SEARCH_LOOP2
      READ(LU_INPUT,TABL)
      IF (ID/=TABLE_ID(N)) CYCLE SEARCH_LOOP2
      NN = NN+1
      TA%TABLE_DATA(NN,:) = TABLE_DATA(1:TA%NUMBER_COLUMNS)
   ENDDO SEARCH_LOOP2
ENDDO READ_TABLE_LOOP

END SUBROUTINE READ_TABLE 
 
SUBROUTINE READ_OBST
USE GEOMETRY_FUNCTIONS, ONLY: BLOCK_CELL
USE DEVICE_VARIABLES, ONLY : DEVICE, N_DEVC
USE CONTROL_VARIABLES, ONLY : CONTROL, N_CTRL 
TYPE(OBSTRUCTION_TYPE), POINTER :: OB2,OBT
TYPE(OBSTRUCTION_TYPE), DIMENSION(:), ALLOCATABLE, TARGET :: TEMP_OBSTRUCTION
INTEGER :: NM,NOM,N_OBST_O,NNN,IC,N,NN,NNNN,N_NEW_OBST,RGB(3)
CHARACTER(30) :: DEVC_ID,SURF_ID,SURF_IDS(3),SURF_ID6(6),CTRL_ID
CHARACTER(60) :: MESH_ID
CHARACTER(25) :: COLOR
REAL(EB) :: TRANSPARENCY,DUMMY
LOGICAL :: SAWTOOTH,EMBEDDED,THICKEN,PERMIT_HOLE,ALLOW_VENT,EVACUATION, REMOVABLE,BNDF_FACE(-3:3),BNDF_OBST,OUTLINE
NAMELIST /OBST/ XB,SURF_ID,SURF_IDS,SURF_ID6,FYI,BNDF_FACE,BNDF_OBST, &
                SAWTOOTH,RGB,TRANSPARENCY,TEXTURE_ORIGIN,THICKEN, OUTLINE,DEVC_ID,CTRL_ID,COLOR, &
                PERMIT_HOLE,ALLOW_VENT,EVACUATION,MESH_ID,REMOVABLE
 
MESH_LOOP: DO NM=1,NMESHES
   M=>MESHES(NM)
   CALL POINT_TO_MESH(NM)
 
   ! Count OBST lines
 
   REWIND(LU_INPUT)
   N_OBST = 0
   COUNT_OBST_LOOP: DO
      CALL CHECKREAD('OBST',LU_INPUT,IOS)
      IF (IOS==1) EXIT COUNT_OBST_LOOP
      READ(LU_INPUT,NML=OBST,END=1,ERR=2,IOSTAT=IOS)
      N_OBST = N_OBST + 1
      2 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I5)')  'ERROR: Problem with OBSTruction number',N_OBST+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDDO COUNT_OBST_LOOP
   1 REWIND(LU_INPUT)
 
   ! Allocate OBSTRUCTION array

   ALLOCATE(M%OBSTRUCTION(0:N_OBST),STAT=IZERO)
   CALL ChkMemErr('READ','OBSTRUCTION',IZERO)
   OBSTRUCTION=>M%OBSTRUCTION
 
   N        = 0
   N_OBST_O = N_OBST
 
   READ_OBST_LOOP: DO NN=1,N_OBST_O
      N        = N + 1
      SURF_ID  = 'null'
      SURF_IDS = 'null'
      SURF_ID6 = 'null'
      COLOR    = 'null'
      MESH_ID     = 'null'
      RGB         = -1
      TRANSPARENCY=  1._EB
      BNDF_FACE   = BNDF_DEFAULT
      BNDF_OBST   = BNDF_DEFAULT
      SAWTOOTH    = .TRUE.
      THICKEN     = THICKEN_OBSTRUCTIONS
      OUTLINE     = .FALSE.
      TEXTURE_ORIGIN = -999._EB
      DEVC_ID  = 'null'
      CTRL_ID = 'null'
      PERMIT_HOLE = .TRUE.
      ALLOW_VENT  = .TRUE.
      REMOVABLE   = .TRUE.
      IF (.NOT.EVACUATION_ONLY(NM)) EVACUATION = .FALSE.
      IF (     EVACUATION_ONLY(NM)) EVACUATION = .TRUE.
      !Timo: A temporary bug fix for evacuation flow fields. Thin walls
      !TImo: with thicken=false do not work in FDS5 (May 31, 20075_RC5+).
      IF (     EVACUATION_ONLY(NM)) THICKEN    = .TRUE.
      !IF (     EVACUATION_ONLY(NM)) SAWTOOTH   = .FALSE.
 
      CALL CHECKREAD('OBST',LU_INPUT,IOS)
      IF (IOS==1) EXIT READ_OBST_LOOP
      READ(LU_INPUT,OBST,END=35)
 
      ! Evacuation criteria
 
      IF (MESH_ID/=MESH_NAME(NM) .AND. MESH_ID/='null') THEN
            N = N-1
            N_OBST = N_OBST-1
            CYCLE READ_OBST_LOOP
      ENDIF
 
      IF ((.NOT.EVACUATION .AND. EVACUATION_ONLY(NM)) .OR. (EVACUATION .AND. .NOT.EVACUATION_ONLY(NM))) THEN
            N = N-1
            N_OBST = N_OBST-1
            CYCLE READ_OBST_LOOP
      ENDIF
 
      ! Reorder coords if necessary
 
      DO I=1,5,2
         IF (XB(I)>XB(I+1)) THEN
            DUMMY   = XB(I)
            XB(I)   = XB(I+1)
            XB(I+1) = DUMMY
         ENDIF
      ENDDO
 
      XB(1) = MAX(XB(1),XS)
      XB(2) = MIN(XB(2),XF)
      XB(3) = MAX(XB(3),YS)
      XB(4) = MIN(XB(4),YF)
      XB(5) = MAX(XB(5),ZS)
      XB(6) = MIN(XB(6),ZF)
      IF (XB(1)>XF .OR. XB(2)<XS .OR. XB(3)>YF .OR. XB(4)<YS .OR. XB(5)>ZF .OR. XB(6)<ZS) THEN
         N = N-1
         N_OBST = N_OBST-1
         CYCLE READ_OBST_LOOP
      ENDIF
 
      ! Begin processing of OBSTruction
 
      OB=>OBSTRUCTION(N)
 
      OB%X1 = XB(1)
      OB%X2 = XB(2)
      OB%Y1 = XB(3)
      OB%Y2 = XB(4)
      OB%Z1 = XB(5)
      OB%Z2 = XB(6)
      OB%I1 = NINT( GINV(XB(1)-XS,1,NM)*RDXI   ) 
      OB%I2 = NINT( GINV(XB(2)-XS,1,NM)*RDXI   )
      OB%J1 = NINT( GINV(XB(3)-YS,2,NM)*RDETA  ) 
      OB%J2 = NINT( GINV(XB(4)-YS,2,NM)*RDETA  )
      OB%K1 = NINT( GINV(XB(5)-ZS,3,NM)*RDZETA ) 
      OB%K2 = NINT( GINV(XB(6)-ZS,3,NM)*RDZETA )
 
      ! If desired, thicken small obstructions
 
      IF (THICKEN .AND. OB%I1==OB%I2) THEN
         OB%I1 = GINV(.5_EB*(XB(1)+XB(2))-XS,1,NM)*RDXI
         OB%I2 = MIN(OB%I1+1,IBAR)
      ENDIF
      IF (THICKEN .AND. OB%J1==OB%J2) THEN
         OB%J1 = GINV(.5_EB*(XB(3)+XB(4))-YS,2,NM)*RDETA
         OB%J2 = MIN(OB%J1+1,JBAR)
      ENDIF
      IF (THICKEN .AND. OB%K1==OB%K2) THEN
         OB%K1 = GINV(.5_EB*(XB(5)+XB(6))-ZS,3,NM)*RDZETA
         OB%K2 = MIN(OB%K1+1,KBAR)
      ENDIF
 
      ! Throw out obstructions that are too small
 
      IF ((OB%I1==OB%I2 .AND. OB%J1==OB%J2) .OR. (OB%I1==OB%I2 .AND. OB%K1==OB%K2) .OR. (OB%J1==OB%J2 .AND. OB%K1==OB%K2)) THEN
         N = N-1
         N_OBST= N_OBST-1
         CYCLE READ_OBST_LOOP
      ENDIF

      IF (OB%I1==OB%I2 .OR. OB%J1==OB%J2 .OR. OB%K1==OB%K2) OB%THIN = .TRUE.
 
      ! Check to see if obstacle is completely embedded in another
 
      EMBEDDED = .FALSE.
      EMBED_LOOP: DO NNN=1,N-1
         OB2=>OBSTRUCTION(NNN)
         IF (OB%I1>OB2%I1 .AND. OB%I2<OB2%I2 .AND. &
             OB%J1>OB2%J1 .AND. OB%J2<OB2%J2 .AND. &
             OB%K1>OB2%K1 .AND. OB%K2<OB2%K2) THEN
            EMBEDDED = .TRUE.
            EXIT EMBED_LOOP
         ENDIF
      ENDDO EMBED_LOOP
 
      IF (EMBEDDED  .AND. DEVC_ID=='null' .AND.  REMOVABLE .AND. CTRL_ID=='null' ) THEN
            N = N-1
            N_OBST= N_OBST-1
            CYCLE READ_OBST_LOOP
      ENDIF

      ! Check if the SURF IDs exist

      IF (EVACUATION_ONLY(NM)) SURF_ID=EVAC_SURF_DEFAULT

      IF (SURF_ID/='null') CALL CHECK_SURF_NAME(SURF_ID,EX)
      IF (.NOT.EX) THEN
         WRITE(MESSAGE,'(A,A,A)')  'ERROR: SURF_ID ',TRIM(SURF_ID),' does not exist'
         CALL SHUTDOWN(MESSAGE)
      ENDIF

      DO NNNN=1,3
         IF (EVACUATION_ONLY(NM)) SURF_IDS(NNNN)=EVAC_SURF_DEFAULT
         IF (SURF_IDS(NNNN)/='null') CALL CHECK_SURF_NAME(SURF_IDS(NNNN),EX)
         IF (.NOT.EX) THEN
            WRITE(MESSAGE,'(A,A,A)')  'ERROR: SURF_ID ',TRIM(SURF_IDS(NNNN)),' does not exist'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDDO

      DO NNNN=1,6
         IF (EVACUATION_ONLY(NM)) SURF_ID6(NNNN)=EVAC_SURF_DEFAULT
         IF (SURF_ID6(NNNN)/='null') CALL CHECK_SURF_NAME(SURF_ID6(NNNN),EX)
         IF (.NOT.EX) THEN
            WRITE(MESSAGE,'(A,A,A)')  'ERROR: SURF_ID ',TRIM(SURF_ID6(NNNN)),' does not exist'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDDO
 
      ! Save boundary condition info for obstacles
 
      OB%IBC(:) = DEFAULT_SURF_INDEX
 
      DO NNN=0,N_SURF
         IF (SURF_ID    ==SURF_NAME(NNN)) OB%IBC(:)    = NNN
         IF (SURF_IDS(1)==SURF_NAME(NNN)) OB%IBC(3)    = NNN
         IF (SURF_IDS(2)==SURF_NAME(NNN)) OB%IBC(-2:2) = NNN
         IF (SURF_IDS(3)==SURF_NAME(NNN)) OB%IBC(-3)   = NNN
         IF (SURF_ID6(1)==SURF_NAME(NNN)) OB%IBC(-1)   = NNN
         IF (SURF_ID6(2)==SURF_NAME(NNN)) OB%IBC( 1)   = NNN
         IF (SURF_ID6(3)==SURF_NAME(NNN)) OB%IBC(-2)   = NNN
         IF (SURF_ID6(4)==SURF_NAME(NNN)) OB%IBC( 2)   = NNN
         IF (SURF_ID6(5)==SURF_NAME(NNN)) OB%IBC(-3)   = NNN
         IF (SURF_ID6(6)==SURF_NAME(NNN)) OB%IBC( 3)   = NNN
      ENDDO

      ! Determine if the OBST is CONSUMABLE and check if POROUS inappropriately applied

      FACE_LOOP: DO NNN=-3,3
         IF (NNN==0) CYCLE FACE_LOOP
         IF (SURFACE(OB%IBC(NNN))%BURN_AWAY) THEN
            OB%CONSUMABLE = .TRUE.
            IF (.NOT.SAWTOOTH) THEN
               WRITE(MESSAGE,'(A,I5,A)')  'ERROR: OBST number',N,' cannot have a BURN_AWAY SURF_ID and SAWTOOTH=.FALSE.' 
               CALL SHUTDOWN(MESSAGE)
            ENDIF
         ENDIF
         IF (SURFACE(OB%IBC(NNN))%POROUS .AND. .NOT.OB%THIN) THEN
            WRITE(MESSAGE,'(A,I5,A)')  'ERROR: OBST number',N,' must be zero cells thick if it is to be POROUS'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
      ENDDO FACE_LOOP
 
      ! Creation and removal logic
 
      OB%DEVC_ID = DEVC_ID
      OB%CTRL_ID = CTRL_ID
      OB%HIDDEN = .FALSE.
      CALL SEARCH_CONTROLLER('OBST',CTRL_ID,DEVC_ID,OB%DEVC_INDEX,OB%CTRL_INDEX,N)
      IF (DEVC_ID /='null') OB%HIDDEN = .NOT. DEVICE(OB%DEVC_INDEX)%INITIAL_STATE
      IF (CTRL_ID /='null') OB%HIDDEN = .NOT. CONTROL(OB%CTRL_INDEX)%INITIAL_STATE      
      IF (DEVC_ID /='null') OB%REMOVABLE = .TRUE.
      IF (CTRL_ID /='null') OB%REMOVABLE = .TRUE.
      IF (OB%CONSUMABLE)    OB%REMOVABLE = .TRUE.
      ! Choose obstruction color index
      SELECT CASE (COLOR)
         CASE ('INVISIBLE')
            OB%BCI = -3
            TRANSPARENCY = 0._EB
         CASE ('null')
            IF (ANY (RGB<0)) THEN
               OB%BCI=-1
            ELSE
               OB%BCI=-3
            ENDIF
         CASE DEFAULT
            CALL COLOR2RGB(RGB,COLOR)
            OB%BCI = -3
      END SELECT
      OB%RGB  = RGB
      OB%TRANSPARENCY = TRANSPARENCY
      ! Miscellaneous assignments
 
      OB%TEXTURE(:) = TEXTURE_ORIGIN(:)  ! Origin of texture map
      OB%ORDINAL = NN  ! Order of OBST in original input file
      OB%PERMIT_HOLE = PERMIT_HOLE
      OB%ALLOW_VENT  = ALLOW_VENT
 
      ! Make obstruction invisible if it's within a finer mesh
 
      DO NOM=1,NM-1
         IF (XB(1)>=MESHES(NOM)%XS .AND. XB(2)<=MESHES(NOM)%XF .AND. XB(3)>=MESHES(NOM)%YS .AND. XB(4)<=MESHES(NOM)%YF .AND. &
             XB(5)>=MESHES(NOM)%ZS .AND. XB(6)<=MESHES(NOM)%ZF) OB%BCI=-2
      ENDDO
 
      ! Prevent drawing of boundary info if desired
 
      IF (BNDF_DEFAULT) THEN
         OB%SHOW_BNDF(:) = BNDF_FACE(:)
         IF (.NOT.BNDF_OBST) OB%SHOW_BNDF(:) = .FALSE.
      ELSE
         OB%SHOW_BNDF(:) = BNDF_FACE(:)
         IF (BNDF_OBST) OB%SHOW_BNDF(:) = .TRUE.
      ENDIF
 
      ! Smooth obstacles if desired
 
      IF (.NOT.SAWTOOTH) THEN
         OB%BTI = 3
         OB%SAWTOOTH = .FALSE.
      ENDIF
 
      ! In Smokeview, draw the outline of the obstruction
 
      IF (OUTLINE) OB%BTI = 2
      
      ENDDO READ_OBST_LOOP
   35 REWIND(LU_INPUT)
 
ENDDO MESH_LOOP
 
! Read HOLEs and cut out blocks
 
CALL READ_HOLE
 
! Look for OBSTructions that are meant to BURN_AWAY and break them up into single cell blocks

MESH_LOOP_2: DO NM=1,NMESHES
   M=>MESHES(NM)
   CALL POINT_TO_MESH(NM)

   N_OBST_O = N_OBST
   DO N=1,N_OBST_O
      OB => OBSTRUCTION(N)
      IF (OB%CONSUMABLE) THEN

         N_NEW_OBST = MAX(1,OB%I2-OB%I1)*MAX(1,OB%J2-OB%J1)*MAX(1,OB%K2-OB%K1)
         IF (N_NEW_OBST > 1) THEN

            ! Create a temporary array of obstructions with the same properties as the one being replaced, except coordinates

            ALLOCATE(TEMP_OBSTRUCTION(N_NEW_OBST))
            TEMP_OBSTRUCTION = OBSTRUCTION(N)
            NN = 0
            DO K=OB%K1,MAX(OB%K1,OB%K2-1)
               DO J=OB%J1,MAX(OB%J1,OB%J2-1)
                  DO I=OB%I1,MAX(OB%I1,OB%I2-1)
                     NN = NN + 1
                     OBT=>TEMP_OBSTRUCTION(NN)
                     OBT%I1 = I
                     OBT%I2 = MIN(I+1,OB%I2)
                     OBT%J1 = J
                     OBT%J2 = MIN(J+1,OB%J2)
                     OBT%K1 = K
                     OBT%K2 = MIN(K+1,OB%K2)
                     OBT%X1 = M%X(OBT%I1)
                     OBT%X2 = M%X(OBT%I2)
                     OBT%Y1 = M%Y(OBT%J1)
                     OBT%Y2 = M%Y(OBT%J2)
                     OBT%Z1 = M%Z(OBT%K1)
                     OBT%Z2 = M%Z(OBT%K2)
                  ENDDO
                ENDDO
            ENDDO

            CALL RE_ALLOCATE_OBST(NM,N_OBST,N_NEW_OBST-1)
            OBSTRUCTION=>M%OBSTRUCTION
            OBSTRUCTION(N) = TEMP_OBSTRUCTION(1)
            OBSTRUCTION(N_OBST+1:N_OBST+N_NEW_OBST-1) = TEMP_OBSTRUCTION(2:N_NEW_OBST)
            N_OBST = N_OBST + N_NEW_OBST-1
            DEALLOCATE(TEMP_OBSTRUCTION)

         ENDIF
      ENDIF
   ENDDO

ENDDO MESH_LOOP_2


! Go through all meshes, recording which cells are solid
 
MESH_LOOP_3: DO NM=1,NMESHES
   M=>MESHES(NM)
   CALL POINT_TO_MESH(NM)
 
   ! Compute areas of obstruction faces, both actual (AB0) and FDS approximated (AB)
 
   DO N=1,N_OBST
      OB=>OBSTRUCTION(N)
      OB%INPUT_AREA(1) = (OB%Y2-OB%Y1)*(OB%Z2-OB%Z1)
      OB%INPUT_AREA(2) = (OB%X2-OB%X1)*(OB%Z2-OB%Z1)
      OB%INPUT_AREA(3) = (OB%X2-OB%X1)*(OB%Y2-OB%Y1)
      OB%FDS_AREA(1)   = (Y(OB%J2)-Y(OB%J1))*(Z(OB%K2)-Z(OB%K1))
      OB%FDS_AREA(2)   = (X(OB%I2)-X(OB%I1))*(Z(OB%K2)-Z(OB%K1))
      OB%FDS_AREA(3)   = (X(OB%I2)-X(OB%I1))*(Y(OB%J2)-Y(OB%J1))
      OB%DIMENSIONS(1) = OB%I2 - OB%I1
      OB%DIMENSIONS(2) = OB%J2 - OB%J1
      OB%DIMENSIONS(3) = OB%K2 - OB%K1
   ENDDO
 
   ! Create main blockage index array (ICA)
 
   ALLOCATE(M%CELL_INDEX(0:IBP1,0:JBP1,0:KBP1),STAT=IZERO) 
   CALL ChkMemErr('READ','ICA',IZERO) 
   CELL_INDEX=>M%CELL_INDEX
 
   CELL_INDEX = 0 
   NDBC       = 0
 
   DO K=0,KBP1
      DO J=0,JBP1
         DO I=0,1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
         DO I=IBAR,IBP1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
      ENDDO
   ENDDO
 
   DO K=0,KBP1
      DO I=0,IBP1
         DO J=0,1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
         DO J=JBAR,JBP1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
      ENDDO
   ENDDO
 
   DO J=0,JBP1
      DO I=0,IBP1
         DO K=0,1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
         DO K=KBAR,KBP1
            IF (CELL_INDEX(I,J,K)==0) THEN
               NDBC = NDBC + 1
               CELL_INDEX(I,J,K) = NDBC
            ENDIF
         ENDDO
      ENDDO
   ENDDO
 
   DO N=1,N_OBST
      OB=>OBSTRUCTION(N)
      DO K=OB%K1,OB%K2+1
         DO J=OB%J1,OB%J2+1
            DO I=OB%I1,OB%I2+1
               IF (CELL_INDEX(I,J,K)==0) THEN
                  NDBC = NDBC + 1
                  CELL_INDEX(I,J,K) = NDBC
               ENDIF
            ENDDO
         ENDDO
      ENDDO
   ENDDO
 
   ! Store in SOLID which cells are solid and which are not
 
   ALLOCATE(M%SOLID(0:NDBC),STAT=IZERO) 
   CALL ChkMemErr('READ','SOLID',IZERO) 
   M%SOLID = .FALSE.
   SOLID=>M%SOLID
   ALLOCATE(M%OBST_INDEX_C(0:NDBC),STAT=IZERO) 
   CALL ChkMemErr('READ','OBST_INDEX_C',IZERO) 
   M%OBST_INDEX_C = 0
   OBST_INDEX_C=>M%OBST_INDEX_C 
 
   CALL BLOCK_CELL(NM,   0,   0,   1,JBAR,   1,KBAR,1,0)
   CALL BLOCK_CELL(NM,IBP1,IBP1,   1,JBAR,   1,KBAR,1,0)
   IF (TWO_D) THEN
      CALL BLOCK_CELL(NM,   0,IBP1,   0,   0,   0,KBP1,1,0)
      CALL BLOCK_CELL(NM,   0,IBP1,JBP1,JBP1,   0,KBP1,1,0)
   ELSE
      CALL BLOCK_CELL(NM,   1,IBAR,   0,   0,   1,KBAR,1,0)
      CALL BLOCK_CELL(NM,   1,IBAR,JBP1,JBP1,   1,KBAR,1,0)
   ENDIF
   CALL BLOCK_CELL(NM,   1,IBAR,   1,JBAR,   0,   0,1,0)
   CALL BLOCK_CELL(NM,   1,IBAR,   1,JBAR,KBP1,KBP1,1,0)
 
   DO N=1,N_OBST
      OB=>OBSTRUCTION(N)
      IF (.NOT.OB%HIDDEN) CALL BLOCK_CELL(NM,OB%I1+1,OB%I2,OB%J1+1,OB%J2,OB%K1+1,OB%K2,1,N)
   ENDDO
 
   ALLOCATE(M%I_CELL(NDBC),STAT=IZERO) 
   CALL ChkMemErr('READ','I_CELL',IZERO) 
   M%I_CELL = -1
   ALLOCATE(M%J_CELL(NDBC),STAT=IZERO) 
   CALL ChkMemErr('READ','J_CELL',IZERO) 
   M%J_CELL = -1
   ALLOCATE(M%K_CELL(NDBC),STAT=IZERO) 
   CALL ChkMemErr('READ','K_CELL',IZERO) 
   M%K_CELL = -1
   I_CELL=>M%I_CELL 
   J_CELL=>M%J_CELL 
   K_CELL=>M%K_CELL
 
   DO K=0,KBP1
      DO J=0,JBP1
         DO I=0,IBP1
         IC = CELL_INDEX(I,J,K)
            IF (IC>0) THEN
               I_CELL(IC) = I
               J_CELL(IC) = J
               K_CELL(IC) = K
            ENDIF
         ENDDO
      ENDDO
   ENDDO
 
ENDDO MESH_LOOP_3
 
END SUBROUTINE READ_OBST


SUBROUTINE READ_HOLE
USE CONTROL_VARIABLES, ONLY : CONTROl, N_CTRL
USE DEVICE_VARIABLES, ONLY : DEVICE, N_DEVC
CHARACTER(30) :: DEVC_ID,CTRL_ID
CHARACTER(60) :: MESH_ID
CHARACTER(25) :: COLOR
LOGICAL :: EVACUATION
INTEGER :: NM,N_HOLE,NN,NDO,N,I1,I2,J1,J2,K1,K2,RGB(3)
REAL(EB) :: X1,X2,Y1,Y2,Z1,Z2,TRANSPARENCY, DUMMY
NAMELIST /HOLE/ XB,FYI,RGB,TRANSPARENCY,EVACUATION,MESH_ID,COLOR,DEVC_ID,CTRL_ID
TYPE(OBSTRUCTION_TYPE), ALLOCATABLE, DIMENSION(:) :: TEMP_OBST
 
ALLOCATE(TEMP_OBST(0:6))
 
N_HOLE  = 0
REWIND(LU_INPUT)
COUNT_LOOP: DO
   CALL CHECKREAD('HOLE',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_LOOP
   READ(LU_INPUT,NML=HOLE,END=1,ERR=2,IOSTAT=IOS)
   N_HOLE = N_HOLE + 1
   2 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I5)')  'ERROR: Problem with HOLE number',N_HOLE+1
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_LOOP
1 REWIND(LU_INPUT)
 
READ_HOLE_LOOP: DO N=1,N_HOLE
 
   DEVC_ID  = 'null'
   CTRL_ID  = 'null'
   MESH_ID  = 'null'
   COLOR    = 'null'
   RGB      = -1
   TRANSPARENCY  = 1._EB
   EVACUATION = .FALSE.
 
   CALL CHECKREAD('HOLE',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_HOLE_LOOP
   READ(LU_INPUT,HOLE)
 
   DO I=1,5,2
      IF (XB(I)>XB(I+1)) THEN
         DUMMY   = XB(I)
         XB(I)   = XB(I+1)
         XB(I+1) = DUMMY
      ENDIF
   ENDDO
 
   MESH_LOOP: DO NM=1,NMESHES
      M=>MESHES(NM)
      CALL POINT_TO_MESH(NM)
 
      ! Evacuation criteria
 
      IF (MESH_ID/='null' .AND. MESH_ID/=MESH_NAME(NM))CYCLE MESH_LOOP
      IF ((.NOT.EVACUATION .AND. EVACUATION_ONLY(NM)) .OR. (EVACUATION .AND. .NOT.EVACUATION_ONLY(NM)))  CYCLE MESH_LOOP
 
      ! Check if hole is contained within the current mesh
 
      X1 = XB(1)
      X2 = XB(2)
      Y1 = XB(3)
      Y2 = XB(4)
      Z1 = XB(5)
      Z2 = XB(6)
 
      IF (X1>=XF .OR. X2<=XS .OR. Y1>YF .OR. Y2<=YS .OR. Z1>ZF .OR. Z2<=ZS) CYCLE MESH_LOOP
 
      X1 = MAX(X1,XS-0.001_EB*DX(0))
      X2 = MIN(X2,XF+0.001_EB*DX(IBP1))
      Y1 = MAX(Y1,YS-0.001_EB*DY(0))
      Y2 = MIN(Y2,YF+0.001_EB*DY(JBP1))
      Z1 = MAX(Z1,ZS-0.001_EB*DZ(0))
      Z2 = MIN(Z2,ZF+0.001_EB*DZ(KBP1))
 
      I1 = NINT( GINV(XB(1)-XS,1,NM)*RDXI   ) 
      I2 = NINT( GINV(XB(2)-XS,1,NM)*RDXI   )
      J1 = NINT( GINV(XB(3)-YS,2,NM)*RDETA  ) 
      J2 = NINT( GINV(XB(4)-YS,2,NM)*RDETA  )
      K1 = NINT( GINV(XB(5)-ZS,3,NM)*RDZETA ) 
      K2 = NINT( GINV(XB(6)-ZS,3,NM)*RDZETA )
 
      NN=0
      OBST_LOOP: DO
         NN=NN+1
         IF (NN>N_OBST) EXIT OBST_LOOP
         OB=>OBSTRUCTION(NN)
         IF (.NOT.OB%PERMIT_HOLE) CYCLE OBST_LOOP
 
         ! TEMP_OBST(0) is the intersection of HOLE and OBST
 
         TEMP_OBST(0)    = OBSTRUCTION(NN)
 
         TEMP_OBST(0)%I1 = MAX(I1,OB%I1)
         TEMP_OBST(0)%I2 = MIN(I2,OB%I2)
         TEMP_OBST(0)%J1 = MAX(J1,OB%J1)
         TEMP_OBST(0)%J2 = MIN(J2,OB%J2)
         TEMP_OBST(0)%K1 = MAX(K1,OB%K1)
         TEMP_OBST(0)%K2 = MIN(K2,OB%K2)
 
         TEMP_OBST(0)%X1 = MAX(X1,OB%X1)
         TEMP_OBST(0)%X2 = MIN(X2,OB%X2)
         TEMP_OBST(0)%Y1 = MAX(Y1,OB%Y1)
         TEMP_OBST(0)%Y2 = MIN(Y2,OB%Y2)
         TEMP_OBST(0)%Z1 = MAX(Z1,OB%Z1)
         TEMP_OBST(0)%Z2 = MIN(Z2,OB%Z2)
 
         ! Ignore OBSTs that do not intersect with HOLE or are merely sliced by the hole.
 
         IF (TEMP_OBST(0)%I2-TEMP_OBST(0)%I1<0 .OR. TEMP_OBST(0)%J2-TEMP_OBST(0)%J1<0 .OR. &
             TEMP_OBST(0)%K2-TEMP_OBST(0)%K1<0) CYCLE OBST_LOOP
         IF (TEMP_OBST(0)%I2-TEMP_OBST(0)%I1==0) THEN 
            IF (OB%I1<TEMP_OBST(0)%I1 .OR.  OB%I2>TEMP_OBST(0)%I2) CYCLE OBST_LOOP
         ENDIF
         IF (TEMP_OBST(0)%J2-TEMP_OBST(0)%J1==0) THEN
            IF (OB%J1<TEMP_OBST(0)%J1 .OR.  OB%J2>TEMP_OBST(0)%J2) CYCLE OBST_LOOP
         ENDIF
         IF (TEMP_OBST(0)%K2-TEMP_OBST(0)%K1==0) THEN
            IF (OB%K1<TEMP_OBST(0)%K1 .OR.  OB%K2>TEMP_OBST(0)%K2) CYCLE OBST_LOOP
         ENDIF
 
         IF (TEMP_OBST(0)%X2<=X1 .OR. TEMP_OBST(0)%X1>=X2 .OR. TEMP_OBST(0)%Y2<=Y1 .OR. TEMP_OBST(0)%Y1>=Y2 .OR. &
            TEMP_OBST(0)%Z2<=Z1 .OR. TEMP_OBST(0)%Z1>=Z2)  CYCLE OBST_LOOP
 
         ! Start counting new OBSTs that need to be created
 
         NDO=0
 
         IF (OB%I1<I1 .AND. I1<OB%I2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = OB%I1
            TEMP_OBST(NDO)%I2 = I1
            TEMP_OBST(NDO)%X1 = OB%X1
            TEMP_OBST(NDO)%X2 = X1
         ENDIF
 
         IF (OB%I1<I2 .AND. I2<OB%I2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = I2
            TEMP_OBST(NDO)%I2 = OB%I2
            TEMP_OBST(NDO)%X1 = X2 
            TEMP_OBST(NDO)%X2 = OB%X2
         ENDIF
 
         IF (OB%J1<J1 .AND. J1<OB%J2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = MAX(I1,OB%I1)
            TEMP_OBST(NDO)%I2 = MIN(I2,OB%I2)
            TEMP_OBST(NDO)%X1 = MAX(X1,OB%X1)
            TEMP_OBST(NDO)%X2 = MIN(X2,OB%X2)
            TEMP_OBST(NDO)%J1 = OB%J1
            TEMP_OBST(NDO)%J2 = J1
            TEMP_OBST(NDO)%Y1 = OB%Y1
            TEMP_OBST(NDO)%Y2 = Y1
         ENDIF
 
         IF (OB%J1<J2 .AND. J2<OB%J2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = MAX(I1,OB%I1)
            TEMP_OBST(NDO)%I2 = MIN(I2,OB%I2)
            TEMP_OBST(NDO)%X1 = MAX(X1,OB%X1)
            TEMP_OBST(NDO)%X2 = MIN(X2,OB%X2)
            TEMP_OBST(NDO)%J1 = J2    
            TEMP_OBST(NDO)%J2 = OB%J2
            TEMP_OBST(NDO)%Y1 = Y2
            TEMP_OBST(NDO)%Y2 = OB%Y2
         ENDIF
 
         IF (OB%K1<K1 .AND. K1<OB%K2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = MAX(I1,OB%I1)
            TEMP_OBST(NDO)%I2 = MIN(I2,OB%I2)
            TEMP_OBST(NDO)%X1 = MAX(X1,OB%X1)
            TEMP_OBST(NDO)%X2 = MIN(X2,OB%X2)
            TEMP_OBST(NDO)%J1 = MAX(J1,OB%J1)
            TEMP_OBST(NDO)%J2 = MIN(J2,OB%J2)
            TEMP_OBST(NDO)%Y1 = MAX(Y1,OB%Y1)
            TEMP_OBST(NDO)%Y2 = MIN(Y2,OB%Y2)
            TEMP_OBST(NDO)%K1 = OB%K1
            TEMP_OBST(NDO)%K2 = K1
            TEMP_OBST(NDO)%Z1 = OB%Z1
            TEMP_OBST(NDO)%Z2 = Z1
         ENDIF
 
         IF (OB%K1<K2 .AND. K2<OB%K2) THEN
            NDO=NDO+1
            TEMP_OBST(NDO)=OBSTRUCTION(NN)
            TEMP_OBST(NDO)%I1 = MAX(I1,OB%I1)
            TEMP_OBST(NDO)%I2 = MIN(I2,OB%I2)
            TEMP_OBST(NDO)%X1 = MAX(X1,OB%X1)
            TEMP_OBST(NDO)%X2 = MIN(X2,OB%X2)
            TEMP_OBST(NDO)%J1 = MAX(J1,OB%J1)
            TEMP_OBST(NDO)%J2 = MIN(J2,OB%J2)
            TEMP_OBST(NDO)%Y1 = MAX(Y1,OB%Y1)
            TEMP_OBST(NDO)%Y2 = MIN(Y2,OB%Y2)
            TEMP_OBST(NDO)%K1 = K2
            TEMP_OBST(NDO)%K2 = OB%K2
            TEMP_OBST(NDO)%Z1 = Z2
            TEMP_OBST(NDO)%Z2 = OB%Z2
         ENDIF
 
         ! Maintain ordinal rank of original obstruction, but negate it. This will be a code for Smokeview.
 
         TEMP_OBST(:)%ORDINAL = -OB%ORDINAL
 
         ! Re-allocate space of new OBSTs, or remove entry for dead OBST
 
         NEW_OBST_IF: IF (NDO>0) THEN
               CALL RE_ALLOCATE_OBST(NM,N_OBST,NDO)
               OBSTRUCTION=>M%OBSTRUCTION
               OBSTRUCTION(N_OBST+1:N_OBST+NDO) = TEMP_OBST(1:NDO)
               N_OBST = N_OBST + NDO
         ENDIF NEW_OBST_IF
 
         ! If the HOLE is to be created or removed, save it in OBSTRUCTION(NN), the original OBST that was broken up

         IF (DEVC_ID/='null' .OR. CTRL_ID/='null') THEN
            OBSTRUCTION(NN) = TEMP_OBST(0)
            OB => OBSTRUCTION(NN)
            OB%DEVC_ID = DEVC_ID
            OB%CTRL_ID = CTRL_ID
            CALL SEARCH_CONTROLLER('HOLE',CTRL_ID,DEVC_ID,OB%DEVC_INDEX,OB%CTRL_INDEX,N)
            IF (DEVC_ID /='null') THEN
               OB%REMOVABLE = .TRUE.
               OB%HIDDEN = DEVICE(OB%DEVC_INDEX)%PRIOR_STATE               
               DEVICE(OB%DEVC_INDEX)%INITIAL_STATE = .NOT.DEVICE(OB%DEVC_INDEX)%PRIOR_STATE
            ENDIF
            IF (CTRL_ID /='null') THEN
               OB%REMOVABLE = .TRUE.
               OB%HIDDEN = CONTROL(OB%CTRL_INDEX)%PRIOR_STATE
               CONTROL(OB%CTRL_INDEX)%INITIAL_STATE = .NOT.CONTROL(OB%CTRL_INDEX)%PRIOR_STATE
            ENDIF
            
            IF (OB%CONSUMABLE)    OB%REMOVABLE = .TRUE.
            SELECT CASE (COLOR)
               CASE ('INVISIBLE')
                  OB%BCI = -3
                  TRANSPARENCY = 0._EB
               CASE ('null')
                  IF (ANY (RGB<0)) THEN
                     OB%BCI=-1
                  ELSE
                     OB%BCI=-3
                  ENDIF
               CASE DEFAULT
                  CALL COLOR2RGB(RGB,COLOR)
                  OB%BCI = -3
            END SELECT
            OB%RGB  = RGB
            OB%TRANSPARENCY = TRANSPARENCY
         ELSE
            OBSTRUCTION(NN) = OBSTRUCTION(N_OBST)
            N_OBST = N_OBST-1
            NN = NN-1
         ENDIF
 
      ENDDO OBST_LOOP
   ENDDO MESH_LOOP
ENDDO READ_HOLE_LOOP
 
REWIND(LU_INPUT)

DEALLOCATE(TEMP_OBST)
END SUBROUTINE READ_HOLE
 
 
SUBROUTINE RE_ALLOCATE_OBST(NM,N_OBST,NDO)
TYPE (OBSTRUCTION_TYPE), ALLOCATABLE, DIMENSION(:) :: DUMMY
INTEGER, INTENT(IN) :: NM,NDO,N_OBST
TYPE (MESH_TYPE), POINTER :: M
M=>MESHES(NM)
ALLOCATE(DUMMY(0:N_OBST))
DUMMY(0:N_OBST) = M%OBSTRUCTION(0:N_OBST)
DEALLOCATE(M%OBSTRUCTION)
ALLOCATE(M%OBSTRUCTION(0:N_OBST+NDO))
M%OBSTRUCTION(0:N_OBST) = DUMMY(0:N_OBST)
DEALLOCATE(DUMMY)
END SUBROUTINE RE_ALLOCATE_OBST
 
 
SUBROUTINE READ_VENT
USE GEOMETRY_FUNCTIONS, ONLY : BLOCK_CELL
USE DEVICE_VARIABLES, ONLY : DEVICE, N_DEVC
USE CONTROL_VARIABLES, ONLY : CONTROL, N_CTRL
 
INTEGER :: N,NN,NM,NNN,NVO,IOR,I1,I2,J1,J2,K1,K2,RGB(3)
REAL(EB) ::SPREAD_RATE,TRANSPARENCY,DUMMY,XYZ(3)
CHARACTER(30) :: DEVC_ID,CTRL_ID,SURF_ID
CHARACTER(60) :: MESH_ID
CHARACTER(25) :: COLOR
LOGICAL :: REJECT_VENT,EVACUATION,OUTLINE
NAMELIST /VENT/ XB,IOR,MB,PBX,PBY,PBZ,SURF_ID,FYI,RGB,TRANSPARENCY,COLOR, &
                TEXTURE_ORIGIN,OUTLINE,DEVC_ID,CTRL_ID, &
                XYZ,EVACUATION,MESH_ID,SPREAD_RATE
 
MESH_LOOP: DO NM=1,NMESHES
   M=>MESHES(NM)
   CALL POINT_TO_MESH(NM)
 
   REWIND(LU_INPUT)
   N_VENT = 0
   COUNT_VENT_LOOP: DO
      CALL CHECKREAD('VENT',LU_INPUT,IOS) 
      IF (IOS==1) EXIT COUNT_VENT_LOOP
      READ(LU_INPUT,NML=VENT,END=3,ERR=4,IOSTAT=IOS)
      N_VENT = N_VENT + 1
      4 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I4)') 'ERROR: Problem with VENT ',N_VENT+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDDO COUNT_VENT_LOOP
   3 REWIND(LU_INPUT)
 
   IF (TWO_D)                         N_VENT = N_VENT + 2
   IF (CYLINDRICAL .AND. M%XS==0._EB) N_VENT = N_VENT + 1
   IF (EVACUATION_ONLY(NM))           N_VENT = N_VENT + 2
 
   ALLOCATE(M%VENTS(N_VENT),STAT=IZERO)
   CALL ChkMemErr('READ','VENTS',IZERO)
   VENTS=>M%VENTS
 
   NVO   = N_VENT
   N     = 0
 
   REWIND(LU_INPUT)
   READ_VENT_LOOP: DO NN=1,NVO
 
      N       = N + 1
      IOR     = 0
      MB      = 'null'
      PBX     = -1.E6_EB
      PBY     = -1.E6_EB
      PBZ     = -1.E6_EB
      SURF_ID = 'null'
      COLOR   = 'null'
      MESH_ID = 'null'
      RGB          = -1
      TRANSPARENCY = 1._EB
      XYZ     = -999._EB
      SPREAD_RATE = 0.05_EB
      REJECT_VENT  = .FALSE.
      TEXTURE_ORIGIN = -999._EB
      OUTLINE      = .FALSE.
      DEVC_ID  = 'null'
      CTRL_ID  = 'null'
      IF (     EVACUATION_ONLY(NM)) EVACUATION = .TRUE.
      IF (.NOT.EVACUATION_ONLY(NM)) EVACUATION = .FALSE.
 
      IF (NN==NVO-2 .AND. CYLINDRICAL .AND. XS==0._EB) MB='XMIN'
      IF (NN==NVO-1 .AND. TWO_D)                       MB='YMIN'
      IF (NN==NVO   .AND. TWO_D)                       MB='YMAX'
      IF (NN==NVO-1 .AND. EVACUATION_ONLY(NM))         MB='ZMIN'
      IF (NN==NVO   .AND. EVACUATION_ONLY(NM))         MB='ZMAX'
 
      IF (MB=='null') THEN
         CALL CHECKREAD('VENT',LU_INPUT,IOS) 
         IF (IOS==1) EXIT READ_VENT_LOOP
         READ(LU_INPUT,VENT,END=37,ERR=38)    ! Read in info for VENT N
      ELSE
         SURF_ID = 'MIRROR'
      ENDIF
 
      IF (PBX>-1.E5_EB .OR. PBY>-1.E5_EB .OR. PBZ>-1.E5_EB) THEN
         XB(1) = XS
         XB(2) = XF
         XB(3) = YS
         XB(4) = YF
         XB(5) = ZS
         XB(6) = ZF
         IF (PBX>-1.E5_EB) XB(1:2) = PBX
         IF (PBY>-1.E5_EB) XB(3:4) = PBY
         IF (PBZ>-1.E5_EB) XB(5:6) = PBZ
      ENDIF
 
      IF (MB/='null') THEN
         XB(1) = XS
         XB(2) = XF
         XB(3) = YS
         XB(4) = YF
         XB(5) = ZS
         XB(6) = ZF
         SELECT CASE (MB)
            CASE('XMIN')
                XB(2) = XS
            CASE('XMAX')
                XB(1) = XF            
            CASE('YMIN')
                XB(4) = YS            
            CASE('YMAX')
                XB(3) = YF
            CASE('ZMIN')
                XB(6) = ZS                                                                
            CASE('ZMAX')      
                XB(5) = ZF                                                                      
            CASE DEFAULT
               WRITE(MESSAGE,'(A,I4,A)') 'ERROR: MB specified for VENT',NN,' is not XMIN, XMAX, YMIN, YMAX, ZMIN, or ZMAX'
               CALL SHUTDOWN(MESSAGE)
         END SELECT
      ENDIF
 
      ! Check that the vent is properly specified
 
      IF (MESH_ID/='null' .AND. MESH_ID/=MESH_NAME(NM))  REJECT_VENT = .TRUE.
 
      IF (XB(3)==XB(4) .AND. TWO_D .AND. NN<NVO-1) THEN
         WRITE(MESSAGE,'(A,I4,A)') 'ERROR: VENT',NN,' cannot be specified on a y boundary in a 2-D calculation'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
 
      IF (XB(1)/=XB(2) .AND. XB(3)/=XB(4) .AND. XB(5)/=XB(6)) THEN
         WRITE(MESSAGE,'(A,I4,A)') 'ERROR: VENT',NN,' must be a plane'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
 
      DO I=1,5,2
         IF (XB(I)>XB(I+1)) THEN
            DUMMY   = XB(I)
            XB(I)   = XB(I+1)
            XB(I+1) = DUMMY
         ENDIF
      ENDDO
      
      VT=>VENTS(N)
      
      IF (XB(1)==XB(2)) VT%TOTAL_INPUT_AREA = (XB(4)-XB(3))*(XB(6)-XB(5))
      IF (XB(3)==XB(4)) VT%TOTAL_INPUT_AREA = (XB(2)-XB(1))*(XB(6)-XB(5))
      IF (XB(5)==XB(6)) VT%TOTAL_INPUT_AREA = (XB(2)-XB(1))*(XB(4)-XB(3))

      XB(1) = MAX(XB(1),XS)
      XB(2) = MIN(XB(2),XF)
      XB(3) = MAX(XB(3),YS)
      XB(4) = MIN(XB(4),YF)
      XB(5) = MAX(XB(5),ZS)
      XB(6) = MIN(XB(6),ZF)
 
      IF (XB(1)>XF .OR. XB(2)<XS .OR. XB(3)>YF .OR. XB(4)<YS .OR. XB(5)>ZF .OR. XB(6)<ZS) REJECT_VENT = .TRUE.
 
      VT%I1 = NINT( GINV(XB(1)-XS,1,NM)*RDXI   ) 
      VT%I2 = NINT( GINV(XB(2)-XS,1,NM)*RDXI   )
      VT%J1 = NINT( GINV(XB(3)-YS,2,NM)*RDETA  ) 
      VT%J2 = NINT( GINV(XB(4)-YS,2,NM)*RDETA  )
      VT%K1 = NINT( GINV(XB(5)-ZS,3,NM)*RDZETA )
      VT%K2 = NINT( GINV(XB(6)-ZS,3,NM)*RDZETA )
 
      IF (XB(1)==XB(2)) THEN
         IF (VT%J1==VT%J2 .OR. VT%K1==VT%K2) REJECT_VENT=.TRUE.
      ENDIF
      IF (XB(3)==XB(4)) THEN
         IF (VT%I1==VT%I2 .OR. VT%K1==VT%K2) REJECT_VENT=.TRUE.
      ENDIF
      IF (XB(5)==XB(6)) THEN
         IF (VT%I1==VT%I2 .OR. VT%J1==VT%J2) REJECT_VENT=.TRUE.
      ENDIF
 
      ! Evacuation criteria
 
      IF (.NOT.EVACUATION .AND. EVACUATION_ONLY(NM)) REJECT_VENT=.TRUE.
      IF (EVACUATION .AND. .NOT.EVACUATION_ONLY(NM)) REJECT_VENT=.TRUE.
 
      ! If the VENT is to rejected
 
      IF (REJECT_VENT) THEN
         N = N-1
         N_VENT = N_VENT-1
         CYCLE READ_VENT_LOOP
      ENDIF
 
      ! Vent area
 
      VT%X1 = XB(1)
      VT%X2 = XB(2)
      VT%Y1 = XB(3)
      VT%Y2 = XB(4)
      VT%Z1 = XB(5)
      VT%Z2 = XB(6)
 
      IF (XB(1)==XB(2)) VT%INPUT_AREA = (XB(4)-XB(3))*(XB(6)-XB(5))
      IF (XB(3)==XB(4)) VT%INPUT_AREA = (XB(2)-XB(1))*(XB(6)-XB(5))
      IF (XB(5)==XB(6)) VT%INPUT_AREA = (XB(2)-XB(1))*(XB(4)-XB(3))
 
      ! Check the SURF_ID against the list of SURF's

      CALL CHECK_SURF_NAME(SURF_ID,EX)
      IF (.NOT.EX) THEN
         WRITE(MESSAGE,'(A,A,A)') 'ERROR: SURF_ID ',TRIM(SURF_ID),' not found'
         CALL SHUTDOWN(MESSAGE)
      ENDIF

      ! Assign IBC, Index of the Boundary Condition

      VT%IBC = DEFAULT_SURF_INDEX
      DO NNN=0,N_SURF
         IF (SURF_ID==SURF_NAME(NNN)) VT%IBC = NNN
      ENDDO

      IF (SURF_ID=='OPEN')   VT%VTI =  2
      IF (SURF_ID=='MIRROR') VT%VTI = -2
      IF ((MB/='null' .OR.  PBX>-1.E5_EB .OR. PBY>-1.E5_EB .OR. PBZ>-1.E5_EB) .AND. SURF_ID=='OPEN') VT%VTI = -2
 
      VT%BOUNDARY_TYPE = SOLID_BOUNDARY
      IF (VT%IBC==OPEN_SURF_INDEX)   VT%BOUNDARY_TYPE = OPEN_BOUNDARY
      IF (VT%IBC==MIRROR_SURF_INDEX) VT%BOUNDARY_TYPE = MIRROR_BOUNDARY
      VT%IOR = IOR
 
      VT%ORDINAL = NN
 
      ! Activate and Deactivate logic

      VT%DEVC_ID = DEVC_ID
      VT%CTRL_ID = CTRL_ID
      CALL SEARCH_CONTROLLER('VENT',CTRL_ID,DEVC_ID,VT%DEVC_INDEX,VT%CTRL_INDEX,N)
      IF (DEVC_ID /= 'null') VT%ACTIVATED = DEVICE(VT%DEVC_INDEX)%INITIAL_STATE
      IF (CTRL_ID /= 'null') VT%ACTIVATED = CONTROL(VT%CTRL_INDEX)%INITIAL_STATE      

      IF ( (VT%BOUNDARY_TYPE == OPEN_BOUNDARY .OR. VT%BOUNDARY_TYPE == MIRROR_BOUNDARY) .AND. &
           (VT%DEVC_ID /= 'null' .OR. VT%CTRL_ID /= 'null') ) THEN
         WRITE(MESSAGE,'(A,I4,A)') 'ERROR: OPEN OR MIRROR VENT',NN,' cannot be controlled by a device'
         CALL SHUTDOWN(MESSAGE)
      ENDIF

      ! Set the VENT color index

      SELECT CASE(COLOR)
         CASE('INVISIBLE')
            VT%VCI=99
            TRANSPARENCY = 0._EB
         CASE('null')
            VT%VCI=99
         CASE DEFAULT
            VT%VCI=99
            CALL COLOR2RGB(RGB,COLOR)
      END SELECT
      IF (VT%VCI==8) VT%VTI = -2
      IF (OUTLINE)   VT%VTI =  2
      VT%RGB = RGB
      VT%TRANSPARENCY = TRANSPARENCY 

      ! Parameters for specified spread of a fire over a VENT
 
      VT%X0 = XYZ(1)
      VT%Y0 = XYZ(2)
      VT%Z0 = XYZ(3)
      VT%FIRE_SPREAD_RATE = SPREAD_RATE
 
      VT%TEXTURE(:) = TEXTURE_ORIGIN(:)
      
38 CONTINUE
   ENDDO READ_VENT_LOOP
37 REWIND(LU_INPUT)
 
   ! Check vents and assign orientations
 
   VENTLOOP2: DO N=1,N_VENT
 
      VT => VENTS(N)
 
      I1 = VT%I1
      I2 = VT%I2
      J1 = VT%J1
      J2 = VT%J2
      K1 = VT%K1
      K2 = VT%K2
 
      IF (VT%IOR==0) THEN
         IF (I1==      0 .AND. I2==0) VT%IOR =  1
         IF (I1==IBAR .AND. I2==IBAR) VT%IOR = -1
         IF (J1==      0 .AND. J2==0) VT%IOR =  2
         IF (J1==JBAR .AND. J2==JBAR) VT%IOR = -2
         IF (K1==      0 .AND. K2==0) VT%IOR =  3
         IF (K1==KBAR .AND. K2==KBAR) VT%IOR = -3
      ENDIF
 
      ORIENTATION_IF: IF (VT%IOR==0) THEN
         IF (I1==I2) THEN
            DO K=K1+1,K2
               DO J=J1+1,J2
                  IF (.NOT.SOLID(CELL_INDEX(I2+1,J,K))) VT%IOR =  1
                  IF (.NOT.SOLID(CELL_INDEX(I2  ,J,K))) VT%IOR = -1
               ENDDO
            ENDDO
         ENDIF
         IF (J1==J2) THEN
            DO K=K1+1,K2
               DO I=I1+1,I2
                  IF (.NOT.SOLID(CELL_INDEX(I,J2+1,K))) VT%IOR =  2
                  IF (.NOT.SOLID(CELL_INDEX(I,J2  ,K))) VT%IOR = -2
               ENDDO
            ENDDO
         ENDIF
         IF (K1==K2) THEN
            DO J=J1+1,J2
               DO I=I1+1,I2
                  IF (.NOT.SOLID(CELL_INDEX(I,J,K2+1))) VT%IOR =  3
                  IF (.NOT.SOLID(CELL_INDEX(I,J,K2  ))) VT%IOR = -3
               ENDDO
            ENDDO
         ENDIF
      ENDIF ORIENTATION_IF
 
      IF (VT%IOR==0) THEN
         WRITE(MESSAGE,'(A,I3,A,I3)')  'ERROR: Specify orientation of VENT ',VT%ORDINAL, ', MESH NUMBER',NM
         CALL SHUTDOWN(MESSAGE)
      ENDIF
 
      ! Other error messages for VENTs
 
      SELECT CASE(ABS(VT%IOR))
         CASE(1)
            IF (I1>=1 .AND. I1<=IBM1) THEN
               IF (VT%BOUNDARY_TYPE==OPEN_BOUNDARY .OR. VT%BOUNDARY_TYPE==MIRROR_BOUNDARY) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: OPEN or MIRROR VENT ',N, ' must be on an exterior boundary.'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
               VT%BOUNDARY_TYPE = SOLID_BOUNDARY
               IF (.NOT.SOLID(CELL_INDEX(I2+1,J2,K2)) .AND.  .NOT.SOLID(CELL_INDEX(I2,J2,K2))) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: VENT ',N, ' must be attached to a solid obstruction'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
            ENDIF
         CASE(2)
            IF (J1>=1 .AND. J1<=JBM1) THEN
               IF (VT%BOUNDARY_TYPE==OPEN_BOUNDARY .OR. VT%BOUNDARY_TYPE==MIRROR_BOUNDARY) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: OPEN or MIRROR VENT ',N, ' must be on an exterior boundary.'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
               VT%BOUNDARY_TYPE = SOLID_BOUNDARY
               IF (.NOT.SOLID(CELL_INDEX(I2,J2+1,K2)) .AND.  .NOT.SOLID(CELL_INDEX(I2,J2,K2))) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: VENT ',N, ' must be attached to a solid obstruction'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
            ENDIF
         CASE(3)
            IF (K1>=1 .AND. K1<=KBM1) THEN
               IF (VT%BOUNDARY_TYPE==OPEN_BOUNDARY .OR. VT%BOUNDARY_TYPE==MIRROR_BOUNDARY) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: OPEN or MIRROR VENT ',N, ' must be on an exterior boundary.'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
               VT%BOUNDARY_TYPE = SOLID_BOUNDARY
               IF (.NOT.SOLID(CELL_INDEX(I2,J2,K2+1)) .AND. .NOT.SOLID(CELL_INDEX(I2,J2,K2))) THEN
                  WRITE(MESSAGE,'(A,I3,A)')  'ERROR: VENT ',N, ' must be attached to a solid obstruction'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
            ENDIF
      END SELECT
 
      ! Open up boundary cells if it is an open vent
 
      IF ( VT%BOUNDARY_TYPE==OPEN_BOUNDARY) THEN
         SELECT CASE(VT%IOR)
            CASE( 1) 
               CALL BLOCK_CELL(NM,   0,   0,J1+1,  J2,K1+1,  K2,0,0)
            CASE(-1) 
               CALL BLOCK_CELL(NM,IBP1,IBP1,J1+1,  J2,K1+1,  K2,0,0)
            CASE( 2) 
               CALL BLOCK_CELL(NM,I1+1,  I2,   0,   0,K1+1,  K2,0,0)
            CASE(-2) 
               CALL BLOCK_CELL(NM,I1+1,  I2,JBP1,JBP1,K1+1,  K2,0,0)
            CASE( 3) 
               CALL BLOCK_CELL(NM,I1+1,  I2,J1+1,  J2,   0,   0,0,0)
            CASE(-3) 
               CALL BLOCK_CELL(NM,I1+1,  I2,J1+1,  J2,KBP1,KBP1,0,0)
         END SELECT
      ENDIF
 
   ENDDO VENTLOOP2
 
   ! Compute vent areas and check for passive openings
 
   VENT_LOOP_3: DO N=1,N_VENT
 
      VT => VENTS(N)
 
      VT%FDS_AREA = 0._EB
      I1 = VT%I1
      I2 = VT%I2
      J1 = VT%J1
      J2 = VT%J2
      K1 = VT%K1
      K2 = VT%K2
 
      SELECT CASE(ABS(VT%IOR))
         CASE(1)
            DO K=K1+1,K2
               DO J=J1+1,J2
                  VT%FDS_AREA = VT%FDS_AREA + DY(J)*DZ(K)
               ENDDO
            ENDDO
         CASE(2)
            DO K=K1+1,K2
               DO I=I1+1,I2
                  VT%FDS_AREA = VT%FDS_AREA + DX(I)*DZ(K)
               ENDDO
            ENDDO
         CASE(3)
            DO J=J1+1,J2
               DO I=I1+1,I2
                  VT%FDS_AREA = VT%FDS_AREA + DX(I)*DY(J)
               ENDDO
            ENDDO
      END SELECT
 
   ENDDO  VENT_LOOP_3
 
ENDDO MESH_LOOP
 
END SUBROUTINE READ_VENT
 
 
SUBROUTINE READ_INIT
 
REAL(EB) :: TEMPERATURE,DENSITY,MASS_FRACTION(1:20),RR_SUM,YY_SUM
INTEGER  :: N,NN
TYPE(INITIALIZATION_TYPE), POINTER :: IN
NAMELIST /INIT/ XB,TEMPERATURE,DENSITY,MASS_FRACTION
 
N_INIT = 0
REWIND(LU_INPUT)
COUNT_LOOP: DO
   CALL CHECKREAD('INIT',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_LOOP
   READ(LU_INPUT,NML=INIT,END=11,ERR=12,IOSTAT=IOS)
   N_INIT = N_INIT + 1
   12 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with INIT no.',N_INIT+1
      CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_LOOP
11 REWIND(LU_INPUT)
 
! If there are no INIT lines, return

IF (N_INIT==0) RETURN
 
ALLOCATE(INITIALIZATION(N_INIT),STAT=IZERO)
CALL ChkMemErr('READ','INITIALIZATION',IZERO)
 
INIT_LOOP: DO N=1,N_INIT
   IN => INITIALIZATION(N)
   XB(1)         = -1000000._EB
   XB(2)         =  1000000._EB
   XB(3)         = -1000000._EB
   XB(4)         =  1000000._EB
   XB(5)         = -1000000._EB
   XB(6)         =  1000000._EB
   TEMPERATURE   = -1000._EB
   DENSITY       = -1000._EB
   MASS_FRACTION = -1000._EB
 
   CALL CHECKREAD('INIT',LU_INPUT,IOS)
   IF (IOS==1) EXIT INIT_LOOP
   READ(LU_INPUT,INIT) 
 
   IN%X1 = XB(1)
   IN%X2 = XB(2)
   IN%Y1 = XB(3)
   IN%Y2 = XB(4)
   IN%Z1 = XB(5)
   IN%Z2 = XB(6)
   IN%TEMPERATURE   = TEMPERATURE + TMPM
   IN%DENSITY       = DENSITY
   IN%MASS_FRACTION = MASS_FRACTION
   IF (DENSITY     > 0._EB) RHOMAX = MAX(RHOMAX,IN%DENSITY)
   IF (TEMPERATURE > 0._EB) TMPMIN = MIN(TMPMIN,IN%TEMPERATURE)

   IF (IN%TEMPERATURE > 0._EB .AND. IN%DENSITY < 0._EB) THEN
      IN%DENSITY        = P_INF/(IN%TEMPERATURE*RSUM0)
      IN%ADJUST_DENSITY = .TRUE.
   ENDIF
   IF (IN%TEMPERATURE < 0._EB .AND. IN%DENSITY > 0._EB) THEN
      IN%TEMPERATURE = P_INF/(IN%DENSITY*RSUM0)
      IN%ADJUST_TEMPERATURE = .TRUE.
   ENDIF
   IF (IN%TEMPERATURE < 0._EB .AND. IN%DENSITY < 0._EB) THEN
      IN%TEMPERATURE = TMPA
      IN%DENSITY     = RHOA
      IN%ADJUST_TEMPERATURE = .TRUE.
      IN%ADJUST_DENSITY     = .TRUE.
   ENDIF

   YY_SUM = 0._EB
   RR_SUM = 0._EB
   DO NN=1,N_SPECIES
      IF (IN%MASS_FRACTION(NN)>0._EB) THEN
         RR_SUM = RR_SUM + IN%MASS_FRACTION(NN)*R0/SPECIES(NN)%MW
         YY_SUM = YY_SUM + IN%MASS_FRACTION(NN)
      ENDIF
      IF (IN%MASS_FRACTION(NN)<0._EB) THEN
         IN%MASS_FRACTION(NN) = SPECIES(NN)%YY0
         RR_SUM = RR_SUM + SPECIES(NN)%YY0*R0/SPECIES(NN)%MW
         YY_SUM = YY_SUM + SPECIES(NN)%YY0
      ENDIF
   ENDDO

   IF (IN%DENSITY < 0._EB) THEN
      RR_SUM = (1._EB-YY_SUM)*SPECIES(0)%YY0*R0/SPECIES(0)%MW + RR_SUM
      IN%DENSITY = P_INF/(IN%TEMPERATURE*RR_SUM)
      IN%ADJUST_DENSITY  = .TRUE.
   ENDIF
 
ENDDO INIT_LOOP
REWIND(LU_INPUT)

END SUBROUTINE READ_INIT


SUBROUTINE READ_ZONE
 
REAL(EB) :: LEAK_AREA(0:20)
INTEGER  :: N,NM
LOGICAL :: SEALED
CHARACTER(30) :: ID
NAMELIST /ZONE/ XB,LEAK_AREA,ID
 
N_ZONE = 0
REWIND(LU_INPUT)
COUNT_ZONE_LOOP: DO
   CALL CHECKREAD('ZONE',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_ZONE_LOOP
   READ(LU_INPUT,NML=ZONE,END=11,ERR=12,IOSTAT=IOS)
   N_ZONE = N_ZONE + 1
   12 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with ZONE no.',N_ZONE+1
      CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_ZONE_LOOP
11 REWIND(LU_INPUT)
 
! Check to see if there are any OPEN vents. If there are not, and there are no declared pressure ZONEs, stop with an error.

SEALED = .TRUE.
IF (ALL(EVACUATION_ONLY)) SEALED = .FALSE.    

DO NM=1,NMESHES
   IF (.NOT.EVACUATION_ONLY(NM)) THEN      
      M => MESHES(NM)
      DO N=1,M%N_VENT
         VT => M%VENTS(N)
         IF (VT%BOUNDARY_TYPE==OPEN_BOUNDARY) SEALED = .FALSE.
      ENDDO
   END IF
ENDDO

IF (SEALED .AND. N_ZONE==0) THEN
   WRITE(MESSAGE,'(A,I3)') 'ERROR: The domain appears to be sealed, but no pressure ZONEs are declared'
   CALL SHUTDOWN(MESSAGE)
ENDIF

! If there are no ZONE lines, return

IF (N_ZONE==0) RETURN
 
ALLOCATE(P_ZONE(N_ZONE),STAT=IZERO)
CALL ChkMemErr('READ','P_ZONE',IZERO)
 
READ_ZONE_LOOP: DO N=1,N_ZONE
 
   WRITE(ID,'(A,I2.2)') 'ZONE_',N
   LEAK_AREA     = 0._EB
   XB(1)         = -1000000._EB
   XB(2)         =  1000000._EB
   XB(3)         = -1000000._EB
   XB(4)         =  1000000._EB
   XB(5)         = -1000000._EB
   XB(6)         =  1000000._EB
 
   CALL CHECKREAD('ZONE',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_ZONE_LOOP
   READ(LU_INPUT,ZONE) 
 
   P_ZONE(N)%ID = ID
   P_ZONE(N)%LEAK_AREA = LEAK_AREA
   P_ZONE(N)%X1 = XB(1)
   P_ZONE(N)%X2 = XB(2)
   P_ZONE(N)%Y1 = XB(3)
   P_ZONE(N)%Y2 = XB(4)
   P_ZONE(N)%Z1 = XB(5)
   P_ZONE(N)%Z2 = XB(6)
 
ENDDO READ_ZONE_LOOP
REWIND(LU_INPUT)

END SUBROUTINE READ_ZONE

 
SUBROUTINE READ_DEVC

! Just read in the DEViCes and the store the info in DEVICE()

USE DEVICE_VARIABLES, ONLY: DEVICE_TYPE, DEVICE, N_DEVC
INTEGER  :: N,NN,NM,MESH_NUMBER,N_DEVCO,IOR,TRIP_DIRECTION
REAL(EB) :: DEPTH,ORIENTATION(3),ROTATION,SETPOINT,FLOWRATE,BYPASS_FLOWRATE,DELAY,XYZ(3)
CHARACTER(30) :: QUANTITY,PROP_ID,CTRL_ID,DEVC_ID
LOGICAL :: INITIAL_STATE,LATCH
TYPE (DEVICE_TYPE), POINTER :: DV
NAMELIST /DEVC/ DEPTH,FYI,IOR,ID,ORIENTATION,PROP_ID,QUANTITY,ROTATION,XB,XYZ,INITIAL_STATE,LATCH,TRIP_DIRECTION,CTRL_ID,& 
                SETPOINT,DEVC_ID,FLOWRATE,DELAY,BYPASS_FLOWRATE
 
N_DEVC = 0
REWIND(LU_INPUT)
COUNT_DEVC_LOOP: DO
   CALL CHECKREAD('DEVC',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_DEVC_LOOP
   READ(LU_INPUT,NML=DEVC,END=11,ERR=12,IOSTAT=IOS)
   N_DEVC = N_DEVC + 1
   12 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I4)') 'ERROR: Problem with DEVC no.',N_DEVC+1
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_DEVC_LOOP
11 REWIND(LU_INPUT)
 
IF (N_DEVC==0) RETURN

! Allocate DEVICE array and set initial values of all to 0

ALLOCATE(DEVICE(N_DEVC),STAT=IZERO)
CALL ChkMemErr('READ','DEVICE',IZERO)
 
! Read in the DEVC lines

N_DEVCO = N_DEVC
N       = 0

READ_DEVC_LOOP: DO NN=1,N_DEVCO

   N          = N+1
   CALL CHECKREAD('DEVC',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_DEVC_LOOP
   CALL SET_DEVC_DEFAULTS
   READ(LU_INPUT,DEVC) 


   IF (XB(1)>-1.E5_EB) THEN
      XYZ(1) = 0.5_EB*(XB(1)+XB(2))
      XYZ(2) = 0.5_EB*(XB(3)+XB(4))
      XYZ(3) = 0.5_EB*(XB(5)+XB(6))
   ELSE
      IF (XYZ(1) < -1.E5_EB) THEN
         WRITE(MESSAGE,'(A,I5,A)')  ' ERROR: DEVC ',NN,' must have coordinates, even if it is not a point quantity'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDIF

   ! Determine which mesh the device is in

   BAD = .FALSE.
   MESH_LOOP: DO NM=1,NMESHES
      IF (.NOT.EVACUATION_ONLY(NM)) THEN      
         M=>MESHES(NM)
         IF (XYZ(1)>=M%XS .AND. XYZ(1)<=M%XF .AND. XYZ(2)>=M%YS .AND. XYZ(2)<=M%YF .AND. XYZ(3)>=M%ZS .AND. XYZ(3)<=M%ZF) THEN
            MESH_NUMBER = NM
            EXIT MESH_LOOP
         ENDIF
      ENDIF
      IF (NM==NMESHES) BAD = .TRUE.
   ENDDO MESH_LOOP

   ! Make sure there is either a QUANTITY or PROP_ID for the DEVICE

   IF (QUANTITY=='null' .AND. PROP_ID=='null') THEN
      WRITE(MESSAGE,'(A,I5,A)')  ' ERROR: DEVC ',NN,' must have either an output QUANTITY or PROP_ID'
      CALL SHUTDOWN(MESSAGE)
   ENDIF

   IF (BAD) THEN
      IF (QUANTITY=='TIME') THEN
         XYZ(1) = MESHES(1)%XS
         XYZ(2) = MESHES(1)%YS
         XYZ(3) = MESHES(1)%ZS
         MESH_NUMBER = 1
      ELSE
         N      = N-1
         N_DEVC = N_DEVC-1
         CYCLE READ_DEVC_LOOP
      ENDIF
   ENDIF

   ! Assign properties to the DEVICE array

   DV => DEVICE(N)
   M  => MESHES(MESH_NUMBER)

   DV%DEPTH            = DEPTH
   DV%IOR              = IOR
   DV%ID               = ID
   DV%MESH             = MESH_NUMBER
   DV%ORDINAL          = NN
   DV%ORIENTATION(1:3) = ORIENTATION(1:3)/SQRT(ORIENTATION(1)**2+ORIENTATION(2)**2+ORIENTATION(3)**2)
   DV%PROP_ID          = PROP_ID
   DV%CTRL_ID          = CTRL_ID   
   DV%DEVC_ID          = DEVC_ID      
   DV%QUANTITY         = QUANTITY
   DV%ROTATION         = ROTATION*TWOPI/360._EB
   DV%SETPOINT         = SETPOINT
   DV%LATCH            = LATCH
   DV%TRIP_DIRECTION   = TRIP_DIRECTION
   DV%INITIAL_STATE    = INITIAL_STATE
   DV%CURRENT_STATE    = INITIAL_STATE
   DV%PRIOR_STATE      = INITIAL_STATE
   DV%FLOWRATE         = FLOWRATE
   DV%BYPASS_FLOWRATE  = BYPASS_FLOWRATE
   DV%DELAY            = DELAY
   DV%X1               = XB(1)
   DV%X2               = XB(2)
   DV%Y1               = XB(3)
   DV%Y2               = XB(4)
   DV%Z1               = XB(5)
   DV%Z2               = XB(6)
   DV%X                = XYZ(1)
   DV%Y                = XYZ(2)
   DV%Z                = XYZ(3)
   
   ! Coordinates for non-point devices

   IF (XB(1)>-1.E5_EB) THEN
      NM = DV%MESH
      M=>MESHES(NM)
      XB(1) = MAX(XB(1),M%XS)
      XB(2) = MIN(XB(2),M%XF)
      XB(3) = MAX(XB(3),M%YS)
      XB(4) = MIN(XB(4),M%YF)
      XB(5) = MAX(XB(5),M%ZS)
      XB(6) = MIN(XB(6),M%ZF)
      DV%X1 = XB(1)
      DV%X2 = XB(2)
      DV%Y1 = XB(3)
      DV%Y2 = XB(4)
      DV%Z1 = XB(5)
      DV%Z2 = XB(6)
      DV%I1 = NINT( GINV(XB(1)-M%XS,1,NM)*M%RDXI)
      DV%I2 = NINT( GINV(XB(2)-M%XS,1,NM)*M%RDXI)
      DV%J1 = NINT( GINV(XB(3)-M%YS,2,NM)*M%RDETA)
      DV%J2 = NINT( GINV(XB(4)-M%YS,2,NM)*M%RDETA)
      DV%K1 = NINT( GINV(XB(5)-M%ZS,3,NM)*M%RDZETA)
      DV%K2 = NINT( GINV(XB(6)-M%ZS,3,NM)*M%RDZETA)
      IF (DV%I1<DV%I2) DV%I1 = DV%I1 + 1
      IF (DV%J1<DV%J2) DV%J1 = DV%J1 + 1
      IF (DV%K1<DV%K2) DV%K1 = DV%K1 + 1
      IF (XB(1)==XB(2)) DV%IOR = 1
      IF (XB(3)==XB(4)) DV%IOR = 2
      IF (XB(5)==XB(6)) DV%IOR = 3
   ENDIF
   
ENDDO READ_DEVC_LOOP
REWIND(LU_INPUT)

CONTAINS

SUBROUTINE SET_DEVC_DEFAULTS

DEPTH            = 0._EB
IOR              = 0
SELECT CASE(N)
   CASE(1:9)
      WRITE(ID,'(A7,I1)') 'Device_',N
   CASE(10:99)
      WRITE(ID,'(A7,I2)') 'Device_',N
   CASE(100:999)
      WRITE(ID,'(A7,I3)') 'Device_',N
   CASE(1000:9999)
      WRITE(ID,'(A7,I4)') 'Device_',N
END SELECT
ORIENTATION(1:3) = (/0._EB,0._EB,-1._EB/)
PROP_ID          = 'null'
CTRL_ID          = 'null'
DEVC_ID          = 'null'
FLOWRATE         = 0._EB
DELAY            = 0._EB
BYPASS_FLOWRATE  = 0._EB
QUANTITY         = 'null'
ROTATION         = 0._EB
XB               = -1.E6_EB
INITIAL_STATE    = .FALSE.
LATCH            = .TRUE.
SETPOINT         = 1.E20_EB
TRIP_DIRECTION   = 1
XYZ              = -1.E6_EB

END SUBROUTINE SET_DEVC_DEFAULTS

END SUBROUTINE READ_DEVC



SUBROUTINE READ_CTRL

! Just read in the ConTRoL parameters and store in the array CONTROL

USE CONTROL_VARIABLES
USE MATH_FUNCTIONS, ONLY : GET_RAMP_INDEX

LOGICAL :: INITIAL_STATE, LATCH
INTEGER :: CYCLES,N,NC
REAL(EB) :: SETPOINT(2), DELAY, CYCLE_TIME
CHARACTER(30) :: ID,FUNCTION_TYPE,INPUT_ID(40),RAMP_ID,ON_BOUND
TYPE (CONTROL_TYPE), POINTER :: CF
NAMELIST /CTRL/ ID,LATCH,INITIAL_STATE,FUNCTION_TYPE,SETPOINT,DELAY,CYCLE_TIME,INPUT_ID,RAMP_ID,CYCLES,N,ON_BOUND
 
N_CTRL = 0
REWIND(LU_INPUT)
COUNT_CTRL_LOOP: DO
   CALL CHECKREAD('CTRL',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_CTRL_LOOP
   READ(LU_INPUT,NML=CTRL,END=11,ERR=12,IOSTAT=IOS)
   N_CTRL = N_CTRL + 1
   12 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I4)') 'ERROR: Problem with CTRL no.',N_CTRL+1
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_CTRL_LOOP
11 REWIND(LU_INPUT)
 
IF (N_CTRL==0) RETURN

! Allocate CONTROL array and set initial values of all to 0

ALLOCATE(CONTROL(N_CTRL),STAT=IZERO)
CALL ChkMemErr('READ','CONTROL',IZERO)
 
! Read in the CTRL lines

READ_CTRL_LOOP: DO NC=1,N_CTRL

   CALL CHECKREAD('CTRL',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_CTRL_LOOP
   CALL SET_CTRL_DEFAULTS
   READ(LU_INPUT,CTRL) 

   ! Make sure there is either a FUNCTION_TYPE type for the CTRL

   IF (FUNCTION_TYPE=='null') THEN
      WRITE(MESSAGE,'(A,I5,A)')  ' ERROR: CTRL ',NC,' must have a FUNCTION_TYPE'
      CALL SHUTDOWN(MESSAGE)
   ENDIF

   ! Assign properties to the CONTROL array

   CF => CONTROL(NC)
   CF%ID            = ID
   CF%LATCH         = LATCH
   CF%INITIAL_STATE = INITIAL_STATE
   CF%CURRENT_STATE = INITIAL_STATE   
   CF%PRIOR_STATE   = INITIAL_STATE      
   CF%SETPOINT      = SETPOINT
   CF%DELAY         = DELAY
   CF%CYCLE_TIME    = CYCLE_TIME
   CF%CYCLES        = CYCLES
   CF%RAMP_ID       = RAMP_ID
   CF%N             = N   
   CF%INPUT_ID      = INPUT_ID
   IF (ON_BOUND=='UPPER') THEN
      CF%ON_BOUND = 1
   ELSE
      CF%ON_BOUND = -1
   ENDIF   
   !Assign control index 
   SELECT CASE(FUNCTION_TYPE)
      CASE('ALL')
         CF%CONTROL_INDEX = AND_GATE
      CASE('ANY')
         CF%CONTROL_INDEX = OR_GATE
      CASE('ONLY')
         CF%CONTROL_INDEX = XOR_GATE
      CASE('AT_LEAST')
         CF%CONTROL_INDEX = X_OF_N_GATE
      CASE('TIME_DELAY')
         CF%CONTROL_INDEX = TIME_DELAY
      CASE('DEADBAND')
         CF%CONTROL_INDEX = DEADBAND
      CASE('CYCLING')
         CF%CONTROL_INDEX = CYCLING
      CASE('CUSTOM')
         CF%CONTROL_INDEX = CUSTOM
         CALL GET_RAMP_INDEX(RAMP_ID,'TIME',CF%RAMP_INDEX)         
      CASE('KILL')
         CF%CONTROL_INDEX = KILL
      CASE('RESTART')
         CF%CONTROL_INDEX = CORE_DUMP
      CASE DEFAULT
         WRITE(MESSAGE,'(A,I5,A)')  ' ERROR: CTRL ',NC,' FUNCTION_TYPE not recognized'
         CALL SHUTDOWN(MESSAGE)
   END SELECT
   
ENDDO READ_CTRL_LOOP
REWIND(LU_INPUT)

CONTAINS

SUBROUTINE SET_CTRL_DEFAULTS
   ID            = 'null'
   LATCH         = .TRUE.
   INITIAL_STATE = .FALSE.
   SETPOINT      = 1000000._EB
   DELAY         = 0._EB
   CYCLE_TIME    = 1000000._EB
   CYCLES        = 1
   FUNCTION_TYPE = 'null'
   RAMP_ID       = 'null'
   INPUT_ID      = 'null'
   ON_BOUND      = 'LOWER'
   N             = 1
END SUBROUTINE SET_CTRL_DEFAULTS

END SUBROUTINE READ_CTRL



SUBROUTINE PROC_CTRL

! Process the CONTROL function parameters

USE DEVICE_VARIABLES, ONLY : DEVICE, N_DEVC
USE CONTROL_VARIABLES
INTEGER :: NC,NN,NNN
TYPE (CONTROL_TYPE), POINTER :: CF

PROC_CTRL_LOOP: DO NC = 1, N_CTRL
   CF => CONTROL(NC)
   CF%PRIOR_STATE=CF%INITIAL_STATE
   CF%CURRENT_STATE=CF%INITIAL_STATE
   !setup input array
   CF%N_INPUTS = 0
   INPUT_COUNT: DO
      IF (CF%INPUT_ID(CF%N_INPUTS+1)=='null') EXIT INPUT_COUNT
      CF%N_INPUTS = CF%N_INPUTS + 1
   END DO INPUT_COUNT
   IF (CF%N_INPUTS==0) THEN
      WRITE(MESSAGE,'(A,I5,A)')  ' ERROR: CTRL ',NC,' must have at least one input'
      CALL SHUTDOWN(MESSAGE)
   ENDIF   
   
   ALLOCATE (CF%INPUT(CF%N_INPUTS),STAT=IZERO)
   CALL ChkMemErr('READ','CF%INPUT',IZERO)
   ALLOCATE (CF%INPUT_TYPE(CF%N_INPUTS),STAT=IZERO)
   CALL ChkMemErr('READ','CF%INPUT_TYPE',IZERO)
   
   BUILD_INPUT: DO NN = 1, CF%N_INPUTS
      CTRL_LOOP: DO NNN = 1, N_CTRL
         IF(CONTROL(NNN)%ID == CF%INPUT_ID(NN)) THEN
            CF%INPUT(NN) = NNN
            CF%INPUT_TYPE(NN) = CONTROL_INPUT
            CYCLE BUILD_INPUT
         ENDIF
      END DO CTRL_LOOP
      DEVC_LOOP: DO NNN = 1, N_DEVC
         IF(DEVICE(NNN)%ID == CF%INPUT_ID(NN)) THEN
            CF%INPUT(NN) = NNN
            CF%INPUT_TYPE(NN) = DEVICE_INPUT
            CYCLE BUILD_INPUT
         ENDIF
      END DO DEVC_LOOP
   WRITE(MESSAGE,'(A,I5,A,A)')  ' ERROR: CTRL ',NC,' cannot locate item for input ', TRIM(CF%INPUT_ID(NN))
   CALL SHUTDOWN(MESSAGE)
   END DO BUILD_INPUT
END DO PROC_CTRL_LOOP  
   
END SUBROUTINE PROC_CTRL   



SUBROUTINE PROC_DEVC
USE DEVICE_VARIABLES, ONLY : DEVICE_TYPE, DEVICE, N_DEVC, PROPERTY, N_PROP
USE CONTROL_VARIABLES
! Process the DEViCes
 
INTEGER  :: N,NN,NNN,NM,QUANTITY_INDEX,MAXCELLS,I,J,K
REAL(EB) :: XX,YY,ZZ,XX1,YY1,ZZ1,DISTANCE,SCANDISTANCE,DX,DY,DZ
TYPE (DEVICE_TYPE),  POINTER :: DV
 
IF (N_DEVC==0) RETURN

! Set initial values for DEViCes

DEVICE(1:N_DEVC)%VALUE = 0._EB
DEVICE(1:N_DEVC)%COUNT = 0

PROC_DEVC_LOOP: DO N=1,N_DEVC

   DV => DEVICE(N)

   ! Check if the device PROPERTY exists and is appropriate

   DV%PROP_INDEX = 0
   IF (DV%PROP_ID /= 'null') THEN
      SUCCESS = .FALSE.
      SEARCH2: DO NN=1,N_PROP
         IF (DV%PROP_ID==PROPERTY(NN)%ID) THEN
            SUCCESS  = .TRUE.
            DV%PROP_INDEX = NN
            EXIT SEARCH2
         ENDIF
      ENDDO SEARCH2
      IF (.NOT.SUCCESS) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: DEVC PROPerty ',TRIM(DV%PROP_ID),' not found'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (DV%QUANTITY=='null' .AND. PROPERTY(DV%PROP_INDEX)%QUANTITY=='null') THEN
         WRITE(MESSAGE,'(5A)')  ' ERROR: DEVC ',TRIM(DV%ID),' or DEVC PROPerty ',TRIM(DV%PROP_ID),' must have a QUANTITY' 
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (DV%QUANTITY=='null' .AND. PROPERTY(DV%PROP_INDEX)%QUANTITY/='null') DV%QUANTITY = PROPERTY(DV%PROP_INDEX)%QUANTITY
   ENDIF

   ! Check if the output QUANTITY exists and is appropriate

   QUANTITY_INDEX = 0
   IF (DV%QUANTITY /= 'null') THEN
      SUCCESS = .FALSE.
      SEARCH1: DO NN=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
         IF (DV%QUANTITY==OUTPUT_QUANTITY(NN)%NAME) THEN
            SUCCESS  = .TRUE.
            QUANTITY_INDEX = NN
            EXIT SEARCH1
         ENDIF
      ENDDO SEARCH1
      IF (.NOT.SUCCESS) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: DEVC QUANTITY ',TRIM(DV%QUANTITY),' is not on the list of outputs'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (OUTPUT_QUANTITY(QUANTITY_INDEX)%MIXTURE_FRACTION_ONLY .AND. .NOT.MIXTURE_FRACTION) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: DEVC QUANTITY ',TRIM(DV%QUANTITY),' inappropriate without mixture fraction model'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (OUTPUT_QUANTITY(QUANTITY_INDEX)%PART_APPROPRIATE) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: DEVC QUANTITY ',TRIM(DV%QUANTITY),' inappropriate'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (OUTPUT_QUANTITY(QUANTITY_INDEX)%INTEGRATED .AND. DV%X1<-1000._EB) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: DEVC QUANTITY ',TRIM(DV%QUANTITY),' requires coordinates using XB'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (QUANTITY_INDEX<0 .AND. DV%IOR==0) THEN
         WRITE(MESSAGE,'(A,I4,A)') 'ERROR: Specify orientation of DEVC ' ,N,' using the parameter IOR'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDIF

   ! Assign properties to the DEVICE array

   M  => MESHES(DV%MESH)

   DV%T_CHANGE         = 10000000._EB
   DV%I                = MAX( 1 , MIN( M%IBAR , FLOOR(GINV(DV%X-M%XS,1,DV%MESH)*M%RDXI)  +1 ) )
   DV%J                = MAX( 1 , MIN( M%JBAR , FLOOR(GINV(DV%Y-M%YS,2,DV%MESH)*M%RDETA) +1 ) )
   DV%K                = MAX( 1 , MIN( M%KBAR , FLOOR(GINV(DV%Z-M%ZS,3,DV%MESH)*M%RDZETA)+1 ) )
   DV%OUTPUT_INDEX     = QUANTITY_INDEX
   DV%CTRL_INDEX       = 0
   DV%QUANTITY         = OUTPUT_QUANTITY(QUANTITY_INDEX)%NAME
   DV%T                = 0._EB
   DV%TMP_L            = TMPA
   
   ! Do initialization of special models
   
   SPECIAL_QUANTITIES: SELECT CASE (DV%QUANTITY)

      CASE ('spot obscuration') 

         IF (DV%PROP_INDEX<1) THEN
            WRITE(MESSAGE,'(A,I4,A)') 'ERROR: DEVC ' ,N,' must have a PROP_ID'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         ALLOCATE(DV%T_E(-1:1000))
         ALLOCATE(DV%Y_E(-1:1000))
         DV%T_E      = T_BEGIN - M%DT
         DV%Y_E      = 0._EB
         DV%N_T_E    = -1
         DV%Y_C      = 0._EB
         DV%SETPOINT = PROPERTY(DV%PROP_INDEX)%ACTIVATION_OBSCURATION
   
      CASE ('LINK TEMPERATURE') 

         IF (DV%PROP_INDEX<1) THEN
            WRITE(MESSAGE,'(A,I4,A)') 'ERROR: DEVC ' ,N,' must have a PROP_ID'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         DV%SETPOINT = PROPERTY(DV%PROP_INDEX)%ACTIVATION_TEMPERATURE
         DV%TMP_L    = PROPERTY(DV%PROP_INDEX)%INITIAL_TEMPERATURE

      CASE ('SPRINKLER LINK TEMPERATURE') 

         IF (DV%PROP_INDEX<1) THEN
            WRITE(MESSAGE,'(A,I4,A)') 'ERROR: DEVC ' ,N,' must have a PROP_ID'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         DV%SETPOINT = PROPERTY(DV%PROP_INDEX)%ACTIVATION_TEMPERATURE
         DV%TMP_L    = PROPERTY(DV%PROP_INDEX)%INITIAL_TEMPERATURE

      CASE ('LAYER HEIGHT','UPPER TEMPERATURE','LOWER TEMPERATURE','UPPER KAPPA') 

         DV%K1 = MAX(1     ,DV%K1)
         DV%K2 = MIN(M%KBAR,DV%K2)

      CASE ('path obscuration')

         NM = DV%MESH
         M=>MESHES(NM)
         DISTANCE = SQRT((DV%X1-DV%X2)**2 + (DV%Y1-DV%Y2)**2 + (DV%Z1-DV%Z2)**2)
         SCANDISTANCE = 0.0001_EB * DISTANCE
         DX = (DV%X2-DV%X1) * 0.0001_EB
         DY = (DV%Y2-DV%Y1) * 0.0001_EB
         DZ = (DV%Z2-DV%Z1) * 0.0001_EB
         XX = DV%X1
         YY = DV%Y1
         ZZ = DV%Z1
         MAXCELLS = 2*MAX(M%IBAR,M%JBAR,M%KBAR)
         ALLOCATE(DV%I_PATH(MAXCELLS))
         ALLOCATE(DV%J_PATH(MAXCELLS))
         ALLOCATE(DV%K_PATH(MAXCELLS))
         ALLOCATE(DV%D_PATH(MAXCELLS))
         DV%D_PATH    = 0._EB
         DV%I_PATH = INT(GINV(DV%X1-M%XS,1,NM)*M%RDXI)   + 1
         DV%J_PATH = INT(GINV(DV%Y1-M%YS,2,NM)*M%RDETA)  + 1
         DV%K_PATH = INT(GINV(DV%Z1-M%ZS,3,NM)*M%RDZETA) + 1
         DV%N_PATH    = 1
         NN = 1
         DO NNN=1,10000
            XX = XX + DX
            I = INT(GINV(XX-M%XS,1,NM)*M%RDXI)   + 1
            YY = YY + DY
            J = INT(GINV(YY-M%YS,2,NM)*M%RDETA)  + 1
            ZZ = ZZ + DZ
            K = INT(GINV(ZZ-M%ZS,3,NM)*M%RDZETA) + 1
            IF (I==DV%I_PATH(NN) .AND. J==DV%J_PATH(NN) .AND. K==DV%K_PATH(NN)) THEN
               DV%D_PATH(NN) = DV%D_PATH(NN) + SCANDISTANCE
            ELSE
               NN = NN + 1
               DV%I_PATH(NN) = I
               DV%J_PATH(NN) = J
               DV%K_PATH(NN) = K
               XX1 = DX
               YY1 = DY
               ZZ1 = DZ
               IF (I/=DV%I_PATH(NN-1)) XX1 = XX-M%X(DV%I_PATH(NN-1))
               IF (J/=DV%J_PATH(NN-1)) YY1 = YY-M%Y(DV%J_PATH(NN-1))
               IF (K/=DV%K_PATH(NN-1)) ZZ1 = ZZ-M%Z(DV%K_PATH(NN-1))
               DV%D_PATH(NN)   = SCANDISTANCE - SQRT(XX1**2+YY1**2+ZZ1**2)
               DV%D_PATH(NN-1) = DV%D_PATH(NN-1) + SCANDISTANCE - DV%D_PATH(NN)
            ENDIF
         ENDDO
         DV%N_PATH = NN
                     
      CASE ('CONTROL')

         DO NN=1,N_CTRL
            IF (CONTROL(NN)%ID==DV%CTRL_ID) DV%CTRL_INDEX = NN
         ENDDO
         IF (DV%CTRL_ID/='null' .AND. DV%CTRL_INDEX<=0) THEN
            WRITE(MESSAGE,'(A,A,A)')  'ERROR: CONTROL ',TRIM(DV%CTRL_ID),' does not exist'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         DV%SETPOINT = 0.5
         DV%TRIP_DIRECTION = 1

      CASE ('aspiration')

         NNN = 0
         ! Count number of inputs for detector and verify that input is soot density device
         DO NN=1,N_DEVC
            IF (DEVICE(NN)%DEVC_ID==DV%ID) THEN
               IF (DEVICE(NN)%QUANTITY /='soot density') THEN
                  WRITE(MESSAGE,'(A,A,A)')  &
                     'ERROR: DEVICE ',TRIM(DEVICE(NN)%ID),' is used an aspiration input without QUANTITY=soot density'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
               NNN = NNN + 1
            ENDIF
         ENDDO
         ALLOCATE(DV%DEVC_INDEX(NNN),STAT=IZERO)
         CALL ChkMemErr('READ','DV%DEVC_INDEX',IZERO)
         DV%DEVC_INDEX = -1
         ALLOCATE(DV%YY_SOOT(NNN,0:100))
         CALL ChkMemErr('READ','DV%YY_SOOT',IZERO)
         DV%YY_SOOT = 0._EB
         ALLOCATE(DV%TIME_ARRAY(0:100))
         CALL ChkMemErr('READ','DV%TIME_ARRAY',IZERO)
         DV%TIME_ARRAY = 0._EB
         DV%TOTAL_FLOWRATE = DV%BYPASS_FLOWRATE
         DV%DT             = -1._EB
         DV%N_INPUTS = NNN
         NNN = 1
         DO NN=1,N_DEVC
            IF (DEVICE(NN)%DEVC_ID==DV%ID) THEN
               DV%TOTAL_FLOWRATE  = DV%TOTAL_FLOWRATE + DEVICE(NN)%FLOWRATE
               DV%DT = MAX(DV%DT,DEVICE(NN)%DELAY)
               IF (NN > N) THEN
                  WRITE(MESSAGE,'(A,A,A)')  &
                     'ERROR: ASPIRATION DEVICE ',TRIM(DV%ID),' is not listed after all its inputs'
                  CALL SHUTDOWN(MESSAGE)
               ENDIF
               DV%DEVC_INDEX(NNN)     = NN
               NNN = NNN + 1
            ENDIF
         ENDDO
         DV%DT = DV%DT * 0.01_EB

   END SELECT SPECIAL_QUANTITIES

   ! Set state variables

   DV%PRIOR_STATE      = DV%INITIAL_STATE
   DV%CURRENT_STATE    = DV%INITIAL_STATE

ENDDO PROC_DEVC_LOOP

END SUBROUTINE PROC_DEVC



SUBROUTINE READ_PROF
 
INTEGER :: N,NM,MESH_NUMBER,NN,N_PROFO,IOR
REAL(EB) :: XYZ(3)
CHARACTER(30) :: QUANTITY
TYPE (PROFILE_TYPE), POINTER :: PF
NAMELIST /PROF/ XYZ,QUANTITY,IOR,ID,FYI
 
N_PROF = 0
REWIND(LU_INPUT)
COUNT_PROF_LOOP: DO
   CALL CHECKREAD('PROF',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_PROF_LOOP
   READ(LU_INPUT,NML=PROF,END=11,ERR=12,IOSTAT=IOS)
   N_PROF = N_PROF + 1
   12 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I4)') 'ERROR: Problem with PROF no.',N_PROF+1
      CALL SHUTDOWN(MESSAGE)
   ENDIF
ENDDO COUNT_PROF_LOOP
11 REWIND(LU_INPUT)

IF (N_PROF==0) RETURN
 
ALLOCATE(PROFILE(N_PROF),STAT=IZERO)
CALL ChkMemErr('READ','PROFILE',IZERO)
 
PROFILE(1:N_PROF)%QUANTITY = 'TEMPERATURE'
PROFILE(1:N_PROF)%IOR   = 0
PROFILE(1:N_PROF)%IW    = 0
 
N_PROFO = N_PROF
N       = 0
 
PROF_LOOP: DO NN=1,N_PROFO
   N    = N+1
   IOR  = 0
   SELECT CASE(N)
      CASE(1:9)        
         WRITE(ID,'(A,I1)') 'PROFILE ',N
      CASE(10:99)      
         WRITE(ID,'(A,I2)') 'PROFILE ',N
      CASE(100:999)    
         WRITE(ID,'(A,I3)') 'PROFILE ',N
   END SELECT
 
   CALL CHECKREAD('PROF',LU_INPUT,IOS)
   IF (IOS==1) EXIT PROF_LOOP
   READ(LU_INPUT,PROF) 
 
! Check for bad PROF quantities or coordinates

   IF (IOR==0) THEN
      WRITE(MESSAGE,'(A,I4,A)') 'ERROR: Specify orientation of PROF ' ,NN,' using the parameter IOR'
      CALL SHUTDOWN(MESSAGE)
   ENDIF

   BAD = .FALSE.
 
   MESH_LOOP: DO NM=1,NMESHES
      IF (.NOT.EVACUATION_ONLY(NM)) THEN      
         M=>MESHES(NM)
         IF (XYZ(1)>=M%XS .AND. XYZ(1)<=M%XF .AND. XYZ(2)>=M%YS .AND. XYZ(2)<=M%YF .AND. XYZ(3)>=M%ZS .AND. XYZ(3)<=M%ZF) THEN
            MESH_NUMBER = NM
            EXIT MESH_LOOP
         ENDIF
      ENDIF
      IF (NM==NMESHES) BAD = .TRUE.
   ENDDO MESH_LOOP
 
   IF (BAD) THEN
      N      = N-1
      N_PROF = N_PROF-1
      CYCLE PROF_LOOP
   ENDIF
 
! Assign parameters to the PROFILE array
 
   PF => PROFILE(N)
   PF%ORDINAL = NN
   PF%MESH    = MESH_NUMBER
   PF%ID   = ID
   PF%QUANTITY = QUANTITY
   PF%X       = XYZ(1)
   PF%Y       = XYZ(2)
   PF%Z       = XYZ(3)
   PF%IOR     = IOR
 
ENDDO PROF_LOOP
REWIND(LU_INPUT)
 
END SUBROUTINE READ_PROF



SUBROUTINE READ_ISOF
 
REAL(EB) :: VALUE(10)
CHARACTER(30) :: QUANTITY,COLOR_QUANTITY
INTEGER :: REDUCE_TRIANGLES,N,ND
TYPE(ISOSURFACE_FILE_TYPE), POINTER :: IS
NAMELIST /ISOF/ QUANTITY,FYI,VALUE,REDUCE_TRIANGLES,COLOR_QUANTITY
 
N_ISOF = 0
REWIND(LU_INPUT)
COUNT_ISOF_LOOP: DO
   CALL CHECKREAD('ISOF',LU_INPUT,IOS) 
   IF (IOS==1) EXIT COUNT_ISOF_LOOP
   READ(LU_INPUT,NML=ISOF,END=9,ERR=10,IOSTAT=IOS)
   N_ISOF = N_ISOF + 1
   10 IF (IOS>0) THEN
      WRITE(MESSAGE,'(A,I2)') 'ERROR: Problem with ISOF no.',N_ISOF
      CALL SHUTDOWN(MESSAGE)
      ENDIF
ENDDO COUNT_ISOF_LOOP
9 REWIND(LU_INPUT)
 
ALLOCATE(ISOSURFACE_FILE(N_ISOF),STAT=IZERO)
CALL ChkMemErr('READ','ISOSURFACE_FILE',IZERO)

READ_ISOF_LOOP: DO N=1,N_ISOF
   IS => ISOSURFACE_FILE(N)
   QUANTITY         = 'nulliso'
   COLOR_QUANTITY   = 'nulliso'
   VALUE            = -999._EB
   REDUCE_TRIANGLES = 1
 
   CALL CHECKREAD('ISOF',LU_INPUT,IOS) 
   IF (IOS==1) EXIT READ_ISOF_LOOP
   READ(LU_INPUT,ISOF) 
 
   IS%REDUCE_TRIANGLES = REDUCE_TRIANGLES
   SUCCESS = .FALSE.
   SEARCH: DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
      IF (QUANTITY==OUTPUT_QUANTITY(ND)%NAME) THEN
         IF (.NOT.OUTPUT_QUANTITY(ND)%ISOF_APPROPRIATE) THEN
            WRITE(MESSAGE,'(3A)')  'ERROR: ISOF quantity ',TRIM(QUANTITY),' not appropriate for isosurface'
            CALL SHUTDOWN(MESSAGE)
         ENDIF
         IS%INDEX = ND
         VALUE_LOOP: DO I=1,10
            IF (VALUE(I)==-999._EB) EXIT VALUE_LOOP
            IS%N_VALUES = I
            IS%VALUE(I) = VALUE(I)
         ENDDO VALUE_LOOP
         SUCCESS = .TRUE.
         EXIT SEARCH
      ENDIF
   ENDDO SEARCH
   IF (.NOT.SUCCESS) THEN
      WRITE(MESSAGE,'(3A)')  'ERROR: ISOF quantity ',TRIM(QUANTITY),' not found'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   SEARCH2: DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
      IF (COLOR_QUANTITY==OUTPUT_QUANTITY(ND)%NAME) THEN
         IS%INDEX2 = ND
         EXIT SEARCH2
      ENDIF
   ENDDO SEARCH2
 
ENDDO READ_ISOF_LOOP
REWIND(LU_INPUT)
 
END SUBROUTINE READ_ISOF
 
 
SUBROUTINE READ_SLCF

REAL(EB) :: MAXIMUM_VALUE,MINIMUM_VALUE
INTEGER :: N,NN,NM,MESH_NUMBER,N_SLCF_O,NITER,ITER,ND
LOGICAL :: VECTOR,RLE,TWO_BYTE
CHARACTER(30) :: QUANTITY
TYPE (SLICE_TYPE), POINTER :: SL
NAMELIST /SLCF/ XB,QUANTITY,MB,FYI,PBX,PBY,PBZ,VECTOR,MESH_NUMBER,RLE,MAXIMUM_VALUE,MINIMUM_VALUE,TWO_BYTE

MESH_LOOP: DO NM=1,NMESHES

   M=>MESHES(NM)
   CALL POINT_TO_MESH(NM)

   N_SLCF   = 0
   N_SLCF_O = 0
   REWIND(LU_INPUT)
   COUNT_SLCF_LOOP: DO
      VECTOR  = .FALSE.
      MESH_NUMBER=NM
      CALL CHECKREAD('SLCF',LU_INPUT,IOS)
      IF (IOS==1) EXIT COUNT_SLCF_LOOP
      READ(LU_INPUT,NML=SLCF,END=9,ERR=10,IOSTAT=IOS)
      N_SLCF_O = N_SLCF_O + 1
      IF (MESH_NUMBER/=NM) CYCLE COUNT_SLCF_LOOP
      N_SLCF  = N_SLCF + 1
      IF (VECTOR .AND. TWO_D) N_SLCF = N_SLCF + 2
      IF (VECTOR .AND. .NOT. TWO_D) N_SLCF = N_SLCF + 3
      10 IF (IOS>0) THEN
         WRITE(MESSAGE,'(A,I3)') 'ERROR: Problem with SLCF no.',N_SLCF+1
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDDO COUNT_SLCF_LOOP
   9 CONTINUE   

   ALLOCATE(M%SLICE(N_SLCF),STAT=IZERO)
   CALL ChkMemErr('READ','ISP1',IZERO)
   CALL POINT_TO_MESH(NM)  ! Reset the pointers after the allocation

   N = 0

   REWIND(LU_INPUT)
   SLCF_LOOP: DO NN=1,N_SLCF_O
      QUANTITY = 'null'
      MB       = 'null'
      PBX      = -1.E6_EB
      PBY      = -1.E6_EB
      PBZ      = -1.E6_EB
      VECTOR   = .FALSE.
      MESH_NUMBER=NM
      RLE      = .FALSE.
      MINIMUM_VALUE = 0._EB
      MAXIMUM_VALUE = 0._EB
      TWO_BYTE = .FALSE.
 
      CALL CHECKREAD('SLCF',LU_INPUT,IOS)
      IF (IOS==1) EXIT SLCF_LOOP
      READ(LU_INPUT,SLCF) 
      IF (MESH_NUMBER/=NM) CYCLE SLCF_LOOP
 
      IF (PBX>-1.E5_EB .OR. PBY>-1.E5_EB .OR. PBZ>-1.E5_EB) THEN
         XB(1) = XS
         XB(2) = XF
         XB(3) = YS
         XB(4) = YF
         XB(5) = ZS
         XB(6) = ZF
         IF (PBX>-1.E5_EB) XB(1:2) = PBX
         IF (PBY>-1.E5_EB) XB(3:4) = PBY
         IF (PBZ>-1.E5_EB) XB(5:6) = PBZ
      ENDIF
 
      IF (MB/='null') THEN
         XB(1) = XS
         XB(2) = XF
         XB(3) = YS
         XB(4) = YF
         XB(5) = ZS
         XB(6) = ZF
         IF (MB=='XMIN') XB(2) = XS
         IF (MB=='XMAX') XB(1) = XF
         IF (MB=='YMIN') XB(4) = YS
         IF (MB=='YMAX') XB(3) = YF
         IF (MB=='ZMIN') XB(6) = ZS
         IF (MB=='ZMAX') XB(5) = ZF
      ENDIF
 
      XB(1) = MAX(XB(1),XS)
      XB(2) = MIN(XB(2),XF)
      XB(3) = MAX(XB(3),YS)
      XB(4) = MIN(XB(4),YF)
      XB(5) = MAX(XB(5),ZS)
      XB(6) = MIN(XB(6),ZF)
 
      ! Make sure the SLCF QUANTITY exists
 
      SUCCESS = .FALSE.
      SEARCH1: DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
         IF (QUANTITY==OUTPUT_QUANTITY(ND)%NAME) THEN
            SUCCESS = .TRUE.
            EXIT SEARCH1
         ENDIF
      ENDDO SEARCH1
      IF (.NOT.SUCCESS) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: SLCF quantity ',TRIM(QUANTITY),' not found'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      
      ! Throw out bad slices
 
      BAD = .FALSE.
      IF (      OUTPUT_QUANTITY(ND)%MIXTURE_FRACTION_ONLY .AND. .NOT.MIXTURE_FRACTION)  THEN
         BAD = .TRUE.
         WRITE(MESSAGE,'(3A)')  ' ERROR: The quantity ',TRIM(QUANTITY),' can only be used when the MIXTURE_FRACTION model is active'
      END IF
      IF (      OUTPUT_QUANTITY(ND)%PART_APPROPRIATE) THEN
         BAD = .TRUE.
         WRITE(MESSAGE,'(3A)')  ' ERROR: The PART quantity ',TRIM(QUANTITY),' is not appropriate for SLCF'
      ENDIF
      IF (.NOT. OUTPUT_QUANTITY(ND)%SLCF_APPROPRIATE) THEN
         BAD = .TRUE.
         WRITE(MESSAGE,'(3A)')  ' ERROR: The quantity ',TRIM(QUANTITY),' is not appropriate for SLCF'     
      ENDIF    
      IF (BAD) CALL SHUTDOWN(MESSAGE)
      
      ! Reject a slice if it is beyond the bounds of the current mesh
 
      IF (XB(1)>XF .OR. XB(2)<XS .OR. XB(3)>YF .OR. XB(4)<YS .OR. XB(5)>ZF .OR. XB(6)<ZS) THEN
         N_SLCF = N_SLCF - 1
         IF (VECTOR .AND. TWO_D) N_SLCF = N_SLCF - 2
         IF (VECTOR .AND. .NOT. TWO_D) N_SLCF = N_SLCF - 3
         CYCLE SLCF_LOOP
      ENDIF
 
      ! Process vector quantities
 
      NITER = 1
      IF (VECTOR .AND. TWO_D) NITER = 3
      IF (VECTOR .AND. .NOT. TWO_D)  NITER = 4
 
      VECTORLOOP: DO ITER=1,NITER
         N = N + 1
         SL=>SLICE(N)
         SL%TWO_BYTE = TWO_BYTE
         SL%I1 = NINT( GINV(XB(1)-XS,1,NM)*RDXI)
         SL%I2 = NINT( GINV(XB(2)-XS,1,NM)*RDXI)
         SL%J1 = NINT( GINV(XB(3)-YS,2,NM)*RDETA)
         SL%J2 = NINT( GINV(XB(4)-YS,2,NM)*RDETA)
         SL%K1 = NINT( GINV(XB(5)-ZS,3,NM)*RDZETA)
         SL%K2 = NINT( GINV(XB(6)-ZS,3,NM)*RDZETA)
         SL%RLE = RLE
         SL%MINMAX(1) = MINIMUM_VALUE
         SL%MINMAX(2) = MAXIMUM_VALUE
         IF (ITER==2)                    QUANTITY = 'U-VELOCITY' 
         IF (ITER==3 .AND. .NOT. TWO_D)  QUANTITY = 'V-VELOCITY' 
         IF (ITER==3 .AND. TWO_D)        QUANTITY = 'W-VELOCITY' 
         IF (ITER==4)                    QUANTITY = 'W-VELOCITY' 
         SEARCH: DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
            IF (QUANTITY==OUTPUT_QUANTITY(ND)%NAME) THEN
               SL%INDEX = ND
               EXIT SEARCH
            ENDIF
         ENDDO SEARCH
      ENDDO VECTORLOOP
  
   ENDDO SLCF_LOOP

   N_SLCF_MAX = MAX(N_SLCF_MAX,N_SLCF) 
 
ENDDO MESH_LOOP

END SUBROUTINE READ_SLCF


SUBROUTINE READ_BNDF

USE DEVICE_VARIABLES
INTEGER :: N,ND,NN
CHARACTER(30) :: QUANTITY,PROP_ID
LOGICAL :: SUCCESS
NAMELIST /BNDF/ QUANTITY,FYI,PROP_ID
TYPE(BOUNDARY_FILE_TYPE), POINTER :: BF
 
N_BNDF = 0
REWIND(LU_INPUT)
COUNT_BNDF_LOOP: DO
   CALL CHECKREAD('BNDF',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_BNDF_LOOP
   READ(LU_INPUT,NML=BNDF,END=209,ERR=210,IOSTAT=IOS)
   N_BNDF = N_BNDF + 1
   210 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with BNDF line')
ENDDO COUNT_BNDF_LOOP
209 REWIND(LU_INPUT)
 
ACCUMULATE_WATER = .FALSE.
 
ALLOCATE(BOUNDARY_FILE(N_BNDF),STAT=IZERO)
CALL ChkMemErr('READ','BOUNDARY_FILE',IZERO)
 
READ_BNDF_LOOP: DO N=1,N_BNDF
   BF => BOUNDARY_FILE(N)
   PROP_ID  = 'null'
   QUANTITY = 'WALL_TEMPERATURE'
   CALL CHECKREAD('BNDF',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_BNDF_LOOP
   READ(LU_INPUT,BNDF)
   
   ! Look to see if output QUANTITY exists
   
   SUCCESS = .FALSE.
   SEARCH: DO ND=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
      IF (QUANTITY==OUTPUT_QUANTITY(ND)%NAME) THEN
         BF%INDEX = ND
         IF (ND <=-70 .AND. ND >-80) ACCUMULATE_WATER = .TRUE.
         SUCCESS  = .TRUE.
         EXIT SEARCH
      ENDIF
   ENDDO SEARCH
   IF (.NOT.SUCCESS) THEN
      WRITE(MESSAGE,'(3A)')  'ERROR: BNDF QUANTITY, ',TRIM(QUANTITY),', not found'
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   
   ! Don't accept gas phase output QUANTITY
   
   IF (BF%INDEX>0 .OR. BF%INDEX==-6)  CALL SHUTDOWN('ERROR: BNDF QUANTITY not appropriate')
   
   ! Check to see if PROP_ID exists
   
   PROP_ID = PROP_ID
   BF%PROP_INDEX = 0
   IF (PROP_ID /= 'null') THEN
      SUCCESS = .FALSE.
      SEARCH2: DO NN=1,N_PROP
         IF (PROP_ID==PROPERTY(NN)%ID) THEN
            SUCCESS  = .TRUE.
            BF%PROP_INDEX = NN
            EXIT SEARCH2
         ENDIF
      ENDDO SEARCH2
      IF (.NOT.SUCCESS) THEN
         WRITE(MESSAGE,'(3A)')  ' ERROR: BNDF PROP_ID ',TRIM(PROP_ID),' not found'
         CALL SHUTDOWN(MESSAGE)
      ENDIF
   ENDIF
   
ENDDO READ_BNDF_LOOP
REWIND(LU_INPUT)
 
END SUBROUTINE READ_BNDF
 
 
SUBROUTINE FIXED_OUTPUT_QUANTITIES
 
! Define OUTPUT_QUANTITYs that have fixed names

INTEGER :: N

ALLOCATE(OUTPUT_QUANTITY(-N_OUTPUT_QUANTITIES:N_OUTPUT_QUANTITIES),STAT=IZERO)
CALL ChkMemErr('READ','OUTPUT_QUANTITY',IZERO) 

DO N=-N_OUTPUT_QUANTITIES,N_OUTPUT_QUANTITIES
   IF (N < 0) THEN
      OUTPUT_QUANTITY(N)%SOLID_PHASE = .TRUE.
      OUTPUT_QUANTITY(N)%ISOF_APPROPRIATE = .FALSE.
      OUTPUT_QUANTITY(N)%SLCF_APPROPRIATE = .FALSE.
   ENDIF
ENDDO
 
OUTPUT_QUANTITY(0)%NAME        = 'SMOKE/WATER'             
OUTPUT_QUANTITY(0)%UNITS       = '  '                      
OUTPUT_QUANTITY(0)%SHORT_NAME  = '  '

OUTPUT_QUANTITY(1)%NAME        = 'DENSITY'                 
OUTPUT_QUANTITY(1)%UNITS       = 'kg/m3'                   
OUTPUT_QUANTITY(1)%SHORT_NAME  = 'rho'

OUTPUT_QUANTITY(2)%NAME        = 'F_X'                     
OUTPUT_QUANTITY(2)%UNITS       = 'm/s2'                    
OUTPUT_QUANTITY(2)%SHORT_NAME  = 'f_x'
OUTPUT_QUANTITY(2)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(2)%IOR = 1

OUTPUT_QUANTITY(3)%NAME  = 'F_Y'                     
OUTPUT_QUANTITY(3)%UNITS  = 'm/s2'                    
OUTPUT_QUANTITY(3)%SHORT_NAME  = 'f_y'
OUTPUT_QUANTITY(3)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(3)%IOR = 2

OUTPUT_QUANTITY(4)%NAME  = 'F_Z'                     
OUTPUT_QUANTITY(4)%UNITS  = 'm/s2'                    
OUTPUT_QUANTITY(4)%SHORT_NAME  = 'f_z'
OUTPUT_QUANTITY(4)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(4)%IOR = 3

OUTPUT_QUANTITY(5)%NAME  = 'TEMPERATURE'             
OUTPUT_QUANTITY(5)%UNITS  = 'C'                       
OUTPUT_QUANTITY(5)%SHORT_NAME  = 'temp'

OUTPUT_QUANTITY(6)%NAME  = 'U-VELOCITY'              
OUTPUT_QUANTITY(6)%UNITS  = 'm/s'                    
OUTPUT_QUANTITY(6)%SHORT_NAME  = 'U-VEL'
OUTPUT_QUANTITY(6)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(6)%IOR = 1

OUTPUT_QUANTITY(7)%NAME  = 'V-VELOCITY'              
OUTPUT_QUANTITY(7)%UNITS = 'm/s'                     
OUTPUT_QUANTITY(7)%SHORT_NAME  = 'V-VEL'
OUTPUT_QUANTITY(7)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(7)%IOR = 2

OUTPUT_QUANTITY(8)%NAME  = 'W-VELOCITY'              
OUTPUT_QUANTITY(8)%UNITS  = 'm/s'                     
OUTPUT_QUANTITY(8)%SHORT_NAME  = 'W-VEL'
OUTPUT_QUANTITY(8)%CELL_POSITION = CELL_FACE
OUTPUT_QUANTITY(8)%IOR = 3

OUTPUT_QUANTITY(9)%NAME  = 'PRESSURE'                
OUTPUT_QUANTITY(9)%UNITS  = 'Pa'                      
OUTPUT_QUANTITY(9)%SHORT_NAME  = 'pres'

OUTPUT_QUANTITY(10)%NAME = 'VELOCITY'                
OUTPUT_QUANTITY(10)%UNITS = 'm/s'                     
OUTPUT_QUANTITY(10)%SHORT_NAME = 'vel'

OUTPUT_QUANTITY(11)%NAME = 'HRRPUV'                  
OUTPUT_QUANTITY(11)%UNITS = 'kW/m3'                   
OUTPUT_QUANTITY(11)%SHORT_NAME = 'hrrpuv'

OUTPUT_QUANTITY(12)%NAME = 'H'                       
OUTPUT_QUANTITY(12)%UNITS = '(m/s)^2'                 
OUTPUT_QUANTITY(12)%SHORT_NAME = 'head'

OUTPUT_QUANTITY(13)%NAME = 'MIXTURE_FRACTION'              
OUTPUT_QUANTITY(13)%UNITS = 'kg/kg'                     
OUTPUT_QUANTITY(13)%SHORT_NAME = 'Z'

OUTPUT_QUANTITY(14)%NAME = 'DIVERGENCE'              
OUTPUT_QUANTITY(14)%UNITS = '1/s'                     
OUTPUT_QUANTITY(14)%SHORT_NAME = 'div'

OUTPUT_QUANTITY(16)%NAME = 'ABSORPTION_COEFFICIENT'  
OUTPUT_QUANTITY(16)%UNITS = '1/m'                     
OUTPUT_QUANTITY(16)%SHORT_NAME = 'kappa'

OUTPUT_QUANTITY(17)%NAME = 'VISCOSITY'               
OUTPUT_QUANTITY(17)%UNITS = 'kg/m/s'                  
OUTPUT_QUANTITY(17)%SHORT_NAME = 'visc'
 
OUTPUT_QUANTITY(18)%NAME = 'RADIANT_INTENSITY'       
OUTPUT_QUANTITY(18)%UNITS = 'kW/m^2'                  
OUTPUT_QUANTITY(18)%SHORT_NAME = 'inten'

OUTPUT_QUANTITY(19)%NAME = 'RADIATION_LOSS'          
OUTPUT_QUANTITY(19)%UNITS = 'kW/m3'                   
OUTPUT_QUANTITY(19)%SHORT_NAME = 'loss'

OUTPUT_QUANTITY(20)%NAME = 'WATER_RADIATION_LOSS'    
OUTPUT_QUANTITY(20)%UNITS = 'kW/m3'                   
OUTPUT_QUANTITY(20)%SHORT_NAME = 'H2O_rad'

! Strain and Vorticity
 
OUTPUT_QUANTITY(24)%NAME = 'STRAIN_RATE_X'           
OUTPUT_QUANTITY(24)%UNITS = '1/s'                     
OUTPUT_QUANTITY(24)%SHORT_NAME = 'strain_x'

OUTPUT_QUANTITY(25)%NAME = 'STRAIN_RATE_Y'           
OUTPUT_QUANTITY(25)%UNITS = '1/s'                     
OUTPUT_QUANTITY(25)%SHORT_NAME = 'strain_y'

OUTPUT_QUANTITY(26)%NAME = 'STRAIN_RATE_Z'           
OUTPUT_QUANTITY(26)%UNITS = '1/s'                     
OUTPUT_QUANTITY(26)%SHORT_NAME = 'strain_z'

OUTPUT_QUANTITY(27)%NAME = 'VORTICITY_X'             
OUTPUT_QUANTITY(27)%UNITS = '1/s'                     
OUTPUT_QUANTITY(27)%SHORT_NAME = 'vort_x'  

OUTPUT_QUANTITY(28)%NAME = 'VORTICITY_Y'             
OUTPUT_QUANTITY(28)%UNITS = '1/s'                     
OUTPUT_QUANTITY(28)%SHORT_NAME = 'vort_y'  

OUTPUT_QUANTITY(29)%NAME = 'VORTICITY_Z'             
OUTPUT_QUANTITY(29)%UNITS = '1/s'                     
OUTPUT_QUANTITY(29)%SHORT_NAME = 'vort_z'  

OUTPUT_QUANTITY(24:29)%CELL_POSITION = CELL_EDGE

! Droplets

OUTPUT_QUANTITY(34)%NAME = 'DROPLET_DIAMETER'                     
OUTPUT_QUANTITY(34)%UNITS = 'mu-m'                       
OUTPUT_QUANTITY(34)%SHORT_NAME = 'diam'
 
OUTPUT_QUANTITY(35)%NAME = 'DROPLET_VELOCITY'                     
OUTPUT_QUANTITY(35)%UNITS = 'm/s'                       
OUTPUT_QUANTITY(35)%SHORT_NAME = 'vel'
 
OUTPUT_QUANTITY(36)%NAME = 'DROPLET_PHASE'                     
OUTPUT_QUANTITY(36)%UNITS = ' '                       
OUTPUT_QUANTITY(36)%SHORT_NAME = 'ior'
 
OUTPUT_QUANTITY(37)%NAME = 'DROPLET_TEMPERATURE'                     
OUTPUT_QUANTITY(37)%UNITS = 'C'                       
OUTPUT_QUANTITY(37)%SHORT_NAME = 'temp'
 
OUTPUT_QUANTITY(38)%NAME = 'DROPLET_MASS'                     
OUTPUT_QUANTITY(38)%UNITS = 'mu-g'                       
OUTPUT_QUANTITY(38)%SHORT_NAME = 'mass'
 
OUTPUT_QUANTITY(39)%NAME = 'DROPLET_AGE'                     
OUTPUT_QUANTITY(39)%UNITS = 's'                       
OUTPUT_QUANTITY(39)%SHORT_NAME = 'age'

OUTPUT_QUANTITY(34:39)%PART_APPROPRIATE = .TRUE.
 
! Mixture Fraction related variables
 
OUTPUT_QUANTITY(41)%NAME = 'fuel'                    
OUTPUT_QUANTITY(41)%UNITS = 'mol/mol'                 
OUTPUT_QUANTITY(41)%SHORT_NAME = 'X_f'

OUTPUT_QUANTITY(42)%NAME = 'oxygen'                  
OUTPUT_QUANTITY(42)%UNITS = 'mol/mol'                 
OUTPUT_QUANTITY(42)%SHORT_NAME = 'X_O2'

OUTPUT_QUANTITY(43)%NAME = 'nitrogen'                
OUTPUT_QUANTITY(43)%UNITS = 'mol/mol'                 
OUTPUT_QUANTITY(43)%SHORT_NAME = 'X_N2'

OUTPUT_QUANTITY(44)%NAME = 'water vapor'             
OUTPUT_QUANTITY(44)%UNITS = 'mol/mol'                 
OUTPUT_QUANTITY(44)%SHORT_NAME = 'X_H2O'

OUTPUT_QUANTITY(45)%NAME = 'carbon dioxide'          
OUTPUT_QUANTITY(45)%UNITS = 'mol/mol'                 
OUTPUT_QUANTITY(45)%SHORT_NAME = 'X_CO2'

OUTPUT_QUANTITY(46)%NAME = 'carbon monoxide'         
OUTPUT_QUANTITY(46)%UNITS = 'mol/mol'                     
OUTPUT_QUANTITY(46)%SHORT_NAME = 'X_CO'

OUTPUT_QUANTITY(47)%NAME = 'hydrogen'                
OUTPUT_QUANTITY(47)%UNITS = 'mol/mol'                     
OUTPUT_QUANTITY(47)%SHORT_NAME = 'X_H2'

OUTPUT_QUANTITY(48)%NAME = 'soot'    
OUTPUT_QUANTITY(48)%UNITS = 'mol/mol'                     
OUTPUT_QUANTITY(48)%SHORT_NAME = 'X_soot'

OUTPUT_QUANTITY(49)%NAME = 'other'    
OUTPUT_QUANTITY(49)%UNITS = 'mol/mol'                     
OUTPUT_QUANTITY(49)%SHORT_NAME = 'X_other'
OUTPUT_QUANTITY(41:49)%MIXTURE_FRACTION_ONLY = .TRUE.

! Species-specific quantities 51-100 are read in via a different subroutine
 
! Integrated Quantities
 
OUTPUT_QUANTITY(104)%NAME  = 'HRR'                   
OUTPUT_QUANTITY(104)%UNITS  = 'kW'                    
OUTPUT_QUANTITY(104)%SHORT_NAME  = 'hrr'
OUTPUT_QUANTITY(104)%INTEGRATED  = .TRUE.

OUTPUT_QUANTITY(105)%NAME  = 'LAYER HEIGHT'          
OUTPUT_QUANTITY(105)%UNITS  = 'm'                     
OUTPUT_QUANTITY(105)%SHORT_NAME  = 'layer'

OUTPUT_QUANTITY(106)%NAME  = 'UPPER TEMPERATURE'     
OUTPUT_QUANTITY(106)%UNITS  = 'C'                     
OUTPUT_QUANTITY(106)%SHORT_NAME  = 'u-tmp'

OUTPUT_QUANTITY(107)%NAME  = 'LOWER TEMPERATURE'     
OUTPUT_QUANTITY(107)%UNITS  = 'C'                     
OUTPUT_QUANTITY(107)%SHORT_NAME  = 'l-tmp'

OUTPUT_QUANTITY(108)%NAME  = 'UPPER KAPPA'           
OUTPUT_QUANTITY(108)%UNITS  = '1/m'                   
OUTPUT_QUANTITY(108)%SHORT_NAME  = 'u-kap'

OUTPUT_QUANTITY(104:108)%INTEGRATED = .TRUE.
OUTPUT_QUANTITY(104:108)%SLCF_APPROPRIATE = .FALSE.

! Model of a TC

OUTPUT_QUANTITY(110)%NAME  = 'THERMOCOUPLE'          
OUTPUT_QUANTITY(110)%UNITS = 'C'                     
OUTPUT_QUANTITY(110)%SHORT_NAME  = 'tc'
 
! Mass and Energy Flows

OUTPUT_QUANTITY(111)%NAME  = 'VOLUME FLOW'
OUTPUT_QUANTITY(111)%UNITS  = 'm3/s'
OUTPUT_QUANTITY(111)%SHORT_NAME  = 'vflow'

OUTPUT_QUANTITY(112)%NAME  = 'MASS FLOW'
OUTPUT_QUANTITY(112)%UNITS  = 'kg/s'
OUTPUT_QUANTITY(112)%SHORT_NAME  = 'mflow'

OUTPUT_QUANTITY(113)%NAME  = 'HEAT FLOW'
OUTPUT_QUANTITY(113)%UNITS = 'kW'
OUTPUT_QUANTITY(113)%SHORT_NAME  = 'hflow'

OUTPUT_QUANTITY(114)%NAME  = 'VOLUME FLOW +'         
OUTPUT_QUANTITY(114)%UNITS  = 'm3/s'                  
OUTPUT_QUANTITY(114)%SHORT_NAME  = 'vflow+'

OUTPUT_QUANTITY(115)%NAME  = 'MASS FLOW +'           
OUTPUT_QUANTITY(115)%UNITS  = 'kg/s'                  
OUTPUT_QUANTITY(115)%SHORT_NAME  = 'mflow+'

OUTPUT_QUANTITY(116)%NAME  = 'HEAT FLOW +'           
OUTPUT_QUANTITY(116)%UNITS  = 'kW'                    
OUTPUT_QUANTITY(116)%SHORT_NAME  = 'hflow+'

OUTPUT_QUANTITY(117)%NAME  = 'VOLUME FLOW -'         
OUTPUT_QUANTITY(117)%UNITS  = 'm3/s'                  
OUTPUT_QUANTITY(117)%SHORT_NAME  = 'vflow-'

OUTPUT_QUANTITY(118)%NAME  = 'MASS FLOW -'           
OUTPUT_QUANTITY(118)%UNITS  = 'kg/s'                  
OUTPUT_QUANTITY(118)%SHORT_NAME  = 'mflow-'

OUTPUT_QUANTITY(119)%NAME  = 'HEAT FLOW -'           
OUTPUT_QUANTITY(119)%UNITS  = 'kW'                    
OUTPUT_QUANTITY(119)%SHORT_NAME  = 'hflow-'

OUTPUT_QUANTITY(111:119)%INTEGRATED = .TRUE.
OUTPUT_QUANTITY(111:119)%SLCF_APPROPRIATE = .FALSE.

! Mixture Fraction mass fractions 
 
OUTPUT_QUANTITY(141)%NAME = 'fuel mass fraction'     
OUTPUT_QUANTITY(141)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(141)%SHORT_NAME = 'Y_f'

OUTPUT_QUANTITY(142)%NAME = 'oxygen mass fraction'   
OUTPUT_QUANTITY(142)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(142)%SHORT_NAME = 'Y_O2'

OUTPUT_QUANTITY(143)%NAME = 'nitrogen mass fraction' 
OUTPUT_QUANTITY(143)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(143)%SHORT_NAME = 'Y_N2'

OUTPUT_QUANTITY(144)%NAME = 'water vapor mass fraction' 
OUTPUT_QUANTITY(144)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(144)%SHORT_NAME = 'Y_H2O'

OUTPUT_QUANTITY(145)%NAME = 'carbon dioxide mass fraction'  
OUTPUT_QUANTITY(145)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(145)%SHORT_NAME = 'Y_CO2'

OUTPUT_QUANTITY(146)%NAME = 'carbon monoxide mass fraction' 
OUTPUT_QUANTITY(146)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(146)%SHORT_NAME = 'Y_CO'

OUTPUT_QUANTITY(147)%NAME = 'hydrogen mass fraction'        
OUTPUT_QUANTITY(147)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(147)%SHORT_NAME = 'Y_H2'

OUTPUT_QUANTITY(148)%NAME = 'soot mass fraction'            
OUTPUT_QUANTITY(148)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(148)%SHORT_NAME = 'Y_soot'

OUTPUT_QUANTITY(149)%NAME = 'other mass fraction'            
OUTPUT_QUANTITY(149)%UNITS = 'kg/kg'                  
OUTPUT_QUANTITY(149)%SHORT_NAME = 'Y_other' 

OUTPUT_QUANTITY(141:149)%MIXTURE_FRACTION_ONLY = .TRUE.
 
! Soot and related outputs

OUTPUT_QUANTITY(151)%NAME = 'soot density'
OUTPUT_QUANTITY(151)%UNITS = 'mg/m3'
OUTPUT_QUANTITY(151)%SHORT_NAME = 'soot'

OUTPUT_QUANTITY(152)%NAME = 'soot volume fraction'
OUTPUT_QUANTITY(152)%UNITS = ' '
OUTPUT_QUANTITY(152)%SHORT_NAME = 'f_v'

OUTPUT_QUANTITY(153)%NAME = 'extinction coefficient'
OUTPUT_QUANTITY(153)%UNITS = '1/m'
OUTPUT_QUANTITY(153)%SHORT_NAME = 'ext'

OUTPUT_QUANTITY(154)%NAME = 'visibility'
OUTPUT_QUANTITY(154)%UNITS = 'm'
OUTPUT_QUANTITY(154)%SHORT_NAME = 'vis'

OUTPUT_QUANTITY(151:154)%MIXTURE_FRACTION_ONLY = .TRUE.

! Sprinklers and Detectors

OUTPUT_QUANTITY(155)%NAME = 'path obscuration'
OUTPUT_QUANTITY(155)%UNITS = '%'
OUTPUT_QUANTITY(155)%SHORT_NAME = 'total obs'
OUTPUT_QUANTITY(155)%MIXTURE_FRACTION_ONLY = .TRUE.
OUTPUT_QUANTITY(155)%INTEGRATED = .TRUE.
OUTPUT_QUANTITY(155)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(156)%NAME = 'SPRINKLER LINK TEMPERATURE'
OUTPUT_QUANTITY(156)%UNITS = 'C'
OUTPUT_QUANTITY(156)%SHORT_NAME = 'link'
OUTPUT_QUANTITY(156)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(157)%NAME = 'LINK TEMPERATURE'
OUTPUT_QUANTITY(157)%UNITS = 'C'
OUTPUT_QUANTITY(157)%SHORT_NAME = 'link'
OUTPUT_QUANTITY(157)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(158)%NAME = 'spot obscuration'
OUTPUT_QUANTITY(158)%UNITS = '%/m'
OUTPUT_QUANTITY(158)%SHORT_NAME = 'obs'
OUTPUT_QUANTITY(158)%MIXTURE_FRACTION_ONLY = .TRUE.
OUTPUT_QUANTITY(158)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(159)%NAME = 'TIME'
OUTPUT_QUANTITY(159)%UNITS = 's'
OUTPUT_QUANTITY(159)%SHORT_NAME = 'time'
OUTPUT_QUANTITY(159)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(160)%NAME = 'CONTROL'
OUTPUT_QUANTITY(160)%UNITS = ' '
OUTPUT_QUANTITY(160)%SHORT_NAME = 'output'
OUTPUT_QUANTITY(160)%SLCF_APPROPRIATE = .FALSE.

OUTPUT_QUANTITY(161)%NAME = 'aspiration'
OUTPUT_QUANTITY(161)%UNITS = '%/m'
OUTPUT_QUANTITY(161)%SHORT_NAME = 'obs'
OUTPUT_QUANTITY(161)%MIXTURE_FRACTION_ONLY = .TRUE.
OUTPUT_QUANTITY(161)%SLCF_APPROPRIATE = .FALSE.

!Quantities 170 - 250 generated for droplet classes in another routine

! Boundary Quantities
 
OUTPUT_QUANTITY(-1)%NAME = 'RADIATIVE_FLUX'          
OUTPUT_QUANTITY(-1)%UNITS = 'kW/m2'                   
OUTPUT_QUANTITY(-1)%SHORT_NAME = 'rad'

OUTPUT_QUANTITY(-2)%NAME = 'CONVECTIVE_FLUX'         
OUTPUT_QUANTITY(-2)%UNITS = 'kW/m2'                   
OUTPUT_QUANTITY(-2)%SHORT_NAME = 'con'

OUTPUT_QUANTITY(-3)%NAME = 'NORMAL_VELOCITY'         
OUTPUT_QUANTITY(-3)%UNITS = 'm/s'                     
OUTPUT_QUANTITY(-3)%SHORT_NAME = 'vel'

OUTPUT_QUANTITY(-4)%NAME = 'GAS_TEMPERATURE'         
OUTPUT_QUANTITY(-4)%UNITS = 'C'                       
OUTPUT_QUANTITY(-4)%SHORT_NAME = 'temp'

OUTPUT_QUANTITY(-5)%NAME = 'WALL_TEMPERATURE'        
OUTPUT_QUANTITY(-5)%UNITS = 'C'                       
OUTPUT_QUANTITY(-5)%SHORT_NAME = 'temp'

OUTPUT_QUANTITY(-6)%NAME = 'INSIDE_WALL_TEMPERATURE' 
OUTPUT_QUANTITY(-6)%UNITS = 'C'                       
OUTPUT_QUANTITY(-6)%SHORT_NAME = 'inside'

OUTPUT_QUANTITY(-7)%NAME = 'BURNING_RATE'            
OUTPUT_QUANTITY(-7)%UNITS = 'kg/m2/s'                 
OUTPUT_QUANTITY(-7)%SHORT_NAME = 'burn'

OUTPUT_QUANTITY(-10)%NAME= 'HEAT_FLUX'               
OUTPUT_QUANTITY(-10)%UNITS= 'kW/m2'                   
OUTPUT_QUANTITY(-10)%SHORT_NAME= 'heat'

OUTPUT_QUANTITY(-11)%NAME= 'PRESSURE_COEFFICIENT'    
OUTPUT_QUANTITY(-11)%UNITS= ' '                       
OUTPUT_QUANTITY(-11)%SHORT_NAME= 'c_p'

OUTPUT_QUANTITY(-12)%NAME= 'BACK_WALL_TEMPERATURE'   
OUTPUT_QUANTITY(-12)%UNITS= 'C'                       
OUTPUT_QUANTITY(-12)%SHORT_NAME= 'back'

OUTPUT_QUANTITY(-13)%NAME= 'GAUGE_HEAT_FLUX'         
OUTPUT_QUANTITY(-13)%UNITS= 'kW/m2'                   
OUTPUT_QUANTITY(-13)%SHORT_NAME= 'gauge'

OUTPUT_QUANTITY(-16)%NAME= 'MASS_LOSS'               
OUTPUT_QUANTITY(-16)%UNITS= 'kg/m2'                   
OUTPUT_QUANTITY(-16)%SHORT_NAME= 'mloss'

OUTPUT_QUANTITY(-19)%NAME= 'INCIDENT_HEAT_FLUX'      
OUTPUT_QUANTITY(-19)%UNITS= 'kW/m2'                   
OUTPUT_QUANTITY(-19)%SHORT_NAME= 'in_flux'
 
OUTPUT_QUANTITY(-30)%NAME= 'HEAT_TRANSFER_COEFFICIENT'    
OUTPUT_QUANTITY(-30)%UNITS= 'W/m2/K'                  
OUTPUT_QUANTITY(-30)%SHORT_NAME= 'h'

OUTPUT_QUANTITY(-31)%NAME= 'RADIOMETER'    
OUTPUT_QUANTITY(-31)%UNITS= 'kW/m2'                  
OUTPUT_QUANTITY(-31)%SHORT_NAME= 'radio'

OUTPUT_QUANTITY(-32)%NAME= 'ADIABATIC_SURFACE_TEMPERATURE'    
OUTPUT_QUANTITY(-32)%UNITS= 'C'                  
OUTPUT_QUANTITY(-32)%SHORT_NAME= 'AST'

OUTPUT_QUANTITY(-33)%NAME= 'WALL_THICKNESS'    
OUTPUT_QUANTITY(-33)%UNITS= 'm'      
OUTPUT_QUANTITY(-33)%SHORT_NAME= 'thick'

!-50 through -70 in PARTICLE_OUTPUT_QUANTITIES

END SUBROUTINE FIXED_OUTPUT_QUANTITIES

 

SUBROUTINE SPECIES_OUTPUT_QUANTITIES
INTEGER :: N

! Gas Phase Output

SPECIES_LOOP: DO N=1,MIN(N_SPECIES,10)

   ! Species Mass Fractions

   OUTPUT_QUANTITY(50+N)%NAME=TRIM(SPECIES(N)%NAME)
   OUTPUT_QUANTITY(50+N)%UNITS='kg/kg'
   WRITE(OUTPUT_QUANTITY(50+N)%SHORT_NAME,'(A,I2.2)') 'spec_',N

   ! Species Fluxes in the x-direction

   OUTPUT_QUANTITY(60+N)%NAME = TRIM(SPECIES(N)%NAME)//'_FLUX_X'
   OUTPUT_QUANTITY(60+N)%UNITS = 'kg/s/m2'
   WRITE(OUTPUT_QUANTITY(60+N)%SHORT_NAME,'(A,I2.2)') 'u*rho*',N
   OUTPUT_QUANTITY(60+N)%CELL_POSITION = CELL_FACE

   ! Species Fluxes in the y-direction

   OUTPUT_QUANTITY(70+N)%NAME = TRIM(SPECIES(N)%NAME)//'_FLUX_Y'
   OUTPUT_QUANTITY(70+N)%UNITS = 'kg/s/m2'
   WRITE(OUTPUT_QUANTITY(70+N)%SHORT_NAME,'(A,I2.2)') 'v*rho*',N
   OUTPUT_QUANTITY(70+N)%CELL_POSITION = CELL_FACE

   ! Species Fluxes in the z-direction

   OUTPUT_QUANTITY(80+N)%NAME = TRIM(SPECIES(N)%NAME)//'_FLUX_Z'
   OUTPUT_QUANTITY(80+N)%UNITS = 'kg/s/m2'
   WRITE(OUTPUT_QUANTITY(80+N)%SHORT_NAME,'(A,I2.2)') 'w*rho*',N
   OUTPUT_QUANTITY(80+N)%CELL_POSITION = CELL_FACE

   ! Species Volume Fractions

   OUTPUT_QUANTITY(90+N)%NAME = TRIM(SPECIES(N)%NAME)//'_VF'
   OUTPUT_QUANTITY(90+N)%UNITS = '  '
   WRITE(OUTPUT_QUANTITY(90+N)%SHORT_NAME,'(A,I2.2,A)') 'spec_',N,'_vf'

ENDDO SPECIES_LOOP

! Solid Phase Output

DO N=1,MIN(N_SPECIES,10)
   OUTPUT_QUANTITY(-20-N)%NAME = TRIM(SPECIES(N)%NAME)//'_FLUX'   
   OUTPUT_QUANTITY(-20-N)%UNITS= 'kg/s/m2'                 
   WRITE(OUTPUT_QUANTITY(-20-N)%SHORT_NAME,'(A,I2.2,A)') 'spec_',N,'_flux'
ENDDO

END SUBROUTINE SPECIES_OUTPUT_QUANTITIES
 


SUBROUTINE PARTICLE_OUTPUT_QUANTITIES
INTEGER :: N,K

DO N = 1, N_EVAP_INDICIES

   DO K = 1, N_PART
      IF (PARTICLE_CLASS(K)%EVAP_INDEX==N) ID = PARTICLE_CLASS(K)%CLASS_NAME
   ENDDO

   ! Gas Phase Droplet Output

   OUTPUT_QUANTITY(170+N)%NAME = TRIM(ID)//'_MPUV'                   
   OUTPUT_QUANTITY(170+N)%UNITS = 'kg/m3'                   
   OUTPUT_QUANTITY(170+N)%SHORT_NAME = 'mpuv'

   OUTPUT_QUANTITY(180+N)%NAME = TRIM(ID)//'_ADD'                   
   OUTPUT_QUANTITY(180+N)%UNITS = 'mu-m'                   
   OUTPUT_QUANTITY(180+N)%SHORT_NAME = 'radii'

   OUTPUT_QUANTITY(190+N)%NAME = TRIM(ID)//'_ADT'                   
   OUTPUT_QUANTITY(190+N)%UNITS = 'C'                   
   OUTPUT_QUANTITY(190+N)%SHORT_NAME = 'temp'

   OUTPUT_QUANTITY(200+N)%NAME = TRIM(ID)//'_FLUX_X'
   OUTPUT_QUANTITY(200+N)%UNITS = 'kg/s/m2'
   OUTPUT_QUANTITY(200+N)%SHORT_NAME = 'flux_x'

   OUTPUT_QUANTITY(210+N)%NAME = TRIM(ID)//'_FLUX_Y'
   OUTPUT_QUANTITY(210+N)%UNITS = 'kg/s/m2'
   OUTPUT_QUANTITY(210+N)%SHORT_NAME = 'flux_y'

   OUTPUT_QUANTITY(220+N)%NAME = TRIM(ID)//'_FLUX_Z'
   OUTPUT_QUANTITY(220+N)%UNITS = 'kg/s/m2'
   OUTPUT_QUANTITY(220+N)%SHORT_NAME = 'flux_z'

   OUTPUT_QUANTITY(201:229)%ISOF_APPROPRIATE = .FALSE.
   OUTPUT_QUANTITY(201:229)%INTEGRATED_DROPLETS = .TRUE.

   ! Solid Phase Particle Outputs

   OUTPUT_QUANTITY(-50-N)%NAME = TRIM(ID)//'_MPUA'                   
   OUTPUT_QUANTITY(-50-N)%UNITS = 'kg/m2'                   
   OUTPUT_QUANTITY(-50-N)%SHORT_NAME = 'mpua'

   OUTPUT_QUANTITY(-60-N)%NAME = TRIM(ID)//'_CPUA'                   
   OUTPUT_QUANTITY(-60-N)%UNITS = 'kW/m2'                   
   OUTPUT_QUANTITY(-60-N)%SHORT_NAME = 'cpua' 

   OUTPUT_QUANTITY(-70-N)%NAME = TRIM(ID)//'_AMPUA'                  
   OUTPUT_QUANTITY(-70-N)%UNITS= 'kg/m2'                   
   OUTPUT_QUANTITY(-70-N)%SHORT_NAME = 'ampua'

END DO 
 
END SUBROUTINE PARTICLE_OUTPUT_QUANTITIES

SUBROUTINE SET_QUANTITIES_AMBIENT
 
! Define OUTPUT_QUANTITYs that have fixed names

OUTPUT_QUANTITY(1)%AMBIENT_VALUE = RHOA
OUTPUT_QUANTITY(5)%AMBIENT_VALUE = TMPA-TMPM
OUTPUT_QUANTITY(110)%AMBIENT_VALUE = TMPA-TMPM
OUTPUT_QUANTITY(-6)%AMBIENT_VALUE = TMPA-TMPM
OUTPUT_QUANTITY(-12)%AMBIENT_VALUE = TMPA-TMPM
OUTPUT_QUANTITY(-32)%AMBIENT_VALUE = TMPA-TMPM

END SUBROUTINE SET_QUANTITIES_AMBIENT


SUBROUTINE SEARCH_KEYWORD(NAME,LU,IOS)
 
INTEGER, INTENT(OUT) :: IOS
INTEGER, INTENT(IN)  :: LU
CHARACTER(*), INTENT(IN) :: NAME
CHARACTER(40) :: TEXT
 
IF (LU<0) THEN
   IOS = -1
   RETURN
ENDIF
 
IOS = 1
REWIND(LU)
READLOOP: DO
   READ(LU,'(A)',END=10) TEXT
   IF (TRIM(TEXT)==TRIM(NAME)) THEN
      IOS = 0
      RETURN
   ELSE
      CYCLE READLOOP
   ENDIF
ENDDO READLOOP
 
10 RETURN
END SUBROUTINE SEARCH_KEYWORD


SUBROUTINE CHECK_SURF_NAME(NAME,EXISTS)

LOGICAL, INTENT(OUT) :: EXISTS
CHARACTER(*), INTENT(IN) :: NAME
INTEGER :: NS

EXISTS = .FALSE.
DO NS=0,N_SURF
   IF (NAME==SURF_NAME(NS)) EXISTS = .TRUE.
ENDDO

END SUBROUTINE CHECK_SURF_NAME


SUBROUTINE SEARCH_CONTROLLER(NAME,CTRL_ID,DEVC_ID,DEVICE_INDEX,CONTROL_INDEX,INPUT_INDEX)

USE DEVICE_VARIABLES, ONLY: DEVICE,N_DEVC
USE CONTROL_VARIABLES, ONLY: CONTROL,N_CTRL
CHARACTER(*), INTENT (IN) :: NAME,CTRL_ID,DEVC_ID
INTEGER :: I, DEVICE_INDEX,CONTROL_INDEX
INTEGER , INTENT(IN) :: INPUT_INDEX
 
! There cannot be both a device and controller for any given entity

IF (DEVC_ID /= 'null' .AND. CTRL_ID /='null') THEN
   WRITE(MESSAGE,'(A,A,1X,I3,A)')  'ERROR: ',TRIM(NAME),INPUT_INDEX,' has both a device (DEVC) and a control (CTRL) specified'
   CALL SHUTDOWN(MESSAGE)
ENDIF

! Search for device

IF (DEVC_ID /= 'null') THEN
   DO I=1,N_DEVC
      IF (DEVICE(I)%ID==DEVC_ID) THEN
         DEVICE_INDEX = I
         RETURN
      ENDIF
   ENDDO
   WRITE(MESSAGE,'(A,A,A)')  'ERROR: DEVICE ',TRIM(DEVC_ID),' does not exist'
   CALL SHUTDOWN(MESSAGE)
ENDIF

! Search for controller

IF (CTRL_ID /= 'null') THEN
   DO I=1,N_CTRL
      IF (CONTROL(I)%ID==CTRL_ID) THEN
         CONTROL_INDEX = I
         RETURN
      ENDIF
   ENDDO
   WRITE(MESSAGE,'(A,A,A)')  'ERROR: CONTROL ',TRIM(CTRL_ID),' does not exist'
   CALL SHUTDOWN(MESSAGE)
ENDIF

END SUBROUTINE SEARCH_CONTROLLER

 

SUBROUTINE COLOR2RGB(RGB,COLOR)
!Translate character string of a color name to RGB value
INTEGER :: RGB(3)
CHARACTER(25) :: COLOR

SELECT CASE(COLOR)
CASE ('ALICE BLUE');RGB = (/240,248,255/)
CASE ('ANTIQUE WHITE');RGB = (/250,235,215/)
CASE ('ANTIQUE WHITE 1');RGB = (/255,239,219/)
CASE ('ANTIQUE WHITE 2');RGB = (/238,223,204/)
CASE ('ANTIQUE WHITE 3');RGB = (/205,192,176/)
CASE ('ANTIQUE WHITE 4');RGB = (/139,131,120/)
CASE ('AQUAMARINE');RGB = (/127,255,212/)
CASE ('AQUAMARINE 1');RGB = (/118,238,198/)
CASE ('AQUAMARINE 2');RGB = (/102,205,170/)
CASE ('AQUAMARINE 3');RGB = (/69,139,116/)
CASE ('AZURE');RGB = (/240,255,255/)
CASE ('AZURE 1');RGB = (/224,238,238/)
CASE ('AZURE 2');RGB = (/193,205,205/)
CASE ('AZURE 3');RGB = (/131,139,139/)
CASE ('BANANA');RGB = (/227,207,87/)
CASE ('BEIGE');RGB = (/245,245,220/)
CASE ('BISQUE');RGB = (/255,228,196/)
CASE ('BISQUE 1');RGB = (/238,213,183/)
CASE ('BISQUE 2');RGB = (/205,183,158/)
CASE ('BISQUE 3');RGB = (/139,125,107/)
CASE ('BLACK');RGB = (/0,0,0/)
CASE ('BLANCHED ALMOND');RGB = (/255,235,205/)
CASE ('BLUE');RGB = (/0,0,255/)
CASE ('BLUE 2');RGB = (/0,0,238/)
CASE ('BLUE 3');RGB = (/0,0,205/)
CASE ('BLUE 4');RGB = (/0,0,139/)
CASE ('BLUE VIOLET');RGB = (/138,43,226/)
CASE ('BRICK');RGB = (/156,102,31/)
CASE ('BROWN');RGB = (/165,42,42/)
CASE ('BROWN 1');RGB = (/255,64,64/)
CASE ('BROWN 2');RGB = (/238,59,59/)
CASE ('BROWN 3');RGB = (/205,51,51/)
CASE ('BROWN 4');RGB = (/139,35,35/)
CASE ('BURLY WOOD');RGB = (/222,184,135/)
CASE ('BURLY WOOD 1');RGB = (/255,211,155/)
CASE ('BURLY WOOD 2');RGB = (/238,197,145/)
CASE ('BURLY WOOD 3');RGB = (/205,170,125/)
CASE ('BURLY WOOD 4');RGB = (/139,115,85/)
CASE ('BURNT SIENNA');RGB = (/138,54,15/)
CASE ('BURNT UMBER');RGB = (/138,51,36/)
CASE ('CADET BLUE');RGB = (/95,158,160/)
CASE ('CADET BLUE 1');RGB = (/152,245,255/)
CASE ('CADET BLUE 2');RGB = (/142,229,238/)
CASE ('CADET BLUE 3');RGB = (/122,197,205/)
CASE ('CADET BLUE 4');RGB = (/83,134,139/)
CASE ('CADMIUM ORANGE');RGB = (/255,97,3/)
CASE ('CADMIUM YELLOW');RGB = (/255,153,18/)
CASE ('CARROT');RGB = (/237,145,33/)
CASE ('CHARTREUSE');RGB = (/127,255,0/)
CASE ('CHARTREUSE 1');RGB = (/118,238,0/)
CASE ('CHARTREUSE 2');RGB = (/102,205,0/)
CASE ('CHARTREUSE 3');RGB = (/69,139,0/)
CASE ('CHOCOLATE');RGB = (/210,105,30/)
CASE ('CHOCOLATE 1');RGB = (/255,127,36/)
CASE ('CHOCOLATE 2');RGB = (/238,118,33/)
CASE ('CHOCOLATE 3');RGB = (/205,102,29/)
CASE ('CHOCOLATE 4');RGB = (/139,69,19/)
CASE ('COBALT');RGB = (/61,89,171/)
CASE ('COBALT GREEN');RGB = (/61,145,64/)
CASE ('COLD GREY');RGB = (/128,138,135/)
CASE ('CORAL');RGB = (/255,127,80/)
CASE ('CORAL 1');RGB = (/255,114,86/)
CASE ('CORAL 2');RGB = (/238,106,80/)
CASE ('CORAL 3');RGB = (/205,91,69/)
CASE ('CORAL 4');RGB = (/139,62,47/)
CASE ('CORNFLOWER BLUE');RGB = (/100,149,237/)
CASE ('CORNSILK');RGB = (/255,248,220/)
CASE ('CORNSILK 1');RGB = (/238,232,205/)
CASE ('CORNSILK 2');RGB = (/205,200,177/)
CASE ('CORNSILK 3');RGB = (/139,136,120/)
CASE ('CRIMSON');RGB = (/220,20,60/)
CASE ('CYAN');RGB = (/0,255,255/)
CASE ('CYAN 2');RGB = (/0,238,238/)
CASE ('CYAN 3');RGB = (/0,205,205/)
CASE ('CYAN 4');RGB = (/0,139,139/)
CASE ('DARK GOLDENROD');RGB = (/184,134,11/)
CASE ('DARK GOLDENROD 1');RGB = (/255,185,15/)
CASE ('DARK GOLDENROD 2');RGB = (/238,173,14/)
CASE ('DARK GOLDENROD 3');RGB = (/205,149,12/)
CASE ('DARK GOLDENROD 4');RGB = (/139,101,8/)
CASE ('DARK GRAY');RGB = (/169,169,169/)
CASE ('DARK GREEN');RGB = (/0,100,0/)
CASE ('DARK KHAKI');RGB = (/189,183,107/)
CASE ('DARK OLIVE GREEN');RGB = (/85,107,47/)
CASE ('DARK OLIVE GREEN 1');RGB = (/202,255,112/)
CASE ('DARK OLIVE GREEN 2');RGB = (/188,238,104/)
CASE ('DARK OLIVE GREEN 3');RGB = (/162,205,90/)
CASE ('DARK OLIVE GREEN 4');RGB = (/110,139,61/)
CASE ('DARK ORANGE');RGB = (/255,140,0/)
CASE ('DARK ORANGE 1');RGB = (/255,127,0/)
CASE ('DARK ORANGE 2');RGB = (/238,118,0/)
CASE ('DARK ORANGE 3');RGB = (/205,102,0/)
CASE ('DARK ORANGE 4');RGB = (/139,69,0/)
CASE ('DARK ORCHID');RGB = (/153,50,204/)
CASE ('DARK ORCHID 1');RGB = (/191,62,255/)
CASE ('DARK ORCHID 2');RGB = (/178,58,238/)
CASE ('DARK ORCHID 3');RGB = (/154,50,205/)
CASE ('DARK ORCHID 4');RGB = (/104,34,139/)
CASE ('DARK SALMON');RGB = (/233,150,122/)
CASE ('DARK SEA GREEN');RGB = (/143,188,143/)
CASE ('DARK SEA GREEN 1');RGB = (/193,255,193/)
CASE ('DARK SEA GREEN 2');RGB = (/180,238,180/)
CASE ('DARK SEA GREEN 3');RGB = (/155,205,155/)
CASE ('DARK SEA GREEN 4');RGB = (/105,139,105/)
CASE ('DARK SLATE BLUE');RGB = (/72,61,139/)
CASE ('DARK SLATE GRAY');RGB = (/47,79,79/)
CASE ('DARK SLATE GRAY 1');RGB = (/151,255,255/)
CASE ('DARK SLATE GRAY 2');RGB = (/141,238,238/)
CASE ('DARK SLATE GRAY 3');RGB = (/121,205,205/)
CASE ('DARK SLATE GRAY 4');RGB = (/82,139,139/)
CASE ('DARK TURQUOISE');RGB = (/0,206,209/)
CASE ('DARK VIOLET');RGB = (/148,0,211/)
CASE ('DEEP PINK');RGB = (/255,20,147/)
CASE ('DEEP PINK 1');RGB = (/238,18,137/)
CASE ('DEEP PINK 2');RGB = (/205,16,118/)
CASE ('DEEP PINK 3');RGB = (/139,10,80/)
CASE ('DEEP SKYBLUE');RGB = (/0,191,255/)
CASE ('DEEP SKYBLUE 1');RGB = (/0,178,238/)
CASE ('DEEP SKYBLUE 2');RGB = (/0,154,205/)
CASE ('DEEP SKYBLUE 3');RGB = (/0,104,139/)
CASE ('DIM GRAY');RGB = (/105,105,105/)
CASE ('DODGERBLUE');RGB = (/30,144,255/)
CASE ('DODGERBLUE 1');RGB = (/28,134,238/)
CASE ('DODGERBLUE 2');RGB = (/24,116,205/)
CASE ('DODGERBLUE 3');RGB = (/16,78,139/)
CASE ('EGGSHELL');RGB = (/252,230,201/)
CASE ('EMERALD GREEN');RGB = (/0,201,87/)
CASE ('FIREBRICK');RGB = (/178,34,34/)
CASE ('FIREBRICK 1');RGB = (/255,48,48/)
CASE ('FIREBRICK 2');RGB = (/238,44,44/)
CASE ('FIREBRICK 3');RGB = (/205,38,38/)
CASE ('FIREBRICK 4');RGB = (/139,26,26/)
CASE ('FLESH');RGB = (/255,125,64/)
CASE ('FLORAL WHITE');RGB = (/255,250,240/)
CASE ('FOREST GREEN');RGB = (/34,139,34/)
CASE ('GAINSBORO');RGB = (/220,220,220/)
CASE ('GHOST WHITE');RGB = (/248,248,255/)
CASE ('GOLD');RGB = (/255,215,0/)
CASE ('GOLD 1');RGB = (/238,201,0/)
CASE ('GOLD 2');RGB = (/205,173,0/)
CASE ('GOLD 3');RGB = (/139,117,0/)
CASE ('GOLDENROD');RGB = (/218,165,32/)
CASE ('GOLDENROD 1');RGB = (/255,193,37/)
CASE ('GOLDENROD 2');RGB = (/238,180,34/)
CASE ('GOLDENROD 3');RGB = (/205,155,29/)
CASE ('GOLDENROD 4');RGB = (/139,105,20/)
CASE ('GRAY');RGB = (/128,128,128/)
CASE ('GRAY 1');RGB = (/3,3,3/)
CASE ('GRAY 10');RGB = (/26,26,26/)
CASE ('GRAY 11');RGB = (/28,28,28/)
CASE ('GRAY 12');RGB = (/31,31,31/)
CASE ('GRAY 13');RGB = (/33,33,33/)
CASE ('GRAY 14');RGB = (/36,36,36/)
CASE ('GRAY 15');RGB = (/38,38,38/)
CASE ('GRAY 16');RGB = (/41,41,41/)
CASE ('GRAY 17');RGB = (/43,43,43/)
CASE ('GRAY 18');RGB = (/46,46,46/)
CASE ('GRAY 19');RGB = (/48,48,48/)
CASE ('GRAY 2');RGB = (/5,5,5/)
CASE ('GRAY 20');RGB = (/51,51,51/)
CASE ('GRAY 21');RGB = (/54,54,54/)
CASE ('GRAY 22');RGB = (/56,56,56/)
CASE ('GRAY 23');RGB = (/59,59,59/)
CASE ('GRAY 24');RGB = (/61,61,61/)
CASE ('GRAY 25');RGB = (/64,64,64/)
CASE ('GRAY 26');RGB = (/66,66,66/)
CASE ('GRAY 27');RGB = (/69,69,69/)
CASE ('GRAY 28');RGB = (/71,71,71/)
CASE ('GRAY 29');RGB = (/74,74,74/)
CASE ('GRAY 3');RGB = (/8,8,8/)
CASE ('GRAY 30');RGB = (/77,77,77/)
CASE ('GRAY 31');RGB = (/79,79,79/)
CASE ('GRAY 32');RGB = (/82,82,82/)
CASE ('GRAY 33');RGB = (/84,84,84/)
CASE ('GRAY 34');RGB = (/87,87,87/)
CASE ('GRAY 35');RGB = (/89,89,89/)
CASE ('GRAY 36');RGB = (/92,92,92/)
CASE ('GRAY 37');RGB = (/94,94,94/)
CASE ('GRAY 38');RGB = (/97,97,97/)
CASE ('GRAY 39');RGB = (/99,99,99/)
CASE ('GRAY 4');RGB = (/10,10,10/)
CASE ('GRAY 40');RGB = (/102,102,102/)
CASE ('GRAY 42');RGB = (/107,107,107/)
CASE ('GRAY 43');RGB = (/110,110,110/)
CASE ('GRAY 44');RGB = (/112,112,112/)
CASE ('GRAY 45');RGB = (/115,115,115/)
CASE ('GRAY 46');RGB = (/117,117,117/)
CASE ('GRAY 47');RGB = (/120,120,120/)
CASE ('GRAY 48');RGB = (/122,122,122/)
CASE ('GRAY 49');RGB = (/125,125,125/)
CASE ('GRAY 5');RGB = (/13,13,13/)
CASE ('GRAY 50');RGB = (/127,127,127/)
CASE ('GRAY 51');RGB = (/130,130,130/)
CASE ('GRAY 52');RGB = (/133,133,133/)
CASE ('GRAY 53');RGB = (/135,135,135/)
CASE ('GRAY 54');RGB = (/138,138,138/)
CASE ('GRAY 55');RGB = (/140,140,140/)
CASE ('GRAY 56');RGB = (/143,143,143/)
CASE ('GRAY 57');RGB = (/145,145,145/)
CASE ('GRAY 58');RGB = (/148,148,148/)
CASE ('GRAY 59');RGB = (/150,150,150/)
CASE ('GRAY 6');RGB = (/15,15,15/)
CASE ('GRAY 60');RGB = (/153,153,153/)
CASE ('GRAY 61');RGB = (/156,156,156/)
CASE ('GRAY 62');RGB = (/158,158,158/)
CASE ('GRAY 63');RGB = (/161,161,161/)
CASE ('GRAY 64');RGB = (/163,163,163/)
CASE ('GRAY 65');RGB = (/166,166,166/)
CASE ('GRAY 66');RGB = (/168,168,168/)
CASE ('GRAY 67');RGB = (/171,171,171/)
CASE ('GRAY 68');RGB = (/173,173,173/)
CASE ('GRAY 69');RGB = (/176,176,176/)
CASE ('GRAY 7');RGB = (/18,18,18/)
CASE ('GRAY 70');RGB = (/179,179,179/)
CASE ('GRAY 71');RGB = (/181,181,181/)
CASE ('GRAY 72');RGB = (/184,184,184/)
CASE ('GRAY 73');RGB = (/186,186,186/)
CASE ('GRAY 74');RGB = (/189,189,189/)
CASE ('GRAY 75');RGB = (/191,191,191/)
CASE ('GRAY 76');RGB = (/194,194,194/)
CASE ('GRAY 77');RGB = (/196,196,196/)
CASE ('GRAY 78');RGB = (/199,199,199/)
CASE ('GRAY 79');RGB = (/201,201,201/)
CASE ('GRAY 8');RGB = (/20,20,20/)
CASE ('GRAY 80');RGB = (/204,204,204/)
CASE ('GRAY 81');RGB = (/207,207,207/)
CASE ('GRAY 82');RGB = (/209,209,209/)
CASE ('GRAY 83');RGB = (/212,212,212/)
CASE ('GRAY 84');RGB = (/214,214,214/)
CASE ('GRAY 85');RGB = (/217,217,217/)
CASE ('GRAY 86');RGB = (/219,219,219/)
CASE ('GRAY 87');RGB = (/222,222,222/)
CASE ('GRAY 88');RGB = (/224,224,224/)
CASE ('GRAY 89');RGB = (/227,227,227/)
CASE ('GRAY 9');RGB = (/23,23,23/)
CASE ('GRAY 90');RGB = (/229,229,229/)
CASE ('GRAY 91');RGB = (/232,232,232/)
CASE ('GRAY 92');RGB = (/235,235,235/)
CASE ('GRAY 93');RGB = (/237,237,237/)
CASE ('GRAY 94');RGB = (/240,240,240/)
CASE ('GRAY 95');RGB = (/242,242,242/)
CASE ('GRAY 97');RGB = (/247,247,247/)
CASE ('GRAY 98');RGB = (/250,250,250/)
CASE ('GRAY 99');RGB = (/252,252,252/)
CASE ('GREEN');RGB = (/0,255,0/)
CASE ('GREEN 2');RGB = (/0,238,0/)
CASE ('GREEN 3');RGB = (/0,205,0/)
CASE ('GREEN 4');RGB = (/0,139,0/)
CASE ('GREEN YELLOW');RGB = (/173,255,47/)
CASE ('HONEYDEW');RGB = (/240,255,240/)
CASE ('HONEYDEW 1');RGB = (/224,238,224/)
CASE ('HONEYDEW 2');RGB = (/193,205,193/)
CASE ('HONEYDEW 3');RGB = (/131,139,131/)
CASE ('HOT PINK');RGB = (/255,105,180/)
CASE ('HOT PINK 1');RGB = (/255,110,180/)
CASE ('HOT PINK 2');RGB = (/238,106,167/)
CASE ('HOT PINK 3');RGB = (/205,96,144/)
CASE ('HOT PINK 4');RGB = (/139,58,98/)
CASE ('INDIAN RED');RGB = (/205,92,92/)
CASE ('INDIAN RED 1');RGB = (/255,106,106/)
CASE ('INDIAN RED 2');RGB = (/238,99,99/)
CASE ('INDIAN RED 3');RGB = (/205,85,85/)
CASE ('INDIAN RED 4');RGB = (/139,58,58/)
CASE ('INDIGO');RGB = (/75,0,130/)
CASE ('IVORY');RGB = (/255,255,240/)
CASE ('IVORY 1');RGB = (/238,238,224/)
CASE ('IVORY 2');RGB = (/205,205,193/)
CASE ('IVORY 3');RGB = (/139,139,131/)
CASE ('IVORY BLACK');RGB = (/41,36,33/)
CASE ('KELLY GREEN');RGB = (/0,128,0/)
CASE ('KHAKI');RGB = (/240,230,140/)
CASE ('KHAKI 1');RGB = (/255,246,143/)
CASE ('KHAKI 2');RGB = (/238,230,133/)
CASE ('KHAKI 3');RGB = (/205,198,115/)
CASE ('KHAKI 4');RGB = (/139,134,78/)
CASE ('LAVENDER');RGB = (/230,230,250/)
CASE ('LAVENDER BLUSH');RGB = (/255,240,245/)
CASE ('LAVENDER BLUSH 1');RGB = (/238,224,229/)
CASE ('LAVENDER BLUSH 2');RGB = (/205,193,197/)
CASE ('LAVENDER BLUSH 3');RGB = (/139,131,134/)
CASE ('LAWN GREEN');RGB = (/124,252,0/)
CASE ('LEMON CHIFFON');RGB = (/255,250,205/)
CASE ('LEMON CHIFFON 1');RGB = (/238,233,191/)
CASE ('LEMON CHIFFON 2');RGB = (/205,201,165/)
CASE ('LEMON CHIFFON 3');RGB = (/139,137,112/)
CASE ('LIGHT BLUE');RGB = (/173,216,230/)
CASE ('LIGHT BLUE 1');RGB = (/191,239,255/)
CASE ('LIGHT BLUE 2');RGB = (/178,223,238/)
CASE ('LIGHT BLUE 3');RGB = (/154,192,205/)
CASE ('LIGHT BLUE 4');RGB = (/104,131,139/)
CASE ('LIGHT CORAL');RGB = (/240,128,128/)
CASE ('LIGHT CYAN');RGB = (/224,255,255/)
CASE ('LIGHT CYAN 1');RGB = (/209,238,238/)
CASE ('LIGHT CYAN 2');RGB = (/180,205,205/)
CASE ('LIGHT CYAN 3');RGB = (/122,139,139/)
CASE ('LIGHT GOLDENROD');RGB = (/255,236,139/)
CASE ('LIGHT GOLDENROD 1');RGB = (/238,220,130/)
CASE ('LIGHT GOLDENROD 2');RGB = (/205,190,112/)
CASE ('LIGHT GOLDENROD 3');RGB = (/139,129,76/)
CASE ('LIGHT GOLDENROD YELLOW');RGB = (/250,250,210/)
CASE ('LIGHT GREY');RGB = (/211,211,211/)
CASE ('LIGHT PINK');RGB = (/255,182,193/)
CASE ('LIGHT PINK 1');RGB = (/255,174,185/)
CASE ('LIGHT PINK 2');RGB = (/238,162,173/)
CASE ('LIGHT PINK 3');RGB = (/205,140,149/)
CASE ('LIGHT PINK 4');RGB = (/139,95,101/)
CASE ('LIGHT SALMON');RGB = (/255,160,122/)
CASE ('LIGHT SALMON 1');RGB = (/238,149,114/)
CASE ('LIGHT SALMON 2');RGB = (/205,129,98/)
CASE ('LIGHT SALMON 3');RGB = (/139,87,66/)
CASE ('LIGHT SEA GREEN');RGB = (/32,178,170/)
CASE ('LIGHT SKY BLUE');RGB = (/135,206,250/)
CASE ('LIGHT SKY BLUE 1');RGB = (/176,226,255/)
CASE ('LIGHT SKY BLUE 2');RGB = (/164,211,238/)
CASE ('LIGHT SKY BLUE 3');RGB = (/141,182,205/)
CASE ('LIGHT SKY BLUE 4');RGB = (/96,123,139/)
CASE ('LIGHT SLATE BLUE');RGB = (/132,112,255/)
CASE ('LIGHT SLATE GRAY');RGB = (/119,136,153/)
CASE ('LIGHT STEEL BLUE');RGB = (/176,196,222/)
CASE ('LIGHT STEEL BLUE 1');RGB = (/202,225,255/)
CASE ('LIGHT STEEL BLUE 2');RGB = (/188,210,238/)
CASE ('LIGHT STEEL BLUE 3');RGB = (/162,181,205/)
CASE ('LIGHT STEEL BLUE 4');RGB = (/110,123,139/)
CASE ('LIGHT YELLOW 1');RGB = (/255,255,224/)
CASE ('LIGHT YELLOW 2');RGB = (/238,238,209/)
CASE ('LIGHT YELLOW 3');RGB = (/205,205,180/)
CASE ('LIGHT YELLOW 4');RGB = (/139,139,122/)
CASE ('LIME GREEN');RGB = (/50,205,50/)
CASE ('LINEN');RGB = (/250,240,230/)
CASE ('MAGENTA');RGB = (/255,0,255/)
CASE ('MAGENTA 2');RGB = (/238,0,238/)
CASE ('MAGENTA 3');RGB = (/205,0,205/)
CASE ('MAGENTA 4');RGB = (/139,0,139/)
CASE ('MANGANESE BLUE');RGB = (/3,168,158/)
CASE ('MAROON');RGB = (/128,0,0/)
CASE ('MAROON 1');RGB = (/255,52,179/)
CASE ('MAROON 2');RGB = (/238,48,167/)
CASE ('MAROON 3');RGB = (/205,41,144/)
CASE ('MAROON 4');RGB = (/139,28,98/)
CASE ('MEDIUM ORCHID');RGB = (/186,85,211/)
CASE ('MEDIUM ORCHID 1');RGB = (/224,102,255/)
CASE ('MEDIUM ORCHID 2');RGB = (/209,95,238/)
CASE ('MEDIUM ORCHID 3');RGB = (/180,82,205/)
CASE ('MEDIUM ORCHID 4');RGB = (/122,55,139/)
CASE ('MEDIUM PURPLE');RGB = (/147,112,219/)
CASE ('MEDIUM PURPLE 1');RGB = (/171,130,255/)
CASE ('MEDIUM PURPLE 2');RGB = (/159,121,238/)
CASE ('MEDIUM PURPLE 3');RGB = (/137,104,205/)
CASE ('MEDIUM PURPLE 4');RGB = (/93,71,139/)
CASE ('MEDIUM SEA GREEN');RGB = (/60,179,113/)
CASE ('MEDIUM SLATE BLUE');RGB = (/123,104,238/)
CASE ('MEDIUM SPRING GREEN');RGB = (/0,250,154/)
CASE ('MEDIUM TURQUOISE');RGB = (/72,209,204/)
CASE ('MEDIUM VIOLET RED');RGB = (/199,21,133/)
CASE ('MELON');RGB = (/227,168,105/)
CASE ('MIDNIGHT BLUE');RGB = (/25,25,112/)
CASE ('MINT');RGB = (/189,252,201/)
CASE ('MINT CREAM');RGB = (/245,255,250/)
CASE ('MISTY ROSE');RGB = (/255,228,225/)
CASE ('MISTY ROSE 1');RGB = (/238,213,210/)
CASE ('MISTY ROSE 2');RGB = (/205,183,181/)
CASE ('MISTY ROSE 3');RGB = (/139,125,123/)
CASE ('MOCCASIN');RGB = (/255,228,181/)
CASE ('NAVAJO WHITE');RGB = (/255,222,173/)
CASE ('NAVAJO WHITE 1');RGB = (/238,207,161/)
CASE ('NAVAJO WHITE 2');RGB = (/205,179,139/)
CASE ('NAVAJO WHITE 3');RGB = (/139,121,94/)
CASE ('NAVY');RGB = (/0,0,128/)
CASE ('OLD LACE');RGB = (/253,245,230/)
CASE ('OLIVE');RGB = (/128,128,0/)
CASE ('OLIVE DRAB');RGB = (/192,255,62/)
CASE ('OLIVE DRAB 1');RGB = (/179,238,58/)
CASE ('OLIVE DRAB 2');RGB = (/154,205,50/)
CASE ('OLIVE DRAB 3');RGB = (/105,139,34/)
CASE ('ORANGE');RGB = (/255,128,0/)
CASE ('ORANGE 1');RGB = (/255,165,0/)
CASE ('ORANGE 2');RGB = (/238,154,0/)
CASE ('ORANGE 3');RGB = (/205,133,0/)
CASE ('ORANGE 4');RGB = (/139,90,0/)
CASE ('ORANGE RED');RGB = (/255,69,0/)
CASE ('ORANGE RED 1');RGB = (/238,64,0/)
CASE ('ORANGE RED 2');RGB = (/205,55,0/)
CASE ('ORANGE RED 3');RGB = (/139,37,0/)
CASE ('ORCHID');RGB = (/218,112,214/)
CASE ('ORCHID 1');RGB = (/255,131,250/)
CASE ('ORCHID 2');RGB = (/238,122,233/)
CASE ('ORCHID 3');RGB = (/205,105,201/)
CASE ('ORCHID 4');RGB = (/139,71,137/)
CASE ('PALE GOLDENROD');RGB = (/238,232,170/)
CASE ('PALE GREEN');RGB = (/152,251,152/)
CASE ('PALE GREEN 1');RGB = (/154,255,154/)
CASE ('PALE GREEN 2');RGB = (/144,238,144/)
CASE ('PALE GREEN 3');RGB = (/124,205,124/)
CASE ('PALE GREEN 4');RGB = (/84,139,84/)
CASE ('PALE TURQUOISE');RGB = (/187,255,255/)
CASE ('PALE TURQUOISE 1');RGB = (/174,238,238/)
CASE ('PALE TURQUOISE 2');RGB = (/150,205,205/)
CASE ('PALE TURQUOISE 3');RGB = (/102,139,139/)
CASE ('PALE VIOLET RED');RGB = (/219,112,147/)
CASE ('PALE VIOLET RED 1');RGB = (/255,130,171/)
CASE ('PALE VIOLET RED 2');RGB = (/238,121,159/)
CASE ('PALE VIOLET RED 3');RGB = (/205,104,137/)
CASE ('PALE VIOLET RED 4');RGB = (/139,71,93/)
CASE ('PAPAYA WHIP');RGB = (/255,239,213/)
CASE ('PEACH PUFF');RGB = (/255,218,185/)
CASE ('PEACH PUFF 1');RGB = (/238,203,173/)
CASE ('PEACH PUFF 2');RGB = (/205,175,149/)
CASE ('PEACH PUFF 3');RGB = (/139,119,101/)
CASE ('PEACOCK');RGB = (/51,161,201/)
CASE ('PINK');RGB = (/255,192,203/)
CASE ('PINK 1');RGB = (/255,181,197/)
CASE ('PINK 2');RGB = (/238,169,184/)
CASE ('PINK 3');RGB = (/205,145,158/)
CASE ('PINK 4');RGB = (/139,99,108/)
CASE ('PLUM');RGB = (/221,160,221/)
CASE ('PLUM 1');RGB = (/255,187,255/)
CASE ('PLUM 2');RGB = (/238,174,238/)
CASE ('PLUM 3');RGB = (/205,150,205/)
CASE ('PLUM 4');RGB = (/139,102,139/)
CASE ('POWDER BLUE');RGB = (/176,224,230/)
CASE ('PURPLE');RGB = (/128,0,128/)
CASE ('PURPLE 1');RGB = (/155,48,255/)
CASE ('PURPLE 2');RGB = (/145,44,238/)
CASE ('PURPLE 3');RGB = (/125,38,205/)
CASE ('PURPLE 4');RGB = (/85,26,139/)
CASE ('RASPBERRY');RGB = (/135,38,87/)
CASE ('RAW SIENNA');RGB = (/199,97,20/)
CASE ('RED');RGB = (/255,0,0/)
CASE ('RED 1');RGB = (/238,0,0/)
CASE ('RED 2');RGB = (/205,0,0/)
CASE ('RED 3');RGB = (/139,0,0/)
CASE ('ROSY BROWN');RGB = (/188,143,143/)
CASE ('ROSY BROWN 1');RGB = (/255,193,193/)
CASE ('ROSY BROWN 2');RGB = (/238,180,180/)
CASE ('ROSY BROWN 3');RGB = (/205,155,155/)
CASE ('ROSY BROWN 4');RGB = (/139,105,105/)
CASE ('ROYAL BLUE');RGB = (/65,105,225/)
CASE ('ROYAL BLUE 1');RGB = (/72,118,255/)
CASE ('ROYAL BLUE 2');RGB = (/67,110,238/)
CASE ('ROYAL BLUE 3');RGB = (/58,95,205/)
CASE ('ROYAL BLUE 4');RGB = (/39,64,139/)
CASE ('SALMON');RGB = (/250,128,114/)
CASE ('SALMON 1');RGB = (/255,140,105/)
CASE ('SALMON 2');RGB = (/238,130,98/)
CASE ('SALMON 3');RGB = (/205,112,84/)
CASE ('SALMON 4');RGB = (/139,76,57/)
CASE ('SANDY BROWN');RGB = (/244,164,96/)
CASE ('SAP GREEN');RGB = (/48,128,20/)
CASE ('SEA GREEN');RGB = (/84,255,159/)
CASE ('SEA GREEN 1');RGB = (/78,238,148/)
CASE ('SEA GREEN 2');RGB = (/67,205,128/)
CASE ('SEA GREEN 3');RGB = (/46,139,87/)
CASE ('SEASHELL');RGB = (/255,245,238/)
CASE ('SEASHELL 1');RGB = (/238,229,222/)
CASE ('SEASHELL 2');RGB = (/205,197,191/)
CASE ('SEASHELL 3');RGB = (/139,134,130/)
CASE ('SEPIA');RGB = (/94,38,18/)
CASE ('SIENNA');RGB = (/160,82,45/)
CASE ('SIENNA 1');RGB = (/255,130,71/)
CASE ('SIENNA 2');RGB = (/238,121,66/)
CASE ('SIENNA 3');RGB = (/205,104,57/)
CASE ('SIENNA 4');RGB = (/139,71,38/)
CASE ('SILVER');RGB = (/192,192,192/)
CASE ('SKY BLUE');RGB = (/135,206,235/)
CASE ('SKY BLUE 1');RGB = (/135,206,255/)
CASE ('SKY BLUE 2');RGB = (/126,192,238/)
CASE ('SKY BLUE 3');RGB = (/108,166,205/)
CASE ('SKY BLUE 4');RGB = (/74,112,139/)
CASE ('SLATE BLUE');RGB = (/106,90,205/)
CASE ('SLATE BLUE 1');RGB = (/131,111,255/)
CASE ('SLATE BLUE 2');RGB = (/122,103,238/)
CASE ('SLATE BLUE 3');RGB = (/105,89,205/)
CASE ('SLATE BLUE 4');RGB = (/71,60,139/)
CASE ('SLATE GRAY');RGB = (/112,128,144/)
CASE ('SLATE GRAY 1');RGB = (/198,226,255/)
CASE ('SLATE GRAY 2');RGB = (/185,211,238/)
CASE ('SLATE GRAY 3');RGB = (/159,182,205/)
CASE ('SLATE GRAY 4');RGB = (/108,123,139/)
CASE ('SNOW');RGB = (/255,250,250/)
CASE ('SNOW 1');RGB = (/238,233,233/)
CASE ('SNOW 2');RGB = (/205,201,201/)
CASE ('SNOW 3');RGB = (/139,137,137/)
CASE ('SPRING GREEN');RGB = (/0,255,127/)
CASE ('SPRING GREEN 1');RGB = (/0,238,118/)
CASE ('SPRING GREEN 2');RGB = (/0,205,102/)
CASE ('SPRING GREEN 3');RGB = (/0,139,69/)
CASE ('STEEL BLUE');RGB = (/70,130,180/)
CASE ('STEEL BLUE 1');RGB = (/99,184,255/)
CASE ('STEEL BLUE 2');RGB = (/92,172,238/)
CASE ('STEEL BLUE 3');RGB = (/79,148,205/)
CASE ('STEEL BLUE 4');RGB = (/54,100,139/)
CASE ('TAN');RGB = (/210,180,140/)
CASE ('TAN 1');RGB = (/255,165,79/)
CASE ('TAN 2');RGB = (/238,154,73/)
CASE ('TAN 3');RGB = (/205,133,63/)
CASE ('TAN 4');RGB = (/139,90,43/)
CASE ('TEAL');RGB = (/0,128,128/)
CASE ('THISTLE');RGB = (/216,191,216/)
CASE ('THISTLE 1');RGB = (/255,225,255/)
CASE ('THISTLE 2');RGB = (/238,210,238/)
CASE ('THISTLE 3');RGB = (/205,181,205/)
CASE ('THISTLE 4');RGB = (/139,123,139/)
CASE ('TOMATO');RGB = (/255,99,71/)
CASE ('TOMATO 1');RGB = (/238,92,66/)
CASE ('TOMATO 2');RGB = (/205,79,57/)
CASE ('TOMATO 3');RGB = (/139,54,38/)
CASE ('TURQUOISE');RGB = (/64,224,208/)
CASE ('TURQUOISE 1');RGB = (/0,245,255/)
CASE ('TURQUOISE 2');RGB = (/0,229,238/)
CASE ('TURQUOISE 3');RGB = (/0,197,205/)
CASE ('TURQUOISE 4');RGB = (/0,134,139/)
CASE ('TURQUOISE BLUE');RGB = (/0,199,140/)
CASE ('VIOLET');RGB = (/238,130,238/)
CASE ('VIOLET RED');RGB = (/208,32,144/)
CASE ('VIOLET RED 1');RGB = (/255,62,150/)
CASE ('VIOLET RED 2');RGB = (/238,58,140/)
CASE ('VIOLET RED 3');RGB = (/205,50,120/)
CASE ('VIOLET RED 4');RGB = (/139,34,82/)
CASE ('WARM GREY');RGB = (/128,128,105/)
CASE ('WHEAT');RGB = (/245,222,179/)
CASE ('WHEAT 1');RGB = (/255,231,186/)
CASE ('WHEAT 2');RGB = (/238,216,174/)
CASE ('WHEAT 3');RGB = (/205,186,150/)
CASE ('WHEAT 4');RGB = (/139,126,102/)
CASE ('WHITE');RGB = (/255,255,255/)
CASE ('WHITE SMOKE');RGB = (/245,245,245/)
CASE ('YELLOW');RGB = (/255,255,0/)
CASE ('YELLOW 1');RGB = (/238,238,0/)
CASE ('YELLOW 2');RGB = (/205,205,0/)
CASE ('YELLOW 3');RGB = (/139,139,0/)
   CASE DEFAULT
      WRITE(MESSAGE,'(A,A,A)') "ERROR: The COLOR, ", TRIM(COLOR),", is not a defined color"
      CALL SHUTDOWN(MESSAGE)      
END SELECT

END SUBROUTINE COLOR2RGB
 
 
END MODULE READ_INPUT

