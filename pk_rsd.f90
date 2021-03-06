module pk_rsd 
  use am_routines
  implicit none
  integer, parameter :: DP = kind(1.0D0)
  real(DP), parameter :: pi = 3.1415926535897932384626433832795d0, twopi=2*pi, fourpi=4*pi
     
  integer :: nk = 200
  real(DP), allocatable :: ak(:), pk(:),pk_dd(:),pk_tt(:),pk_dt(:)
  
  integer imu_max
  parameter(imu_max=10)
  integer ixmax
  parameter(ixmax=400)
  
  integer :: ik_max, ik_max_RegPT
  real(DP), allocatable :: ak_camb(:), pk_camb(:)
  real(DP), allocatable :: ak_RegPT(:), pk_RegPT_dd(:), pk_RegPT_dt(:), pk_RegPT_tt(:)

  real(DP) :: sigmav ! Sigma_v
  real(DP) :: growth ! Growth factor 
  real(DP) :: ff ! Growth rate 
  real(DP) :: sigma_8 = 0.0d0

  ! Bias terms
  real(DP) :: b1, b2
  real(DP) :: bs2 = 0.0d0
  real(DP) :: b3nl = 0.0d0

  logical :: use_nonlinear = .true.

  real(DP), allocatable :: pk0dd(:),pk2dd(:),pk4dd(:)
  real(DP), allocatable :: pk0dt(:),pk2dt(:),pk4dt(:)
  real(DP), allocatable :: pk0tt(:),pk2tt(:),pk4tt(:)
  real(DP), allocatable :: pk0corr_A(:), pk2corr_A(:), pk4corr_A(:)
  real(DP), allocatable :: pk0corr_B(:), pk2corr_B(:), pk4corr_B(:)
  real(DP), allocatable :: pk0(:),pk2(:),pk4(:)

contains
   
  subroutine init_pk()
    implicit none

    allocate(pk0dd(nk),pk2dd(nk),pk4dd(nk))
    allocate(pk0dt(nk),pk2dt(nk),pk4dt(nk))
    allocate(pk0tt(nk),pk2tt(nk),pk4tt(nk))
    allocate(pk0corr_A(nk),pk2corr_A(nk),pk4corr_A(nk))
    allocate(pk0corr_B(nk),pk2corr_B(nk),pk4corr_B(nk))
    allocate(pk0(nk),pk2(nk),pk4(nk))
    pk0dd(:) = 0.0d0
    pk2dd(:) = 0.0d0
    pk4dd(:) = 0.0d0
    pk0dt(:) = 0.0d0
    pk2dt(:) = 0.0d0
    pk4dt(:) = 0.0d0
    pk0tt(:) = 0.0d0
    pk2tt(:) = 0.0d0
    pk4tt(:) = 0.0d0
    pk0corr_A(:) = 0.0d0
    pk2corr_A(:) = 0.0d0
    pk4corr_A(:) = 0.0d0
    pk0corr_B(:) = 0.0d0
    pk2corr_B(:) = 0.0d0
    pk4corr_B(:) = 0.0d0
    pk0(:) = 0.0d0
    pk2(:) = 0.0d0
    pk4(:) = 0.0d0

    if (bs2 .eq. 0.0d0) bs2 = -4.0/7.0*(b1-1.0)
    if (b3nl .eq. 0.0d0) b3nl = 32.0/315.0*(b1-1.0)

  end subroutine init_pk
 
! ******************************************************* 

      subroutine load_matterpower_data(filename, regpt_dd,regpt_dt,regpt_tt)

!     input file is assumed to be the matter power spectrum data 
!     created by CAMB code. 

      implicit none
      character(len=200) filename, regpt_dd,regpt_dt,regpt_tt

      integer ikmax
      parameter(ikmax=10000)
      integer ik
      real(DP) :: ak_temp(ikmax), pk_temp(ikmax), dlnk
      real(DP) :: dum1,dum2,dum3,dum4,dum5,dum6,dum7,dum8,dum9,dum10,dum11
      
      ak_temp(:) = 0.0d0
      pk_temp(:) = 0.0d0
 
      open(9, file=trim(filename), status='unknown')
      do ik=1, ikmax
         read(9,*,END=10) ak_temp(ik), pk_temp(ik)
      enddo
 10   continue
      close(9)

      ik_max = ik-1
      allocate(ak_camb(ik_max),pk_camb(ik_max))
      ak_camb(1:ik_max) = ak_temp(1:ik_max)
      pk_camb(1:ik_max) = pk_temp(1:ik_max)

      if (sigma_8 .ne. 0.0d0) call normalization_trapez(8.0d0)

      dlnk=log(ak_temp(ik-1)/ak_temp(1))/dble(nk-1)

      allocate(ak(nk),pk(nk),pk_dd(nk),pk_dt(nk),pk_tt(nk))
      do ik=1,nk
         ak(ik) = ak_temp(1)*exp(dble(ik-1)*dlnk)
         pk(ik) = find_pk(ak(ik))
      end do

      ! Linear dd, tt and dt
      do ik=1,nk
          pk_dd(ik) = pk(ik)
          pk_tt(ik) = pk(ik)
          pk_dt(ik) = pk(ik)
      end do
      if (use_nonlinear) then

        open(9, file=trim(regpt_dd), status='unknown')
        do ik=1, ikmax
          read(9,*,END=11) ak_temp(ik), dum1,dum2,dum3,dum4,dum5,dum6,pk_temp(ik),dum7,dum8,dum9,dum10,dum11
        enddo
 11     continue
        close(9)

        ik_max_RegPT = ik-1
        allocate(ak_RegPT(ik_max_RegPT),pk_RegPT_dd(ik_max_RegPT),pk_RegPT_dt(ik_max_RegPT),pk_RegPT_tt(ik_max_RegPT))
        ak_RegPT(1:ik_max_RegPT) = ak_temp(1:ik_max_RegPT)
        pk_RegPT_dd(1:ik_max_RegPT) = pk_temp(1:ik_max_RegPT)  

        open(9, file=trim(regpt_dt), status='unknown')
        do ik=1, ik_max_RegPT
          read(9,*) ak_temp(ik), dum1,dum2,dum3,dum4,dum5,dum6,pk_RegPT_dt(ik),dum7,dum8,dum9,dum10,dum11
        enddo
        close(9)

        open(9, file=trim(regpt_tt), status='unknown')
        do ik=1, ik_max_RegPT
          read(9,*) ak_temp(ik), dum1,dum2,dum3,dum4,dum5,dum6,pk_RegPT_tt(ik),dum7,dum8,dum9,dum10,dum11
        enddo
        close(9)

        do ik=1, ik_max_RegPT
          !write(*,'(10E15.5)') ak_RegPT(ik), pk_RegPT_dd(ik), pk_RegPT_dt(ik), pk_RegPT_tt(ik)
        enddo

        do ik=1,nk
          pk_dd(ik) = find_pk_RegPT(1,ak(ik))
          pk_tt(ik) = find_pk_RegPT(2,ak(ik))
          pk_dt(ik) = find_pk_RegPT(3,ak(ik))
          !write(*,'(10E15.5)') ak(ik),pk(ik),pk_dd(ik),pk_dt(ik),pk_tt(ik)
        end do

      endif

      write(6,*) 'k_min =', ak(1)
      write(6,*) 'k_max =', ak(nk)
      
      call init_pk()

    end subroutine load_matterpower_data

! ******************************************************* 

    subroutine normalization_trapez(r_th)
      implicit none
      real(DP) r_th
      integer ik
      real(DP) :: W_TH,sigma_a,sigma_b,x,const

      x = ak_camb(1) * r_th
      if(x.lt.1.d-3) then
         W_TH = 1.d0 - x*x / 10.d0 + x**4 / 280.d0 
      else
         W_TH = 3.d0 * (sin(x) - x * cos(x))/x/x/x
      endif
      sigma_a = W_TH * W_TH * pk_camb(1) * ak_camb(1) * ak_camb(1)
      sigma_a = sigma_a / (2.d0 * pi * pi)

      const = 0.d0 
      do ik=2, ik_max
         x = ak_camb(ik) * r_th
         if(x.lt.1.d-3) then
            W_TH = 1.d0 - x*x / 10.d0 + x**4 / 280.d0 
         else
            W_TH = 3.d0 * (sin(x) - x * cos(x))/x/x/x
         endif
         sigma_b = W_TH * W_TH * pk_camb(ik) * ak_camb(ik) * ak_camb(ik) 
         sigma_b = sigma_b / (2.d0 * pi * pi)
         const = const + (sigma_a + sigma_b) * ( ak_camb(ik) - ak_camb(ik-1) )/ 2.d0
         sigma_a = sigma_b
      enddo

      write(*,*) 'Sigma_8 = ',sqrt(const)
      pk_camb(:) = pk_camb(:) * (sigma_8**2.0)/const
      write(*,*) 'Rescaling P(k) to sigma_8 = ',sigma_8

    end subroutine normalization_trapez

! ******************************************************* 

    function find_pk(kk)

      implicit none
      integer j, jmin, jmax
      real(DP) :: kk, s, ds, find_pk

      call hunt(ak_camb(1:ik_max), kk, j)
      jmin = j - 2
      jmax = j + 2
      if(jmin.lt.1) jmin = 1
      if(jmax.ge.ik_max) jmax = ik_max
      call polint(ak_camb(jmin:jmax),pk_camb(jmin:jmax),kk,s,ds)
      find_pk = s
      
    end function find_pk

    function find_pk_RegPT(a,kk)

      implicit none
      integer a,j, jmin, jmax
      real(DP) :: kk, s, ds, find_pk_RegPT

      call hunt(ak_RegPT(1:ik_max_RegPT), kk, j)
      jmin = j - 2
      jmax = j + 2
      if(jmin.lt.1) jmin = 1
      if(jmax.ge.ik_max_RegPT) jmax = ik_max_RegPT
      if (a.eq.1) call polint(ak_RegPT(jmin:jmax),pk_RegPT_dd(jmin:jmax),kk,s,ds)
      if (a.eq.2) call polint(ak_RegPT(jmin:jmax),pk_RegPT_dt(jmin:jmax),kk,s,ds)
      if (a.eq.3) call polint(ak_RegPT(jmin:jmax),pk_RegPT_tt(jmin:jmax),kk,s,ds)
      find_pk_RegPT = s
      
    end function find_pk_RegPT

    function find_pkl(a,kk)
      
      implicit none
      integer a,j, jmin, jmax
      real(DP) :: kk, s, ds, find_pkl

      call hunt(ak(1:nk), kk, j)
      jmin = j - 2
      jmax = j + 2
      if(jmin.lt.1) jmin = 1
      if(jmax.ge.nk) jmax = nk
      if (a.eq.1) call polint(ak(jmin:jmax),pk0(jmin:jmax),kk,s,ds)
      if (a.eq.2) call polint(ak(jmin:jmax),pk2(jmin:jmax),kk,s,ds)
      if (a.eq.3) call polint(ak(jmin:jmax),pk4(jmin:jmax),kk,s,ds)
      find_pkl = s

    end function find_pkl

! ******************************************************* 

    function fp(ip, x, mu,k,xmin,xmax)

!     ip=1 for kernel of pk_B111
!     ip=2 for kernel of pk_B112
!     ip=3 for kernel of pk_B121
!     ip=4 for kernel of pk_B122
!     ip=5 for kernel of pk_B211
!     ip=6 for kernel of pk_B212
!     ip=7 for kernel of pk_B221
!     ip=8 for kernel of pk_B222
!     ip=9 for kernel of pk_B312
!     ip=10 for kernel of pk_B321
!     ip=11 for kernel of pk_B322
!     ip=12 for kernel of pk_B422
!
      implicit none
      integer ip
      real(DP) fp
      real(DP) mu, k, x, xmin, xmax
      real(DP) mumin, mumax

      if(ip.eq.1) then
         fp = x**2 * (mu*mu-1.) / 2.
      elseif(ip.eq.2) then
         fp = 3.*x**2 * (mu*mu-1.)**2 / 8.
      elseif(ip.eq.3) then
         fp = 3.*x**4 * (mu*mu-1.)**2 / (1.+x*x-2.*mu*x) / 8.
      elseif(ip.eq.4) then
         fp = 5.*x**4 * (mu*mu-1.)**3 / (1.+x*x-2.*mu*x) / 16.
      elseif(ip.eq.5) then
         fp = x * (x+2.*mu-3.*x*mu*mu) / 2.
      elseif(ip.eq.6) then
         fp = - 3.*x * (mu*mu-1.) * (-x-2.*mu+5.*x*mu*mu) / 4.
      elseif(ip.eq.7) then
         fp = 3.*x**2 * (mu*mu-1.) * (-2.+x*x+6.*x*mu-5.*x*x*mu*mu) &
             / (1.+x*x-2.*mu*x) / 4.
      elseif(ip.eq.8) then
         fp = - 3.*x**2 * (mu*mu-1.)**2 &
             * (6.-5.*x*x-30.*x*mu+35.*x*x*mu*mu) &
             / (1.+x*x-2.*mu*x) / 16.
      elseif(ip.eq.9) then
         fp = x * (4.*mu*(3.-5.*mu*mu) + x*(3.-30.*mu*mu+35.*mu**4) )/ 8.
      elseif(ip.eq.10) then
         fp = x * (-8.*mu + x*(-12.+36.*mu*mu+12.*x*mu*(3.-5.*mu*mu)+ &
             x**2*(3.-30.*mu*mu+35.*mu**4) ) ) / (1.+x*x-2.*mu*x) / 8.
      elseif(ip.eq.11) then
         fp = 3.*x * (mu*mu-1.) * (-8.*mu + x*(-12.+60.*mu*mu+ &
             20.*x*mu*(3.-7.*mu*mu)+5.*x*x*(1.-14.*mu*mu+21.*mu**4)) ) &
             / (1.+x*x-2.*mu*x) / 16.
      elseif(ip.eq.12) then
         fp = x * (8.*mu*(-3.+5.*mu*mu) - 6.*x*(3.-30.*mu*mu+35.*mu**4) &
             + 6.*x*x*mu*(15.-70.*mu*mu+63*mu**4) + x**3*(5.-21.*mu*mu* &
             (5.-15.*mu*mu+11.*mu**4)) ) / (1.+x*x-2.*mu*x) / 16.
      endif

      fp = fp * x  / (1.+x*x-2.*mu*x)* find_pk(k*x)*find_pk(k*sqrt(1.+x*x-2.*mu*x))
      
    end function fp

! ******************************************************* 

      function  fp_A(ip, x, mu,k,xmin,xmax)

!     ip=1 for kernel of pk_A11
!     ip=2 for kernel of pk_A12
!     ip=3 for kernel of pk_A22
!     ip=4 for kernel of pk_A23
!     ip=5 for kernel of pk_A33

      implicit none
      integer ip
      real*8 fp_A
      real*8 mu, k, x, xmax, xmin

      if(ip.eq.1) then
         fp_A = - x**3 * ( mu+6.*mu**3+x*x*mu*(-3.+10.*mu*mu)+ &
             x*(-3.+mu*mu-12.*mu**4) ) / 7.
      elseif(ip.eq.2 .or. ip.eq.4) then
         fp_A = x**4 * (mu*mu-1.) * (-1.+7.*x*mu-6.*mu*mu) / 14.
      elseif(ip.eq.3) then
         fp_A = x**3 * ( x*x*mu*(13.-41.*mu*mu) -4.*(mu+6.*mu**3) &
             + x*(5.+9.*mu*mu+42.*mu**4) ) / 14.
      elseif(ip.eq.5) then
         fp_A = x**3 * (1.-7.*x*mu+6.*mu*mu) &
             * (-2.*mu+x*(-1.+3.*mu*mu)) / 14.
      endif

      fp_A = fp_A * x * find_pk(k) * find_pk(k*sqrt(1.+x*x-2.*mu*x)) / (1.+x*x-2.*mu*x)**2

      end function fp_A

! ******************************************************* 

      function  fp_tA(ip, x, mu,k,xmin,xmax)

!     ip=6 for kernel of pk_tA11
!     ip=7 for kernel of pk_tA12
!     ip=8 for kernel of pk_tA22
!     ip=9 for kernel of pk_tA23
!     ip=10 for kernel of pk_tA33

      implicit none
      integer ip
      real*8 fp_tA
      real*8 mu, k, x, xmax, xmin
      
      if(ip.eq.6) then
         fp_tA = (-mu+x*(2.*mu*mu-1.)) * (-3.*x-7.*mu+10.*x*mu*mu) / 7.
      elseif(ip.eq.7) then
         fp_tA = x * (mu*mu-1.) * (3.*x+7.*mu-10.*x*mu*mu) / 14.
      elseif(ip.eq.8) then
         fp_tA = ( 28.*mu*mu + x*mu*(25.-81.*mu*mu) &
             + x**2*(1.-27.*mu*mu+54.*mu**4) ) / 14.
      elseif(ip.eq.9) then
         fp_tA = - x * (mu*mu-1.) * (x-7.*mu+6.*x*mu*mu) / 14. 
      elseif(ip.eq.10) then
         fp_tA = ( x-7.*mu+6.*x*mu*mu ) * ( -2.*mu + &
             x*(3.*mu*mu-1.) ) / 14.
      endif

      fp_tA = fp_tA * x * find_pk(k*x) * find_pk(k*sqrt(1.+x*x-2.*mu*x)) / (1.+x*x-2.*mu*x)**2

      end function fp_tA

! ******************************************************* 

    function  fp_aa(ip, x, mu,k,xmin,xmax)

!     ip=11 for kernel of pk_aa11
!     ip=12 for kernel of pk_aa12
!     ip=13 for kernel of pk_aa22
!     ip=14 for kernel of pk_aa23
!     ip=15 for kernel of pk_aa33

      implicit none
      integer ip
      real*8 fp_aa
      real*8 mu, k, x, xmax, xmin

      if(ip.eq.11) then
         fp_aa = ( -7.*mu*mu + x**3*mu * (-3.+10.*mu*mu) + 3.*x &
             * (mu+6.*mu**3) + x*x * (6.-19.*mu*mu-8.*mu**4) ) / 7.
      elseif(ip.eq.12 .or. ip.eq.14) then
         fp_aa = x * (-1.+mu*mu) * (6.*x - 7.*(1.+x*x)*mu + 8.*x*mu*mu) &
             / 14.
      elseif(ip.eq.13) then
         fp_aa = ( -28.*mu*mu + x**3*mu* (-13.+41.*mu*mu) + &
             x*mu*(11.+73.*mu*mu) - 2.*x*x*(-9.+31.*mu*mu+20.*mu**4) ) &
             / 14.
      elseif(ip.eq.15) then
         fp_aa = ( 7.*mu + x * (-6.+7.*x*mu-8.*mu*mu) ) * &
             ( -2.*mu + x*(-1.+3.*mu*mu) ) / 14.
      endif

      fp_aa = fp_aa * x * find_pk(k) * find_pk(k*x) / (1.+x*x-2.*mu*x)

      end function fp_aa

! ******************************************************* 

    function integ_fp_B(ip, x,k,xmin,xmax)

      implicit none
      integer ip, imu
      real(DP)  integ_fp_B, xmin, xmax, mumin, mumax
      real(DP)  k, x, mu, wmu(imu_max), mmu(imu_max)
     
      integ_fp_B = 0.d0

      mumin = max(-1.0, (1.+x**2-xmax**2)/2./x)
      mumax = min( 1.0, (1.+x**2-xmin**2)/2./x)

      if(x.ge.0.5d0) mumax= 0.5d0/x

      call gaulegf(mumin, mumax, mmu, wmu, imu_max)

      do imu=1, imu_max
         integ_fp_B = integ_fp_B + wmu(imu) * fp(ip, x, mmu(imu),k,xmin,xmax)
      enddo

    end function integ_fp_B

    function integ_fp_A(ip, x,k,xmin,xmax)

      implicit none
      integer ip, imu
      real*8  integ_fp_A, xmin, xmax, mumin, mumax
      real*8  k, x, mu, wmu(imu_max), mmu(imu_max)

      integ_fp_A = 0.d0

      mumin = max(-1.0, (1.+x**2-xmax**2)/2./x)
      mumax = min( 1.0, (1.+x**2-xmin**2)/2./x)

      if(x.ge.0.5d0) mumax= 0.5d0/x

      call gaulegf(mumin, mumax, mmu, wmu, imu_max)

         do imu=1, imu_max
            if(ip.le.5)  integ_fp_A = integ_fp_A + wmu(imu) * fp_A(ip, x, mmu(imu),k,xmin,xmax)
            if(ip.ge.6 .and. ip.le.10) integ_fp_A = integ_fp_A + wmu(imu) * fp_tA(ip, x, mmu(imu),k,xmin,xmax)
            if(ip.ge.11) integ_fp_A = integ_fp_A + wmu(imu) * fp_aa(ip, x, mmu(imu),k,xmin,xmax)
         enddo
        
     end function integ_fp_A

! ******************************************************* 

    subroutine calc_correction(ik)
      
      implicit none
      integer ik, isub
      integer ix
      real(DP) :: kmin, kmax, xmin, xmax, mumin, mumax
      real(DP) :: k, ww(ixmax), xx(ixmax),kfact
      real(DP) :: alpha
      real(DP) :: pk_B111, pk_B112, pk_B121
      real(DP) :: pk_B122, pk_B211, pk_B212
      real(DP) :: pk_B221, pk_B222, pk_B312
      real(DP) :: pk_B321, pk_B322, pk_B422
      real(DP) :: pk_B1, pk_B2, pk_B3, pk_B4
      real(DP) ::  pk_A11, pk_A12, pk_A22
      real(DP) ::  pk_A23, pk_A33
      real(DP) ::  pk_tA11, pk_tA12, pk_tA22
      real(DP) ::  pk_tA23, pk_tA33
      real(DP) ::  pk_aa11, pk_aa12, pk_aa22
      real(DP) ::  pk_aa23, pk_aa33
      real(DP) :: pk_A1, pk_A2, pk_A3
      real(DP) :: fact00,fact10,fact20,fact30,fact40
      real(DP) :: fact02,fact12,fact22,fact32,fact42
      real(DP) :: fact04,fact14,fact24,fact34,fact44
      real(DP) :: ptt,pdt,pdd
      real(DP) :: pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8

      kmin = ak(1)
      kmax = ak(nk) 

      pk_B111 = 0.0d0
      pk_B112 = 0.0d0
      pk_B121 = 0.0d0
      pk_B122 = 0.0d0
      pk_B211 = 0.0d0
      pk_B212 = 0.0d0
      pk_B221 = 0.0d0
      pk_B222 = 0.0d0
      pk_B312 = 0.0d0
      pk_B321 = 0.0d0
      pk_B322 = 0.0d0
      pk_B422 = 0.0d0
      pk_B1 = 0.0d0
      pk_B2 = 0.0d0
      pk_B3 = 0.0d0
      pk_B4 = 0.0d0

      pk_A11 = 0.0d0 
      pk_A12 = 0.0d0
      pk_A22 = 0.0d0
      pk_A23 = 0.0d0 
      pk_A33 = 0.0d0
      pk_tA11 = 0.0d0
      pk_tA12 = 0.0d0
      pk_tA22 = 0.0d0
      pk_tA23 = 0.0d0
      pk_tA33 = 0.0d0
      pk_aa11 = 0.0d0
      pk_aa12 = 0.0d0
      pk_aa22 = 0.0d0
      pk_aa23 = 0.0d0
      pk_aa33 = 0.0d0

      k = ak(ik)

      xmin = kmin / k
      xmax = kmax / k

!     ////// Gauss-Legendre integration //////  c

      if(k.lt.0.2) isub =200 
      if(k.ge.0.2) isub =0 
                
      call gaulegf(log(xmin),log(xmax),xx,ww,ixmax-isub)

      do ix=1, ixmax-isub
        xx(ix)= dexp(xx(ix))
        pk_B111 = pk_B111+ww(ix)*integ_fp_B(1,xx(ix),k,xmin,xmax)
        pk_B112 = pk_B112+ww(ix)*integ_fp_B(2,xx(ix),k,xmin,xmax)
        pk_B121 = pk_B121+ww(ix)*integ_fp_B(3,xx(ix),k,xmin,xmax)
        pk_B122 = pk_B122+ww(ix)*integ_fp_B(4,xx(ix),k,xmin,xmax)
        pk_B211 = pk_B211+ww(ix)*integ_fp_B(5,xx(ix),k,xmin,xmax)
        pk_B212 = pk_B212+ww(ix)*integ_fp_B(6,xx(ix),k,xmin,xmax)
        pk_B221 = pk_B221+ww(ix)*integ_fp_B(7,xx(ix),k,xmin,xmax)
        pk_B222 = pk_B222+ww(ix)*integ_fp_B(8,xx(ix),k,xmin,xmax)
        pk_B312 = pk_B312+ww(ix)*integ_fp_B(9,xx(ix),k,xmin,xmax)
        pk_B321 = pk_B321+ww(ix)*integ_fp_B(10,xx(ix),k,xmin,xmax)
        pk_B322 = pk_B322+ww(ix)*integ_fp_B(11,xx(ix),k,xmin,xmax)
        pk_B422 = pk_B422+ww(ix)*integ_fp_B(12,xx(ix),k,xmin,xmax)
        pk_A11 = pk_A11+ww(ix)*integ_fp_A(1,xx(ix),k,xmin,xmax)
        pk_A12 = pk_A12+ww(ix)*integ_fp_A(2,xx(ix),k,xmin,xmax)
        pk_A22 = pk_A22+ww(ix)*integ_fp_A(3,xx(ix),k,xmin,xmax)
        pk_A23 = pk_A23+ww(ix)*integ_fp_A(4,xx(ix),k,xmin,xmax)
        pk_A33 = pk_A33+ww(ix)*integ_fp_A(5,xx(ix),k,xmin,xmax)     
        pk_tA11 = pk_tA11+ww(ix)*integ_fp_A(6,xx(ix),k,xmin,xmax)
        pk_tA12 = pk_tA12+ww(ix)*integ_fp_A(7,xx(ix),k,xmin,xmax)
        pk_tA22 = pk_tA22+ww(ix)*integ_fp_A(8,xx(ix),k,xmin,xmax)
        pk_tA23 = pk_tA23+ww(ix)*integ_fp_A(9,xx(ix),k,xmin,xmax)
        pk_tA33 = pk_tA33+ww(ix)*integ_fp_A(10,xx(ix),k,xmin,xmax)
        pk_aa11 = pk_aa11+ww(ix)*integ_fp_A(11,xx(ix),k,xmin,xmax)
        pk_aa12 = pk_aa12+ww(ix)*integ_fp_A(12,xx(ix),k,xmin,xmax)
        pk_aa22 = pk_aa22+ww(ix)*integ_fp_A(13,xx(ix),k,xmin,xmax)
        pk_aa23 = pk_aa23+ww(ix)*integ_fp_A(14,xx(ix),k,xmin,xmax)
        pk_aa33 = pk_aa33+ww(ix)*integ_fp_A(15,xx(ix),k,xmin,xmax)
      enddo

      kfact = k**3 / (2.*pi)**2

      pk_B111 = 2.d0 * pk_B111 * kfact
      pk_B112 = - 2.d0 * pk_B112 * kfact
      pk_B121 = - 2.d0 * pk_B121 * kfact
      pk_B122 = 2.d0 * pk_B122 * kfact
      pk_B211 = 2.d0 * pk_B211 * kfact
      pk_B212 = - 2.d0 * pk_B212 * kfact
      pk_B221 = - 2.d0 * pk_B221 * kfact
      pk_B222 = 2.d0 * pk_B222 * kfact
      pk_B312 = - 2.d0 * pk_B312 * kfact
      pk_B321 = - 2.d0 * pk_B321 * kfact
      pk_B322 = 2.d0 * pk_B322 * kfact
      pk_B422 = 2.d0 * pk_B422 * kfact
      pk_A11 = 2.d0 * pk_A11 * kfact
      pk_A12 = 2.d0 * pk_A12 * kfact
      pk_A22 = 2.d0 * pk_A22 * kfact
      pk_A23 = 2.d0 * pk_A23 * kfact
      pk_A33 = 2.d0 * pk_A33 * kfact
      pk_tA11 = 2.d0 * pk_tA11 * kfact
      pk_tA12 = 2.d0 * pk_tA12 * kfact
      pk_tA22 = 2.d0 * pk_tA22 * kfact
      pk_tA23 = 2.d0 * pk_tA23 * kfact
      pk_tA33 = 2.d0 * pk_tA33 * kfact
      pk_aa11 = 2.d0 * pk_aa11 * kfact
      pk_aa12 = 2.d0 * pk_aa12 * kfact
      pk_aa22 = 2.d0 * pk_aa22 * kfact
      pk_aa23 = 2.d0 * pk_aa23 * kfact
      pk_aa33 = 2.d0 * pk_aa33 * kfact

      !write(6,'(i4,1p4e18.10)') ik,k,pk(ik),pk_B111(ik),pk_B112(ik)
         
      pk_B1 = ff**2*pk_B111 + ff**3*pk_B112 + ff**3*pk_B121 + ff**4*pk_B122
      pk_B2 = ff**2*pk_B211 + ff**3*pk_B212 + ff**3*pk_B221 + ff**4*pk_B222
      pk_B3 =                 ff**3*pk_B312 + ff**3*pk_B321 + ff**4*pk_B322
      pk_B4 =                                                 ff**4*pk_B422

      pk_A1 = ff*(pk_A11+pk_tA11+pk_aa11) + ff**2*(pk_A12+pk_tA12+pk_aa12) 
      pk_A2 =                               ff**2*(pk_A22+pk_tA22+pk_aa22) + ff**3*(pk_A23+pk_tA23+pk_aa23) 
      pk_A3 =                                                                ff**3*(pk_A33+pk_tA33+pk_aa33) 

      alpha = (k*ff*sigmav)**2.0

      fact00 = fact(0,0,alpha) 
      fact10 = fact(1,0,alpha) 
      fact20 = fact(2,0,alpha)
      fact30 = fact(3,0,alpha)
      fact40 = fact(4,0,alpha)

      fact02 = fact(0,2,alpha) 
      fact12 = fact(1,2,alpha) 
      fact22 = fact(2,2,alpha)
      fact32 = fact(3,2,alpha)
      fact42 = fact(4,2,alpha)

      fact04 = fact(0,4,alpha) 
      fact14 = fact(1,4,alpha) 
      fact24 = fact(2,4,alpha)
      fact34 = fact(3,4,alpha)
      fact44 = fact(4,4,alpha)
      
      call calc_bias_corr(k,pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8)

      pdd = pk_dd(ik)*b1**2
      pdt = pk_dt(ik)*b1
      ptt = pk_tt(ik)
      pdd = pdd + 2.0*b1*b2*pb1 + 2.0*bs2*b1*pb3 + 2.0*b2*bs2*pb5 + bs2**2*pb6 + b2**2*pb7 + &
        2.0*b3nl*pb8*find_pk(k)
      pdt = pdt + b2*pb2 + bs2*pb4 + b3nl*pb8*find_pk(k)
   
      pk0dd(ik) = fact00*pdd
      pk2dd(ik) = fact02*pdd
      pk4dd(ik) = fact04*pdd

      pk0dt(ik) = 2*ff*fact10*pdt
      pk2dt(ik) = 2*ff*fact12*pdt
      pk4dt(ik) = 2*ff*fact14*pdt

      pk0tt(ik) = ff**2*fact20*ptt
      pk2tt(ik) = ff**2*fact22*ptt
      pk4tt(ik) = ff**2*fact24*ptt

      ! Note A(k,mu,f) ~ kmuf (eqn 19) and B(k,mu,f) ~ (kmuf)^2 (eqn 20 of Taruya 2010)
      ! Writing as A(k,mu,beta) so f->beta means B ~ b_1^2 and A ~ b_1

      pk0corr_B(ik) = (fact10 * pk_B1 + fact20 * pk_B2 + fact30 * pk_B3 + fact40 * pk_B4)*b1**2.0
      pk2corr_B(ik) = (fact12 * pk_B1 + fact22 * pk_B2 + fact32 * pk_B3 + fact42 * pk_B4)*b1**2.0
      pk4corr_B(ik) = (fact14 * pk_B1 + fact24 * pk_B2 + fact34 * pk_B3 + fact44 * pk_B4)*b1**2.0

      pk0corr_A(ik) = (fact10 * pk_A1 + fact20 * pk_A2 + fact30 * pk_A3)*b1**1.0
      pk2corr_A(ik) = (fact12 * pk_A1 + fact22 * pk_A2 + fact32 * pk_A3)*b1**1.0
      pk4corr_A(ik) = (fact14 * pk_A1 + fact24 * pk_A2 + fact34 * pk_A3)*b1**1.0

      pk0(:) = pk0dd(:)+pk0dt(:)+pk0tt(:)+pk0corr_A(:)+pk0corr_B(:)
      pk2(:) = pk2dd(:)+pk2dt(:)+pk2tt(:)+pk2corr_A(:)+pk2corr_B(:)
      pk4(:) = pk4dd(:)+pk4dt(:)+pk4tt(:)+pk4corr_A(:)+pk4corr_B(:)
         
      !write(6,'(i4,1p100e11.3)') ik,k,pk0dd(ik),pk2dd(ik),pk4dd(ik),&
      !  pk0dt(ik),pk2dt(ik),pk4dt(ik),pk0tt(ik),pk2tt(ik),pk4tt(ik), &
      !  pk0corr_B(ik),pk2corr_B(ik),pk4corr_B(ik),pk0corr_A(ik),pk2corr_A(ik),pk4corr_A(ik)
         
    end subroutine calc_correction

! ******************************************************* 

    subroutine calc_pkred()
  
!     Summing up all contributions to redshift P(k) in PT
!     and calculating monopole, quadrupole and hexadecapole
!     spectra

      implicit none
      integer ik
      
      !$OMP PARAllEl DO DEFAUlT(SHARED),SCHEDUlE(DYNAMIC) &
      !$OMP & PRIVATE(ik)
      do ik=1,nk
         call calc_correction(ik)
      end do
      !$OMP END PARAllEl DO

    end subroutine calc_pkred

! ******************************************************* 

    subroutine output_pkred(filename)

      implicit none
      character(len=200) filename
      integer ik
      
      open(unit=11,file=trim(filename)//'_l0.dat',status='unknown')
      do ik=1,nk
         write(11,'(1p100e11.3)') ak(ik),pk0dd(ik),pk0dt(ik),pk0tt(ik),pk0corr_A(ik),pk0corr_B(ik)
      end do
      close(11)

      open(unit=11,file=trim(filename)//'_l2.dat',status='unknown')
      do ik=1,nk
         write(11,'(1p100e11.3)') ak(ik),pk2dd(ik),pk2dt(ik),pk2tt(ik),pk2corr_A(ik),pk2corr_B(ik)
      end do
      close(11)

      open(unit=11,file=trim(filename)//'_l4.dat',status='unknown')
      do ik=1,nk
         write(11,'(1p100e11.3)') ak(ik),pk4dd(ik),pk4dt(ik),pk4tt(ik),pk4corr_A(ik),pk4corr_B(ik)
      end do
      close(11)

    end subroutine output_pkred

! ******************************************************* 

    subroutine apply_window(filename,outfile)

      implicit none
      character(len=200) filename,outfile

      integer ikmax
      parameter(ikmax=200000)
      integer ik, ikw_max, ikk
      real(DP) :: ak_temp(ikmax), akp_temp(ikmax)
      real(DP) :: win00_temp(ikmax),win02_temp(ikmax),win04_temp(ikmax)
      real(DP) :: win20_temp(ikmax),win22_temp(ikmax),win24_temp(ikmax)
      real(DP) :: win40_temp(ikmax),win42_temp(ikmax),win44_temp(ikmax)
      real(DP) :: ak_prev,akp(ikmax)
      real(DP) :: win00(ikmax),win02(ikmax),win04(ikmax)
      real(DP) :: win20(ikmax),win22(ikmax),win24(ikmax)
      real(DP) :: win40(ikmax),win42(ikmax),win44(ikmax)
      real(DP) :: sum0,sum2,sum4

      ak_temp(:) = 0.0d0
      akp_temp(:) = 0.0d0
      win00_temp(:) = 0.0d0
      win02_temp(:) = 0.0d0
      win04_temp(:) = 0.0d0
      win20_temp(:) = 0.0d0
      win22_temp(:) = 0.0d0
      win24_temp(:) = 0.0d0
      win40_temp(:) = 0.0d0
      win42_temp(:) = 0.0d0
      win44_temp(:) = 0.0d0

      open(9, file=trim(filename), status='unknown')
      do ik=1, ikmax
         read(9,*,END=10) ak_temp(ik), akp_temp(ik),&
              win00_temp(ik),win02_temp(ik),win04_temp(ik),&
              win20_temp(ik),win22_temp(ik),win24_temp(ik),&
              win40_temp(ik),win42_temp(ik),win44_temp(ik)
      enddo
10    continue
      close(9)

      ikw_max = ik-1
    
      open(11,file=trim(outfile),status='unknown')

      ak_prev = 0.0d0
      ikk = 1
      do ik=1,ikw_max
         if (ak_temp(ik).ne.ak_prev) then
            if (ik.ne.1) then
               write(11,'(10E15.5)') ak_prev,2*pi*sum0,2*pi*sum2,2*pi*sum4
            end if
            akp(:) = 0.0d0
            win00(:) = 0.0d0
            win02(:) = 0.0d0
            win04(:) = 0.0d0
            win20(:) = 0.0d0
            win22(:) = 0.0d0
            win24(:) = 0.0d0
            win40(:) = 0.0d0
            win42(:) = 0.0d0
            win44(:) = 0.0d0
            ikk = 1
            ak_prev = ak_temp(ik)
            sum0 = 0.0d0
            sum2 = 0.0d0
            sum4 = 0.0d0
         end if
         akp(ikk) = akp_temp(ik)
         win00(ikk) = win00_temp(ik)
         win02(ikk) = win02_temp(ik)
         win04(ikk) = win04_temp(ik)
         win20(ikk) = win20_temp(ik)
         win22(ikk) = win22_temp(ik)
         win24(ikk) = win24_temp(ik)
         win40(ikk) = win40_temp(ik)
         win42(ikk) = win42_temp(ik)
         win44(ikk) = win44_temp(ik)
         if (akp(ikk)>0.0d0 .and. akp(ikk)<0.3d0) then
            if (ikk>1) then
               sum0 = sum0 + &
                    (find_pkl(1,akp(ikk))*akp(ikk)**2*win00(ikk)+find_pkl(1,akp(ikk-1))*akp(ikk-1)**2*win00(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(2,akp(ikk))*akp(ikk)**2*win02(ikk)+find_pkl(2,akp(ikk-1))*akp(ikk-1)**2*win02(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(3,akp(ikk))*akp(ikk)**2*win04(ikk)+find_pkl(3,akp(ikk-1))*akp(ikk-1)**2*win04(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 
               sum2 = sum2 +  &
                    (find_pkl(1,akp(ikk))*akp(ikk)**2*win20(ikk)+find_pkl(1,akp(ikk-1))*akp(ikk-1)**2*win20(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(2,akp(ikk))*akp(ikk)**2*win22(ikk)+find_pkl(2,akp(ikk-1))*akp(ikk-1)**2*win22(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(3,akp(ikk))*akp(ikk)**2*win24(ikk)+find_pkl(3,akp(ikk-1))*akp(ikk-1)**2*win24(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 
               sum4 = sum4 +  &
                    (find_pkl(1,akp(ikk))*akp(ikk)**2*win40(ikk)+find_pkl(1,akp(ikk-1))*akp(ikk-1)**2*win40(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(2,akp(ikk))*akp(ikk)**2*win42(ikk)+find_pkl(2,akp(ikk-1))*akp(ikk-1)**2*win42(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 + &
                    (find_pkl(3,akp(ikk))*akp(ikk)**2*win44(ikk)+find_pkl(3,akp(ikk-1))*akp(ikk-1)**2*win44(ikk-1))*(akp(ikk)-akp(ikk-1))/2.0 
            end if
         end if
         ikk=ikk+1
      end do

      close(11)

    end subroutine apply_window

! ******************************************************* 

      function fact(n, l, alpha)

!     (2l+1)/2 * integ dmu  mu^(2n) * exp(-alpha*mu^2) * P_l(mu)

      implicit none
      integer n, l
      real(DP) fact, nn, alpha
      nn = dble(n)

      if(alpha.gt.0.05) then

         if(l.eq.0) then
            fact = gamhalf(n) * gammp(0.5+nn,alpha)
            fact = fact / alpha**(nn+0.5) / 4.d0
         elseif(l.eq.2) then
            fact = alpha * gamhalf(n) * gammp(0.5+nn,alpha) &
                - 3.d0 * gamhalf(n+1) * gammp(1.5+nn,alpha) 
            fact = fact / alpha**(nn+1.5) * (-5.d0/8.d0)
         elseif(l.eq.4) then
            fact = 12.*gamhalf(n)*gammp(0.5+nn,alpha)/alpha**(n+0.5)  &
                -120.*gamhalf(n+1)*gammp(1.5+nn,alpha)/alpha**(n+1.5) &
                +140.*gamhalf(n+2)*gammp(2.5+nn,alpha)/alpha**(n+2.5)
            fact = fact * 9./128.
         endif

      else

         if(l.eq.0) then
            fact = 1./(2.+4.*nn) - alpha/(6.+4.*nn) + alpha**2/(20.+8.*nn) 
         elseif(l.eq.2) then
            fact = nn/(3.+8.*nn+4.*nn**2) &
                - (nn+1.)*alpha/(15.+16.*nn+4.*nn**2) &
                + (nn+2.)*alpha**2/(70.+48.*nn+8.*nn**2)
            fact = fact * 5.d0
         elseif(l.eq.4) then
            fact = dble(n*(n-1))/dble(15+46*n+36*n**2+8*n**3) &
                - dble(n*(n+1))/dble(105+142*n+60*n**2+8*n**3)*alpha &
                + dble((n+1)*(n+2))/dble(315+286*n+84*n**2+8*n**3) &
                *alpha**2/2.d0
            fact = fact * 18.d0
         endif
         
      endif

      fact = fact * (1.d0 + (-1.d0)**(2.*nn)) 
      
    end function fact

! ******************************************************* 

    subroutine calc_bias_corr(k,pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8)

      !\int d^3q /(2*pi)^3 G^(2)(k-q,q) * P(k-q) * P(q)

      real(DP) :: k,kmin,kmax,xmin,xmax
      real(DP) :: xx(ixmax), wx(ixmax),x
      integer ix
      real(DP) :: i1,i2,i3,i4,i5,i6,i7,i8
      real(DP) :: pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8
      real(DP) :: plin2

      kmin = ak(1)
      kmax = ak(nk)

      pb1 = 0.0d0
      pb2 = 0.0d0
      pb3 = 0.0d0
      pb4 = 0.0d0
      pb5 = 0.0d0
      pb6 = 0.0d0
      pb7 = 0.0d0
      pb8 = 0.0d0
      plin2 = 0.0d0

      xmin = kmin / k
      xmax = kmax / k

      call gaulegf(dlog(xmin),dlog(xmax),xx,wx,ixmax)
      
      ! Gauss-Legendre integration over x (=q/k)

      do ix=1,ixmax
         x = dexp(xx(ix))
         call  calc_integ_bias_corr(k,x,xmin,xmax,i1,i2,i3,i4,i5,i6,i7,i8)
         pb1 = pb1 + wx(ix)*i1*x**3
         pb2 = pb2 + wx(ix)*i2*x**3
         pb3 = pb3 + wx(ix)*i3*x**3
         pb4 = pb4 + wx(ix)*i4*x**3
         pb5 = pb5 + wx(ix)*i5*x**3
         pb6 = pb6 + wx(ix)*i6*x**3
         pb7 = pb7 + wx(ix)*i7*x**3
         plin2 = plin2 + wx(ix)*x**3*find_pk(x*k)**2.0
         pb8 = pb8 + wx(ix)*i8*x**3
      end do
      
      pb1 = 2.0*pb1 * k**3 / (2.d0*pi)**2
      pb2 = 2.0*pb2 * k**3 / (2.d0*pi)**2
      pb3 = 2.0*pb3 * k**3 / (2.d0*pi)**2
      pb4 = 2.0*pb4 * k**3 / (2.d0*pi)**2
      pb5 = 2.0*pb5 * k**3 / (2.d0*pi)**2
      pb6 = 2.0*pb6 * k**3 / (2.d0*pi)**2
      pb7 = 2.0*pb7 * k**3 / (2.d0*pi)**2
      plin2 = 2.0*plin2 * k**3 / (2.d0*pi)**2
      pb8 = 2.0*pb8 * k**3 / (2.d0*pi)**2

      pb5 = -0.5*(2.0/3.0*plin2-pb5)
      pb6 = -0.5*(4.0/9.0*plin2-pb6)
      pb7 = -0.5*(plin2-pb7)
      pb8 = pb8*105.0/16.0

      !write(*,'(10E15.5)') k,find_pk(k),pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8

    end subroutine calc_bias_corr

    subroutine calc_integ_bias_corr(k,x,xmin,xmax,i1,i2,i3,i4,i5,i6,i7,i8)
      
      implicit none
      real(DP) :: k,x,xmin,xmax
      real(DP) :: i1,i2,i3,i4,i5,i6,i7,i8
      real(DP) :: mumin,mumax
      real(DP) :: mmu(imu_max), wmu(imu_max)
      real(DP) :: k1,k2,k3,k4,k5,k6,k7,k8
      integer :: imu
      
      i1 = 0.0d0
      i2 = 0.0d0
      i3 = 0.0d0
      i4 = 0.0d0
      i5 = 0.0d0
      i6 = 0.0d0
      i7 = 0.0d0
      i8 = 0.0d0
      
      mumin = max(-1.d0, (1.d0+x**2-xmax**2)/2.d0/x)
      mumax = min( 1.d0, (1.d0+x**2-xmin**2)/2.d0/x)

      if(x.ge.0.5d0) mumax= 0.5d0/x
      
      call gaulegf(mumin, mumax, mmu, wmu, imu_max)

      do imu=1, imu_max
         call kernel_pkcorr(k,x,mmu(imu),k1,k2,k3,k4,k5,k6,k7,k8)
         i1 = i1 + wmu(imu) * k1
         i2 = i2 + wmu(imu) * k2
         i3 = i3 + wmu(imu) * k3
         i4 = i4 + wmu(imu) * k4
         i5 = i5 + wmu(imu) * k5
         i6 = i6 + wmu(imu) * k6
         i7 = i7 + wmu(imu) * k7
         i8 = i8 + wmu(imu) * k8
      enddo

    end subroutine calc_integ_bias_corr
      
    subroutine kernel_pkcorr(k,x,mu,k1,k2,k3,k4,k5,k6,k7,k8)

      implicit none
      real(DP) :: k,x,mu
      real(DP) :: k1,k2,k3,k4,k5,k6,k7,k8
      real(DP) :: kq,q, pk_q,pk_kq
      
      kq = k*dsqrt(1.d0+x**2-2.d0*mu*x)
      q = k*x
      
      pk_q = find_pk(q)
      pk_kq = find_pk(kq)
      
      k1 = pk_q*pk_kq*kernel(1,kq,q,k,mu)
      k2 = pk_q*pk_kq*kernel(2,kq,q,k,mu)
      k3 = pk_q*pk_kq*kernel(3,kq,q,k,mu)
      k4 = pk_q*pk_kq*kernel(4,kq,q,k,mu)
      k5 = pk_q*pk_kq*kernel(5,kq,q,k,mu)
      k6 = pk_q*pk_kq*kernel(6,kq,q,k,mu)
      k7 = pk_q*pk_kq
      k8 = pk_q*kernel(7,kq,q,k,mu)

    end subroutine kernel_pkcorr

    function kernel(a, k1, k2, k3,mu)

!     a=1 for kernel of pk_b2d
!     a=2 for kernel of pk_b2t
!     a=3 for kernel of pk_bs2d
!     a=4 for kernel of pk_bs2t
!     a=5 partial kernel for pk_b2s2
!     a=6 partial kernel for pk_bs22
!     a=7 kernel for sigma_3^2

      implicit none
      
      integer a
      real(DP)   kernel, k1, k2, k3, k1dk2, mu
      k1dk2 = ( k3**2 - k1**2 - k2**2 ) / 2.d0

      if(a.eq.1) kernel = 5.d0/7.d0 + 0.5d0*k1dk2* &
           (1.d0/k1**2 + 1.d0/k2**2) + 2.d0/7.d0*(k1dk2/(k1*k2))**2
      if(a.eq.2) kernel = 3.d0/7.d0 + 0.5d0*k1dk2* &
           (1.d0/k1**2 + 1.d0/k2**2) + 4.d0/7.d0*(k1dk2/(k1*k2))**2
      if(a.eq.3) kernel = (5.d0/7.d0 + 0.5d0*k1dk2* &
           (1.d0/k1**2 + 1.d0/k2**2) + 2.d0/7.d0*(k1dk2/(k1*k2))**2)* &
           ((k1dk2/(k1*k2))**2-1.0/3.0)
      if(a.eq.4) kernel = (3.d0/7.d0 + 0.5d0*k1dk2* &
           (1.d0/k1**2 + 1.d0/k2**2) + 4.d0/7.d0*(k1dk2/(k1*k2))**2)* &
           ((k1dk2/(k1*k2))**2-1.0/3.0) 
      if(a.eq.5) kernel = ((k1dk2/(k1*k2))**2-1.0/3.0)
      if(a.eq.6) kernel = ((k1dk2/(k1*k2))**2-1.0/3.0)**2.0
      if(a.eq.7) kernel = 2.0d0/7.0d0*(mu**2-1.0)*((k1dk2/(k1*k2))**2-1.0/3.0)+8.0/63.0

    end function kernel
    
  end module pk_rsd


