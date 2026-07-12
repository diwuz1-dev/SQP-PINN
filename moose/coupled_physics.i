# coupled_physics_single_T.i
#
# Reduced neutron--thermal benchmark for SQP-PINN.
#
# Safer MOOSE formulation:
#   phi : neutron flux in fuel only
#   T   : one continuous temperature variable on fuel + coolant
#
# SQP interpretation:
#   Ts = T restricted to fuel
#   Tf = T restricted to coolant
#
# This automatically enforces:
#   Ts = Tf at the fuel-coolant interface
# and the weak form gives natural flux balance across the internal material interface.
#
# No Navier--Stokes.
# No pressure.
# No solved velocity.
# No advection in this debug/final baseline case.

# -------------------------
# Parameters
# -------------------------

D_phi = 0.05
Sigma_a = 1.0

rho_s_cp_s = 1.0
rho_f_cp_f = 1.0

k_s = 0.50
k_f = 0.15

gamma = 10.0


# -------------------------
# Mesh
# -------------------------
# Domain: [0,1] x [0,1]
# Fuel:   [0,0.4] x [0,1]
# Coolant:[0.4,1] x [0,1]
#
# nx = 80 gives dx = 1/80, so x = 0.4 is exactly a mesh line.

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    xmax = 1.0
    ymin = 0.0
    ymax = 1.0
    nx = 320
    ny = 128
  []

  [fuel_block]
    type = SubdomainBoundingBoxGenerator
    input = gen
    bottom_left = '0.0 0.0 0.0'
    top_right = '0.4 1.0 0.0'
    block_id = 1
    block_name = fuel
  []

  [coolant_block]
    type = SubdomainBoundingBoxGenerator
    input = fuel_block
    bottom_left = '0.4 0.0 0.0'
    top_right = '1.0 1.0 0.0'
    block_id = 2
    block_name = coolant
  []

  [fuel_left]
    type = SideSetsAroundSubdomainGenerator
    input = coolant_block
    block = fuel
    normal = '-1 0 0'
    new_boundary = fuel_left
  []

  [fuel_bottom]
    type = SideSetsAroundSubdomainGenerator
    input = fuel_left
    block = fuel
    normal = '0 -1 0'
    new_boundary = fuel_bottom
  []

  [fuel_top]
    type = SideSetsAroundSubdomainGenerator
    input = fuel_bottom
    block = fuel
    normal = '0 1 0'
    new_boundary = fuel_top
  []

  [coolant_bottom]
    type = SideSetsAroundSubdomainGenerator
    input = fuel_top
    block = coolant
    normal = '0 -1 0'
    new_boundary = coolant_bottom
  []

  [coolant_top]
    type = SideSetsAroundSubdomainGenerator
    input = coolant_bottom
    block = coolant
    normal = '0 1 0'
    new_boundary = coolant_top
  []

  [coolant_right]
    type = SideSetsAroundSubdomainGenerator
    input = coolant_top
    block = coolant
    normal = '1 0 0'
    new_boundary = coolant_right
  []

  # Interface sideset is used for neutron zero-flux checking/sampling.
  # It is NOT used for thermal coupling because T is one continuous variable.
  [interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = coolant_right
    primary_block = fuel
    paired_block = coolant
    new_boundary = interface
  []
[]


# -------------------------
# Variables
# -------------------------

[Variables]
  [phi]
    block = fuel
  []

  [T]
    block = 'fuel coolant'
  []
[]


# -------------------------
# Initial conditions
# -------------------------
# These are temperature-rise / nondimensional ICs.
# The neutron boundary ramp satisfies phi_left_func(y,0)=0, so the phi IC and BC are compatible.

[ICs]
  [phi_ic]
    type = ConstantIC
    variable = phi
    block = fuel
    value = 0.0
  []

  [T_ic]
    type = ConstantIC
    variable = T
    block = 'fuel coolant'
    value = 0.0
  []
[]


# -------------------------
# Materials
# -------------------------
# Same material property name k_th on both blocks, but different values.
# MatDiffusion reads k_th blockwise.

[Materials]
  [fuel_props]
    type = GenericConstantMaterial
    block = fuel
    prop_names = 'D_phi k_th'
    prop_values = '${D_phi} ${k_s}'
  []

  [coolant_props]
    type = GenericConstantMaterial
    block = coolant
    prop_names = 'k_th'
    prop_values = '${k_f}'
  []
[]


# -------------------------
# Functions
# -------------------------

[Functions]
  [phi_left_func]
    type = ParsedFunction
    expression = '(1 - exp(-5*t))*(1 + 0.2*(sin(pi*y))^2)'
  []
[]


# -------------------------
# Kernels
# -------------------------

[Kernels]

  # Neutron equation in fuel:
  #
  #   phi_t - div(D_phi grad phi) + Sigma_a phi = 0

  [phi_time]
    type = CoefTimeDerivative
    variable = phi
    block = fuel
    Coefficient = 1.0
  []

  [phi_diff]
    type = MatDiffusion
    variable = phi
    block = fuel
    diffusivity = D_phi
  []

  [phi_absorption]
    type = Reaction
    variable = phi
    block = fuel
    rate = ${Sigma_a}
  []


  # Temperature equation:
  #
  # Fuel:
  #   rho_s c_s T_t - div(k_s grad T) = gamma phi
  #
  # Coolant:
  #   rho_f c_f T_t - div(k_f grad T) = 0
  #
  # Since rho_s c_s = rho_f c_f = 1 here, one time-derivative coefficient is enough.
  # If you later want different rho*c in fuel/coolant, split this into two
  # CoefTimeDerivative blocks restricted by block.

  [T_time_fuel]
    type = CoefTimeDerivative
    variable = T
    block = fuel
    Coefficient = ${rho_s_cp_s}
  []

  [T_time_coolant]
    type = CoefTimeDerivative
    variable = T
    block = coolant
    Coefficient = ${rho_f_cp_f}
  []

  [T_diff]
    type = MatDiffusion
    variable = T
    block = 'fuel coolant'
    diffusivity = k_th
  []

  # Source in fuel only:
  # residual form: rho cp T_t - div(k grad T) - gamma phi = 0
  [T_source_from_phi]
    type = CoupledForce
    variable = T
    block = fuel
    v = phi
    coef = ${gamma}
  []

[]


# -------------------------
# Boundary conditions
# -------------------------

[BCs]

  # Neutron source on left fuel boundary:
  #   phi(0,y,t) = (1-exp(-5t))(1+0.2 sin(pi y))
  [phi_left]
    type = FunctionDirichletBC
    variable = phi
    boundary = fuel_left
    function = phi_left_func
  []

  # Zero neutron flux on top, bottom, and fuel-coolant interface:
  #   dphi/dn = 0
  [phi_zero_flux]
    type = NeumannBC
    variable = phi
    boundary = 'fuel_top fuel_bottom interface'
    value = 0.0
  []


  # Thermal BCs:
  #
  # Fuel outer boundaries insulated.
  # Coolant top/bottom insulated.
  # Coolant right boundary held at reference temperature 0 to act as a heat sink.

  [T_fuel_outer_insulated]
    type = NeumannBC
    variable = T
    boundary = 'fuel_left fuel_top fuel_bottom'
    value = 0.0
  []

  [T_coolant_top_bottom_insulated]
    type = NeumannBC
    variable = T
    boundary = 'coolant_top coolant_bottom'
    value = 0.0
  []

  [T_coolant_right_sink]
    type = DirichletBC
    variable = T
    boundary = coolant_right
    value = 0.0
  []

[]


# -------------------------
# Solver
# -------------------------

[Preconditioning]
  [smp]
    type = SMP
    full = true
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON

  dt = 1e-3
  end_time = 1.0

  nl_rel_tol = 1e-8
  nl_abs_tol = 1e-10
  l_tol = 1e-10

  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu mumps'
[]


# -------------------------
# Output
# -------------------------

[Outputs]
  [exo]
    type = Exodus
    file_base = coupled_single_T
    execute_on = 'initial timestep_end'
  []

  csv = true
[]
