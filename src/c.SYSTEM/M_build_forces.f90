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

! M_build_forces
! Module Description
! ===========================================================================
!>       This is a module containing all of the assembler programs required
!! to assemble all of the forces for the two-center interactions for
!! the Harris interactions.
!!
!! It contains the following subroutines within the module:
!!
!!      build_forces - sums all dF/dx terms from Dassemblers to get Forces.
!!                     and then finally sums all together to get an Ftot.
!!      writeout_forces - write out the forces components for each atom
!!
! ===========================================================================
        module M_build_forces
        use M_assemble_blocks
        use M_configuraciones

! Type Declaration
! ===========================================================================
! None

! module procedures
        contains

! ===========================================================================
! initialize_forces
! ===========================================================================
! Subroutine Description
! ===========================================================================
!> This subroutine initializes the force arrays.
!
! ===========================================================================
! Code written by:
!> @author Barry Haycock
! Box 6315, 209 Hodges Hall
! Department of Physics
! West Virginia University
! Morgantown, WV 26506-6315
!
! (304) 293-3422 x1409 (office)
! (304) 293-5732 (FAX)
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine initialize_forces (s)
        implicit none

        include '../include/constants.h'

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s            !< the structure to be used

! Local Parameters and Data Declaration
! ===========================================================================
! None

! Local Variable Declaration and Description
! ===========================================================================
        integer iatom                   !< counter over atoms/neighbors

! Allocate Arrays
! ===========================================================================
! Forces are stored in a Type with each piece, this makes acessing them and use
! pretty easy across the game.
        allocate (s%forces (s%natoms))

! Procedure
! ===========================================================================
! Initialize forces to zero
        do iatom = 1, s%natoms
          ! band-structure interactions
          s%forces(iatom)%kinetic = 0.0d0
          s%forces(iatom)%vna = 0.0d0
          s%forces(iatom)%vna_self = 0.0d0 !just testing
          s%forces(iatom)%vna_ontopof = 0.0d0 !just testing
          s%forces(iatom)%vxc = 0.0d0
          s%forces(iatom)%vnl = 0.0d0
          s%forces(iatom)%ewald = 0.0d0

          ! corrections to the force
          s%forces(iatom)%usr = 0.0d0
          s%forces(iatom)%pulay = 0.0d0

          ! three-center interactions
          s%forces(iatom)%f3naa = 0.0d0
          s%forces(iatom)%f3nab = 0.0d0
          s%forces(iatom)%f3nac = 0.0d0
          s%forces(iatom)%f3xca = 0.0d0
          s%forces(iatom)%f3xcb = 0.0d0
          s%forces(iatom)%f3xcc = 0.0d0
          s%forces(iatom)%ftot  = 0.0d0
        end do

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine initialize_forces


! ===========================================================================
! build_forces
! ===========================================================================
! Subroutine Description
! ===========================================================================
!> This subroutine builds the total forces by adding contributions from the
!! kinetic, Vna, etc. and stores to a T_force variable called forces (:).
!
! ===========================================================================
! Code written by:
!> @author Barry Haycock
! Box 6315, 209 Hodges Hall
! Department of Physics
! West Virginia University
! Morgantown, WV 26506-6315
!
! (304) 293-3422 x1409 (office)
! (304) 293-5732 (FAX)
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine build_forces (s)
        implicit none

        include '../include/constants.h'

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s            !< the structure to be used

! Local Parameters and Data Declaration
! ===========================================================================
! None

! Local Variable Declaration and Description
! ===========================================================================
        integer iatom, ineigh, matom !< counter over atoms/neighbors
        integer in1, in2             !< species number
        integer jatom, num_neigh     !< counters over neighbors
        integer mbeta                !< the cell containing neighbor of iatom
        integer norb_mu, norb_nu     !< size of the (mu, nu) block for pair
        integer ix                   !< counter over dimensions
        integer imu, inu             !< counter over MEs

        real sumT
        real, dimension(3) :: vna                     !just for testing
        real, dimension(3) :: vna_ontop                     !just for testing
        real, dimension(3) :: kin                     !just for testing
        type(T_forces), pointer :: pfi
        type(T_forces), pointer :: pfj

        ! band-structure interactions
        type(T_assemble_block), pointer :: pK_neighbors
        type(T_assemble_neighbors), pointer :: pkinetic
        type(T_assemble_block), pointer :: pvna_neighbors
        type(T_assemble_neighbors), pointer :: pvna
        type(T_assemble_block), pointer :: pvxc_neighbors
        type(T_assemble_neighbors), pointer :: pvxc
        type(T_assemble_block), pointer :: pSR_neighbors
        type(T_assemble_neighbors), pointer :: pewaldsr
        type(T_assemble_block), pointer :: pLR_neighbors
        type(T_assemble_neighbors), pointer :: pewaldlr

        ! for overlap repulsive force
        type(T_assemble_block), pointer :: pCape_neighbors
        type(T_assemble_neighbors), pointer :: pcapemat
        type(T_assemble_block), pointer :: poverlap_neighbors
        type(T_assemble_neighbors), pointer :: poverlap

        ! Density matrix stuff
        type(T_assemble_neighbors), pointer :: pdenmat
        type(T_assemble_block), pointer :: pRho_neighbors
        type(T_assemble_block), pointer :: pRho_neighbors_matom

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
!       T W O - C E N T E R   B A N D - S T R U C T U R E   F O R C E S
! ***************************************************************************
! loop over atoms in central cell
        do iatom = 1, s%natoms
          matom = s%neigh_self(iatom)
          in1 = s%atom(iatom)%imass
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn

          ! cut some lengthy notation
          pfi=>s%forces(iatom)

          ! density matrix
          pdenmat=>s%denmat(iatom)
          pRho_neighbors_matom=>pdenmat%neighbors(matom)

          ! interactions for each contribution
          pkinetic=>s%kinetic(iatom)
          pvna=>s%vna(iatom)
          pvxc=>s%vxc(iatom)
          pewaldsr=>s%ewaldsr(iatom)
          pewaldlr=>s%ewaldlr(iatom)

! allocate force terms and initialize to zero
          !allocate (pfi%vna_atom (3, num_neigh)); pfi%vna_atom = 0.0d0
          !allocate (pfi%vxc_off_site (3, num_neigh)); pfi%vxc_off_site = 0.0d0
          !allocate (pfi%vxc_on_site (3, num_neigh)); pfi%vxc_on_site = 0.0d0
          allocate (pfi%ewaldsr (3, num_neigh)); pfi%ewaldsr = 0.0d0
          allocate (pfi%ewaldlr (3, num_neigh)); pfi%ewaldlr = 0.0d0

! Now loop over all neighbors ineigh of iatom.
          do ineigh = 1, num_neigh
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max

            ! cut some lengthy notation
            pfj=>s%forces(jatom)

            ! density matrix - neighbors
            pRho_neighbors=>pdenmat%neighbors(ineigh)

            ! interactions - neighbors
            pK_neighbors=>pkinetic%neighbors(ineigh)
            pvna_neighbors=>pvna%neighbors(ineigh)

! KINETIC FORCES (TWO-CENTER)
! ***************************************************************************
! The derivatives are tpx and, where p means derivative and x means crytal
! coordinates. The derivative is a vector in crystal
! coordinates and is stored in pK_neighbors%Dblock. The subroutine
! returns the derivative for just that one value of iatom and ineigh, and the
! result is returned in the arguement list, tpx(3,4,4).
            do ix = 1, 3
              sumT = 0.0d0
              do inu = 1, norb_nu
                do imu = 1, norb_mu
                  sumT = sumT                                                &
                   + pRho_neighbors%block(imu,inu)*pK_neighbors%Dblock(ix,imu,inu)
                end do
              end do

! Now add sum to appropriate force term. see notes "the total band structure
! The (-1.d0) makes it "force-like".
              ! direct term
              pfi%kinetic(ix) = pfi%kinetic(ix) + (-1.0d0)*sumT
              ! cross term
              pfj%kinetic(ix) = pfj%kinetic(ix) - (-1.0d0)*sumT
            end do ! do ix


! ASSEMBLE HARTREE (TWO-CENTER) FORCES - ATOM CASE
! ***************************************************************************
! The vna 2 centers are: ontop (L), ontop (R), and atm.
! First, do vna_atom case. Here we compute <i | v(j) | i> matrix elements.
!
! If r1 = r2, then this is a case where the two wavefunctions are at the
! same site, but the potential vna is at a different site (atm case).
! The derivative wrt the "atom r1" position (not the NA position) are
! stored in bcnapx.

! Note that the loop below involves num_orb(in1) ONLY. Why?
! Because the potential is somewhere else (or even at iatom), but we are
! computing the vna_atom term, i.e. < phi(i) | v | phi(i) > but V=v(j) )
! interactions.

! Form the "force-like" derivative of the atom terms for NA,
! or -(d/dr1) <phi(mu,r-r1)!h(r-ratm)!phi(nu,r-r1)>.

! Now loop over all neighbors ineigh of iatom.
! Notice the explicit negative sign, this makes it force like.
!           do inu = 1, norb_mu
!             do imu = 1, norb_mu
!               pfi%vna_atom(:,ineigh) = pfi%vna_atom(:,ineigh)              &
!     &           - pRho_neighbors_matom%block(imu,inu)*pvna_neighbors%Dblock(:,imu,inu)
!              end do
!           end do
          end do ! end loop over neighbors


! ASSEMBLE EXCHANGE-CORRELATION (TWO-CENTER) FORCE - ON-SITE CASE
! ***************************************************************************
! The vxc two-center forces are: vxc_on_site and vxc_off_site.

! First we calculate the on-site force contributions.
! Note that the loop below involves num_orb(in1) ONLY. Why?
! Because the potential is somewhere else (or even at iatom), but we are
! computing the vxc_on_site term, i.e. < phi(i) | v | phi(i) > but V=v(j) )
! interactions.

! Now loop over all neighbors ineigh of iatom.
          pvxc_neighbors=>pvxc%neighbors(matom)
          do ineigh = 1, num_neigh
            do inu = 1, norb_mu
              do imu = 1, norb_mu
     !           pfi%vxc_on_site(:,ineigh) = pfi%vxc_on_site(:,ineigh)        &
     !&           - pRho_neighbors_matom%block(imu,inu)*pvxc_neighbors%Dblock(:,imu,inu)
              end do
            end do
          end do ! end loop over neighbors


! ASSEMBLE EXCHANGE-CORRELATION (TWO-CENTER) FORCE - OFF-SITE CASE
! ***************************************************************************
! Next, we calculate the off site force interaction terms.
! If r1 = r2, then this is a case of the self-interaction term or the
! one center term which has no force.
!
! Form the "force-like" derivative of the atom terms for vxc,
! or -(d/dr1) <phi(mu,r-r1)!h(r-ratm)!phi(nu,r-r1)>.

! Now loop over all neighbors ineigh of iatom.
          do ineigh = 1, num_neigh
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max

            ! cut some lengthy notation
            pfj=>s%forces(jatom)

            ! density matrix - neighbors
            pRho_neighbors=>pdenmat%neighbors(ineigh)

            ! vxc interactions - neighbors
            pvxc_neighbors=>pvxc%neighbors(ineigh)

! Notice the explicit negative sign, this makes it force like.
            if (iatom .eq. jatom .and. mbeta .eq. 0) then

! Do nothing here - special case. Interaction already calculated in atm case.

            else
              do inu = 1, norb_nu
                do imu = 1, norb_mu
     !             pfi%vxc_off_site(:,ineigh) = pfi%vxc_off_site(:,ineigh)    &
     !&             - pRho_neighbors%block(imu,inu)*pvxc_neighbors%Dblocko(:,imu,inu)
                end do
              end do
            end if
          end do ! end loop over neighbors


!  ASSEMBLE EWALD (TWO-CENTER) FORCES
! ***************************************************************************
! The Ewald two-center forces are: ewaldsr and ewaldlr.
!
! If r1 = r2, then this is a case of the self-interaction term or the
! one center term which has no force.
!
! Form the "force-like" derivative of the atom terms for vxc,
! or -(d/dr1) <phi(mu,r-r1)!h(r-ratm)!phi(nu,r-r1)>.

! Now loop over all neighbors ineigh of iatom.
          do ineigh = 1, num_neigh
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max

            ! cut some lengthy notation
            pfj=>s%forces(jatom)

            ! density matrix - neighbors
            pRho_neighbors=>pdenmat%neighbors(ineigh)

            ! interactions - neighbors
            pSR_neighbors=>pewaldsr%neighbors(ineigh)
            pLR_neighbors=>pewaldlr%neighbors(ineigh)

! Notice the explicit negative sign, this makes it force like.
            if (iatom .eq. jatom .and. mbeta .eq. 0) then

! Do nothing here - special self-interaction case.

            else

! short-range part ewaldsr
              do inu = 1, norb_nu
                do imu = 1, norb_mu
!                  pfi%ewaldsr(:,ineigh) = pfi%ewaldsr(:,ineigh)              &
!     &             - 0.5d0*pRho_neighbors%block(imu,inu)*pSR_neighbors%Dblock(:,imu,inu)
! Note - remove the 0.5d0 and make sure it gets into the Dassembler - I add it here
! because the 0.5d0 was here in the original assemble_F.f90 routine.
                end do
              end do

! long-range part ewaldsr
              do inu = 1, norb_nu
                do imu = 1, norb_mu
!                  pfi%ewaldlr(:,ineigh) = pfi%ewaldlr(:,ineigh)              &
!     &             - pRho_neighbors%block(imu,inu)*pLR_neighbors%Dblock(:,imu,inu)
                end do
              end do
            end if
          end do ! end loop over neighbors
        end do ! end loop over atoms


! ADD CONTRIBUTIONS TO GET TOTAL BAND-STRUCTURE FORCE (TWO-CENTER)
! ***************************************************************************
! loop over atoms in central cell
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          vna = 0.0d0 ! just testing
          vna_ontop= 0.0d0
          kin= 0.0d0
          pfi=>s%forces(iatom)



! kinetic contribution to total force
! ****************************************************************************
          pfi%ftot = pfi%ftot + pfi%kinetic
          kin= kin + pfi%kinetic
! Loop over all neighbors of iatom and add in the neighbor-contributed forces
! ****************************************************************************
          num_neigh = s%neighbors(iatom)%neighn
          do ineigh = 1, num_neigh

! cut some lengthy notation
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            pfj => s%forces(jatom)

! vna contribution to total force
! ****************************************************************************
! Hartree forces - atom case
  !          vna= vna + sqrt(pfi%vna_atom(1,ineigh)**2 &
  !&         + pfi%vna_atom(2,ineigh)**2 + pfi%vna_atom(3,ineigh)**2)
            vna= vna + pfi%vna_atom(:,ineigh)
            vna_ontop= vna_ontop + pfi%vna_ontop(:,ineigh)

            pfi%vna_self = pfi%vna_self + pfi%vna_atom(:,ineigh)
            pfj%vna_self = pfj%vna_self - pfi%vna_atom(:,ineigh)

            pfi%vna = pfi%vna + pfi%vna_atom(:,ineigh)
            pfj%vna = pfj%vna - pfi%vna_atom(:,ineigh)

            pfi%ftot = pfi%ftot + pfi%vna_atom(:,ineigh)
            pfj%ftot = pfj%ftot - pfi%vna_atom(:,ineigh)

! Hartree forces - ontop terms

            pfi%vna_ontopof = pfi%vna_ontopof + pfi%vna_ontop(:,ineigh)
            pfj%vna_ontopof = pfj%vna_ontopof - pfi%vna_ontop(:,ineigh)

            pfi%vna = pfi%vna + pfi%vna_ontop(:,ineigh)
            pfj%vna = pfj%vna - pfi%vna_ontop(:,ineigh)

            pfi%ftot = pfi%ftot + pfi%vna_ontop(:,ineigh)
            pfj%ftot = pfj%ftot - pfi%vna_ontop(:,ineigh)

! vxc contribution to total force
! ****************************************************************************
! off site interactions
            pfi%vxc = pfi%vxc + pfi%vxc_off_site(:,ineigh)
            pfj%vxc = pfj%vxc - pfi%vxc_off_site(:,ineigh)

            pfi%ftot = pfi%ftot + pfi%vxc_off_site(:,ineigh)
            pfj%ftot = pfj%ftot - pfi%vxc_off_site(:,ineigh)

! on site interactions
            pfi%vxc = pfi%vxc + pfi%vxc_on_site(:,ineigh)
            pfj%vxc = pfj%vxc - pfi%vxc_on_site(:,ineigh)

            pfi%ftot = pfi%ftot + pfi%vxc_on_site(:,ineigh)
            pfj%ftot = pfj%ftot - pfi%vxc_on_site(:,ineigh)

! Ewald contribution to total force
! ****************************************************************************
! ewaldsr interactions
            pfi%ewald = pfi%ewald - pfi%ewaldsr(:,ineigh)
            pfj%ewald = pfj%ewald + pfi%ewaldsr(:,ineigh)

            pfi%ftot = pfi%ftot - pfi%ewaldsr(:,ineigh)
            pfj%ftot = pfj%ftot + pfi%ewaldsr(:,ineigh)

! ewaldlr interactions
            pfi%ewald = pfi%ewald - pfi%ewaldlr(:,ineigh)
            pfj%ewald = pfj%ewald + pfi%ewaldlr(:,ineigh)

            pfi%ftot = pfi%ftot - pfi%ewaldlr(:,ineigh)
            pfj%ftot = pfj%ftot + pfi%ewaldlr(:,ineigh)
          end do ! end loop over neighbors
          print *, '*******************'
          print *, 'vav', iatom, vna(1), vna(2), vna(3)
          write(*, 501) 'vav', iatom, vna
          print *, 'f_vna_atom', iatom, sqrt(vna(1)**2 &
  &         + vna(2)**2 + vna(3)**2)
          print *, 'f_vna_ontop', iatom, sqrt(vna_ontop(1)**2 &
  &         + vna_ontop(2)**2 + vna_ontop(3)**2)
          print *, 'f_kin', iatom, sqrt(kin(1)**2 &
  &         + kin(2)**2 + kin(3)**2)
          print *, '*******************'
        end do ! end loop over atoms

! Vnl contribution to total force
! ****************************************************************************
! Loop over all atoms iatom in the central cell.
        do iatom = 1, s%natoms

! cut some lengthy notation
          pfi=>s%forces(iatom)

! Loop over all neighbors of iatom and add in the neighbor-contributed forces
! Note - the neighbor mapping for vnl is different than neighbor mapping for
! other terms, so, we need to add in the contributions correctly.
          do ineigh = 1, s%neighbors_PP(iatom)%neighn
            jatom = s%neighbors_PP(iatom)%neigh_j(ineigh)

! cut some lengthy notation
            pfj => s%forces(jatom)

! atom contribution
            pfi%vnl = pfi%vnl + pfi%vnl_atom(:,ineigh)
            pfj%vnl = pfj%vnl - pfi%vnl_atom(:,ineigh)

            pfi%ftot = pfi%ftot + pfi%vnl_atom(:,ineigh)
            pfj%ftot = pfj%ftot - pfi%vnl_atom(:,ineigh)
          end do

! ontop left contribution
          do ineigh = 1, s%neighbors_PPx(iatom)%neighn
            jatom = s%neighbors_PPx(iatom)%neigh_j(ineigh)

! cut some lengthy notation
            pfj => s%forces(jatom)

            pfi%vnl = pfi%vnl + 2.0d0*pfi%vnl_ontop(:,ineigh)
            pfj%vnl = pfj%vnl - 2.0d0*pfi%vnl_ontop(:,ineigh)

            pfi%ftot = pfi%ftot + 2.0d0*pfi%vnl_ontop(:,ineigh)
            pfj%ftot = pfj%ftot - 2.0d0*pfi%vnl_ontop(:,ineigh)
          end do ! end loop over neighbors
        end do  ! end loop over atoms
! ***************************************************************************
!                                   E N D
!       T W O - C E N T E R   B A N D - S T R U C T U R E   F O R C E S
! ***************************************************************************

! ADD CONTRIBUTIONS TO GET TOTAL BAND-STRUCTURE FORCE (THREE-CENTER)
! ***************************************************************************
! Loop over all atoms iatom in the central cell.
! Single-source loops (not dependent on neighbours)
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pfi=>s%forces(iatom)

! vna three-center contribution to the total force
! ****************************************************************************
          pfi%ftot = pfi%ftot - pfi%f3naa - pfi%f3nab - pfi%f3nac

! vxc three-center contribution to the total force
! ****************************************************************************
          pfi%ftot = pfi%ftot - pfi%f3xca - pfi%f3xcb - pfi%f3xcc
        end do ! end loop over atoms
! ***************************************************************************
!                                   E N D
!     T H R E E - C E N T E R   B A N D - S T R U C T U R E   F O R C E S
! ***************************************************************************

! ***************************************************************************
!
!            P U L A Y   C O R R E C T I O N S   (T W O - C E N T E R)
! ***************************************************************************
! loop over atoms in central cell
        do iatom = 1, s%natoms
          in1 = s%atom(iatom)%imass
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn

          ! cut some lengthy notation
          pfi=>s%forces(iatom)

          ! density matrix with eigenvalues
          pcapemat=>s%capemat(iatom)

          ! interactions for each contribution
          poverlap=>s%overlap(iatom)

! Now loop over all neighbors ineigh of iatom.
          do ineigh = 1, num_neigh
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max

            ! cut some lengthy notation
            pfj=>s%forces(jatom)

            ! density matrix - neighbors
            pCape_neighbors=>pcapemat%neighbors(ineigh)

            ! interactions - neighbors
            poverlap_neighbors=>poverlap%neighbors(ineigh)

! The derivatives are tpx and, where p means derivative and x means crytal
! coordinates. The derivative is a vector in crystal
! coordinates and is stored in pK_neighbors%Dblock. The subroutine
! returns the derivative for just that one value of iatom and ineigh, and the
! result is returned in the arguement list, tpx(3,4,4).
            do ix = 1, 3
              sumT = 0.0d0
              do inu = 1, norb_nu
                do imu = 1, norb_mu
                  sumT = sumT                                                &
                   + pCape_neighbors%block(imu,inu)*poverlap_neighbors%Dblock(ix,imu,inu)
                end do
              end do

! Now add sum to appropriate force term. see notes "the total band structure
! The (-1.d0) makes it "force-like".
              ! direct term
              pfi%pulay(ix) = pfi%pulay(ix) + (-1.0d0)*sumT
              ! cross term
              pfj%pulay(ix) = pfj%pulay(ix) - (-1.0d0)*sumT
            end do ! do ix
          end do ! end loop over neighbors
        end do ! end loop over atoms

! ADD CONTRIBUTIONS TO GET TOTAL FORCE AFTER PULAY CORRECTION
! ***************************************************************************
! loop over atoms in central cell
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pfi=>s%forces(iatom)

! overlap repulsive contribution to total force
! ****************************************************************************
          pfi%ftot = pfi%ftot - pfi%pulay
        end do
! ***************************************************************************
!                                  E N D
!            P U L A Y   C O R R E C T I O N S   (T W O - C E N T E R)
! ***************************************************************************

! ***************************************************************************
!
!            U S R   C O R R E C T I O N S   (T W O - C E N T E R)
! ***************************************************************************
! Loop over all atoms iatom in the central cell.
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pfi=>s%forces(iatom)
          pfi%ftot = pfi%ftot + pfi%usr
        end do ! end loop over atoms

! Format Statements
! ===========================================================================
! None
501     format (A, I2, 3(2x,F10.3))
! End Subroutine
! ===========================================================================
        return
        end subroutine build_forces


! ===========================================================================
! writeout_forces
! ===========================================================================
! Subroutine Description
! ===========================================================================
!>       This routine is a utility to write out the components of the forces.
!
! ===========================================================================
!> @author James P. Lewis
! Box 6315, 209 Hodges Hall
! Department of Physics
! West Virginia University
! Morgantown, WV 26506-6315
!
! (304) 293-3422 x1409 (office)
! (304) 293-5732 (FAX)
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine writeout_forces (s)
        implicit none

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s            !< the structure to be used

! Local Parameters and Data Declaration
! ===========================================================================
! None

! Local Variable Declaration and Description
! ===========================================================================
        integer iatom                       !< counter for atom loop
        integer logfile                     !< writing to which unit

        type(T_forces), pointer :: pfi

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
! Initialize logfile
        logfile = s%logfile

        write (logfile,*)
        write (logfile,103) 'The kinetic force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_kinetic', iatom, s%atom(iatom)%species%symbol,&
     &                                            s%forces(iatom)%kinetic
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The Hartree (vna) two-center force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_vna_2c', iatom, s%atom(iatom)%species%symbol,&
     &                                           s%forces(iatom)%vna
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The Hartree (vna) self: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_vna_self', iatom, s%atom(iatom)%species%symbol,&
     &                                           s%forces(iatom)%vna_self
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The Hartree (vna) on_top_of: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_vna_on_top_of', iatom, s%atom(iatom)%species%symbol,&
     &                                           s%forces(iatom)%vna_ontopof
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The Hartree (vna) three-center force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pfi=>s%forces(iatom)
          write (logfile,102) 'f_vna_3c', iatom, s%atom(iatom)%species%symbol,&
     &                                           pfi%f3naa + pfi%f3nab + pfi%f3nac
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The non-local pseudopotential (vnl) force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_vnl', iatom, s%atom(iatom)%species%symbol,&
     &                                        s%forces(iatom)%vnl
        end do
        write (logfile,100)

        write (logfile,100)
        write (logfile,*)
        write (logfile,103) 'The exchange correlation (vxc) two-center force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_vxc_2c', iatom, s%atom(iatom)%species%symbol,&
     &                                           s%forces(iatom)%vxc
        end do
        write (logfile,100)

        write (logfile,100)
        write (logfile,*)
        write (logfile,103) 'The exchange correlation (vxc) three-center force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pfi=>s%forces(iatom)
          write (logfile,102) 'f_vxc_3c', iatom, s%atom(iatom)%species%symbol,&
     &                                           pfi%f3xca + pfi%f3xcb + pfi%f3xcc
        end do
        write (logfile,100)

        write (logfile,100)
        write (logfile,*)
        write (logfile,103) 'The long-range electrostatics (ewald) force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_ewald', iatom, s%atom(iatom)%species%symbol,&
     &                                          s%forces(iatom)%ewald
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The total band-structure force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_ebs', iatom, s%atom(iatom)%species%symbol,  &
     &                        s%forces(iatom)%kinetic + s%forces(iatom)%vna  &
     &                        + s%forces(iatom)%vnl + s%forces(iatom)%vxc    &
     &                        + s%forces(iatom)%ewald
        end do
        write (logfile,100)

        write (logfile,*)
        write (logfile,103) 'The short-range (double-counting) (usr) force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_usr', iatom, s%atom(iatom)%species%symbol, &
     &                                        s%forces(iatom)%usr
        end do

        write (logfile,*)
        write (logfile,103) 'The overlap repulsive force: '
        write (logfile,100)
        write (logfile,101)
        write (logfile,100)
        do iatom = 1, s%natoms
          write (logfile,102) 'f_pulay', iatom, s%atom(iatom)%species%symbol,&
     &                                          s%forces(iatom)%pulay
        end do
        write (logfile,100)

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
100     format (4x, 70('='))
101     format (4x, 'Force ', 'Atom # ', 2x, ' Type ', 5x,   &
     &              ' x ', 9x, ' y ', 9x, ' z ')
102     format (4x, A,  i5, 7x, a2, 3(2x,ES10.3))
103     format (4x, A)
500     format (A, I2, 3(2x,ES10.3))

! End Subroutine
! ===========================================================================
        return
        end subroutine writeout_forces


! End Module
! ===========================================================================
        end module M_build_forces
