module user

	implicit none

	INTEGER, PARAMETER :: 			&
		DP = SELECTED_REAL_KIND(14),	&

!-----------------------------------------------------------------------------------------------!
!					GRID AND DOMAIN SIZE					!
!-----------------------------------------------------------------------------------------------!
		Nx=101,				& ! Nodes in the x-direction
		Ny=101,				& ! Nodes in the y-directionc
		!Ny=69 to have Ly=12h and Ny 91 to have Ly=18h

		ALGORITMO=2	!**    (ALGORITMO = SIMPLE (1), SIMPLEC (2))

	real(KIND = DP)  ::			&

		Hx,Hy,					& ! Domain size
		Factorx=1.0D-30,		& ! x-Screcth grid factor
		Factory=1.0D-30,		& ! y-Screcth grid factor
!-----------------------------------------------------------------------------------------------!
!					NUMERICAL PARAMETERS					!
!-----------------------------------------------------------------------------------------------!
		epsilonU=1.0D-7,		& ! Residual tolerance for U
		epsilonV=1.0D-7,		& ! Residual tolerance for V
		epsilonP=1.0D-7,		& ! Residual tolerance for P
		epsilonT=1.0D-7,		& ! Residual tolerance for T
		epsilonC=1.0D-7,		& ! Residual tolerance for C
		epsilonTK=1.0D-7,		& ! Residual tolerance for TK
		epsilone=1.0D-7,		& ! Residual tolerance for e

		relaxU=0.8D+00,			& ! Relax factor for U
		relaxV=0.8D+00,			& ! Relax factor for V
		relaxP=1.0D+00,			& ! Relax factor for P
		relaxT=0.8D+00,			& ! Relax factor for T
		relaxC=0.8D+00,			& ! Relax factor for C
		relaxTK=0.8D+00,		& ! Relax factor for TK
		relaxe=0.8D+00,			& ! Relax factor for e

		dt =5.0D-02,			& ! Time step
		to=0.0D+00			 ! Initial time

!-----------------------------------------------------------------------------------------------!
!					RANS PARAMATERS						!
!-----------------------------------------------------------------------------------------------!
	integer::															&
		rans_model = 0 !  0:Laminar |1:k-epsilon HH |2:k-epsilon JL |3: k-epsilon LS | 4:k-w PHD | 5:k-w WX 1994

	real(KIND = DP)  ::													&
		Cmu,C1e,C2e,Theta_k,Theta_e,Theta_t,C_k,C3e,Crw,Cw1,Cw2,		&
!-----------------------------------------------------------------------------------------------!
!					THERMOPHYSICAL PROPERTIES				!
!-----------------------------------------------------------------------------------------------!

		Ra=1.0D+07,			  & ! Rayleigh Number
		Bbeta=3.322D-03,		  & ! Expansion Coefficient for the Boussinesq Approximation
		Pr=0.71D+00,			  & ! Prantl Number
		Sch,			  	  & ! Schmidt Number: Turbulent~0.75
		Th,				  & ! Skin Temperature 
		Tc=297.5836D+00,		  & ! Air Temperature
		G=9.8D+00,			  & ! Gravity
		R=287.0D+00,			  & ! Gas Constant for Air
		Po=101325.0D+00,		  & ! Initial Pressure
		B1=26.916D+00,			  & ! Highest Building Height
		B2=25.782D+00,		  	  & ! Lowest Building Height
		BW=10.0D+00,			  & ! Building Width
		ABD=10.0D+00,			  & ! Above Building Distance
		BD=20.51D+00,			  & ! Distance between buildings
		U10,	  			  & ! Horizontal Speed from Upper View*: vary speed trying to adjust the results 
		V10,	  			  & ! Vertical Speed from Upper View*: vary speed trying to adjust the results
		zeta=45.00D+00,		  & ! Street Angle with Respect to the Meridian
		emiss,				  & ! BC Emissions from Vehicles: Baseline Value is 1.0D-09 kg/m³

		
		C_coflow, 			  & ! Try x2 and x1/2 to understand the emission influence
		CONTERo,							& ! Thermal conductivity
		MUo,ratio_mu,ratio_conter,			& ! Viscoity
		RHOo,								& ! Density
		Cpo	,								& ! Specific heat	
		Res_U,Res_V,Res_P,Res_T,Res_C,Res_TK,Res_e,Rmax_U,Rmax_V,Rmax_P,Rmax_T,Rmax_C,Rmax_e,Rmax_TK, &
		tadim,DeltaT,dt_adim,Tref,PSIP,RHOmed,Pmed, &
		time_start,time_finish

	integer::				&
		case_jet,			&
		Boussinesq=1,	  	&	! If Boussinesq=1 applies Bouss. Approx.. If Boussinesq=2 DO NOT APPLY Bouss. Appr. and density is variable
		CttProperties=1,	&  	! If CttProperties=1 properties are constant. if CttProperties=2 mu and conter are tmeprature dependent by Sutherland's law	
		ite_coupling=0



 		logical :: street_canyon =.TRUE., outside_canyon

	        real(KIND = DP)  :: U_bg ! Background Velocity
!-----------------------------------------------------------------------------------------------!
!					SOLVER OPTIONS						!
!-----------------------------------------------------------------------------------------------!
	
	integer::					&
!		itermax_t=15000,			& ! Maximum number of iterations

		itermax=1000,			& ! Maximum number of iterations, usually 50k
		iter,iter_t,i,j,		&

		npas_P=15,			& ! Time to apply the P-solver subroutine per iteration 
		npas_U=1,			& ! Time to apply the U-solver subroutine per iteration 
		npas_V=1,			& ! Time to apply the V-solver subroutine per iteration
		npas_T=1,			& ! Time to apply the T-solver subroutine per iteration
		npas_C=1,			& ! Time to apply the C-solver subroutine per iteration

		n=4,				& ! Interpolation scheme: 1:Central, 2:Upwind, 3:Hybrid, 4:Power law, 5:Exponential


		n_high_order_scheme = 0 	! No HOS: 		n_high_order_scheme = 0	
									! Van Leer: 	n_high_order_scheme = 1
									! Van Albada: 	n_high_order_scheme = 2
									! Min-Mod: 		n_high_order_scheme = 3
									! SUPERBEE : 	n_high_order_scheme = 4
									! QUICK :		n_high_order_scheme = 5
									! UMIST :		n_high_order_scheme = 6

	logical :: high_order_on_velocities_u=.false., high_order_on_velocities_v=.false., high_order_on_scalars=.false.


!-----------------------------------------------------------------------------------------------!
!					MATRIX DIMENSIONS					!
!-----------------------------------------------------------------------------------------------!
	real(KIND = DP), dimension(Nx) :: 	&
		DXP,X,DXU,XU

	real(KIND = DP), dimension(Ny) :: 	&
		DYP,Y,DYV,YV,U_in,Tk_in,e_in,T_in,C_in

	real(KIND = DP), dimension(Nx,Ny) :: 	&
		apu,apv,ae,aw,an,as,ap,b,du,dv,	&
		Ux,U,Uold,			&
		Vx,V,Vold,			&
		Px,P,Pc,T,C,Told,Cold,			&
		mu,CONTER,cp,rho,RHOold,	&
		TxxL, TyyL, TxyL,		&
		TxxT, TyyT, TxyT,		&
		MuT, TK,Tkx, e,			&
		Fep,Fnp,Pk,Gk,APUNB,APVNB,Rij_T,Rij_C,Rij_u,Rij_v,Sdc_ij_v, &
		P_rad

end module user
