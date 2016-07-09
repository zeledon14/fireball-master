! copyright info:
!
!                             @Copyright 2016
!                           Fireball Committee
! West Virginia University - James P. Lewis, Chair
! Arizona State University - Otto F. Sankey
! Universidad Autonoma de Madrid - Jose Ortega
! Academy of Sciences of the Czech Republic - Pavel Jelinek

! Previous and/or current contributors:
! Auburn University - Jian Jun Dong
! Caltech - Brandon Keith
! Dublin Institute of Technology - Barry Haycock
! Pacific Northwest National Laboratory - Kurt Glaesemann
! University of Texas at Austin - Alex Demkov
! Ohio University - Dave Drabold
! Washington University - Pete Fedders
! West Virginia University - Ning Ma and Hao Wang
! also Gary Adams, Juergen Frisch, John Tomfohr, Kevin Schmidt,
!      and Spencer Shellman

!
! RESTRICTED RIGHTS LEGEND
! Use, duplication, or disclosure of this software and its documentation
! by the Government is subject to restrictions as set forth in subdivision
! { (b) (3) (ii) } of the Rights in Technical Data and Computer Software
! clause at 52.227-7013.

! M_Dassemble_rho_McWEDA
! Module Description
! ===========================================================================
!>       This is a module containing  the assembler programs required
!! to calculate the matrix elements for the densities rho_in and rho_at
!! used in the McWEDA-Harris interactions (e.g. Sankey-Niklewski).
!! It contains the following subroutines within the module:
!!
!!       Dassemble_rho_2c.f90 - assembles  two center part for rho_in and rho_at
!!       Dassemble_rho_3c.f90 - three center part for rho_in
!!       Dassemble_rho_average.f90 - calculates the final result for average
!!                                  densities
!!       Dassemble_rho_weighted_2c.f90 - assembles two center part
!!                                      for Wrho, Wrho_bond
!!       Dassemble_rho_weighted_3c.f90 - three center part for Wrho
!!       Dassemble_S_weighted.f90 - assembles overlap_weighted (and averaged)
!!                                 PRB 71, 235101 (2005):
!!                                 denominators in Eqs. (19), (22) and (25)
!!
!! For a complete list of the interactions see the files 2c.Z1.Z2.dir now
!! located in the Fdata directory.  This list will change depending on
!! the datafiles included there. This list is an output from running create.x
! ===========================================================================
         module M_Dassemble_vxc_3c
         use M_assemble_blocks
         use M_configuraciones
         use M_Fdata_2c
         use M_Fdata_3c
         use M_rotations
         use M_Drotations 
        
! Type Declaration
! ===========================================================================
! None

! module procedures
         contains


! ===========================================================================
! Dassemble_vxc_3c
! ===========================================================================
! Subroutine Description
! ===========================================================================
!>       This routine calculates neutral atom 3-center matrix interactions
!! for rho_in - used to evaluate exchange-correlation interactions.
!
! ===========================================================================
! Code written by:
!> @author James P. Lewis
! Box 6315, 209 Hodges Hall
! Department of Physics
! West Virginia University
! Morgantown, WV 26506-6315
!
! (304) 293-5141 (office)
! (304) 293-5732 (FAX)
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_vxc_3c (s)
        implicit none

        include '../include/constants.h'
        include '../include/interactions_3c.h'

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s           !< the structure to be used.

! Parameters and Data Declaration
! ===========================================================================
! None

! Variable Declaration and Description
! ===========================================================================
        integer ialpha, iatom, jatom     !< the three parties involved
        integer ibeta, jbeta             !< cells for three atoms
        integer ineigh, mneigh           !< counter over neighbors
        integer in1, in2, in3            !< species numbers
        integer isubtype                 !< which subtype
        integer interaction, isorp       !< which interaction and subtype
        integer ix, iindex
        integer nssh_i, nssh_j           !< size of the block for the pair
        integer issh, jssh               !< counter over shells
        integer norb_mu, norb_nu         !< size of the block for the pair
        integer imu, inu
        real dexc_in                       !< 1st derivative of xc
        real d2exc_in                      !< 2nd derivativive of xc
        real dmuxc_in                      !< 1st derivative of xc
        real exc_in                        !< xc energy
        real muxc_in                       !< xc potential_
        real d2muxc_in                     !< 2nd derivative of xc

        real Qneutral                    !< charge
        real z                           !< distances between r1 and r2
        real x, cost                     !< dnabc and angle
        real rho_aver
        real, dimension (3, 3) :: eps     !< the epsilon matrix
        real, dimension (3, 3, 3) :: deps !< derivative of epsilon matrix
        real, dimension (3) :: r1, r2, r3, r12, r21   !< positions
        real, dimension (3) :: sighat     !< unit vector along r2 - r1
        real, dimension (3) :: rhat       !< unit vector along bc - r3
        real, dimension (3) :: amt
        real, dimension (3) :: bmt
        
        real, dimension (3, 3, 3) :: depsA  !< the Depsilon matrix for the bond-charge
        real, dimension (3, 3, 3) :: depsB  !< the Depsilon matrix for the potential

! bcxcm = density matrix in molecular coordinates
! bcxcx = density matrix in crystal coordinates
! d..bcxcm = derivative of density matrix in molecular coordinates
! vdxcM.. = vectorized derivative of density matrix in molecular coordinates
! vdxcX.. = vectorized derivative of density matrix in crystal coordinates
        real, dimension (:, :), allocatable :: bcxcm
        real, dimension (:, :), allocatable :: bcxcx
        real, dimension (:, :), allocatable :: dpbcxcm
        real, dimension (:, :), allocatable :: dxbcxcm
        real, dimension (:, :), allocatable :: dybcxcm
        
        real, dimension (:, :, :), allocatable :: vdxcMa
        real, dimension (:, :, :), allocatable :: vdxcMb
        real, dimension (:, :, :), allocatable :: vdxcXa
        real, dimension (:, :, :), allocatable :: vdxcXb
        real, dimension (:, :, :), allocatable :: vdxcXc
        
        real, dimension (:, :, :), allocatable :: rhoxa !rho crystal coord, deriv respect to a
        real, dimension (:, :, :), allocatable :: rhoxb !rho crystal coord, deriv respect to b
        real, dimension (:, :, :), allocatable :: rhoxc !rho crystal coord, deriv respect to c

        real, dimension (:, :), allocatable :: bcxcm_weig
        real, dimension (:, :), allocatable :: bcxcx_weig
        real, dimension (:, :), allocatable :: dpbcxcm_weig
        real, dimension (:, :), allocatable :: dxbcxcm_weig
        real, dimension (:, :), allocatable :: dybcxcm_weig

        real, dimension (:, :, :), allocatable :: vdxcMa_weig
        real, dimension (:, :, :), allocatable :: vdxcMb_weig
        real, dimension (:, :, :), allocatable :: vdxcMc_weig

        real, dimension (:, :, :), allocatable :: rhoma_weig !rho molecular coord, deriv respect to a
        ! and weighted over the shells
        real, dimension (:, :, :), allocatable :: rhomb_weig !rho molecular coord, deriv respect to b
        ! and weighted over the shells
        real, dimension (:, :, :), allocatable :: rhomc_weig !rho molecular coord, deriv respect to c
        ! and weighted over the shells

        type(T_Fdata_cell_3c), pointer :: pFdata_cell
        type(T_Fdata_bundle_3c), pointer :: pFdata_bundle

        !force
        type(T_forces), pointer :: pfalpha
        type(T_forces), pointer :: pfi
        type(T_forces), pointer :: pfj

        ! density matrix stuff
        type(T_assemble_neighbors), pointer :: pdenmat
        type(T_assemble_block), pointer :: pRho_neighbors

        interface
          function distance (a, b)
            real distance
            real, intent (in), dimension (3) :: a, b
          end function distance
        end interface
        type(T_assemble_neighbors), pointer :: prho_in
        type(T_assemble_block), pointer :: prho_in_neighbors

        type(T_assemble_neighbors), pointer :: prhoS_in ! weighted over shells
        type(T_assemble_block), pointer :: prhoS_in_neighbors! weighted over shells

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
! Loop over the atoms in the central cell.
        do ialpha = 1, s%natoms
          in3 = s%atom(ialpha)%imass
          r3 = s%atom(ialpha)%ratom
          pfalpha=>s%forces(ialpha)
          rho_aver= 0.0d0
          ! loop over the common neighbor pairs of ialpha
          do ineigh = 1, s%neighbors(ialpha)%ncommon
            mneigh = s%neighbors(ialpha)%neigh_common(ineigh)
            if (mneigh .ne. 0) then
              iatom = s%neighbors(ialpha)%iatom_common_j(ineigh)
              ibeta = s%neighbors(ialpha)%iatom_common_b(ineigh)
              r1 = s%atom(iatom)%ratom + s%xl(ibeta)%a
              in1 = s%atom(iatom)%imass
              norb_mu = species(in1)%norb_max
              nssh_i = species(in1)%nssh

              jatom = s%neighbors(ialpha)%jatom_common_j(ineigh)
              jbeta = s%neighbors(ialpha)%jatom_common_b(ineigh)
              r2 = s%atom(jatom)%ratom + s%xl(jbeta)%a
              in2 = s%atom(jatom)%imass
              norb_nu = species(in2)%norb_max
              nssh_j = species(in2)%nssh

              ! cut some lengthy notation
              prho_in=>s%rho_in(iatom); prho_in_neighbors=>prho_in%neighbors(mneigh)
              
              prhoS_in=>s%rho_in_weighted(iatom)
              prhoS_in_neighbors=>prhoS_in%neighbors(mneigh)

              pfi=>s%forces(iatom); pfj=>s%forces(jatom)

              pdenmat=>s%denmat(iatom)
              pRho_neighbors=>pdenmat%neighbors(mneigh) !rho_3c


! SET-UP STUFF
! ***************************************************************************
! Find r21 = vector pointing from r1 to r2, the two ends of the bondcharge.
! This gives us the distance dbc (or y value in the 2D grid).
              r21 = r2 - r1
              z = distance (r1, r2)

              ! unit vector in sigma direction.
              if (z .lt. 1.0d-05) then
                sighat(1) = 0.0d0
                sighat(2) = 0.0d0
                sighat(3) = 1.0d0
              else
                sighat = (r2 - r1)/z
              end if

! ***************************************************************************
! Find rnabc = vector pointing from center of bondcharge to r3
! This gives us the distance dnabc (or x value in the 2D grid).
              r12 = 0.5d0*(r1 + r2)
              x = distance (r12, r3)

              ! unit vector in rnabc direction.
              if (x .lt. 1.0d-05) then
                rhat(1) = 0.0d0
                rhat(2) = 0.0d0
                rhat(3) = 0.0d0
              else
                rhat = (r3 - 0.5d0*(r1 + r2))/x
              end if
              cost = dot_product(sighat, rhat)

              call epsilon_function (rhat, sighat, eps)
              call Depsilon_3c (r1, r2, r21, z, r3, rhat, eps, depsA, depsB)

! Get the matrix from the data files - which is the matrix in molecular
! coordinates, stored in bcxcm. where m means molecular coordinates.
! Rotate the matrix into crystal coordinates. The rotated  matrix elements
! are stored in bcxcx, where x means crytal coordinates.
              ! matrix element derivatives
              allocate (bcxcm(norb_mu, norb_nu)); bcxcm = 0.0d0
              allocate (bcxcx(norb_mu, norb_nu)); bcxcx = 0.0d0
              allocate (dpbcxcm(norb_mu, norb_nu)); dpbcxcm = 0.0d0
              allocate (dxbcxcm(norb_mu, norb_nu)); dxbcxcm = 0.0d0
              allocate (dybcxcm(norb_mu, norb_nu)); dybcxcm = 0.0d0
              
              ! vectorial representations
              allocate (vdxcMa(3, norb_mu, norb_nu)); vdxcMa = 0.0d0
              allocate (vdxcMb(3, norb_mu, norb_nu)); vdxcMb = 0.0d0
              allocate (vdxcXa(3, norb_mu, norb_nu)); vdxcXa = 0.0d0
              allocate (vdxcXb(3, norb_mu, norb_nu)); vdxcXb = 0.0d0
              allocate (vdxcXc(3, norb_mu, norb_nu)); vdxcXc = 0.0d0
              
              allocate (rhoxa(3, norb_mu, norb_nu)); rhoxa = 0.0d0
              allocate (rhoxb(3, norb_mu, norb_nu)); rhoxb = 0.0d0
              allocate (rhoxc(3, norb_mu, norb_nu)); rhoxc = 0.0d0

              allocate (bcxcm_weig (nssh_i, nssh_j)); bcxcm_weig = 0.0d0
              allocate (bcxcx_weig (nssh_i, nssh_j)); bcxcx_weig = 0.0d0
              allocate (dpbcxcm_weig (nssh_i, nssh_j)); dpbcxcm_weig = 0.0d0
              allocate (dxbcxcm_weig (nssh_i, nssh_j)); dxbcxcm_weig = 0.0d0
              allocate (dybcxcm_weig (nssh_i, nssh_j)); dybcxcm_weig = 0.0d0

              ! vectorized derivatives
              allocate (vdxcMa_weig (3, nssh_i, nssh_j)); vdxcMa_weig = 0.0d0
              allocate (vdxcMb_weig (3, nssh_i, nssh_j)); vdxcMb_weig = 0.0d0
              allocate (vdxcMc_weig (3, nssh_i, nssh_j)); vdxcMc_weig = 0.0d0

              allocate (rhoma_weig (3, nssh_i, nssh_j)); rhoma_weig = 0.0d0
              allocate (rhomb_weig (3, nssh_i, nssh_j)); rhomb_weig = 0.0d0
              allocate (rhomc_weig (3, nssh_i, nssh_j)); rhomc_weig = 0.0d0
 
              do isubtype = 1, species(in3)%nssh
                Qneutral = species(in3)%shell(isubtype)%Qneutral
                
                bcxcm= 0.0d0; dpbcxcm= 0.0d0;
                dxbcxcm= 0.0d0; dybcxcm= 0.0d0;
                vdxcMa = 0.0d0; vdxcMb = 0.0d0;
                vdxcXa = 0.0d0; vdxcXb = 0.0d0; vdxcXc = 0.0d0

                bcxcm_weig= 0.0d0; dpbcxcm_weig= 0.0d0;
                dxbcxcm_weig= 0.0d0; dybcxcm_weig= 0.0d0;
                !vdxcMa_weig = 0.0d0; vdxcMb_weig = 0.0d0;
                !vdxcXa_weig = 0.0d0; vdxcXb_weig = 0.0d0; vdxcXc_weig = 0.0d0
                call getDMEs_Fdata_3c (in1, in2, in3, P_rho_3c, isubtype, x, &
     &                                 z, norb_mu, norb_nu, cost, rhat,      &
     &                                 sighat, bcxcm, dpbcxcm, dxbcxcm, dybcxcm)
             
                call getDMEs_Fdata_3c (in1, in2, in3, P_rhoS_3c, isubtype, x,&
     &                                 z, nssh_i, nssh_j, cost, rhat, sighat,&
     &                                 bcxcm_weig, dpbcxcm_weig, dxbcxcm_weig, dybcxcm_weig)

                ! Rotate into crystal coordinates
                call rotate (in1, in2, eps, norb_mu, norb_nu, bcxcm, bcxcx)
                do ix = 1, 3

! The first piece will be the force with respect to atom 3.
                 if (x .gt. 1.0d-5) then
                  amt(ix) = (sighat(ix) - cost*rhat(ix))/x
                 else
                  amt = 0.0d0
                 end if

                 bmt(:) = (cost*sighat(:) - rhat(:))/z

                 pFdata_bundle => Fdata_bundle_3c(in1, in2, in3)
                 pFdata_cell =>                                               &
     &             pFdata_bundle%Fdata_cell_3c(pFdata_bundle%index_3c(P_rho_3c,isubtype,1))

                 do iindex = 1, pFdata_cell%nME
                   imu = pFdata_cell%mu_3c(iindex)
                   inu = pFdata_cell%nu_3c(iindex)

! Now recover f3naMa which is a two-dimensional array
                   vdxcMa(ix,imu,inu) = rhat(ix)*dxbcxcm(imu,inu)            &
     &                                 + amt(ix)*dpbcxcm(imu,inu)

! The second piece will be the force with respect to atom 1.
                   bmt(ix) = (cost*sighat(ix) - rhat(ix))/z

! Now recover f3naMb which is a two-dimensional array
                   vdxcMb(ix,imu,inu) = - sighat(ix)*dybcxcm(imu, inu)       &
     &                                   + bmt(ix)*dpbcxcm(imu, inu)         &
     &                                   - vdxcMa(ix,imu,inu)/2.0d0
                 end do ! iindex
                end do ! ix

                do issh = 1, species(in1)%nssh
                   do jssh = 1, species(in2)%nssh
                     vdxcMa_weig(:,issh,jssh) = rhat(:)*dxbcxcm_weig(issh,jssh) + amt(:)*dpbcxcm_weig(issh,jssh)
                     bmt(:) = (cost*sighat(:) - rhat(:))/z

                     vdxcMb_weig(:,issh,jssh) = - sighat(:)*dybcxcm_weig(issh,jssh)                             &
     &                                      + bmt(:)*dpbcxcm_weig(issh,jssh) - vdxcMa_weig(:,issh,jssh)/2.0d0
                     vdxcMc_weig(:,issh,jssh) = - vdxcMa_weig(:,issh,jssh) - vdxcMb_weig(:,issh,jssh)
                   end do ! jssh
                end do ! issh
! ***************************************************************************
! Convert to Crystal Coordinates
! ***************************************************************************
! The call to rotated does the rotations to crystal coordinates of these
! force things.
!
! For example:
! Suppose we have f_A(3,mu,nu), which is d/dratm M(mu,nu) where M(mu,nu)
! is in molecular. To transform M(mu,nu) to crystal, we need Udag * M * U.
! Therefore, f_A(3,mu,nu)[CRYSTAL] = (d/dratm Udag) * M * U
!                                   + Udag * M * (d/dratm U)
!                                   + Udag * f_A * U.
!
! So, to use this baby, put in deps3c (deps/dr1, deps/dr2, deps/dratm),
! and f_A and M.
!
! NOTE: rotated works on the assumption that we are adding derivatives,
! NOT forces. So f3naMa,... etc. MUST not yet be forcelike.
! We do the - sign for forces at the end.
! ***************************************************************************
! Force on the neutral atom with respect to atom 3 (f3naMa).
                call Drotate (in1, in2, eps, depsA, norb_mu, norb_nu, bcxcm, &
     &                        vdxcMa, vdxcXa)

! Force on the neutral atom with respect to atom 1 (f3naMb).
                call Drotate (in1, in2, eps, depsB, norb_mu, norb_nu, bcxcm, &
     &                        vdxcMb, vdxcXb)

! Make things force-like and determine f3naXc, whcih is found from Newtons Laws:
                vdxcXa(:,:,:) = - vdxcXa(:,:,:)
                vdxcXb(:,:,:) = - vdxcXb(:,:,:)
                vdxcXc(:,:,:) = - vdxcXa(:,:,:) - vdxcXb(:,:,:)

                rhoxa = rhoxa + vdxcXa*Qneutral
                rhoxb = rhoxb + vdxcXb*Qneutral
                rhoxc = rhoxc + vdxcXc*Qneutral

                rhoma_weig =  rhoma_weig + vdxcMa_weig*Qneutral
                rhomb_weig =  rhomb_weig + vdxcMb_weig*Qneutral
                rhomc_weig =  rhomc_weig + vdxcMc_weig*Qneutral

              end do ! isubtype = 1, species(in3)%nssh

              deallocate (bcxcm, bcxcx, dpbcxcm, dxbcxcm, dybcxcm)
              deallocate (vdxcMa, vdxcMb, vdxcXa, vdxcXb, vdxcXc)
              deallocate (bcxcm_weig, bcxcx_weig, dpbcxcm_weig, dxbcxcm_weig, dybcxcm_weig)
              deallocate (vdxcMa_weig, vdxcMb_weig, vdxcMc_weig)



              do issh = 1, species(in1)%nssh
                do jssh = 1, species(in2)%nssh
                  call lda_ceperley_alder (prhoS_in_neighbors%block(issh,jssh), exc_in, muxc_in,  &
     &                                   dexc_in, d2exc_in, dmuxc_in, d2muxc_in)
                  pfalpha%f3xca = pfalpha%f3xca &
             & -d2muxc_in*rhoma_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)**2
                  pfi%f3xcb = pfi%f3xcb &
             & -d2muxc_in*rhomb_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)**2
                  pfj%f3xcc = pfj%f3xcc &
             & -d2muxc_in*rhomc_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)**2
                  do isubtype = 1, species(in3)%nssh
                    pFdata_bundle => Fdata_bundle_3c(in1, in2, in3)
                    pFdata_cell =>                                             &
     &                pFdata_bundle%Fdata_cell_3c(pFdata_bundle%index_3c(P_rho_3c,isubtype,1))
                    rho_aver= 0.0d0
                    do iindex = 1, pFdata_cell%nME
                      imu = pFdata_cell%mu_3c(iindex)
                      inu = pFdata_cell%nu_3c(iindex)

!                      vxca(:,imu,inu) = d2muxc_in*rhoma_weig(:,issh,jssh)*prho_in_neighbors%block(issh,jssh) &
!     &                     + dmuxc_in*rhoxa(:,imu,inu)

!                      vxcb(:,imu,inu) = d2muxc_in*rhomb_weig(:,issh,jssh)*prho_in_neighbors%block(issh,jssh) &
!     &                     + dmuxc_in*rhoxb(:,imu,inu)

!                      vxcc(:,imu,inu) = d2muxc_in*rhomc_weig(:,issh,jssh)*prho_in_neighbors%block(issh,jssh) &
!     &                     + dmuxc_in*rhoxc(:,imu,inu)

        
                       
                      pfalpha%f3xca = pfalpha%f3xca&
             &             - pRho_neighbors%block(imu,inu)*dmuxc_in*rhoxa(:,imu,inu)
                      pfi%f3xcb = pfi%f3xcb&
             &             - pRho_neighbors%block(imu,inu)*dmuxc_in*rhoxb(:,imu,inu)
                      pfj%f3xcc = pfj%f3xcc&
             &             - pRho_neighbors%block(imu,inu)*dmuxc_in*rhoxc(:,imu,inu)

                      rho_aver= rho_aver + pRho_neighbors%block(imu,inu)
                    end do !iindex = 1, pFdata_cell%nME
                  end do ! isubtype = 1, species(in3)%nssh
!                  pfalpha%f3xca = pfalpha%f3xca &
!             & +d2muxc_in*rhoma_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)*rho_aver
!                  pfi%f3xcb = pfi%f3xcb &
!             & +d2muxc_in*rhomb_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)*rho_aver
!                  pfj%f3xcc = pfj%f3xcc &
!             & +d2muxc_in*rhomc_weig(:,issh,jssh)*prhoS_in_neighbors%block(issh,jssh)*rho_aver

                end do ! jssh = 1, species(in2)%nssh
              end do ! issh = 1, species(in1)%nss
                   
            end if ! if (mneigh .ne. 0)
            deallocate (rhoxa, rhoxb, rhoxc)
            deallocate (rhoma_weig, rhomb_weig, rhomc_weig)
          end do ! end loop over neighbors
        end do ! end loop over atoms

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine Dassemble_vxc_3c

! End Module
! ===========================================================================
        end module M_Dassemble_vxc_3c