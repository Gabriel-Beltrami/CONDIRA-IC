program CONDIRA

	use user
	use grids
	use cfdlib
	use visual 

	implicit none

	call CPU_TIME(Time_start)


	call dependent_var(DeltaT,Hx,Hy,dt,Tref,CONTERo,Po,Muo)			! Compute dependent variables
	!call GRID_half_jet(DXP,DYP,DXU,DYV,X,Y,XU,YV)					! Grid generation
	call GRID2d (DXP,DYP,DXU,DYV,X,Y,XU,YV,Hx,Hy)
	!call dependent_var(DeltaT,Hx,Hy,dt,Tref,CONTERo,Po,Muo)			! Compute dependent variables
	call start(U,V,P,T,Tref,rho,Fep,Fnp,TKx,e)						! Initaial values for U,V and P

	!--------------------------------------- SIMPLE/SIMPLEC -------------------------------------------------------!
	do iter=1,itermax

		call update_U (Ux,U)						! Replace Ux=U
		call update_V (Vx,V)						! Replace Vx=V		
		call update_P (Px,P)						! Replace Px=P
		call update_P (Tk,Tkx)						! Replace Tkx=Tk		

		   ! Detemine the local thermal properties
        CALL PROPERTIES(Mu,CONTER,CP,CONTERo,T,Muo,CPo,RHO,Po,Pmed,Hx,Hy,DXP,DYP,Tref,RHOo,MuT,e,TK)


		if (rans_model .eq. 0) then
			CALL stressLT(Mu,U,V,DXP,DYP,DYV,DXU,TxxL,TyyL,TxyL, TxxT, TyyT, TxyT, Tk, MuT, RHO)
			TxxT(:,:) = 0.0D+0 ; TxyT(:,:) = 0.0D+0 ; TyyT(:,:) = 0.0D+0 ; MuT(:,:) = 0.0D+0 ;
		else
			CALL stressLT(Mu,U,V,DXP,DYP,DYV,DXU,TxxL,TyyL,TxyL, TxxT, TyyT, TxyT, Tk, MuT, RHO)
		end if


		   ! Compute U 	
	    call coef_U(DXP,DYP,DXU,DYV,X,Y,XU,YV,				&
			Ux,Vx,Px,							&
			du,ae,aw,as,an,b,RES_U,Rmax_U,mu,apu,dt,RHO,			&
			TxxL, TyyL, TxyL, Fep, Fnp, MUt, TxxT, TyyT, TxyT,APUNB)

		call LBL_adi(1,1,(Nx-1),Ny,apu,ae,aw,an,as,b,Ux,npas_U,RELAXU)
!		call LBL_x(1,1,(Nx-1),Ny,apu,ae,aw,an,as,b,Ux,npas_U,RELAXU)

		   ! Compute V 	
	    call COEF_V(DXP,DYP,DXU,DYV,X,Y,XU,YV,				&
		 	 Ux,Vx,Px,dv,ae,aw,as,an,b,					&
		 	 RES_V,Rmax_V,mu,apv,dt,Tref,RHO,RHOmed,			&
		  	TxxL, TyyL, TxyL, Fep, Fnp, MuT, TxxT, TyyT, TxyT,APVNB)

	    call LBL_adi(1,1,Nx,(Ny-1),apv,AE,AW,AN,AS,B,Vx,npas_V,RELAXV)
			!	call LGS_adi(1,1,Nx,(Ny-1),apv,AE,AW,AN,AS,B,Vx,npas_V,RELAXV)
!	    call LBL_x(1,1,Nx,(Ny-1),apv,AE,AW,AN,AS,B,Vx,npas_V,RELAXV)

		   ! Compute P 

		call COEF_P(DXP,DYP,Ux,Vx,du,dv,ap,ae,aw,as,an,b,RES_P,Rmax_P,RHO,apu,apv,apunb,apvnb)	
	    call reset(Pc)							
		call LBL_ADI(1,1,Nx,Ny,AP,AE,AW,AN,AS,B,Pc,npas_P,RelaxP)

		   ! Update corrected values
		call update_U (U,Ux)						
		call update_V (V,Vx)
		call correct (U,Ux,V,Vx,Pc,P,Px,du,dv,Fep,Fnp,rho)
		
		!C
				DO I=2,NX-1
					   P(I,1)=P(I,2)                                        !        "FRONTERA SUR"
					   P(I,NY)=P(I,NY-1)                                     !       "FRONTERA NORTE"
				END DO                                                                
				DO J=1,NY
					   P(1,J)=P(2,J)                                         !       "FRONTERA OESTE"
					   P(NX,J)=P(NX-1,J)                                     !       "FRONTERA ESTE"
				END DO  
			!C
			!CC    CALCULO DE LA VELOCIDAD U Y V EN LA FRONTERA
			!C
				DO I=1,NX-1
					   U(I,1)=0.0D+00                                         !      "FRONTERA SUR"
					   U(I,NY)=0.0D+00                                        !      "FRONTERA NORTE"
				END DO                                                                
				DO J=2,NY-1
					   U(1,J)=0.0D+00                                          !     "FRONTERA OESTE"
					   U(NX-1,J)=0.0D+00                                       !     "FRONTERA ESTE"
				END DO  

				DO I=1,NX
					   V(I,1)=0.0D+00                                           !    "FRONTERA SUR"
					   V(I,NY-1)=0.0D+00                                        !    "FRONTERA NORTE"
				END DO                                                                
				DO J=2,NY-2
					   V(1,J)=0.0D+00                                           !    "FRONTERA OESTE"
					   V(NX,J)=0.0D+00                                          !    "FRONTERA ESTE"
        			END DO 

	call MASSFLUXES(RHOo,U,V,FEP,FNP,iter)

	!---------------------------------------END SIMPLE/SIMPLEC-----------------------------------------------------!

	!--------------------------------------- Compute scalars  -----------------------------------------------------!
		   ! Compute T 	
	      	call COEF_T(DXP,DYP,DXU,DYV,X,Y,XU,YV,							&
			CONTER,Cp,RHO,U,V,T,ap,ae,aw,as,an,b,Res_T,Rmax_T,dt,Fep,Fnp,MUt)

	      	call LBL_ADI(1,1,Nx,Ny,ap,AE,AW,AN,AS,B,T,npas_T,RELAXT)
!	      	call LBL_x(1,1,Nx,Ny,ap,AE,AW,AN,AS,B,T,npas_T,RELAXT)

		if (rans_model .ne. 0) then

		   ! Compute TK	
			call COEF_Tk(DXP,DYP,DXU,DYV,X,Y,XU,YV,							&
				Mu,Mut,RHO,U,V,TKx,e,ap,ae,aw,as,an,b,Res_Tk,Rmax_Tk,dt,Fep,Fnp,T,Txxt,Tyyt,Txyt,Pk,Gk)
			call LBL_ADI(1,1,Nx,Ny,ap,AE,AW,AN,AS,B,Tkx,npas_T,RELAXTk)
			
			DO I=1,NX
				   TKx(I,1)=0.0D+00                                            !  "FRONTERA SUR"
				   TKx(I,NY)=0.0D+00                                            ! "FRONTERA NORTE"
			END DO                                                                
			DO J=2,NY-1
				   TKx(1,J)=0.0D+00                                             ! "FRONTERA OESTE"
				   TKx(NX,J)=0.0D+00                                            ! "FRONTERA ESTE"
			END DO  

		   ! Compute e	
			call COEF_e(DXP,DYP,DXU,DYV,X,Y,XU,YV,			&
				Mu,MuT,RHO,U,V,Tk,e,ap,ae,aw,as,an,b,Res_e,Rmax_e,dt,Fep,Fnp,T,Txxt,Tyyt,Txyt,Pk,Gk)	
			call LBL_ADI(1,1,Nx,Ny,ap,AE,AW,AN,AS,B,e,npas_T,RELAXe)
			
			DO I=1,NX
				   E(I,1)=E(I,2)        !"FRONTERA SUR"
				   E(I,NY)=E(I,NY-1)    !"FRONTERA NORTE"
			END DO                                                                
			DO J=2,NY-1
				   E(1,J)=E(2,J)        !"FRONTERA OESTE"
				   E(NX,J)=E(NX-1,J)    !"FRONTERA ESTE"
			END DO  

		end if

	!--------------------------------------- check convergence  -----------------------------------------------------!

		   ! Monitoring residual values during execution
		if (mod(iter,1000)==0) then
			call print_Residual (iter,iter_t,Res_U,Res_V,Res_P,Rmax_U,Rmax_V,Rmax_P,Res_T,Rmax_T,	&
				Res_Tk,Rmax_Tk,Res_e,Rmax_e)
		end if

		if ( converegence(Res_U,Res_V,Res_P,Res_T,Res_e,Res_TK,iter)  ) then
			exit
		   end if

	end do
!--------------------------------------------- 		 END Loop 	-----------------------------------------------------!
	
	call write_vtk(U,V,P,T,b,iter_t,TK,e,MuT)
		call literatura_compare(iter_t,X,Hy,Hx,DeltaT,tadim,U,V,T,Pmed,Po,CONTERo,CONTER,Mu,MuT)


	call CPU_TIME(Time_finish)
        write(*,*) (time_finish-time_start)

	close(2)
	close(3)
	
end program CONDIRA


