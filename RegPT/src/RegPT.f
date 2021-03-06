c ********************************************************** c
c
      program RegPT
c                                                            c
c               Time-stamp: <2012-07-31 13:43:30 ataruya>    c
c                                                            c
c    ataruya@phys.s.u-tokyo.ac.jp                            c
c    francis.bernardeau@cea.fr                               c
c ********************************************************** c
c
c     Stand-alone version
c
c     Computation of non-linear power spectrum and correlation 
c     function at 2-loop order in arbitrary (flat) cosmology 
c     with direct method and fast method based on the pre-computed 
c     data of RegPT results for fiducial cosmology.
c
c     Output format of the data file 'aaa_pk_RegPT.dat' :
c
c     k, [data for z_1], [data for z_2], ..., [data for z_n]
c
c     where [data for z_i] represents the chunked data for 
c     spectrum data at redshift z_i: 
c
c      P_no-wiggle(k,z_i), P_lin(k,z_i), P_RegPT_direct(k,z_i), err
c
c     where err is the difference between fast and direct methods
c     when -direct option is set. Otherwise the format is
c
c      P_no-wiggle(k,z_i), P_lin(k,z_i), P_RegPT_fast(k,z_i), 0.
c 
c     ---------------------------------------------------------
c
c     Output format of the data file 'aaa_xi_RegPT.dat':
c
c     r, [data for z_1], [data for z_2], ..., [data_for z_n]
c
c     where [data for z_i] represents the chunked data for correlation
c     function data: 
c
c     Xi_lin(r,z_i), Xi_RegPT_fast(r,z_i)
c     ---------------------------------------------------------
c
c     Output format for 'aaa_st_PT.dat':
c
c     k, P_no-wiggle(k),P_lin(k),G1_1loop,G1_2loop,
c        Pk_G2_tree-G2-tree,Pk_G2_1loop-G2-tree,Pk_G2_1loop-G2_1loop
c        Pk_G3_tree-G3_tree
c     ---------------------------------------------------------
c
      implicit none
      integer  iboost, inum_z, imodel_fid
      real*8  cosm_params(7)
      real*8  D_growth(100), sigma8_boost, kmin, kmax
c     -----------------------------------------------------
c
      integer iarg, nargs,inz,ikmax,ik_max,kl
      parameter(ikmax=2000)
      real*8  ak(ikmax), pk(ikmax)
      character argc*60,argstr*60,infile*60,pkfile*60,stfile*60
      character intype*9,xifile*60,cfid*10,args(103)*60,flag_phys*1
      character paramsfile*60,pref*60,path*60,mpath*60
      integer iverbose,ifast,icalc_xi,ifid,frack,lec,ia, icamb
      real*8 sigma8,z_red(100),omegam,omegab,w_de,hv,ns,iprec
      real*8 ombh2,omch2,Hubblev,omc,omb,oml,omn,omk,ommh2,omnuh2
      real*8 samp,spivot
      common /pk_data/ ak, pk, ik_max      
      common /commandline1/ intype,infile,pkfile,stfile,xifile
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns

c the computation and output default parameters
      path      = "./"
      mpath     = "data/"
      infile    = "matterpower.dat"
      pkfile    = "pk_RegPT.dat"
      xifile    = "xi_RegPT.dat"
      stfile    = "st_PT.dat"
      intype    = "spectrum"
      iverbose  = 1
      icalc_xi  = 0
      ifast     = 1
      icamb     = 1
      inum_z    = 1
      z_red(1)  = 0.5
      ifid      = 0

c the default cosmological parameters 
c     AJM - do I need to turn off rescaling? 
      sigma8    = 0.847
      omegam    = 0.279d0
      omegab    = 0.165 * omegam
      w_de      = -1.0
      ns        = .96d0
      Hubblev   = 70.1
      hv        = 0.701d0
      samp      = 2.1d-9
      spivot    = .05  ! [1/Mpc]

c reading of the command line options
      nargs   =iargc()
      do iarg=1,nargs
         call getarg(iarg,argc)
         lec=len(trim(argc))
         if (argc(lec-3:lec).eq.".ini") then
            paramsfile=trim(path)//argc
            open(9, file=paramsfile, status='old',err=104)
            do kl=1,ikmax
               read(9,*,END=19) (args(ia),ia=1,3)
               if (args(1).eq."verbose") 
     &              read(args(3),*,err=106) iverbose               
               if (args(1).eq."path") path=args(3)
               if (args(1).eq."datapath") mpath=args(3)
               if ((args(1).eq."fast").and.(args(3)(1:1).eq."T"))
     &              ifast=1
               if ((args(1).eq."fast").and.(args(3)(1:1).eq."F"))
     &              ifast=0
               if ((args(1).eq."direct").and.(args(3)(1:1).eq."T"))
     &              ifast=0
               if ((args(1).eq."direct").and.(args(3)(1:1).eq."F"))
     &              ifast=1
               if ((args(1).eq."direct1loop").and.(args(3)(1:1).eq."T"))
     &              ifast=2
               if ((args(1).eq."direct1loop").and.(args(3)(1:1).eq."F"))
     &              ifast=1
               if ((args(1).eq."xicompute").and.(args(3)(1:1).eq."T"))
     &              icalc_xi=1
               if ((args(1).eq."xicompute").and.(args(3)(1:1).eq."F"))
     &              icalc_xi=0
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."s"))
     &              intype="spectrum"
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."S"))
     &              intype="spectrum"
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."p"))
     &              intype="spectrum"
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."P"))
     &              intype="spectrum"
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."t"))
     &              intype="transfer"
               if ((args(1).eq."intype").and.(args(3)(1:1).eq."T"))
     &              intype="transfer"
               if (args(1).eq."camb") then 
                  paramsfile=args(3)
                  icamb = 0
               endif
               if (args(1).eq."infile") infile=args(3)
               if (args(1).eq."pkfile") pkfile=args(3)
               if (args(1).eq."xifile") xifile=args(3)
               if (args(1).eq."stfile") stfile=args(3)
               if (args(1).eq."sigma8") read(args(3),*,err=106) sigma8
               if (args(1).eq."omegam") read(args(3),*,err=106) omegam
               if (args(1).eq."omegab") read(args(3),*,err=106) omegab
               if (args(1).eq."w") read(args(3),*,err=106) w_de
               if (args(1).eq."h") read(args(3),*,err=106) hv
               if (args(1).eq."ns") read(args(3),*,err=106) ns
               if (args(1).eq."samp") read(args(3),*,err=106) samp
               if (args(1).eq."spivot") read(args(3),*,err=106) spivot
               if (args(1).eq."fiducial") then
                  if (args(3).eq."wmap3") ifid=1
                  if (args(3).eq."M001") ifid=2
                  if (args(3).eq."M023") ifid=3
               endif
               if (args(1).eq."nz") then
                  read(args(3),*,err=106) inum_z
                  inum_z=min(inum_z,100)
                  read(9,*,err=106) args(1),args(2),
     &                 (z_red(inz),inz=1,inum_z)
               endif
            enddo
 19         continue
            close(9)
         endif
         if (argc.eq."-noverbose") then
            iverbose=0
         endif
         if (argc.eq."-verbose") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) iverbose
         endif
         if (argc.eq."-path") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,path)
         endif
         if (argc.eq."-datapath") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,mpath)
         endif
         if (argc.eq."-direct") ifast=0
         if (argc.eq."-fast") ifast=1
         if (argc.eq."-direct1loop") ifast=2
         if (argc.eq."-spectrum") intype="spectrum"
         if (argc.eq."-transfer") intype="transfer"
         if (argc.eq."-infile") call getarg(iarg+1,infile)
         if (argc.eq."-pkfile") call getarg(iarg+1,pkfile)
         if (argc.eq."-xifile") call getarg(iarg+1,xifile)
         if (argc.eq."-stfile") call getarg(iarg+1,stfile)
         if (argc.eq."-camb" .or. icamb.eq.0) then
            if(icamb.ne.0) call getarg(iarg+1,paramsfile) 
            ombh2=0.
            omch2=0.
            omc=0.
            omb=0.
            open(9, file=paramsfile, status='old',err=104)
            do kl=1,ikmax
              read(9,*,END=14) args(1),args(2),args(3)
              if (args(1).eq.'use_physical') read(args(3),*) flag_phys
              if (args(1).eq.'hubble') read(args(3),*) Hubblev
              if (args(1).eq.'pivot_scalar') read(args(3),*) spivot
              if (args(1)(1:10).eq.'scalar_amp') read(args(3),*) samp
              if (args(1).eq.'ombh2') read(args(3),*) ombh2
              if (args(1).eq.'omch2') read(args(3),*) omch2
              if (args(1).eq.'omnuh2') read(args(3),*) omnuh2
              if (args(1).eq.'omk') read(args(3),*) omk
              if (args(1).eq.'omega_baryon') read(args(3),*) omb
              if (args(1).eq.'omega_cdm') read(args(3),*) omc
              if (args(1).eq.'omega_lambda') read(args(3),*) oml
              if (args(1).eq.'omega_neutrino') read(args(3),*) omn
              if (args(1).eq.'w') read(args(3),*) w_de
              if (args(1)(1:21).eq.'scalar_spectral_index') 
     &             read(args(3),*) ns
            enddo
 14         close(9)
            if(flag_phys.eq."T") then 
               if (omk.ne.0.) then 
                  write(6,*) omk, abs(omc+omb+oml+omn-1.)
                  write(6,*) ' ! Error : non-zero curvature models are 
     & not considered'
                  stop
               endif
               if (omnuh2.ne.0.) then
                  write(6,*) ' ! Error : massive neutrinos are not
     & considered'
                  stop
               endif
            elseif(flag_phys.eq."F") then 
               if (abs(omc+omb+oml+omn-1.).ge.1.d-3) then 
                  write(6,*) omk, abs(omc+omb+oml+omn-1.)
                  write(6,*) ' ! Error : non-zero curvature models are 
     & not considered'
                  stop
               endif
               if (omn.ne.0.) then
                  write(6,*) ' ! Error : massive neutrinos are not
     & considered'
                  stop
               endif
            endif
c
            hv=Hubblev/100.
            omegab=max(ombh2/hv/hv,omb)
            omegam=omegab+max(omch2/hv/hv,omc)
            if (iverbose.eq.2) then
               write(6,*) '> h =', hv
               write(6,*) '> omegam= ',omegam
               write(6,*) '> omegab= ',omegab
               write(6,*) '>      w= ',w_de
            endif
         endif
         if (argc.eq."-sigma8") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) sigma8
         endif
         if (argc.eq."-omegam") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) omegam
         endif
         if (argc.eq."-omegab") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) omegab
         endif
         if (argc.eq."-w") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) w_de
         endif
         if (argc.eq."-h") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) hv
         endif
         if (argc.eq."-ns") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) ns
         endif
         if (argc.eq."-samp") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) samp
         endif
         if (argc.eq."-spivot") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) spivot
         endif
         if (argc.eq."-fiducial") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,cfid)
            if (cfid.eq."wmap3") ifid=1
            if (cfid.eq."M001") ifid=2
            if (cfid.eq."M023") ifid=3
         endif
         if (argc.eq."-nz") then
            if (iarg.eq.nargs) goto 106
            call getarg(iarg+1,argstr)
            read(argstr,*,err=106) inum_z
            do inz=1,min(inum_z,20)
               if (iarg+inz.eq.nargs) goto 106
               call getarg(iarg+1+inz,argstr)
               read(argstr,*,err=106) z_red(inz)
            enddo
         endif
         if (argc.eq."-xicompute") then
            icalc_xi=1
         endif
      enddo
      infile=trim(path)//infile
      pkfile=trim(path)//pkfile
      xifile=trim(path)//xifile
      stfile=trim(path)//stfile
      if (iverbose.eq.2) then
         write(6,*) '> intype = ',intype
         write(6,*) '> infile = ',infile
         write(6,*) '> pkfile = ',pkfile
         write(6,*) '> xifile = ',xifile
         write(6,*) '> stfile = ',stfile
         write(6,*) '> omegam = ',omegam
         if(intype.eq."spectrum") then
            write(6,*) '> sigma8 = ',sigma8
         elseif(intype.eq."transfer") then
            write(6,*) '> samp = ',samp
            write(6,*) '> spivot = ',spivot
         endif
      endif         
c
c
c inline instructions when verbose <> 0      
      if (iverbose.ge.1) then
      write(6,*)  '-----------------------------------------------------
     &--------------------------'
      write(6,*)  ':  RegPT up to 2 loop order for P(k) and Xi(r)       
     &                         :'
      write(6,*)  '-----------------------------------------------------
     &--------------------------'
      write(6,*)  ': Description of the online options:                 
     &                         :' 
      write(6,*)  ':  "-noverbose", to suppress verbose                 
     &                         :'
      write(6,*)  ':  "-verbose" nn, to set verbose level at nn (default
     &=1)                      :'
      write(6,*)  ':                                                    
     &                         :'
      write(6,*)  ':  "-path aaa", to access path to input and ouput fil
     &es (default =./)         :'
      write(6,*)  ':  "-spectrum", to specify file type of the input fil
     &e as power spectrum,     :'
      write(6,*)  ':           that contains "k,P(k)" (default choice)  
     &                         :'
      write(6,*)  ':  "-transfer", to specify file type of the input fil
     &e as transfer function,  :'
      write(6,*)  ':           whose file format is the same as in the C
     &AMB output file          :'
      write(6,*)  ':  "-infile" aaa, to specify the input name file (def
     &ault = "matterpower.dat"):'
      write(6,*)  ':  "-camb" aaa, to use CAMB ouput parameter file for  
     &cosmological parameters  :'
      write(6,*)  ':                                                    
     &                         :'
      write(6,*)  ':  "-sigma8" xxx, to specify value of sigma8, 0. to l
     &eft it unchanged from    :'
      write(6,*)  ':           file, (default=0.817)                    
     &                         :'
      write(6,*)  ':  "-omegam" xxx, to specify the value of Omega_m (de
     &fault=.279)              :'
      write(6,*)  ':  "-omegab" xxx, to specify the value of Omega_b (de
     &fault=.046)              :'
      write(6,*)  ':  "-w" xxx, to specify the EOS of dark energy w  (de
     &fault=-1.0)              :'
      write(6,*)  ':  "-ns" xxx, to specify the value of ns (default=.96
     &)                        :'
      write(6,*)  ':  "-h" xxx, to specify the value of h (default=.70) 
     &                         :'
      write(6,*)  ':    Note that spatial curvature is forced to be flat
     &, i.e.                   :'
      write(6,*)  ':    Omega_DE=1-Omega_m. ns, Omega_b, and h are only 
     &used to compute the      :'
      write(6,*)  ':    no-wiggle power spectrum whereas Omega_m determi
     &nes the growth rate.     :'
      write(6,*)  ':                                                    
     &                         :'
      write(6,*)  ':  "-direct1loop"  to use direct method for 1-loop ca 
     &lculation                :'
      write(6,*)  ':  "-direct" to use fast AND direct method           
     &                         :'
      write(6,*)  ':  "-fast" to use fast method only (default choice)  
     &                         :'
      write(6,*)  ':                                                    
     &                         :'
      write(6,*)  ':  "-datapath" xxx, to specify the path access to the
     & data files of the       :'
      write(6,*)  ':           fiducial models (default = "data/")      
     &                         :'
      write(6,*)  ':  "-fiducial" aaa, to impose fiducial model, compute
     &r choice by default      :'
      write(6,*)  ':  "-nz" nn z1 z2..., to specify the number of redshi
     &fts (default=1, z=0.5)   :'
      write(6,*)  ':  "-xicompute", to compute 2-pt correlation functs (
     &not done by default)     :'
      write(6,*)  ':                                                    
     &                         :'
      write(6,*)  ':  "-pkfile" aaa, to specify the output file name of 
     &power spectrum as aaa,   :'
      write(6,*)  ':           (default = "pk_RegPT.dat")               
     &                         :'
      write(6,*)  ':  "-xifile" aaa, to specify the output file name of 
     &correlation func. as aaa,:'
      write(6,*)  ':           (default = "xi_RegPT.dat") This option is
     & valid when the option,  :'
      write(6,*)  ':           -xicompute, is specified                 
     &                         :'
      write(6,*)  ':  "-stfile" aaa, to specify the output file name of 
     &PT diagrams as aaa,      :'
      write(6,*)  ':           (default = "st_PT.dat")  This option is v
     &alid when the option,    :'
      write(6,*)  ':           -direct, is specified                    
     &                         :'
      write(6,*)  ':____________________________________________________
     &_________________________:'
      write(6,*)
      write(6,*) '    Execution log :'
      write(6,*)
      endif
c
c  ////// Load linear power specrum (target model) //////
c
      call load_matterpower_data(samp,spivot)
      iprec=ak(nint(.5*ik_max))/ak(nint(.5*ik_max)-1)-1.
      if (iverbose.ge.1) 
     &     write(6,'(A,f5.2,A,A)')' > wave modes are ',
     &     100.*iprec,'% apart in ',trim(infile)
      frack=1
      if (iprec.le..03) frack=max(1,nint(.03/iprec))
      if ((iverbose.ge.1).and.(frack.gt.1)) then
         write(6,*) '> output spacing is set such that k are 3% apart'
         write(6,'(15x,A,I2,A)') 'computation will be done every',frack,
     &        ' input value'
      endif
c
c  ////// Load linear power specrum (fiducial model) //////
c
      call load_matterpower_fid(imodel_fid, sigma8_boost,mpath)
c
c  ////// Load pre-computed RegPT data //////
c
      call load_precomputed_RegPT_data(imodel_fid,mpath)
c
c      if (iverbose.ge.1) then
c         write(6,*) '> pre-computed RegPT data, done'
c      endif
c
c  ////// Set parameters & output format //////
c
      call set_params(D_growth, cosm_params)
c
c  ////// Linear theory estimate of 1D velocity dispersion //////
c
ccc      call calc_sigmav2
c
ccc      write(6,*)
ccc      write(6,*) 'Calculation of sigma_v^2, done'
c
c  ////// Truncation of power spectrum data //////
c
      kmin = 5.d-4   ! default values
      kmax = 10.d0
      call truncation_k(kmin, kmax)
c
c  ////// RegPT main part //////
c
c     direct 1-loop calculation
c
      if(ifast.eq.2) then
         call calc_regpt_1loop(D_growth, frack)
         goto 99
      endif
c
c     fast 2-loop calculation
c
      call calc_regpt_fast(D_growth, sigma8_boost,frack)
c
      if (iverbose.ge.1) then
         write(6,*) '> Fast method calculation, done'
      endif
c
c     direct 2-loop calculation
c
      ! AJM 
      if (ifast.eq.0) then
         call calc_regpt_direct(1,1,D_growth, cosm_params,frack,'dd')
         call save_pk(D_growth, sigma8_boost, cosm_params,frack,'dd')
         call calc_regpt_direct(2,2,D_growth, cosm_params,frack,'tt')
         call save_pk(D_growth, sigma8_boost, cosm_params,frack,'tt')
         call calc_regpt_direct(1,2,D_growth, cosm_params,frack,'dt')
         call save_pk(D_growth, sigma8_boost, cosm_params,frack,'dt')

         if (iverbose.ge.1) then
            write(6,*) '> Calculation RegPT - direct method, done'
         endif
         
      endif
c
c  ////// Save power spectrum data  //////  c
c
 99   call save_pk(D_growth, sigma8_boost, cosm_params,frack,'default')
c
      if(iverbose.ge.2) call estimate_k_crit(D_growth, z_red)
c
c ////// Save correlation function data  (optional -xicompute) //////  c
c
      call save_xi(D_growth, sigma8_boost)
c
      goto 108
 104  write(6,*) ' ! Error, file not found: ',trim(paramsfile)
      stop
 106  write(6,*) ' ! Error in command line'
      stop
 108  continue
      end
c
c ******************************************************* c
c
      subroutine load_matterpower_data(samp,spivot)
c
c ******************************************************* c
c
c     matter power spectrum for target cosmological model
c
c     For intype='spectrum', the data is supposed to consist of 
c     two columns, i.e., k and P(k), where k is in units of [h/Mpc] 
c
c     For intype='transfer', the data is supposed to consist of 
c     7 columns, and 1st (k) and 7th columns (tm) are used to compute 
c     matter power spectrum P(k) in the following way (according to 
c     camb format):
c
c     P(k) = 2*pi^2 * h^4 * k * (k*h/spivot)^(ns-1) * tm^2
c
c     where k is in units of [h/Mpc], while spivot is in units of [1/Mpc]
c     
      implicit none
c
      integer ik, ikmax, ik_max, inorm
      parameter(ikmax=2000)
      real*8  ak(ikmax), pk(ikmax),ns, samp, spivot
      real*8  sigma_a, sigma_b, pi, W_TH, x, const, r_th
      real*8  tc,tb,tg,tr,tn,tm
      character infile*60,pkfile*60,stfile*60,xifile*60,intype*9
      integer iverbose,ifast,inum_z,icalc_xi,ifid
      real*8 sigma8,z_red(100),omegam,omegab,w_de,hv
      common /pk_data/ ak, pk, ik_max
      common /commandline1/ intype,infile,pkfile,stfile,xifile
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns
      pi = 4.d0 * datan(1.d0)
      r_th = 8.d0
c     -----------------------------------------------------
c
      open(9, file=infile, status='old',err=104)
      if (intype.eq."spectrum") then
         do ik=1, ikmax
            read(9,*,END=10) ak(ik), pk(ik)
         enddo
 10      ik_max = ik - 1 
         close(9)
      endif
      if (intype.eq."transfer") then
         do ik=1,ikmax
            read(9,*,END=11) ak(ik),tc,tb,tg,tr,tn,tm
            pk(ik)=samp * ak(ik) * (ak(ik)*hv/spivot)**(ns-1.) * tm**2
     &           * 2.d0*pi*pi * hv**4
         enddo
 11      ik_max = ik - 1 
         close(9)
      endif
c
      if (iverbose.ge.1) then
         write(6,'(A,A)')' > linear matter power spectrum: ',
     &      infile
         write(6,'(15x,A,1p2e14.8)') 'kmin=', ak(1)
         write(6,'(15x,A,1p2e14.8)') 'kmax=', ak(ik_max)
         write(6,'(15x,A,I4)') 'ik_max=',ik_max
      endif
c      read(5,*) inorm
c
c  ////// sigma8 normalization (optional) //////
c
      if(sigma8.ge.0.) then
c         write(6,*) 'Type sigma8 at z=0 '
c         read(5,*) sigma8 
c
         x = ak(1) * r_th
         if(x.lt.1.d-3) then
            W_TH = 1.d0 - x*x / 10.d0 + x**4 / 280.d0 
         else
            W_TH = 3.d0 * (sin(x) - x * cos(x))/x/x/x
         endif
         sigma_a = W_TH * W_TH * pk(1) * ak(1) * ak(1)
         sigma_a = sigma_a / (2.d0 * pi * pi)
c
         const = sigma_a * ak(1) / 2.d0
         do ik=2, ik_max
            x = ak(ik) * r_th
            if(x.lt.1.d-3) then
               W_TH = 1.d0 - x*x / 10.d0 + x**4 / 280.d0 
            else
               W_TH = 3.d0 * (sin(x) - x * cos(x))/x/x/x
            endif
            sigma_b = W_TH * W_TH * pk(ik) * ak(ik) * ak(ik) 
            sigma_b = sigma_b / (2.d0 * pi * pi)
            const = const + 
     &           (sigma_a + sigma_b) * ( ak(ik) - ak(ik-1) )/ 2.d0
            sigma_a = sigma_b
         enddo
c
         if (iverbose.ge.1) write(6,'(A,f5.3)') 
     &                           ' > sigma8 in file: ',const**.5
         if (sigma8.gt.0.) then
            do ik=1, ik_max
               pk(ik) = sigma8 * sigma8 / const * pk(ik) 
            enddo
            if (iverbose.ge.1) 
     &           write(6,'(15x,A,f5.3)')'set to sigma8 = ',sigma8
         endif
c
c         write(6,*)
c         write(6,*) 'normalization factor:', sigma8 * sigma8 / const
c         write(6,*)
c
      endif
      goto 105
 104  write(6,*) ' ! Error, file not found: ',trim(infile)
      stop
 105  continue
      end
c
c ******************************************************* c
c
      subroutine set_params(D_growth, cosm_params)
c
c ******************************************************* c
c
c     cosm_params(1) :  omega_m
c     cosm_params(2) :  omega_v
c     cosm_params(3) :  omega_b
c     cosm_params(4) :  h
c     cosm_params(5) :  T_cmb
c     cosm_params(6) :  n_s
c     cosm_params(7) :  w
c
      implicit none
      integer  iparams, isample_k, inum_k, isample_r, inum_r
      integer  iz
      real*8  kmin, kmax, rmin, rmax, cosm_params(7)
      real*8  D_growth(100), z_red(100)
      character infile*60,pkfile*60,stfile*60,xifile*60
      character intype*9
      integer iverbose,ifast,inum_z,icalc_xi,ifid
      real*8 sigma8,omegam,omegab,w_de,hv,ns
      common  /iset_k/  kmin, kmax, isample_k, inum_k
      common  /iset_r/  rmin, rmax, isample_r, inum_r
      common /commandline1/ intype,infile,pkfile,stfile,xifile
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns
c     -----------------------------------------------------
c
c     ///////// Set cosmological parameters ///////
c
c     cosmological parameters (wmap5) for target cosmology (default)
c
      cosm_params(1) = omegam
      cosm_params(2) = 1.d0 - omegam
      cosm_params(3) = omegab
      cosm_params(4) = hv
      cosm_params(5) = 2.726d0
      cosm_params(6) = ns
      cosm_params(7) = w_de
     
      do iz=1, inum_z
            call find_growth_factor(z_red(iz), cosm_params, 
     &        D_growth(iz))
      enddo
      if (iverbose.ge.1) then
         write(6,*)'> redshifts and growth rates'
         do iz=1, inum_z
            write(6,'(13x,f6.2,f8.4)') z_red(iz),D_growth(iz)
         enddo
      endif
      isample_k=1
      if(icalc_xi.eq.1) then
         isample_r=1
c         if(isample_r.eq.1) then
         rmin = 10.d0
         rmax = 200.d0
         inum_r = 501
c         elseif(isample_r.eq.2 .or. isample_r.eq.3) then
c            write(6,*) 
c            write(6,*) 
c     &           'Set output range [rmin, rmax] and number of points'
c            read(5,*) rmin, rmax, inum_r
c         endif
      endif
c
      end
c
c ******************************************************* c
c
      ! AJM
      subroutine save_pk(D_growth,sigma8_boost,cosm_params,frack,fn)
c
c ******************************************************* c
c
      implicit none
c
      integer ik, ikmax, ik_max, ik_max_fast
      integer iz, inum_z,frack,ia
      parameter(ikmax=2000)
      real*8  ak(ikmax), pk(ikmax)
      real*8  ak_fast(ikmax), pk_fast(ikmax,100), dpk_fast(ikmax,100)
      real*8  pk_main(ikmax,100)
      real*8  pk_EH(ikmax), D_growth(100), cosm_params(7)
c
      integer isample_k, inum_k 
      real*8  kmin, kmax, ak_out(ikmax), pklin_target, pklin_fid
      real*8  pk_RegPT_f(100), dpk_RegPT_f(100), sigma8_boost
      real*8  pk_RegPT_m(100)
      character  outfile*80, suffix_outfile*60
c
      character argc*60,infile*60,pkfile*60,stfile*60
      character intype*9, xifile*60
      character fn*60 
      integer iverbose,ifast,icalc_xi,ifid
      real*8 sigma8,z_red(100),omegam,omegab,w_de,hv,ns
      common  /pk_data/ ak, pk, ik_max
      common  /dpk_main/ pk_main
      common  /dpk_fast/ ak_fast, pk_fast, dpk_fast, ik_max_fast
      common  /iset_k/  kmin, kmax, isample_k, inum_k
c
      common  /commandline1/ intype,infile,pkfile,stfile,xifile
      common  /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common  /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns
c     -----------------------------------------------------
c
      ! AJM
      open(9, file=trim(pkfile)//'_'//trim(fn), status='unknown')

c
c  ////// No-wiggle power spectrum //////
c
      if(isample_k.eq.1) then
         call no_wiggle_pklin(ik_max,ak(1),ak_fast,pk_EH,cosm_params)
c
         do ik=1, ik_max,frack
            call find_pklin(1, ak_fast(ik),pklin_fid)
            if (ifast.eq.1 .or. ifast.eq.2) then
               write(9,'(1p401e18.10)') ak_fast(ik), 
     &              (D_growth(iz)**2*pk_EH(ik), 
     &              D_growth(iz)**2*pk(ik), 
     &              pk_fast(ik,iz)+dpk_fast(ik,iz),0., 
cc     &           D_growth(iz)**2*(pk(ik) - pklin_fid*sigma8_boost**2),  
     &              iz=1, inum_z )
            else
               write(9,'(1p401e18.10)') ak_fast(ik), 
     &              (D_growth(iz)**2*pk_EH(ik), 
     &              D_growth(iz)**2*pk(ik), 
     &              pk_main(ik,iz),
     &          (pk_fast(ik,iz)+dpk_fast(ik,iz))-pk_main(ik,iz),
     &              iz=1, inum_z )
            endif
         enddo
c
      else
c
         if(kmin.lt.ak_fast(1)) kmin=ak_fast(1)
         if(kmax.gt.ak_fast(ik_max_fast)) kmax=ak_fast(ik_max_fast)
c
         do ik=1, inum_k
            if(isample_k.eq.2) ak_out(ik) = 
     &           kmin * (kmax/kmin)**(dble(ik-1)/dble(inum_k-1))
            if(isample_k.eq.3) ak_out(ik) = 
     &           kmin + (kmax-kmin)*(dble(ik-1)/dble(inum_k-1))
c            write(6,*) 
         enddo
c
         call no_wiggle_pklin(inum_k, ak(1), ak_out, pk_EH, cosm_params)
c
         do ik=1, inum_k
            call find_pklin(2, ak_out(ik), pklin_target)
            call find_pklin(1, ak_out(ik), pklin_fid)
            call find_pk_fast(1, inum_z, ak_out(ik), pk_RegPT_f) 
            call find_pk_fast(2, inum_z, ak_out(ik), dpk_RegPT_f) 
            call find_pk_main(inum_z, ak_out(ik), pk_RegPT_m) 
            if (ifast.eq.1 .or. ifast.eq.2) then
               write(9,'(1p401e18.10)') ak_fast(ik), 
     &              ( D_growth(iz)**2*pk_EH(ik), 
     &              D_growth(iz)**2*pklin_target, 
     &              pk_RegPT_f(iz)+dpk_RegPT_f(iz),0., 
cc     &           D_growth(iz)**2*(pk(ik) - pklin_fid*sigma8_boost**2),  
     &              iz=1, inum_z )
            else
               write(9,'(1p401e18.10)') ak_fast(ik), 
     &              ( D_growth(iz)**2*pk_EH(ik), 
     &              D_growth(iz)**2*pklin_target, 
     &              pk_RegPT_m(iz),
     &          (pk_RegPT_f(iz)+dpk_RegPT_f(iz))-pk_RegPT_m(iz),
     &              iz=1, inum_z )
            endif
         enddo
c
      endif

      close(9)
c
      if (iverbose.ge.1) then
         write(6,'(A,A)') ' > power spectra saved in ',trim(pkfile)
      endif
c
      end
c
c ******************************************************* c
c
      subroutine save_xi(D_growth, sigma8_boost)
c
c ******************************************************* c
c
      implicit none
c
      integer ir, irmax, iz
      parameter(irmax=1000)
      real*8  ar(irmax), xi_lin(irmax)
      real*8  xi_fast(irmax,100), dxi_fast(irmax,100)
      real*8  dxi_lin(irmax)
      real*8  D_growth(100), sigma8_boost
c
      integer isample_r, inum_r
      real*8  rmin, rmax
      character outfile*80, suffix_outfile*60
      character argc*60,infile*60,pkfile*60,stfile*60
      character intype*9, xifile*60
      integer iverbose,ifast,inum_z,icalc_xi,ifid
      real*8 sigma8,z_red(100),omegam,omegab,w_de,hv,ns
c
      common  /dxi_fast/ ar, xi_lin, xi_fast, dxi_fast, dxi_lin
      common  /iset_r/  rmin, rmax, isample_r, inum_r
c
      common  /commandline1/ intype,infile,pkfile,stfile,xifile
      common  /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common  /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns
c     -----------------------------------------------------
c
      if(icalc_xi.eq.1) then
c
         call calc_xi(sigma8_boost)
c
         open(10, file=xifile, status='unknown')
         do ir=1, inum_r
            write(10,'(1p301e18.10)') ar(ir), 
     &           ( D_growth(iz)**2*xi_lin(ir), 
     &           xi_fast(ir,iz)+dxi_fast(ir,iz), 
cc     &           D_growth(iz)**2*dxi_lin(ir),     ! new line added
     &           iz=1, inum_z )
         enddo
         close(10)
c
         if (iverbose.ge.1) then 
            write(6,*) '> correlation functions saved in ',
     &trim(xifile)
         endif
      endif
c
      end
c
c ********************************************************** c
c
      ! AJM
      subroutine calc_RegPT_direct(a, b, D_growth, cosm_params,frack,fn)
c
c ********************************************************** c
c     This routine computes the aray pk_main and save the diagram
c     values
c ********************************************************** c
c
      implicit none
c
      integer ik, iz, inum_z, inum_k,ikmax,ik_max,frack, a, b
      parameter(ikmax=2000)
      real*8  k,kmin,kmax
c      parameter(inum_k=12, k_IR=0.01d0, k_UV=0.40d0)
      real*8  D_growth(100)
c
      real*8  G1a_1loop, G1a_2loop, G1b_1loop, G1b_2loop
      real*8  pkcorr_G2_tree_tree, pkcorr_G2_tree_1loop
      real*8  pkcorr_G2_1loop_1loop, pkcorr_G3_tree
c
      real*8  sigmav2_running, pk_lin, exp_factor, G1a_reg, G1b_reg
      real*8  pkcorr_G1, pkcorr_G2, pkcorr_G3
      real*8  ak(ikmax), pk(ikmax),pk_EH(ikmax),cosm_params(7)
      real*8  ak_fast(ikmax), pk_fast(ikmax,100), dpk_fast(ikmax,100)
      real*8  pk_main(ikmax,100)
      integer isample_k
c
      character  outfile*80, suffix_outfile*60
      character argc*60,infile*60,pkfile*60,stfile*60
      character fn*60
      character intype*9, xifile*60
      integer iverbose,ifast,icalc_xi,ifid,ideb,iend
      real*8 sigma8,z_red(100),omegam,omegab,w_de,hv,ns
c
      common  /iset_k/  kmin, kmax, isample_k, inum_k
      common  /pk_data/ ak, pk, ik_max
      common  /dpk_main/ pk_main
      common  /commandline1/ intype,infile,pkfile,stfile,xifile
      common  /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      common  /commandline3/ sigma8,z_red,omegam,omegab,w_de,hv,ns
c     -----------------------------------------------------
c
c     open output file for the diagram values at z=0
c
      open(11, file=trim(stfile)//'_'//trim(fn), status='unknown')
c
      call no_wiggle_pklin(ik_max,ak(1),ak,pk_EH,cosm_params)
      if (iverbose.ge.2) then
         write(6,*) ' > Direct method calculations'
         write(6,*) ' > iz, k, pk_main'
      endif
      do ik=1, ik_max,frack
         k = ak(ik)
         call find_pklin(2, k, pk_lin)
         do iz=1,inum_z
            pk_main(ik,iz)=D_growth(iz)**2*pk_lin
         enddo
         if (k.le..01) ideb=ik
         if (k.le.1.02) iend=ik
      enddo

c     zedo padding just for late analysis
      do ik=1, ideb+frack-1, frack
         k = ak(ik)
         call find_pklin(2, k, pk_lin)
         write(11,'(1p9e18.10)') k, pk_EH(ik), pk_lin, 0.d0, 0.d0,
     &        0.d0, 0.d0, 0.d0, 0.d0
      enddo
c
      do ik=ideb+frack, iend,frack 
         k = ak(ik)
c
c     ///// RegPTmain calculations (at 2-loop level) ////
c
         if ((iverbose.eq.1).and.(ik.gt.ideb)) then
            if (mod(ik-ideb-frack,20*frack).eq.0) then
               write(6,'(A,i2,A)') ' > Direct computation done at ',
     &         nint((100.*(ik-frack-ideb))/(iend-ideb-frack)),
     &         ' percent.'
            endif
         endif
       
         call calc_pkcorr_from_Gamma1(a, b, k, G1a_1loop, G1a_2loop,
     &        G1b_1loop, G1b_2loop)
         call calc_pkcorr_from_Gamma2(a, b, k, pkcorr_G2_tree_tree,
     &        pkcorr_G2_tree_1loop, pkcorr_G2_1loop_1loop)
         call calc_pkcorr_from_Gamma3(a, b, k, pkcorr_G3_tree)

c
         call calc_running_sigmav2(k, sigmav2_running)
c
         call find_pklin(2, k, pk_lin)
c
         write(11,'(1p9e18.10)') k,pk_EH(ik),pk_lin,G1a_1loop,G1a_2loop,
     &        pkcorr_G2_tree_tree,pkcorr_G2_tree_1loop,
     &        pkcorr_G2_1loop_1loop,pkcorr_G3_tree
c
         do iz=1, inum_z
            exp_factor = 0.5d0 * (k*D_growth(iz))**2 * sigmav2_running
            G1a_reg = 1.d0 + exp_factor + 0.5*exp_factor**2 + 
     &           D_growth(iz)**2*G1a_1loop * (1.d0 + exp_factor) + 
     &           D_growth(iz)**4*G1a_2loop 
            G1b_reg = 1.d0 + exp_factor + 0.5*exp_factor**2 + 
     &        D_growth(iz)**2*G1b_1loop * (1.d0 + exp_factor) + 
     &        D_growth(iz)**4*G1b_2loop 
            G1a_reg = G1a_reg * D_growth(iz) * dexp(-exp_factor)
            G1b_reg = G1b_reg * D_growth(iz) * dexp(-exp_factor)
c     
            pkcorr_G1 = G1a_reg*G1b_reg * pk_lin
            pkcorr_G2 = pkcorr_G2_tree_tree * 
     &           (1.d0 + exp_factor)**2 + pkcorr_G2_tree_1loop *
     &           D_growth(iz)**2*(1.d0 + exp_factor) + 
     &           pkcorr_G2_1loop_1loop * D_growth(iz)**4 
            pkcorr_G2 = pkcorr_G2 * D_growth(iz)**4 * 
     &           dexp(-2.d0 * exp_factor)
            pkcorr_G3 = pkcorr_G3_tree * D_growth(iz)**6 *
     &           dexp(-2.d0 * exp_factor)
            pk_main(ik,iz) = pkcorr_G1 + pkcorr_G2 + pkcorr_G3
            if (iverbose.ge.2) then
               if (mod(ik-ideb-frack,2*frack).eq.0) then
               write(6,'(4x,I2,2e18.10)') iz,k,pk_main(ik, iz)
               endif
            endif
         enddo
      enddo
c
c     zedo padding just for late analysis
      do ik=iend+1, ik_max, frack
         k = ak(ik)
         call find_pklin(2, k, pk_lin)
         write(11,'(1p9e18.10)') k, pk_EH(ik), pk_lin, 0.d0, 0.d0,
     &        0.d0, 0.d0, 0.d0, 0.d0
      enddo
c
      close(11)
      if (iverbose.ge.1) then 
         write(6,*) '> diagram values saved in ',stfile
      endif
c
c      write(6,*)
c      write(6,'(A,A)') 'Check result ---> ',outfile
c
      end
c
c ******************************************************* c
c
      subroutine load_matterpower_fid(imodel_fid, sigma8_boost,mpath)
c
c ******************************************************* c
c
c     Loading fiducial power spectra, and estimating the boost factor 
c     in power spectrum amplitude for each fiducial model
c
c     Model selection
c         For the 20 logarithmically sampled points in the range 0.01 < k < 1, 
c         we try to minimize the chi^2 by varying "b" for each fiducial model:
c
c         chi^2 = (1/20) * 
c            sum_i^20 [ln(pklin_target(k_i)) - ln(b^2*pklin_fid(k_i)) ]^2 / sigma_i^2
c
c     Determination of boost factor
c         For the 20 logarithmically sampled points in the range 0.15 < k < 1, 
c         we try to minimize the chi^2 by varying "b":
c
c         chi^2 = (1/20) * 
c            sum_i^20 [pklin_target(k_i) - b^2*pklin_fid(k_i) ]^2 / sigma_i^2
c
c         The best-fit value of b is regarded as the boost parameter. 
c
c     imodel_fid = 0:  wmap3
c     imodel_fid = 1:  M001
c     imodel_fid = 2:  M023
c
      implicit none
      integer iloop, imodel_fid, ichoice
      integer ik, ikmax, ik_max, ik_max_fid, iknum
      parameter(ikmax=2000, iknum=20)
      real*8  ak(ikmax), pk(ikmax), k
      real*8  ak_fid(ikmax), pk_fid(ikmax), sigma8_boost
      real*8  pklin_fid, pklin_target
      real*8  k_IR, k_UV, kmin, kmax, sigma_i, Ai, Bi, Ai_chi, Bi_chi
      real*8  s8_boost(3), delta_pk1(3,20), delta_pk2(3,20)
      real*8  chi2_min, chi2(3), boost_chi(3)
      character infile*60, fid_model*60,mpath*60
      integer iverbose,ifast,icalc_xi,ifid,inum_z
      common /pk_data/ ak, pk, ik_max
      common /pk_data_fid/  ak_fid, pk_fid,ik_max_fid 
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
c     ---------------------------------------------------
      kmin = 0.15
      kmax = 1.d0
c
      k_IR =0.01
      k_UV= 1.d0
c
      do iloop=1, 3
c
c  ////// load matter power spectrum ///////
c
         if(iloop.eq.1) infile = trim(mpath)//'matterpower_wmap3.dat'
         if(iloop.eq.2) infile = trim(mpath)//'matterpower_M001.dat'
         if(iloop.eq.3) infile = trim(mpath)//'matterpower_M023.dat'
         open(9,file=infile, status='old',err=104)
         do ik=1, ikmax
            read(9,*,END=5) ak_fid(ik), pk_fid(ik)
         enddo
 5       ik_max_fid = ik - 1
         close(9)
c
c  ////// estimate sigma8_boost parameter /////
c
         if(k_IR.lt. max(ak(1),ak_fid(1)))  k_IR= max(ak(1),ak_fid(1))
         if(kmin.lt. max(ak(1),ak_fid(1)))  kmin= max(ak(1),ak_fid(1))
         if(k_UV.gt. min(ak(ik_max),ak_fid(ik_max_fid)))  
     &        k_UV= min(ak(ik_max),ak_fid(ik_max_fid))
         if(kmax.gt. min(ak(ik_max),ak_fid(ik_max_fid)))  
     &        kmax= min(ak(ik_max),ak_fid(ik_max_fid))
c
c  ///// Error check before rescaling power spectrum amplitude /////
c
         Ai = 0.d0
         Bi = 0.d0
         Ai_chi = 0.d0
         Bi_chi = 0.d0
c
         do ik=1, iknum
            k = k_IR * (k_UV / k_IR)**(dble(ik-1)/dble(iknum-1))
            sigma_i = k
            call find_pklin(1, k, pklin_fid)
            call find_pklin(2, k, pklin_target)
            Ai_chi = Ai_chi + dlog(pklin_target/pklin_fid) / sigma_i**2
            Bi_chi = Bi_chi +  1.d0 / sigma_i**2
c
            k = kmin * (kmax / kmin)**(dble(ik-1)/dble(iknum-1))
            call find_pklin(1, k, pklin_fid)
            call find_pklin(2, k, pklin_target)
            sigma_i = k
            Ai = Ai + pklin_target * pklin_fid / sigma_i**2
            Bi = Bi + (pklin_fid / sigma_i)**2
         enddo
c
         boost_chi(iloop) = dsqrt(dexp(Ai_chi / Bi_chi))
         s8_boost(iloop) = dsqrt(Ai / Bi)
c
c     ///// Error check after rescaling power spectrum amplitude /////
c
         chi2(iloop) = 0.d0
         do ik=1, iknum
            k = k_IR * (k_UV / k_IR)**(dble(ik-1)/dble(iknum-1))
            sigma_i = k
            call find_pklin(1, k, pklin_fid)
            call find_pklin(2, k, pklin_target)
            chi2(iloop) = chi2(iloop) + 
     &         ( dlog(pklin_target / (boost_chi(iloop)**2 * pklin_fid) ) 
     &            / sigma_i )**2 / dble(iknum)
c
            k = kmin * (kmax / kmin)**(dble(ik-1)/dble(iknum-1))
            sigma_i = k
            call find_pklin(1, k, pklin_fid)
            call find_pklin(2, k, pklin_target)
            delta_pk1(iloop,ik) = pklin_target / pklin_fid - 1.d0
            delta_pk2(iloop,ik) = pklin_target / 
     &          (s8_boost(iloop)**2 * pklin_fid) - 1.d0
         enddo
c
         if(iloop.eq.1)  fid_model='> wmap3'
         if(iloop.eq.2)  fid_model='> M001'
         if(iloop.eq.3)  fid_model='> M023'
         if (iverbose.eq.2) then
            write(6,'(A7,2x,A,1p2e18.10)')
     &        fid_model,': chi2, sigma8_boost=', 
     &        chi2(iloop), s8_boost(iloop)
         endif
      enddo
c
      chi2_min = min( chi2(1), chi2(2), chi2(3))
      if(chi2_min.eq.chi2(1)) then
         imodel_fid = 0
         fid_model='wmap3'
         sigma8_boost = s8_boost(1)
      elseif(chi2_min.eq.chi2(2)) then
         imodel_fid = 1
         fid_model='M001'
         sigma8_boost = s8_boost(2)
      elseif(chi2_min.eq.chi2(3)) then
         imodel_fid = 2
         fid_model='M023'
         sigma8_boost = s8_boost(3)
      endif
c
      if (iverbose.ge.1) then
      write(6,'(A)') ' > selected fiducial model'
      write(6,'(A,A5)') '   (from "wmap3", "M001", "M023"): ',fid_model
      write(6,'(11x,A,1p1e18.10)') '    sigma8_boost=',sigma8_boost
      endif
c      write(6,*) 'Is this OK ?  y[1], n[0]'
c      read(5,*) ichoice
      if(ifid.ne.0) then
         imodel_fid=ifid-1
         if(ifid.eq.1) sigma8_boost = s8_boost(1)
         if(ifid.eq.2) sigma8_boost = s8_boost(2)
         if(ifid.eq.3) sigma8_boost = s8_boost(3)
      endif
      if (iverbose.eq.2) then
         write(6,'(A)') ' > Performance of fid. model with boost factor'
         write(6,'(A)') ' >  1: k,   2: d_pk(before),  3: d_pk(after)'
         do ik=1, iknum
            k = kmin * (kmax / kmin)**(dble(ik-1)/dble(iknum-1))
            if(imodel_fid.eq.0) write(6,'(A,1p3e18.10)')  
     &           '> ',k, delta_pk1(1,ik), delta_pk2(1,ik)
            if(imodel_fid.eq.1) write(6,'(A,1p3e18.10)')  
     &           '> ',k, delta_pk1(2,ik), delta_pk2(2,ik)
            if(imodel_fid.eq.2) write(6,'(A,1p3e18.10)')  
     &           '> ',k, delta_pk1(3,ik), delta_pk2(3,ik)
         enddo
      endif
      goto 105
 104  write(6,*) ' ! Error, file not found: ',trim(infile)
      stop
 105  continue
      end
c
c ******************************************************* c
c
      subroutine load_precomputed_RegPT_data(imodel_fid,mpath)
c
c ******************************************************* c
c
c     imodel_fid = 0 : wmap3
c     imodel_fid = 1 : M001
c     imodel_fid = 2 : M023
c
      implicit none
      integer imodel_fid
      integer ik, ikmax, ik_max_fid, ik_max_G1, ik_max_G2, ik_max_G3
      integer i, j, ik_max_corr, iq_max_corr
      parameter(ikmax=2000)
      real*8   ak_fid(ikmax), pk_fid(ikmax), dummy
      real*8   ak_G1(ikmax), G1a_1loop(ikmax), G1b_1loop(ikmax)
      real*8   G1a_2loop(ikmax), G1b_2loop(ikmax)
      real*8   ak_G2(ikmax), pkcorr_G2_tree_tree(ikmax)
      real*8   pkcorr_G2_tree_1loop(ikmax), pkcorr_G2_1loop_1loop(ikmax)
      real*8   ak_G3(ikmax), pkcorr_G3_tree(ikmax)
      real*8   ak_corr(ikmax), aq_corr(ikmax)
      real*8   M1(ikmax, ikmax), X2(ikmax, ikmax), Y2(ikmax, ikmax)
      real*8   Z2(ikmax, ikmax), Q2(ikmax, ikmax), R2(ikmax, ikmax)
      real*8   S3(ikmax, ikmax)
      character infile*60, ifile1*60, ifile2*60, ifile3*60, mpath*60
      integer iverbose,ifast,icalc_xi,ifid,inum_z
      common /pk_data_fid/  ak_fid, pk_fid, ik_max_fid 
      common /pkcorr_G1_fid/  ak_G1, G1a_1loop, G1b_1loop, 
     *     G1a_2loop, G1b_2loop, ik_max_G1
      common /pkcorr_G2_fid/  ak_G2, pkcorr_G2_tree_tree, 
     *     pkcorr_G2_tree_1loop, pkcorr_G2_1loop_1loop, ik_max_G2
      common /pkcorr_G3_fid/  ak_G3, pkcorr_G3_tree, ik_max_G3
      common /RegPTcorr_fid/  ak_corr, aq_corr, M1, X2, Y2, Z2, 
     *     Q2, R2, S3, ik_max_corr, iq_max_corr
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
c     ---------------------------------------------------
c
c     ////// Read matter power spectrum for fiducial cosmology //////
c
c     The power spectrum amplitude is supposed to be normalized at z=0
c
      
      if(imodel_fid.eq.0) then 
         infile = trim(mpath)//'matterpower_wmap3.dat'
      elseif(imodel_fid.eq.1) then 
         infile = trim(mpath)//'matterpower_M001.dat'
      elseif(imodel_fid.eq.2) then 
         infile = trim(mpath)//'matterpower_M023.dat'
      endif
      open(9, file=infile, status='old',err=104)
      if (iverbose.ge.1) then
         write(6,*) '> Load matter power spectrum (fiducial model):'
         write(6,'(15x,A)') infile
      endif
c
      do ik=1, ikmax
         read(9,*,END=5) ak_fid(ik), pk_fid(ik)
      enddo
 5    ik_max_fid = ik - 1
      close(9)
c
c
c
      if(imodel_fid.eq.0) then
         ifile1 = trim(mpath)//'pkcorr_Gamma1_wmap3.dat'
         ifile2 = trim(mpath)//'pkcorr_Gamma2_wmap3.dat'
         ifile3 = trim(mpath)//'pkcorr_Gamma3_wmap3.dat'
      elseif(imodel_fid.eq.1) then
         ifile1 = trim(mpath)//'pkcorr_Gamma1_M001.dat'
         ifile2 = trim(mpath)//'pkcorr_Gamma2_M001.dat'
         ifile3 = trim(mpath)//'pkcorr_Gamma3_M001.dat'
      elseif(imodel_fid.eq.2) then
         ifile1 = trim(mpath)//'pkcorr_Gamma1_M023.dat'
         ifile2 = trim(mpath)//'pkcorr_Gamma2_M023.dat'
         ifile3 = trim(mpath)//'pkcorr_Gamma3_M023.dat'
      endif
      infile=ifile1
      open(10, file=infile, status='old',err=104)
      infile=ifile2
      open(11, file=infile, status='old',err=104)
      infile=ifile3
      open(12, file=infile, status='old',err=104)
      if (iverbose.ge.1) then
         write(6,*) '> Load RegPTmain data (for fiducial model):'
         write(6,'(15x,A)') ifile1
         write(6,'(15x,A)') ifile2
         write(6,'(15x,A)') ifile3
      endif
c
c     ////// Read pkcorr_Gamma1.dat  //////
c
      do ik=1, ikmax
         read(10,*,END=16) ak_G1(ik), dummy, 
     &        G1a_1loop(ik), G1a_2loop(ik), G1b_1loop(ik), G1b_2loop(ik)
      enddo
 16   ik_max_G1 = ik - 1
      close(10)
c
c     ////// Read pkcorr_Gamma2.dat  //////
c
      do ik=1, ikmax
         read(11,*,END=17) ak_G2(ik), dummy, 
     &        pkcorr_G2_tree_tree(ik), pkcorr_G2_tree_1loop(ik), 
     &        pkcorr_G2_1loop_1loop(ik)
      enddo
 17   ik_max_G2 = ik - 1
      close(11)
c
c     ////// Read pkcorr_Gamma3.dat  //////
c
      do ik=1, ikmax
         read(12,*,END=18) ak_G3(ik), dummy, 
     &        pkcorr_G3_tree(ik)
      enddo
 18   ik_max_G3 = ik - 1
      close(12)
c
c     ////// Read pre-computed data from RegPTcorr.f  //////
c
c
      if(imodel_fid.eq.0) then
         infile = trim(mpath)//'RegPTcorr_2loop_wmap3.dat'
      elseif(imodel_fid.eq.1) then
         infile = trim(mpath)//'RegPTcorr_2loop_M001.dat'
      elseif(imodel_fid.eq.2) then
         infile = trim(mpath)//'RegPTcorr_2loop_M023.dat'
      endif
c     
      open(12,err=104,file=infile,status='unknown')
      ik_max_corr = 1
      iq_max_corr = 1
 111  read(12,*,END=25) i, j, ak_corr(i), aq_corr(j), M1(i,j), X2(i,j),
     &     Y2(i,j), Z2(i,j), Q2(i,j), R2(i,j), S3(i,j)
      ik_max_corr = max(i, ik_max_corr)
      iq_max_corr = max(j, iq_max_corr)
      goto 111
 25   close(12) 
c
c      write(6,*)
      if (iverbose.ge.1) then
         write(6,*) '> Load RegPTcorr data:'
         write(6,'(15x,A)') infile
      endif
      if (iverbose.ge.2) then
         write(6,'(15x,A,I5)') 'ik_max_corr: ', 
     &        ik_max_corr
         write(6,'(15x,A,I5)') 'iq_max_corr: ', 
     &        iq_max_corr
      endif
      goto 105
 104  write(6,*) ' ! Error, file not found: ',trim(infile)
      stop
 105  continue
      end
c
c ******************************************************* c
c
      subroutine calc_sigmav2
c
c ******************************************************* c
c
      implicit none
c
      integer ikmax, ik_max, ix, ixmax
      parameter(ikmax=2000)
      parameter(ixmax=1000)
      real*8  ak(ikmax), pk(ikmax)
      real*8  kk(ixmax), wk(ixmax), pi, kmin, kmax
      real*8  k, pklin, sigmav2_target
      common /pk_data/ ak, pk, ik_max
      common /velocity_disp/ sigmav2_target
      integer iverbose,ifast,inum_z,icalc_xi,ifid
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
      pi = 4.d0 * datan(1.d0)

c     --------------------------------------------------------
c
c     ///// sigmav2 for fiducial cosmology ///// 
c
      kmin = ak(1)
      kmax = ak(ik_max)
      call gauleg(dlog(kmin),dlog(kmax),kk,wk,ixmax)
c
      sigmav2_target = 0.d0
c
      do ix=1, ixmax
         k = dexp(kk(ix))
         call find_pklin(2, k, pklin)
         sigmav2_target = sigmav2_target + 
     &        wk(ix) * pklin * k / (6.d0*pi**2)
      enddo
c
      if (iverbose.ge.1) then
         write(6,*) 'sigmav2_target=',sigmav2_target
         write(6,*)
      endif
c
      end
c
c ******************************************************* c
c
      subroutine calc_running_sigmav2(k, sigmav2)
c
c ******************************************************* c
c
c     sigmav^2 = int_0^{k/2} dq P0(q)/(6*pi^2)
c
      implicit none
c
      integer ik, ikmax, ik_max
      parameter(ikmax=2000)
      real*8  ak(ikmax), pk(ikmax), pk_kmax
      real*8  k, kmax, sigmav2, pi
      common /pk_data/ ak, pk, ik_max
      pi = 4.d0 * datan(1.d0)
c     --------------------------------------------------------
c
      sigmav2 = 0.d0
      kmax = k/2.d0
c
      if(kmax.lt.ak(1)) then
         goto 1
      else
c
         do ik=1, ik_max-1
            if(ak(ik+1).gt.kmax ) then
               pk_kmax = pk(ik) + 
     &              (pk(ik+1)-pk(ik))/(ak(ik+1)-ak(ik)) *(kmax-ak(ik))
               sigmav2 = sigmav2 + 
     &              ( pk_kmax + pk(ik) ) * ( kmax - ak(ik) ) /2.d0 
     &              / (6.d0*pi**2)
               goto 1
            else
               sigmav2 = sigmav2 + 
     &              ( pk(ik+1) + pk(ik) ) * ( ak(ik+1) - ak(ik) ) /2.d0 
     &              / (6.d0*pi**2)
            endif
         enddo
c
      endif
c
 1    continue
c
      end
c
c ******************************************************* c
c
      subroutine truncation_k(kmin, kmax)
c
c ******************************************************* c
c     re-calculation of the ak and pk arrays so that it runs
c     from kmin to kmax with same spacing and ik_max is changed
c     accordingly.
c ******************************************************* c
c
      implicit none
c
      integer ik, ikk, ikmax, ik_max, ik_max_fid
      parameter(ikmax=2000)
      real*8 ak(ikmax), pk(ikmax), ak_fid(ikmax), pk_fid(ikmax)
      real*8 akk(ikmax), pkk(ikmax)
      real*8 kmin, kmax
      common /pk_data/ ak, pk, ik_max
      common /pk_data_fid/ ak_fid, pk_fid, ik_max_fid
c     -----------------------------------------------------
c
c     ///// truncation (1) /////
c
      do ik=1, ik_max
         akk(ik) = ak(ik)
         pkk(ik) = pk(ik)
      enddo
c
      ikk = 1
      do ik=1, ik_max
         if(akk(ik).ge.kmin .and. akk(ik).le.kmax
ccc     &        .and. mod(ik,2).eq.0 ) then
     &        ) then
            ak(ikk) = akk(ik)
            pk(ikk) = pkk(ik)
            ikk = ikk + 1
         endif
      enddo
c
      ik_max = ikk -1
c
c     ///// truncation (2)  /////
c
      do ik=1, ik_max_fid
         akk(ik) = ak_fid(ik)
         pkk(ik) = pk_fid(ik)
      enddo
c
      ikk = 1
      do ik=1, ik_max_fid
         if(akk(ik).ge.kmin .and. akk(ik).le.kmax
ccc     &        .and. mod(ik,2).eq.0 ) then
     &        ) then
            ak_fid(ikk) = akk(ik)
            pk_fid(ikk) = pkk(ik)
            ikk = ikk + 1
         endif
      enddo
c
      ik_max_fid = ikk -1
c
c      write(6,*) 'ik_max, ik_max_fid=',ik_max, ik_max_fid
c
      end
c
c
c ******************************************************* c
c
      subroutine calc_regpt_fast(D_growth, sigma8_boost,frack)
c
c ******************************************************* c
c     This routine computes the table values ak_total, pk_total and 
c     dpk_total.
c ******************************************************* c
c
      implicit none
c
      integer ik, ikmax, ik_max, ik_max_fid, ik_max_fast
      integer ix, ixmax, iz, inum_z,frack,ff
      parameter(ikmax=2000)
ccc      parameter(ixmax=1000)
      parameter(ixmax=300)
      real*8  qmin, qmax, q, qq(ixmax), wq(ixmax)
      real*8  sigmav2_target, sigmav2_running, sigma8_boost
      real*8  k, ak(ikmax), pk(ikmax)
      real*8  ak_fast(ikmax), pk_fast(ikmax,100), dpk_fast(ikmax,100)
      real*8  D_growth(100), exp_factor
      real*8  G1a_1loop, G1b_1loop, G1a_2loop, G1b_2loop
      real*8  pkcorr_G2_tree_tree, pkcorr_G2_tree_1loop
      real*8  pkcorr_G2_1loop_1loop, pkcorr_G2
      real*8  pkcorr_G3_tree, pkcorr_G3
      real*8  G1a_reg, G1b_reg, dG1a_reg, dG1b_reg
      real*8  pklin, pklin_fid, dpklin, pi
      real*8  int_L1, int_M1, int_X2, int_Y2, int_Z2
      real*8  int_Q2, int_R2, int_S3
      real*8  kernel_L1, kernel_M1, kernel_X2, kernel_Y2, kernel_Z2
      real*8  kernel_Q2, kernel_R2, kernel_S3
      real*8  dpkcorr_G2, dpkcorr_G3
c     ^^^^^^^  check ^^^^^^^^
      real*8  check_L1, check_M1, check_X2, check_Y2, check_Z2, check_S3
c     ^^^^^^^  check ^^^^^^^^
      character  outfile*80, suffix_outfile*60
      integer iverbose,ifast,icalc_xi,ifid
c
      real*8  dG1a_1loop,dG1a_2loop,dpkcorr_G2_tree_tree
      real*8  dpkcorr_G2_tree_1loop,dpkcorr_G2_1loop_1loop
      real*8  dpkcorr_G3_tree
c
      common /velocity_disp/ sigmav2_target
      common /pk_data/ ak, pk, ik_max
      common /dpk_fast/ ak_fast, pk_fast, dpk_fast, ik_max_fast
      common  /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
c     --------------------------------------------------------
c
      pi = 4.d0 * datan(1.d0)
      qmin = ak(1)
      qmax = ak(ik_max)
c
      call gauleg(dlog(qmin),dlog(qmax),qq,wq,ixmax)
c
c     ^^^^^^^  check ^^^^^^^^
ccc      open(11, file='check_XYZ.dat', status='unknown')
c     ^^^^^^^  check ^^^^^^^^
c
c loop over modes
      if (iverbose.ge.1) 
     &     write(6,*) '... Fast method computation running...'
      if (iverbose.ge.2) then
         write(6,*) ' > fast method results'
         write(6,*) ' > iz, k, pk_fast, dpk_fast, total'
      endif
      
      ff=frack
      if (icalc_xi.eq.1) ff=1
      do 10 ik=1, ik_max,ff
c
         k = ak(ik)
c
         int_L1 = 0.d0
         int_M1 = 0.d0
         int_X2 = 0.d0
         int_Y2 = 0.d0
         int_Z2 = 0.d0
         int_Q2 = 0.d0
         int_R2 = 0.d0
         int_S3 = 0.d0
c     ^^^^^^^  check ^^^^^^^^
         check_L1 = 0.d0
         check_M1 = 0.d0
         check_X2 = 0.d0
         check_Y2 = 0.d0
         check_Z2 = 0.d0
         check_S3 = 0.d0
c     ^^^^^^^  check ^^^^^^^^
c
c     ^^^^^^^  Test for scale-dependent sigma8_boost ^^^^^^^^
cc         call find_pklin(1, k, pklin_fid)
cc         call find_pklin(2, k, pklin)
cc         sigma8_boost = dsqrt( pklin / pklin_fid )
cc         write(6,'(A,1p2e18.10)') 'Test for sigma8_boost: ', 
cc     &        ak(ik), sigma8_boost
c     ^^^^^^^  Test for scale-dependent sigma8_boost ^^^^^^^^
c
c Computation of the 1st order perturbation contributing terms to the diagrams
c for notation see paper
c
         do ix=1, ixmax
            q = dexp(qq(ix))
            call find_pklin(1, q, pklin_fid)
            call find_pklin(2, q, pklin)
            dpklin = pklin - pklin_fid * sigma8_boost**2
            call find_RegPTcorr2(k, q, kernel_M1, kernel_X2, 
     &           kernel_Y2, kernel_Z2, kernel_Q2, kernel_R2, 
     &           kernel_S3)
            int_L1 = int_L1 + wq(ix) * kernel_L1(k, q) * dpklin
            int_M1 = int_M1 + wq(ix) * kernel_M1 * dpklin
            int_X2 = int_X2 + wq(ix) * kernel_X2 * dpklin
            int_Y2 = int_Y2 + wq(ix) * kernel_Y2 * dpklin
            int_Z2 = int_Z2 + wq(ix) * kernel_Z2 * dpklin
            int_Q2 = int_Q2 + wq(ix) * kernel_Q2 * dpklin
            int_R2 = int_R2 + wq(ix) * kernel_R2 * dpklin
            int_S3 = int_S3 + wq(ix) * kernel_S3 * dpklin
c     ^^^^^^^  check ^^^^^^^^
            check_L1 = check_L1 + wq(ix) * kernel_L1(k,q) * pklin
            check_M1 = check_M1 + wq(ix) * kernel_M1 * pklin
            check_X2 = check_X2 + wq(ix) * kernel_X2 * pklin
            check_Y2 = check_Y2 + wq(ix) * kernel_Y2 * pklin
            check_Z2 = check_Z2 + wq(ix) * kernel_Z2 * pklin
            check_S3 = check_S3 + wq(ix) * kernel_S3 * pklin
c     ^^^^^^^  check ^^^^^^^^
c
         enddo
c
c     The first order contributing terms are rescaled with the sigma8_boost factors 
ccc   sigma8_boost
c
         int_M1 = int_M1 * sigma8_boost**2
         int_X2 = int_X2 * sigma8_boost**2
         int_Y2 = int_Y2 * sigma8_boost**4
         int_Z2 = int_Z2 * sigma8_boost**6
         int_Q2 = int_Q2 * sigma8_boost**4
         int_R2 = int_R2 * sigma8_boost**6
         int_S3 = int_S3 * sigma8_boost**4
c
c construction of the 0th order contribution to the values of the diagrams from
c the fiducial model. The contributing diagrams are then rescaled by the sigma8_boost factor.
c
         call find_pklin(1, k, pklin_fid)
         call find_pklin(2, k, pklin)
         call find_G1(k, G1a_1loop, G1b_1loop, G1a_2loop, G1b_2loop)
         call find_G2(k, pkcorr_G2_tree_tree, pkcorr_G2_tree_1loop, 
     &           pkcorr_G2_1loop_1loop)
         call find_G3(k, pkcorr_G3_tree)

         G1a_1loop = G1a_1loop * sigma8_boost**2
         G1b_1loop = G1b_1loop * sigma8_boost**2
         G1a_2loop = G1a_2loop * sigma8_boost**4
         G1b_2loop = G1b_2loop * sigma8_boost**4
         pkcorr_G2_tree_tree = pkcorr_G2_tree_tree * sigma8_boost**4
         pkcorr_G2_tree_1loop = pkcorr_G2_tree_1loop * sigma8_boost**6
         pkcorr_G2_1loop_1loop = pkcorr_G2_1loop_1loop * sigma8_boost**8
         pkcorr_G3_tree = pkcorr_G3_tree * sigma8_boost**6

c reconstruction of the diagram values (at z=0)
         dG1a_1loop=int_L1
         dG1a_2loop=2.d0*int_M1
         dpkcorr_G2_tree_tree=4.d0*int_X2
         dpkcorr_G2_tree_1loop=8.d0*int_Y2+4.d0*int_Q2
         dpkcorr_G2_1loop_1loop=4.d0*int_Z2+4.d0*int_R2
         dpkcorr_G3_tree=18.d0*int_S3

c         write(10,'(1p20e18.10)') k, pklin, 
c     &        G1a_1loop, G1a_2loop,
c     &        pkcorr_G2_tree_tree, pkcorr_G2_tree_1loop,
c     &        pkcorr_G2_1loop_1loop, pkcorr_G3_tree,
c     &        dpklin, dG1a_1loop, dG1a_2loop,
c     &        dpkcorr_G2_tree_tree, dpkcorr_G2_tree_1loop,
c     &        dpkcorr_G2_1loop_1loop, dpkcorr_G3_tree
c
c     Unperturbed part of power spectrum (but the time dependence 
c     is replaced with those in target cosmological model)
c
         ak_fast(ik) = k
c
         call calc_running_sigmav2(k, sigmav2_running)
c
c     do-loop for multiple output redshifts
c
         do 20 iz=1, inum_z
ccc         exp_factor = 0.5d0 * (k*D_growth)**2 * sigmav2_target
            exp_factor = 0.5d0 * (k*D_growth(iz))**2 * sigmav2_running
c
            if(exp_factor.ge.50.d0) goto 5
c
            G1a_reg = D_growth(iz) * ( 1.d0 + exp_factor + 
     &           exp_factor**2/2.d0 + 
     &           D_growth(iz)**2*(1.d0 + exp_factor)*G1a_1loop + 
     &           D_growth(iz)**4*G1a_2loop ) * dexp(-exp_factor)
            G1b_reg = D_growth(iz) * ( 1.d0 + exp_factor + 
     &           exp_factor**2/2.d0 + 
     &           D_growth(iz)**2*(1.d0 + exp_factor)*G1b_1loop + 
     &           D_growth(iz)**4*G1b_2loop ) * dexp(-exp_factor)
            pkcorr_G2 = pkcorr_G2_tree_tree * 
     &           (1.d0 + exp_factor)**2 + pkcorr_G2_tree_1loop * 
     &           D_growth(iz)**2*(1.d0 + exp_factor) + 
     &           pkcorr_G2_1loop_1loop * D_growth(iz)**4 
            pkcorr_G2 = pkcorr_G2 * D_growth(iz)**4 * 
     &           dexp(-2.d0 * exp_factor)
            pkcorr_G3 = pkcorr_G3_tree * D_growth(iz)**6 * 
     &           dexp(-2.d0 * exp_factor)
c         
            pk_fast(ik, iz) = G1a_reg*G1b_reg * pklin_fid * 
     &           sigma8_boost**2 + pkcorr_G2 + pkcorr_G3
c
c     Perturbed part of power spectrum 
c
            dpklin = pklin - pklin_fid * sigma8_boost**2
            dG1a_reg = D_growth(iz)**3 * ( (1.d0+exp_factor)*int_L1
     &           + D_growth(iz)**2*2.d0*int_M1 ) * dexp(-exp_factor) 
            dG1b_reg = dG1a_reg
c
            dpkcorr_G2 = (1.d0 + exp_factor)**2 * int_X2 + 
     &           2.d0*D_growth(iz)**2*(1.d0 + exp_factor) * int_Y2 + 
     &           D_growth(iz)**4 *int_Z2
            dpkcorr_G2 = dpkcorr_G2 + 
     &           (1.d0+exp_factor)*int_Q2*D_growth(iz)**2 + 
     &           int_R2*D_growth(iz)**4 
            dpkcorr_G2 = dpkcorr_G2 * 4.d0 * D_growth(iz)**4 * 
     &           dexp(-2.d0*exp_factor)
c
            dpkcorr_G3 = 18.d0*int_S3 * D_growth(iz)**6 * 
     &           dexp(-2.d0*exp_factor)
c
            dpk_fast(ik, iz) = (G1a_reg*dG1b_reg + dG1a_reg*G1b_reg)*
     &           pklin + G1a_reg*G1b_reg*dpklin + 
     &           dpkcorr_G2 + dpkcorr_G3
            if (iverbose.ge.2) then
               if (mod((ik-1)/ff,10).eq.0) then
               write(6,'(4x,I2,4e18.10)') 
     &              iz,k,pk_fast(ik, iz),dpk_fast(ik, iz),
     &                 pk_fast(ik, iz)+dpk_fast(ik, iz)
               endif
            endif
c
 5          continue
c
 20      continue
c
c     ^^^^^^^  check ^^^^^^^^
ccc         write(11,'(1p7e18.10)') k, check_L1, check_M1, check_X2, 
ccc     &        check_Y2, check_Z2, check_S3
c     ^^^^^^^  check ^^^^^^^^
c
 10   continue
ccc      close(10)
c
      ik_max_fast = ik_max
c
c     ^^^^^^^  check ^^^^^^^^
ccc      close(11)
c     ^^^^^^^  check ^^^^^^^^
c
      end
c
c ******************************************************* c
c
      function kernel_L1(k, q)  
c
c ******************************************************* c
c
c     integrand:  q**2/(2*pi**2) * f_1(k, q)
c
      implicit none
c
      real*8  kernel_L1, k, q, x
      real*8  pi
      pi = 4.d0 * datan(1.d0)
c     -------------------------------------------
c    
      x = q / k
c
      if((x.le.10.d0).and. abs(x-1.d0).ge.1.d-2) then
         kernel_L1 = 6.d0/x/x - 79.d0 + 50.d0*x*x - 21.d0*x*x*x*x 
     &        + 0.75d0*(1.d0/x-x)**3 * (2.d0 + 7.d0*x*x) 
     &        * dlog(abs((1.d0-x)/(1.d0+x))**2)
         kernel_L1 = kernel_L1 / 504.d0
      elseif(abs(x-1.d0).lt.1.d-2) then 
         kernel_L1 = - 11.d0/126.d0 + (x-1.d0)/126.d0 
     &        - 29.d0/252.d0 * (x-1.d0)**2
      elseif(x.gt.10.d0) then
         kernel_L1 = - 61.d0/630.d0 + 2.d0/105.d0/x/x 
     &        - 10.d0/1323.d0 /x/x/x/x
      endif
c
      kernel_L1 = kernel_L1 * x * k**3 / (2.d0*pi*pi)
c
      end
c
c ******************************************************* c
c
      subroutine find_RegPTcorr(k, q, kernel_M1, kernel_X2, kernel_Y2,
     &           kernel_Z2, kernel_Q2, kernel_R2, kernel_S3)
c
c ******************************************************* c
c
c     polynomial interpolation of the pre-computed data from RegPTcorr
c
      implicit none
c
      integer ik, iq, ikmax, ik_max, iq_max
      parameter(ikmax=2000)
      integer hk, hq, jk, jq, jk_min, jk_max, jq_min, jq_max
      real*8  k, q, dy, ds, pi
      real*8  ss_M1, ss_X2, ss_Y2, ss_Z2, ss_Q2, ss_R2, ss_S3
      real*8  ak(ikmax), aq(ikmax), M1(ikmax, ikmax)
      real*8  X2(ikmax, ikmax), Y2(ikmax, ikmax), Z2(ikmax, ikmax)
      real*8  Q2(ikmax, ikmax), R2(ikmax, ikmax), S3(ikmax, ikmax)
      real*8  yktmp_M1(20), yktmp_X2(20), yktmp_Y2(20), yktmp_Z2(20)
      real*8  yktmp_Q2(20), yktmp_R2(20), yktmp_S3(20)
      real*8  yqtmp_M1(20), yqtmp_X2(20), yqtmp_Y2(20), yqtmp_Z2(20)
      real*8  yqtmp_Q2(20), yqtmp_R2(20), yqtmp_S3(20)
      real*8  kernel_M1, kernel_X2, kernel_Y2, kernel_Z2, kernel_Q2
      real*8  kernel_R2, kernel_S3
      common /RegPTcorr_fid/  ak, aq, M1, X2, Y2, Z2, 
     *     Q2, R2, S3, ik_max, iq_max
      pi = 4.d0 * datan(1.d0)
c     -------------------------------------------
c
      if(k.le.ak(ik_max) .and. q.le.aq(iq_max)) then 
c
         call hunt(ak, ik_max, k, jk)
         call hunt(aq, iq_max, q, jq)
         jk_min = jk - 3
         jk_max = jk + 3
         jq_min = jq - 3
         jq_max = jq + 3
         if(jk_min.lt.1) jk_min = 1
         if(jq_min.lt.1) jq_min = 1
         if(jk_max.ge.ik_max) jk_max = ik_max
         if(jq_max.ge.iq_max) jq_max = iq_max
c
         do hk = jk_min, jk_max
            do hq = jq_min, jq_max
               yqtmp_M1(hq) = M1(hk, hq)
               yqtmp_X2(hq) = X2(hk, hq)
               yqtmp_Y2(hq) = Y2(hk, hq)
               yqtmp_Z2(hq) = Z2(hk, hq)
               yqtmp_Q2(hq) = Q2(hk, hq)
               yqtmp_R2(hq) = R2(hk, hq)
               yqtmp_S3(hq) = S3(hk, hq)
            enddo
            call polint(aq(jq_min), yqtmp_M1(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_M1(hk), dy)
            call polint(aq(jq_min), yqtmp_X2(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_X2(hk), dy)
            call polint(aq(jq_min), yqtmp_Y2(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_Y2(hk), dy)
            call polint(aq(jq_min), yqtmp_Z2(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_Z2(hk), dy)
            call polint(aq(jq_min), yqtmp_Q2(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_Q2(hk), dy)
            call polint(aq(jq_min), yqtmp_R2(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_R2(hk), dy)
            call polint(aq(jq_min), yqtmp_S3(jq_min), jq_max-jq_min+1, 
     &           q, yktmp_S3(hk), dy)
         enddo
         call polint(ak(jk_min), yktmp_M1(jk_min), jk_max-jk_min+1, 
     &        k, ss_M1, ds) 
         call polint(ak(jk_min), yktmp_X2(jk_min), jk_max-jk_min+1, 
     &        k, ss_X2, ds) 
         call polint(ak(jk_min), yktmp_Y2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Y2, ds) 
         call polint(ak(jk_min), yktmp_Z2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Z2, ds) 
         call polint(ak(jk_min), yktmp_Q2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Q2, ds) 
         call polint(ak(jk_min), yktmp_R2(jk_min), jk_max-jk_min+1, 
     &        k, ss_R2, ds) 
         call polint(ak(jk_min), yktmp_S3(jk_min), jk_max-jk_min+1, 
     &        k, ss_S3, ds) 
c
      elseif(k.le.ak(ik_max) .and. q.gt.aq(iq_max)) then 
c
         call hunt(ak, ik_max, k, jk)         
         jk_min = jk - 3
         jk_max = jk + 3
         if(jk_min.lt.1) jk_min = 1
         if(jk_max.ge.ik_max) jk_max = ik_max
         do hk = jk_min, jk_max
            yktmp_M1(hk) = M1(hk, iq_max)
            yktmp_X2(hk) = X2(hk, iq_max)
            yktmp_Y2(hk) = Y2(hk, iq_max)
            yktmp_Z2(hk) = Z2(hk, iq_max)
            yktmp_Q2(hk) = Q2(hk, iq_max)
            yktmp_R2(hk) = R2(hk, iq_max)
            yktmp_S3(hk) = S3(hk, iq_max)
         enddo
         call polint(ak(jk_min), yktmp_M1(jk_min), jk_max-jk_min+1, 
     &        k, ss_M1, ds) 
         call polint(ak(jk_min), yktmp_X2(jk_min), jk_max-jk_min+1, 
     &        k, ss_X2, ds) 
         call polint(ak(jk_min), yktmp_Y2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Y2, ds) 
         call polint(ak(jk_min), yktmp_Z2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Z2, ds) 
         call polint(ak(jk_min), yktmp_Q2(jk_min), jk_max-jk_min+1, 
     &        k, ss_Q2, ds) 
         call polint(ak(jk_min), yktmp_R2(jk_min), jk_max-jk_min+1, 
     &        k, ss_R2, ds) 
         call polint(ak(jk_min), yktmp_S3(jk_min), jk_max-jk_min+1, 
     &        k, ss_S3, ds) 
c
      elseif(k.gt.ak(ik_max) .and. q.le.aq(iq_max)) then 
c
         call hunt(aq, iq_max, q, jq)         
         jq_min = jq - 3
         jq_max = jq + 3
         if(jq_min.lt.1) jq_min = 1
         if(jq_max.ge.iq_max) jq_max = iq_max
         do hq = jq_min, jq_max
            yqtmp_M1(hq) = M1(ik_max, hq)
            yqtmp_X2(hq) = X2(ik_max, hq)
            yqtmp_Y2(hq) = Y2(ik_max, hq)
            yqtmp_Z2(hq) = Z2(ik_max, hq)
            yqtmp_Q2(hq) = Q2(ik_max, hq)
            yqtmp_R2(hq) = R2(ik_max, hq)
            yqtmp_S3(hq) = S3(ik_max, hq)
         enddo
         call polint(aq(jq_min), yqtmp_M1(jq_min), jq_max-jq_min+1, 
     &        q, ss_M1, ds) 
         call polint(aq(jq_min), yqtmp_X2(jq_min), jq_max-jq_min+1, 
     &        q, ss_X2, ds) 
         call polint(aq(jq_min), yqtmp_Y2(jq_min), jq_max-jq_min+1, 
     &        q, ss_Y2, ds) 
         call polint(aq(jq_min), yqtmp_Z2(jq_min), jq_max-jq_min+1, 
     &        q, ss_Z2, ds) 
         call polint(aq(jq_min), yqtmp_Q2(jq_min), jq_max-jq_min+1, 
     &        q, ss_Q2, ds) 
         call polint(aq(jq_min), yqtmp_R2(jq_min), jq_max-jq_min+1, 
     &        q, ss_R2, ds) 
         call polint(aq(jq_min), yqtmp_S3(jq_min), jq_max-jq_min+1, 
     &        q, ss_S3, ds) 
c
      elseif(k.gt.ak(ik_max) .and. q.lt.aq(iq_max)) then 
c
         ss_M1 = M1(ik_max, iq_max)
         ss_X2 = X2(ik_max, iq_max)
         ss_Y2 = Y2(ik_max, iq_max)
         ss_Z2 = Z2(ik_max, iq_max)
         ss_Q2 = Q2(ik_max, iq_max)
         ss_R2 = R2(ik_max, iq_max)
         ss_S3 = S3(ik_max, iq_max)
c
      endif
c
      kernel_M1 = ss_M1 * q**3 / (2.d0*pi*pi)
      kernel_X2 = ss_X2 * q**3 / (2.d0*pi*pi)
      kernel_Y2 = ss_Y2 * q**3 / (2.d0*pi*pi)
      kernel_Z2 = ss_Z2 * q**3 / (2.d0*pi*pi)
      kernel_Q2 = ss_Q2 * q**3 / (2.d0*pi*pi)
      kernel_R2 = ss_R2 * q**3 / (2.d0*pi*pi)
      kernel_S3 = ss_S3 * q**3 / (2.d0*pi*pi)
c
      end
c
c ******************************************************* c
c
      subroutine find_RegPTcorr2(k, q, kernel_M1, kernel_X2, kernel_Y2,
     &           kernel_Z2, kernel_Q2, kernel_R2, kernel_S3)
c
c ******************************************************* c
c
c     polynomial interpolation of the pre-computed data from RegPTcorr
c
      implicit none
c
      integer a, ik, iq, ikmax, ik_max, iq_max
      parameter(ikmax=2000)
      integer hk, hq, jk, jq, jk_min, jk_max, jq_min, jq_max
      real*8  k, q, dy, ds, pi
      real*8  ss
      real*8  ak(ikmax), aq(ikmax), M1(ikmax, ikmax)
      real*8  X2(ikmax, ikmax), Y2(ikmax, ikmax), Z2(ikmax, ikmax)
      real*8  Q2(ikmax, ikmax), R2(ikmax, ikmax), S3(ikmax, ikmax)
      real*8  yktmp(ikmax), yqtmp(ikmax)
      real*8  kernel_M1, kernel_X2, kernel_Y2, kernel_Z2, kernel_Q2
      real*8  kernel_R2, kernel_S3
      common /RegPTcorr_fid/  ak, aq, M1, X2, Y2, Z2, 
     *     Q2, R2, S3, ik_max, iq_max
      pi = 4.d0 * datan(1.d0)
c     -------------------------------------------
c
c!!!! c!!!! c!!!! 
cc      write(6,*) 'in find_RegPTcorr2: top'
c!!!! c!!!! c!!!! 
c
      if(k.le.ak(ik_max) .and. q.le.aq(iq_max)) then 
c
         call hunt(ak, ik_max, k, jk)
         call hunt(aq, iq_max, q, jq)
         jk_min = jk - 3
         jk_max = jk + 3
         jq_min = jq - 3
         jq_max = jq + 3
         if(jk_min.lt.1) jk_min = 1
         if(jq_min.lt.1) jq_min = 1
         if(jk_max.ge.ik_max) jk_max = ik_max
         if(jq_max.ge.iq_max) jq_max = iq_max
c
         do a=1, 7
c
            do hk = jk_min, jk_max
               do hq = jq_min, jq_max
                  if(a.eq.1) yqtmp(hq) = M1(hk, hq)
                  if(a.eq.2) yqtmp(hq) = X2(hk, hq)
                  if(a.eq.3) yqtmp(hq) = Y2(hk, hq)
                  if(a.eq.4) yqtmp(hq) = Z2(hk, hq)
                  if(a.eq.5) yqtmp(hq) = Q2(hk, hq)
                  if(a.eq.6) yqtmp(hq) = R2(hk, hq)
                  if(a.eq.7) yqtmp(hq) = S3(hk, hq)
c!!!! c!!!! c!!!! 
cc                  if(k.ge.0.8 .and. a.eq.3) write(6,'(A,1p3e18.10)') 
cc     &                 'in find_RegPTcorr2',ak(hk), aq(hq), yqtmp(hq)
c!!!! c!!!! c!!!! 
               enddo
c
               call polint(aq(jq_min), yqtmp(jq_min), jq_max-jq_min+1, 
     &              q, ss, dy)
               yktmp(hk) = ss
c!!!! c!!!! c!!!! 
cc               if(k.ge.0.8 .and. a.eq.5) write(6,'(A,i6,1p3e18.10)') 
cc     &              'in find_RegPTcorr2: 1st polint=>',
cc     &              hk, ak(hk),q,yktmp(hk)
cc               if(yktmp(hk).lt.1.d-30) yktmp(hk) = 0.d0
c!!!! c!!!! c!!!! 
            enddo
c
c!!!! c!!!! c!!!! 
cc               if(k.ge.0.8 .and. a.eq.5) then
cc                  write(6,'(A,1p10e18.10)') 
cc     &              'in find_RegPTcorr2: before 2nd polint=>',
cc     &              (ak(hk),hk=jk_min,jk_max)
cc                  write(6,'(A,1p10e18.10)') 
cc     &              'in find_RegPTcorr2: before 2nd polint=>',
cc     &              (yktmp(hk),hk=jk_min,jk_max)
cc                  pause
cc               endif
c!!!! c!!!! c!!!! 
            call polint(ak(jk_min), yktmp(jk_min), jk_max-jk_min+1, 
     &           k, ss, ds) 
c!!!! c!!!! c!!!! 
cc               if(k.ge.0.8 .and. a.eq.5) then
cc                  write(6,'(A,1p3e18.10)') 
cc     &              'in find_RegPTcorr2: after 2nd polint=>',
cc     &              k,q,ss
cc                  pause
cc               endif
c!!!! c!!!! c!!!! 
            if(a.eq.1) kernel_M1 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.2) kernel_X2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.3) kernel_Y2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.4) kernel_Z2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.5) kernel_Q2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.6) kernel_R2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.7) kernel_S3 = ss * q**3 / (2.d0*pi*pi)
c
         enddo
c
         elseif(k.le.ak(ik_max) .and. q.gt.aq(iq_max)) then 
c
            call hunt(ak, ik_max, k, jk)         
            jk_min = jk - 3
            jk_max = jk + 3
            if(jk_min.lt.1) jk_min = 1
            if(jk_max.ge.ik_max) jk_max = ik_max
            do hk = jk_min, jk_max
               yktmp(hk) = M1(hk, iq_max)
            enddo
         call polint(ak(jk_min), yktmp(jk_min), jk_max-jk_min+1, 
     &        k, ss, ds) 
c
      elseif(k.gt.ak(ik_max) .and. q.le.aq(iq_max)) then 
c
         call hunt(aq, iq_max, q, jq)         
         jq_min = jq - 3
         jq_max = jq + 3
         if(jq_min.lt.1) jq_min = 1
         if(jq_max.ge.iq_max) jq_max = iq_max
c
         do a=1, 7
c
            do hq = jq_min, jq_max
               if(a.eq.1) yqtmp(hq) = M1(ik_max, hq)
               if(a.eq.2) yqtmp(hq) = X2(ik_max, hq)
               if(a.eq.3) yqtmp(hq) = Y2(ik_max, hq)
               if(a.eq.4) yqtmp(hq) = Z2(ik_max, hq)
               if(a.eq.5) yqtmp(hq) = Q2(ik_max, hq)
               if(a.eq.6) yqtmp(hq) = R2(ik_max, hq)
               if(a.eq.7) yqtmp(hq) = S3(ik_max, hq)
            enddo
            call polint(aq(jq_min), yqtmp(jq_min), jq_max-jq_min+1, 
     &           q, ss, ds) 
c
            if(a.eq.1) kernel_M1 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.2) kernel_X2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.3) kernel_Y2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.4) kernel_Z2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.5) kernel_Q2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.6) kernel_R2 = ss * q**3 / (2.d0*pi*pi)
            if(a.eq.7) kernel_S3 = ss * q**3 / (2.d0*pi*pi)
c     
         enddo
c
      elseif(k.gt.ak(ik_max) .and. q.lt.aq(iq_max)) then 
c
         kernel_M1 = M1(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_X2 = X2(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_Y2 = Y2(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_Z2 = Z2(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_Q2 = Q2(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_R2 = R2(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
         kernel_S3 = S3(ik_max, iq_max) * q**3 / (2.d0*pi*pi)
c
      endif
c
      end
c
c ******************************************************* c
c
      subroutine find_growth_factor(zred, cosm_params, D_growth)
c
c ******************************************************* c
c
      implicit none
      real*8   a, b, c,  zred, zred1, zi
      real*8   g0, gz, zz, s, ds, D_growth
      real*8   cosm_params(7), w_de, Omega_m, Omega_v
c     -------------------------------------------
c
      Omega_m = cosm_params(1)
      Omega_v = cosm_params(2)
      w_de = cosm_params(7)
c
      a = -1.d0 / (3.d0 * w_de)
      b = (w_de - 1.d0)/ (2.d0 * w_de)
      c = 1.d0 - 5.d0 / (6.d0 * w_de)
c
      zred1 = 1.d0 + zred
      zi = - Omega_v / Omega_m
      zz = zi * zred1**(3.d0*w_de) 
c
      call HYGFX(a,b,c,zi, g0)  
      call HYGFX(a,b,c,zz, gz)  
c
      D_growth = (gz/g0) / zred1
c
      end
c
c ******************************************************* c
c
      subroutine find_pk(kk, pklin)
c
c ******************************************************* c
c
      implicit none
      integer ik_max, ikmax
      integer j, jmin, jmax
      parameter(ikmax=2000)
      real*8 ak(ikmax), pk(ikmax), kk, s, ds, pklin
      common /pk_data/ ak, pk, ik_max
c     -------------------------------------------
c
      if(kk.le.ak(ik_max)) then
c
         call hunt(ak, ik_max, kk, j)
c
         jmin = j - 2
         jmax = j + 2
         if(jmin.lt.1) jmin = 1
         if(jmax.ge.ik_max) jmax = ik_max
c
         call polint(ak(jmin),pk(jmin),jmax-jmin+1,kk,s,ds)
c
      else
c
         call extrapolation(2, kk, s)
c
      endif
c
      pklin = s
c      
      end
c
c ******************************************************* c
c
      subroutine find_pklin(i, kk, pklin)
c
c ******************************************************* c
c
c     i = 1:   power spectrum for fiducial cosmology
c     i = 2:   power spectrum for target cosmology
c
      implicit none
      integer i, ik_max, ik_max_fid, ikmax
      integer j, jmin, jmax
      parameter(ikmax=2000)
      real*8 ak(ikmax), pk(ikmax), ak_fid(ikmax), pk_fid(ikmax)
      real*8 kk, s, ds, pklin
      common /pk_data/ ak, pk, ik_max
      common /pk_data_fid/  ak_fid, pk_fid, ik_max_fid 
c     -------------------------------------------
c
      if(i.eq.1) then   
c
         if(kk.le.ak_fid(ik_max_fid)) then
            call hunt(ak_fid, ik_max_fid, kk, j)
            jmin = j - 2
            jmax = j + 2
            if(jmin.lt.1) jmin = 1
            if(jmax.ge.ik_max_fid) jmax = ik_max_fid
            call polint(ak_fid(jmin),pk_fid(jmin),jmax-jmin+1,kk,s,ds)
         else
            call extrapolation(1, kk, s)
         endif
c
      elseif(i.eq.2) then
c
         if(kk.le.ak(ik_max)) then
            call hunt(ak, ik_max, kk, j)
            jmin = j - 2
            jmax = j + 2
            if(jmin.lt.1) jmin = 1
            if(jmax.ge.ik_max) jmax = ik_max
            call polint(ak(jmin),pk(jmin),jmax-jmin+1,kk,s,ds)
         else
            call extrapolation(2, kk, s)
         endif
c
      endif
c
      pklin = s
c      
      end
c
c ******************************************************* c
c
      subroutine find_G1(kk, G1a_1L, G1b_1L, G1a_2L, G1b_2L)
c
c ******************************************************* c
c
      implicit none
      integer i, ik_max_G1, ikmax
      integer j, jmin, jmax
      parameter(ikmax=2000)
      real*8  ak_G1(ikmax), G1a_1loop(ikmax), G1b_1loop(ikmax)
      real*8  G1a_2loop(ikmax), G1b_2loop(ikmax)
      real*8  kk, G1a_1L, G1b_1L, G1a_2L, G1b_2L
      real*8  s1, s2, s3, s4, ds1, ds2, ds3, ds4
      common /pkcorr_G1_fid/  ak_G1, G1a_1loop, G1b_1loop, 
     *     G1a_2loop, G1b_2loop, ik_max_G1
c     -------------------------------------------
c
      if(kk.le.ak_G1(ik_max_G1)) then
         call hunt(ak_G1, ik_max_G1, kk, j)
         jmin = j - 2
         jmax = j + 2
         if(jmin.lt.1) jmin = 1
         if(jmax.ge.ik_max_G1) jmax = ik_max_G1
         call polint(ak_G1(jmin),G1a_1loop(jmin),jmax-jmin+1,kk,s1,ds1)
         call polint(ak_G1(jmin),G1b_1loop(jmin),jmax-jmin+1,kk,s2,ds2)
         call polint(ak_G1(jmin),G1a_2loop(jmin),jmax-jmin+1,kk,s3,ds3)
         call polint(ak_G1(jmin),G1b_2loop(jmin),jmax-jmin+1,kk,s4,ds4)
      else
         s1 = G1a_1loop(ik_max_G1)
         s2 = G1b_1loop(ik_max_G1)
         s3 = G1a_2loop(ik_max_G1)
         s4 = G1b_2loop(ik_max_G1)
      endif
c
      G1a_1L = s1
      G1b_1L = s2
      G1a_2L = s3
      G1b_2L = s4
c      
      end
c
c ******************************************************* c
c
      subroutine find_G2(kk, pkcorr_G2_tt, pkcorr_G2_t1, pkcorr_G2_11)
c
c ******************************************************* c
c
      implicit none
      integer i, ik_max_G2, ikmax
      integer j, jmin, jmax
      parameter(ikmax=2000)
      real*8 ak_G2(ikmax), pkcorr_G2_tree_tree(ikmax)
      real*8 pkcorr_G2_tree_1loop(ikmax), pkcorr_G2_1loop_1loop(ikmax)
      real*8 kk, pkcorr_G2_tt, pkcorr_G2_t1, pkcorr_G2_11
      real*8 s1, s2, s3, ds1, ds2, ds3
      common /pkcorr_G2_fid/  ak_G2, pkcorr_G2_tree_tree, 
     *     pkcorr_G2_tree_1loop, pkcorr_G2_1loop_1loop, ik_max_G2
c     -------------------------------------------
c
      if(kk.le.ak_G2(ik_max_G2)) then
         call hunt(ak_G2, ik_max_G2, kk, j)
         jmin = j - 2
         jmax = j + 2
         if(jmin.lt.1) jmin = 1
         if(jmax.ge.ik_max_G2) jmax = ik_max_G2
         call polint(ak_G2(jmin), pkcorr_G2_tree_tree(jmin), 
     &        jmax-jmin+1, kk, s1, ds1)
         call polint(ak_G2(jmin), pkcorr_G2_tree_1loop(jmin), 
     &        jmax-jmin+1, kk, s2, ds2)
         call polint(ak_G2(jmin), pkcorr_G2_1loop_1loop(jmin), 
     &        jmax-jmin+1, kk, s3, ds3)
      else
         s1 = pkcorr_G2_tree_tree(ik_max_G2)
         s2 = pkcorr_G2_tree_1loop(ik_max_G2)
         s3 = pkcorr_G2_1loop_1loop(ik_max_G2)
      endif
c
      pkcorr_G2_tt = s1
      pkcorr_G2_t1 = s2
      pkcorr_G2_11 = s3
c      
      end
c
c ******************************************************* c
c
      subroutine find_G3(kk, pkcorr_G3)
c
c ******************************************************* c
c
      implicit none
      integer i, ik_max_G3, ikmax
      integer j, jmin, jmax
      parameter(ikmax=2000)
      real*8 ak_G3(ikmax), pkcorr_G3_tree(ikmax)
      real*8 kk, pkcorr_G3, s, ds
      common /pkcorr_G3_fid/  ak_G3, pkcorr_G3_tree, ik_max_G3
c     -------------------------------------------
c
      if(kk.le.ak_G3(ik_max_G3)) then
         call hunt(ak_G3, ik_max_G3, kk, j)
         jmin = j - 2
         jmax = j + 2
         if(jmin.lt.1) jmin = 1
         if(jmax.ge.ik_max_G3) jmax = ik_max_G3
         call polint(ak_G3(jmin), pkcorr_G3_tree(jmin), 
     &        jmax-jmin+1, kk, s, ds)
      else
         s = pkcorr_G3_tree(ik_max_G3)
      endif
c
      pkcorr_G3 = s
c      
      end
c
c ******************************************************* c
c
      subroutine find_pk_fast(i, inum_z, kk, pk)
c
c ******************************************************* c
c
c     Calculation of interpolation value for pk_fast 
c     i = 1:   pk_fast, RegPT power spectrum for target cosmology
c     i = 2:  dpk_fast, Perturbative correction for RegPT power spectrum
c
      implicit none
      integer  i, ik, ik_max, ik_max_fast, ikmax
      integer  j, jmin, jmax, iz, inum_z
      parameter(ikmax=2000)
      real*8   ak(ikmax), pk_fast(ikmax,100), dpk_fast(ikmax,100)
      real*8   ak_work(10), pk_work(10)
      real*8   kk, s, ds, pk(100)
      common /dpk_fast/ ak, pk_fast, dpk_fast, ik_max_fast
c     -------------------------------------------
c
      call hunt(ak, ik_max_fast, kk, j)
      jmin = j - 2
      jmax = j + 2
      if(jmin.lt.1) jmin = 1
      if(jmax.ge.ik_max_fast) jmax = ik_max_fast
c
      do iz=1, inum_z
c
         if(i.eq.1) then
            do ik=0, jmax-jmin
               ak_work(ik+1) = ak(jmin+ik) 
               pk_work(ik+1) = pk_fast(jmin+ik,iz)
            enddo
c
         elseif(i.eq.2) then 
            do ik=0, jmax-jmin
               ak_work(ik+1) = ak(jmin+ik) 
               pk_work(ik+1) = dpk_fast(jmin+ik,iz)
            enddo
         endif
c
         call polint(ak_work,pk_work,jmax-jmin+1,kk,s,ds)
         pk(iz) = s
c
      enddo
c
      end
c
c ******************************************************* c
c
      subroutine find_pk_main(inum_z, kk, pk)
c
c ******************************************************* c
c
c     Calculation of interpolation value for pk_fast 
c     pk_main, RegPT power spectrum from exact diag. calculations
c
      implicit none
      integer  i, ik, ik_max, ik_max_fast, ikmax
      integer  j, jmin, jmax, iz, inum_z
      parameter(ikmax=2000)
      real*8   pk_main(ikmax,100)
      real*8   ak(ikmax), pk_fast(ikmax,100), dpk_fast(ikmax,100)
      real*8   ak_work(10), pk_work(10)
      real*8   kk, s, ds, pk(100)
c      common  /pk_data/ ak, pk, ik_max
      common  /dpk_main/ pk_main
      common  /dpk_fast/ ak, pk_fast, dpk_fast, ik_max_fast
c     -------------------------------------------
c
      call hunt(ak, ik_max_fast, kk, j)
      jmin = j - 2
      jmax = j + 2
      if(jmin.lt.1) jmin = 1
      if(jmax.ge.ik_max_fast) jmax = ik_max_fast
c
      do iz=1, inum_z
c
         do ik=0, jmax-jmin
            ak_work(ik+1) = ak(jmin+ik) 
            pk_work(ik+1) = pk_main(jmin+ik,iz)
         enddo
c
         call polint(ak_work,pk_work,jmax-jmin+1,kk,s,ds)
         pk(iz) = s
c
      enddo
c
      end
c
c ******************************************************* c
c
      subroutine extrapolation(i, kk, pklin)
c
c ******************************************************* c
c
c     Extrapolation of linear P(k) data 
c
c     The extrapolation is done assuming the single power-law  
c     form of P(k) on small-scales. The slope of power-law 
c     function is determined by using the last 15 points of 
c     P(k) data.  
c
c     i = 1:   power spectrum for fiducial cosmology
c     i = 2:   power spectrum for targer cosmology
c
      implicit none 
      integer i, ik, ik_max, ik_max_fid, ikmax, ikdelta
      parameter(ikmax=2000, ikdelta=15)
      real*8  ak(ikmax), pk(ikmax), ak_fid(ikmax), pk_fid(ikmax)
      real*8  dlnp_dlnk, n_eff, kk, pklin
      common /pk_data/ ak, pk, ik_max
      common /pk_data_fid/  ak_fid, pk_fid, ik_max_fid 
c     --------------------------------------
c
      dlnp_dlnk = 0.d0
c
      do ik = ik_max - ikdelta, ik_max-1
         if(i.eq.1) 
     &        dlnp_dlnk = dlnp_dlnk + log(pk_fid(ik+1)/pk_fid(ik-1))
     &        /log(ak_fid(ik+1)/ak_fid(ik-1))
         if(i.eq.2) 
     &        dlnp_dlnk = dlnp_dlnk + log(pk(ik+1)/pk(ik-1))
     &        /log(ak(ik+1)/ak(ik-1))
      enddo
c
      n_eff = dlnp_dlnk / dble(ikdelta)
      if(n_eff.lt.-3.d0) n_eff = -3.d0
      if(kk.gt.1.d3) n_eff = -3.d0
c
      if(i.eq.1) pklin = pk_fid(ik_max) * (kk / ak_fid(ik_max)) ** n_eff
      if(i.eq.2) pklin = pk(ik_max) * (kk / ak(ik_max)) ** n_eff
c
      end
c
c ************************************************ c
c
      subroutine no_wiggle_pklin(ik_max,kmin,ak,pk_EH,cosm_params)
c
c ************************************************ c
c
      implicit none
      integer ik, ikmax, ik_max
      parameter(ikmax=2000)
      real*8  ak(ikmax), pk_EH(ikmax), cosm_params(7)
      real*8  const, kmin, Pk_lin_EH, pklin1
c     ----------------------------------
c
c ///// normalization at largest scale using target model  ///// c
c
      call find_pklin(2, kmin, pklin1)
      const = pklin1 / Pk_lin_EH(kmin, cosm_params) 
c
      do ik = 1, ik_max
         pk_EH(ik) = const * Pk_lin_EH(ak(ik), cosm_params) 
      enddo
c
      end
c
c ************************************************ c
c
      function Pk_lin_EH(k, cosm_params)
c
c ************************************************ c
c
c     compute un-normalized linear P(k) 
c     based on eq.(29) of Eisenstein & Hu (1998)
c     (no-wiggle approximation)  
c
c     cosm_params(1) :  omega_m
c     cosm_params(2) :  omega_v
c     cosm_params(3) :  omega_b
c     cosm_params(4) :  h
c     cosm_params(5) :  T_cmb
c     cosm_params(6) :  n_s
c     cosm_params(7) :  w
c
      implicit none
      real*8 k, ss, alpha_gam, theta_cmb
      real*8 gamma_eff, q, L0, C0, T_EH, Pk_lin_EH
      real*8 cosm_params(7)
      real*8 omegab, omega0, h, Tcmb, n_s
c     -----------------------------------------
c
      omega0 = cosm_params(1)
      omegab = cosm_params(3)
      h = cosm_params(4)
      Tcmb = cosm_params(5)
      n_s = cosm_params(6)

c ///// fitting formula for no-wiggle P(k) (Eq.[29] of EH98)
c
      ss = 44.5 * h * dlog( 9.83 / (omega0*h*h) ) / 
     &     dsqrt( 1.d0 + 10.d0 * (omegab*h*h)**0.75 )
      alpha_gam = 1.d0 
     &     - 0.328 * dlog( 431. * omega0*h*h ) * omegab/omega0
     &     + 0.38 * dlog( 22.3 * omega0*h*h ) * (omegab/omega0)**2
      theta_cmb = Tcmb / 2.70 
      gamma_eff = omega0 * h * 
     &     ( alpha_gam + (1.d0 - alpha_gam) / (1.d0 + (0.43*k*ss)**4) )
c
      q = k * theta_cmb**2 / gamma_eff
      L0 = dlog( 2.d0 * dexp(1.d0) + 1.8 * q ) 
      C0 = 14.2 + 731.d0 / ( 1.d0 + 62.5 * q )
c
      T_EH = L0 / (L0 + C0*q*q )
c
      Pk_lin_EH = k ** n_s * T_EH**2 
c
      end
c
c
c ************************************************************
c
      subroutine calc_xi(sigma8_boost)
c
c ************************************************************
c
c     Calculation of correlation function from the power spectrum 
c     data using a simple trapezoidal rule
c
      implicit none
      integer ik, ir, ix, ikmax, ik_max, ixmax, irmax
      integer inum_r, isample_r, icalc_xi,inum_z,ifast,iverbose
      integer iz,ifid
      parameter(ikmax=2000, ixmax=10000, irmax=1000)
      real*8  ak(ikmax), pk(ikmax)
      real*8  ar(irmax), xi_lin(irmax)
      real*8  xi_fast(irmax,100), dxi_fast(irmax,100)
      real*8  dxi_lin(irmax), sigma8_boost
      real*8  rmin, rmax, kmin, kmax, k1, k2
      real*8  pklin1a,  pklin2a,  pklin1b,  pklin2b,  sinc, pi
      real*8  pk1(100), dpk1(100), pk2(100), dpk2(100)
      common /pk_data/ ak, pk, ik_max
      common /dxi_fast/ ar, xi_lin, xi_fast, dxi_fast, dxi_lin
      common  /iset_r/  rmin, rmax, isample_r, inum_r
      common /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid

      pi = 4.d0 * datan(1.d0)
c     ------------------------------------------------
c
      kmin = ak(1)
      kmax = ak(ik_max)
c
      if(inum_r.gt.irmax) inum_r = irmax 
      if(ifast.eq.2) sigma8_boost = 1.d0
c
      do ir = 1, inum_r
         if(isample_r.eq.1 .or. isample_r.eq.2) 
     &        ar(ir) = rmin * (rmax/rmin)**(dble(ir-1)/dble(inum_r-1))
         if(isample_r.eq.3) 
     &        ar(ir) = rmin + (rmax-rmin)*(dble(ir-1)/dble(inum_r-1))
         xi_lin(ir) = 0.0d0
         dxi_lin(ir) = 0.0d0
         do iz=1, inum_z
            xi_fast(ir, iz) = 0.0d0
            dxi_fast(ir, iz) = 0.0d0
         enddo
c
         k1 = kmin
         call find_pklin(2, k1, pklin1a)
         call find_pklin(1, k1, pklin1b)
         call find_pk_fast(1, inum_z, k1, pk1)
         call find_pk_fast(2, inum_z, k1, dpk1)
c
         do ix = 1, ixmax-1
c
            k2 = kmin * (kmax/kmin) ** (dble(ix)/dble(ixmax-1))
c
            call find_pklin(2, k2, pklin2a)
            call find_pklin(1, k2, pklin2b)
            call find_pk_fast(1, inum_z, k2, pk2)
            call find_pk_fast(2, inum_z, k2, dpk2)
c
            xi_lin(ir) = xi_lin(ir) + 
     &           ( k1*k1 * sinc(k1*ar(ir)) * pklin1a 
     &           + k2*k2 * sinc(k2*ar(ir)) * pklin2a ) * (k2 - k1)/2.d0
c
            dxi_lin(ir) = dxi_lin(ir) + 
     &           ( k1*k1 * sinc(k1*ar(ir)) * pklin1b 
     &           + k2*k2 * sinc(k2*ar(ir)) * pklin2b ) * (k2 - k1)/2.d0
c
            do iz=1, inum_z
               xi_fast(ir, iz) = xi_fast(ir, iz) + 
     &              ( k1*k1 * sinc(k1*ar(ir)) * pk1(iz)
     &              + k2*k2 * sinc(k2*ar(ir)) * pk1(iz) ) * 
     &              (k2 - k1)/2.d0
               dxi_fast(ir, iz) = dxi_fast(ir, iz) + 
     &              ( k1*k1 * sinc(k1*ar(ir)) * dpk1(iz) 
     &              + k2*k2 * sinc(k2*ar(ir)) * dpk2(iz) ) * 
     &              (k2 - k1)/2.d0
            enddo
c     
            k1 = k2
            pklin1a = pklin2a
            pklin1b = pklin2b
            do iz=1, inum_z
               pk1(iz) = pk2(iz)
               dpk1(iz) = dpk2(iz)
            enddo
c
         enddo
c
         xi_lin(ir)   = xi_lin(ir)   / (2.d0*pi*pi)
         dxi_lin(ir)  = dxi_lin(ir) / (2.d0*pi*pi) * sigma8_boost**2
         dxi_lin(ir)  = xi_lin(ir) - dxi_lin(ir) 
         do iz=1, inum_z
            xi_fast(ir, iz) = xi_fast(ir, iz) / (2.d0*pi*pi)
            dxi_fast(ir, iz) = dxi_fast(ir, iz) / (2.d0*pi*pi)
         enddo
c     
      enddo
c     
      end
c
c ******************************************************* c
c
      function sinc(x)
c
c ******************************************************* c
c
      real*8 x, sinc
c
      if(dabs(x).le.1.d-3) then 
         sinc = 1 - x**2/6.d0 + x**4/120.d0
      else
         sinc = sin(x)/x
      endif
c
      end
c
c
c ******************************************************* c
c
      subroutine estimate_k_crit(D_growth, z_red) 
c
c ******************************************************* c
c
c     Estimate of validity range in RegPT based on the empirical 
c     criterion
c
c     k_crit^2 \int_0^k_crit dq P_lin(q,z) / (6*pi^2) = C
c
c     with C=0.7 (for 2-loop)
c
      implicit none
c
      integer ikmax, ik_max, ix, ixmax, iz
      integer iverbose, ifast, inum_z, icalc_xi, ifid
      real*8  sigmav_k, D_growth(100), z_red(100), pi
      real*8  CC, C_crit, C_crit_1loop, C_crit_2loop
      parameter(ikmax=2000, ixmax=1000)
      parameter(C_crit_2loop=0.7d0, C_crit_1loop=0.30d0)
      real*8  k, kmin, kmax, ak(ikmax), pk(ikmax)
      real*8  k1, k2, pklin1, pklin2, kcrit(100)
c
      common /pk_data/ ak, pk, ik_max
      common  /commandline2/ iverbose,ifast,inum_z,icalc_xi,ifid
c
      pi = 4.d0 * datan(1.d0)
c     ---------------------------------- 
c
      kmin = ak(1)
      kmax = ak(ik_max)
c
      if(ifast.eq.0 .or. ifast.eq.1) C_crit = C_crit_2loop
      if(ifast.eq.2) C_crit = C_crit_1loop
c
      do 10 iz=1, inum_z
c
         k1 = kmin
         pklin1 = pk(1)
         sigmav_k = 0.5d0 * k1 * pklin1 
c
         do ix=2, ixmax 
c
            k2 = kmin * (kmax/kmin)**(dble(ix-1)/dble(ixmax-1))
            call find_pklin(2,k2, pklin2)
c
            sigmav_k = sigmav_k + 0.5d0 * (k2 - k1) * (pklin2 + pklin1) 
c
            CC = D_growth(iz)**2 * k2**2 * sigmav_k / (6.d0*pi*pi)
c
            if(CC.ge.C_crit) then
               kcrit(iz) = k2
               goto 10
            else
               k1 = k2
               pklin1 = pklin2
            endif
c
         enddo
c
 10   continue
c
      write(6,*)
      if(ifast.eq.0 .or. ifast.eq.1) 
     &     write(6,*) '> Validity range of RegPT 2-loop in P(k)[h/Mpc]:'
      if(ifast.eq.2) 
     &     write(6,*) '> Validity range of RegPT 1-loop in P(k)[h/Mpc]:'
      write(6,*) '>'
      do iz=1, inum_z
         write(6,'(A,f4.2,A,f4.2)') 
     &        ' >            k_crit(z=',z_red(iz),')=',kcrit(iz)
      enddo
      write(6,*)
c
      end
c
c ************************************************ c
c
      SUBROUTINE hunt(xx,n,x,jlo)
c
c ************************************************ c
c
      implicit none
      INTEGER jlo,n
      REAL*8 x,xx(n)
      INTEGER inc,jhi,jm
      LOGICAL ascnd
      ascnd=xx(n).gt.xx(1)
      if(jlo.le.0.or.jlo.gt.n)then
        jlo=0
        jhi=n+1
        goto 3
      endif
      inc=1
      if(x.ge.xx(jlo).eqv.ascnd)then
1       jhi=jlo+inc
        if(jhi.gt.n)then
          jhi=n+1
        else if(x.ge.xx(jhi).eqv.ascnd)then
          jlo=jhi
          inc=inc+inc
          goto 1
        endif
      else
        jhi=jlo
2       jlo=jhi-inc
        if(jlo.lt.1)then
          jlo=0
        else if(x.lt.xx(jlo).eqv.ascnd)then
          jhi=jlo
          inc=inc+inc
          goto 2
        endif
      endif
3     if(jhi-jlo.eq.1)return
      jm=(jhi+jlo)/2
      if(x.gt.xx(jm).eqv.ascnd)then
        jlo=jm
      else
        jhi=jm
      endif
      goto 3
      END
c
c
c ************************************************************
c
      SUBROUTINE polint(xa,ya,n,x,y,dy)
c
c ************************************************************
c
      implicit none
      INTEGER n,NMAX
      REAL*8 dy,x,y,xa(n),ya(n)
      PARAMETER (NMAX=10)
      INTEGER i,m,ns
      REAL*8 den,dif,dift,ho,hp,w,c(NMAX),d(NMAX)
      ns=1
      dif=abs(x-xa(1))
      do 11 i=1,n
        dift=abs(x-xa(i))
        if (dift.lt.dif) then
          ns=i
          dif=dift
        endif
        c(i)=ya(i)
        d(i)=ya(i)
11    continue
      y=ya(ns)
      ns=ns-1
      do 13 m=1,n-1
        do 12 i=1,n-m
          ho=xa(i)-x
          hp=xa(i+m)-x
          w=c(i+1)-d(i)
          den=ho-hp
          if(den.eq.0.) then 
             write(6,*) 'failure in polint'
             stop
          endif
          den=w/den
          d(i)=hp*den
          c(i)=ho*den
12      continue
        if (2*ns.lt.n-m)then
          dy=c(ns+1)
        else
          dy=d(ns)
          ns=ns-1
        endif
        y=y+dy
13    continue
      return
      END
C
c ************************************************************
c
      SUBROUTINE gauleg(x1,x2,x,w,n)
c
c ************************************************************
c
      INTEGER n
      REAL*8 x1,x2,x(n),w(n)
      DOUBLE PRECISION EPS
      PARAMETER (EPS=3.d-14)
      INTEGER i,j,m
      DOUBLE PRECISION p1,p2,p3,pp,xl,xm,z,z1
      m=(n+1)/2
      xm=0.5d0*(x2+x1)
      xl=0.5d0*(x2-x1)
      do 12 i=1,m
        z=cos(3.141592654d0*(i-.25d0)/(n+.5d0))
1       continue
          p1=1.d0
          p2=0.d0
          do 11 j=1,n
            p3=p2
            p2=p1
            p1=((2.d0*j-1.d0)*z*p2-(j-1.d0)*p3)/j
11        continue
          pp=n*(z*p1-p2)/(z*z-1.d0)
          z1=z
          z=z1-p1/pp
        if(abs(z-z1).gt.EPS)goto 1
        x(i)=xm-xl*z
        x(n+1-i)=xm+xl*z
        w(i)=2.d0*xl/((1.d0-z*z)*pp*pp)
        w(n+1-i)=w(i)
12    continue
      return
      END
c
c
c ******************************************************* c
c
        SUBROUTINE HYGFX(A,B,C,X,HF)
c
c ******************************************************* c
C
C       ====================================================
C       Purpose: Compute hypergeometric function F(a,b,c,x)
C       Input :  a --- Parameter
C                b --- Parameter
C                c --- Parameter, c <> 0,-1,-2,...
C                x --- Argument   ( x < 1 )
C       Output:  HF --- F(a,b,c,x)
C       Routines called:
C            (1) GAMMAX for computing gamma function
C            (2) PSI for computing psi function
C       ====================================================
C
        IMPLICIT DOUBLE PRECISION (A-H,O-Z)
        LOGICAL L0,L1,L2,L3,L4,L5
        PI=3.141592653589793D0
        EL=.5772156649015329D0
        L0=C.EQ.INT(C).AND.C.LT.0.0
        L1=1.0D0-X.LT.1.0D-15.AND.C-A-B.LE.0.0
        L2=A.EQ.INT(A).AND.A.LT.0.0
        L3=B.EQ.INT(B).AND.B.LT.0.0
        L4=C-A.EQ.INT(C-A).AND.C-A.LE.0.0
        L5=C-B.EQ.INT(C-B).AND.C-B.LE.0.0
        IF (L0.OR.L1) THEN
           WRITE(*,*)'The hypergeometric series is divergent'
           RETURN
        ENDIF
        EPS=1.0D-15
        IF (X.GT.0.95) EPS=1.0D-8
        IF (X.EQ.0.0.OR.A.EQ.0.0.OR.B.EQ.0.0) THEN
           HF=1.0D0
           RETURN
        ELSE IF (1.0D0-X.EQ.EPS.AND.C-A-B.GT.0.0) THEN
           CALL GAMMAX(C,GC)
           CALL GAMMAX(C-A-B,GCAB)
           CALL GAMMAX(C-A,GCA)
           CALL GAMMAX(C-B,GCB)
           HF=GC*GCAB/(GCA*GCB)
           RETURN
        ELSE IF (1.0D0+X.LE.EPS.AND.DABS(C-A+B-1.0).LE.EPS) THEN
           G0=DSQRT(PI)*2.0D0**(-A)
           CALL GAMMAX(C,G1)
           CALL GAMMAX(1.0D0+A/2.0-B,G2)
           CALL GAMMAX(0.5D0+0.5*A,G3)
           HF=G0*G1/(G2*G3)
           RETURN
        ELSE IF (L2.OR.L3) THEN
           IF (L2) NM=INT(ABS(A))
           IF (L3) NM=INT(ABS(B))
           HF=1.0D0
           R=1.0D0
           DO 10 K=1,NM
              R=R*(A+K-1.0D0)*(B+K-1.0D0)/(K*(C+K-1.0D0))*X
10            HF=HF+R
           RETURN
        ELSE IF (L4.OR.L5) THEN
           IF (L4) NM=INT(ABS(C-A))
           IF (L5) NM=INT(ABS(C-B))
           HF=1.0D0
           R=1.0D0
           DO 15 K=1,NM
              R=R*(C-A+K-1.0D0)*(C-B+K-1.0D0)/(K*(C+K-1.0D0))*X
15            HF=HF+R
           HF=(1.0D0-X)**(C-A-B)*HF
           RETURN
        ENDIF
        AA=A
        BB=B
        X1=X
        IF (X.LT.0.0D0) THEN
           X=X/(X-1.0D0)
           IF (C.GT.A.AND.B.LT.A.AND.B.GT.0.0) THEN
              A=BB
              B=AA
           ENDIF
           B=C-B
        ENDIF
        IF (X.GE.0.75D0) THEN
           GM=0.0D0
           IF (DABS(C-A-B-INT(C-A-B)).LT.1.0D-15) THEN
              M=INT(C-A-B)
              CALL GAMMAX(A,GA)
              CALL GAMMAX(B,GB)
              CALL GAMMAX(C,GC)
              CALL GAMMAX(A+M,GAM)
              CALL GAMMAX(B+M,GBM)
              CALL PSI(A,PA)
              CALL PSI(B,PB)
              IF (M.NE.0) GM=1.0D0
              DO 30 J=1,ABS(M)-1
30               GM=GM*J
              RM=1.0D0
              DO 35 J=1,ABS(M)
35               RM=RM*J
              F0=1.0D0
              R0=1.0D0
              R1=1.0D0
              SP0=0.D0
              SP=0.0D0
              IF (M.GE.0) THEN
                 C0=GM*GC/(GAM*GBM)
                 C1=-GC*(X-1.0D0)**M/(GA*GB*RM)
                 DO 40 K=1,M-1
                    R0=R0*(A+K-1.0D0)*(B+K-1.0)/(K*(K-M))*(1.0-X)
40                  F0=F0+R0
                 DO 45 K=1,M
45                  SP0=SP0+1.0D0/(A+K-1.0)+1.0/(B+K-1.0)-1.0/K
                 F1=PA+PB+SP0+2.0D0*EL+DLOG(1.0D0-X)
                 DO 55 K=1,250
                    SP=SP+(1.0D0-A)/(K*(A+K-1.0))+(1.0-B)/(K*(B+K-1.0))
                    SM=0.0D0
                    DO 50 J=1,M
50                     SM=SM+(1.0D0-A)/((J+K)*(A+J+K-1.0))+1.0/
     &                    (B+J+K-1.0)
                    RP=PA+PB+2.0D0*EL+SP+SM+DLOG(1.0D0-X)
                    R1=R1*(A+M+K-1.0D0)*(B+M+K-1.0)/(K*(M+K))*(1.0-X)
                    F1=F1+R1*RP
                    IF (DABS(F1-HW).LT.DABS(F1)*EPS) GO TO 60
55                  HW=F1
60               HF=F0*C0+F1*C1
              ELSE IF (M.LT.0) THEN
                 M=-M
                 C0=GM*GC/(GA*GB*(1.0D0-X)**M)
                 C1=-(-1)**M*GC/(GAM*GBM*RM)
                 DO 65 K=1,M-1
                    R0=R0*(A-M+K-1.0D0)*(B-M+K-1.0)/(K*(K-M))*(1.0-X)
65                  F0=F0+R0
                 DO 70 K=1,M
70                  SP0=SP0+1.0D0/K
                 F1=PA+PB-SP0+2.0D0*EL+DLOG(1.0D0-X)
                 DO 80 K=1,250
                    SP=SP+(1.0D0-A)/(K*(A+K-1.0))+(1.0-B)/(K*(B+K-1.0))
                    SM=0.0D0
                    DO 75 J=1,M
75                     SM=SM+1.0D0/(J+K)
                    RP=PA+PB+2.0D0*EL+SP-SM+DLOG(1.0D0-X)
                    R1=R1*(A+K-1.0D0)*(B+K-1.0)/(K*(M+K))*(1.0-X)
                    F1=F1+R1*RP
                    IF (DABS(F1-HW).LT.DABS(F1)*EPS) GO TO 85
80                  HW=F1
85               HF=F0*C0+F1*C1
              ENDIF
           ELSE
              CALL GAMMAX(A,GA)
              CALL GAMMAX(B,GB)
              CALL GAMMAX(C,GC)
              CALL GAMMAX(C-A,GCA)
              CALL GAMMAX(C-B,GCB)
              CALL GAMMAX(C-A-B,GCAB)
              CALL GAMMAX(A+B-C,GABC)
              C0=GC*GCAB/(GCA*GCB)
              C1=GC*GABC/(GA*GB)*(1.0D0-X)**(C-A-B)
              HF=0.0D0
              R0=C0
              R1=C1
              DO 90 K=1,250
                 R0=R0*(A+K-1.0D0)*(B+K-1.0)/(K*(A+B-C+K))*(1.0-X)
                 R1=R1*(C-A+K-1.0D0)*(C-B+K-1.0)/(K*(C-A-B+K))
     &              *(1.0-X)
                 HF=HF+R0+R1
                 IF (DABS(HF-HW).LT.DABS(HF)*EPS) GO TO 95
90               HW=HF
95            HF=HF+C0+C1
           ENDIF
        ELSE
           A0=1.0D0
           IF (C.GT.A.AND.C.LT.2.0D0*A.AND.
     &         C.GT.B.AND.C.LT.2.0D0*B) THEN
              A0=(1.0D0-X)**(C-A-B)
              A=C-A
              B=C-B
           ENDIF
           HF=1.0D0
           R=1.0D0
           DO 100 K=1,250
              R=R*(A+K-1.0D0)*(B+K-1.0D0)/(K*(C+K-1.0D0))*X
              HF=HF+R
              IF (DABS(HF-HW).LE.DABS(HF)*EPS) GO TO 105
100           HW=HF
105        HF=A0*HF
        ENDIF
        IF (X1.LT.0.0D0) THEN
           X=X1
           C0=1.0D0/(1.0D0-X)**AA
           HF=C0*HF
        ENDIF
        A=AA
        B=BB
        IF (K.GT.120) WRITE(*,115)
115     FORMAT(1X,'Warning! You should check the accuracy')
        RETURN
        END
c
c ******************************************************* c
c
        SUBROUTINE GAMMAX(X,GA)
c
c ******************************************************* c
C
C       ==================================================
C       Purpose: Compute gamma function ??(x)
C       Input :  x  --- Argument of ??(x)
C                       ( x is not equal to 0,-1,-2,??????)
C       Output:  GA --- ??(x)
C       ==================================================
C
        IMPLICIT DOUBLE PRECISION (A-H,O-Z)
        DIMENSION G(26)
        PI=3.141592653589793D0
        IF (X.EQ.INT(X)) THEN
           IF (X.GT.0.0D0) THEN
              GA=1.0D0
              M1=X-1
              DO 10 K=2,M1
10               GA=GA*K
           ELSE
              GA=1.0D+300
           ENDIF
        ELSE
           IF (DABS(X).GT.1.0D0) THEN
              Z=DABS(X)
              M=INT(Z)
              R=1.0D0
              DO 15 K=1,M
15               R=R*(Z-K)
              Z=Z-M
           ELSE
              Z=X
           ENDIF
           DATA G/1.0D0,0.5772156649015329D0,
     &          -0.6558780715202538D0, -0.420026350340952D-1,
     &          0.1665386113822915D0,-.421977345555443D-1,
     &          -.96219715278770D-2, .72189432466630D-2,
     &          -.11651675918591D-2, -.2152416741149D-3,
     &          .1280502823882D-3, -.201348547807D-4,
     &          -.12504934821D-5, .11330272320D-5,
     &          -.2056338417D-6, .61160950D-8,
     &          .50020075D-8, -.11812746D-8,
     &          .1043427D-9, .77823D-11,
     &          -.36968D-11, .51D-12,
     &          -.206D-13, -.54D-14, .14D-14, .1D-15/
           GR=G(26)
           DO 20 K=25,1,-1
20            GR=GR*Z+G(K)
           GA=1.0D0/(GR*Z)
           IF (DABS(X).GT.1.0D0) THEN
              GA=GA*R
              IF (X.LT.0.0D0) GA=-PI/(X*GA*DSIN(PI*X))
           ENDIF
        ENDIF
        RETURN
        END
c
c ******************************************************* c
c
        SUBROUTINE PSI(X,PS)
c
c ******************************************************* c
C
C       ======================================
C       Purpose: Compute Psi function
C       Input :  x  --- Argument of psi(x)
C       Output:  PS --- psi(x)
C       ======================================
C
        IMPLICIT DOUBLE PRECISION (A-H,O-Z)
        XA=DABS(X)
        PI=3.141592653589793D0
        EL=.5772156649015329D0
        S=0.0D0
        IF (X.EQ.INT(X).AND.X.LE.0.0) THEN
           PS=1.0D+300
           RETURN
        ELSE IF (XA.EQ.INT(XA)) THEN
           N=XA
           DO 10 K=1 ,N-1
10            S=S+1.0D0/K
           PS=-EL+S
        ELSE IF (XA+.5.EQ.INT(XA+.5)) THEN
           N=XA-.5
           DO 20 K=1,N
20            S=S+1.0/(2.0D0*K-1.0D0)
           PS=-EL+2.0D0*S-1.386294361119891D0
        ELSE
           IF (XA.LT.10.0) THEN
              N=10-INT(XA)
              DO 30 K=0,N-1
30               S=S+1.0D0/(XA+K)
              XA=XA+N
           ENDIF
           X2=1.0D0/(XA*XA)
           A1=-.8333333333333D-01
           A2=.83333333333333333D-02
           A3=-.39682539682539683D-02
           A4=.41666666666666667D-02
           A5=-.75757575757575758D-02
           A6=.21092796092796093D-01
           A7=-.83333333333333333D-01
           A8=.4432598039215686D0
           PS=DLOG(XA)-.5D0/XA+X2*(((((((A8*X2+A7)*X2+
     &        A6)*X2+A5)*X2+A4)*X2+A3)*X2+A2)*X2+A1)
           PS=PS-S
        ENDIF
        IF (X.LT.0.0) PS=PS-PI*DCOS(PI*X)/DSIN(PI*X)-1.0D0/X
        RETURN
        END
c
