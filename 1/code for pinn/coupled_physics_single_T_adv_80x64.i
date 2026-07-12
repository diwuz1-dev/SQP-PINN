# coupled_physics_single_T_adv_80x64.i
#
# Reduced neutron--thermal benchmark with prescribed coolant advection.
#
# Unknowns:
#   phi : neutron flux in fuel only
#   T   : one continuous temperature variable on fuel + coolant
#
# SQP interpretation:
#   Ts = T restricted to fuel
#   Tf = T restricted to coolant
#
# No Navier--Stokes.
# No pressure.
# Coolant velocity is prescribed: v = (0, vy).
#
# Fallback version:
#   - ConservativeAdvection in coolant volume
#   - Dirichlet inlet at coolant_bottom
#   - zero diffusive flux at coolant_top and coolant_right
#
# Test mesh: 80 x 64

D_phi = 0.05
Sigma_a = 1.0

rho_s_cp_s = 1.0
rho_f_cp_f = 1.0

k_s = 0.50
k_f = 0.15

gamma = 10.0
vy = 1.0

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0.0
    xmax = 1.0
    ymin = 0.0
    ymax = 1.0
    nx = 512
    ny = 512
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

  [interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = coolant_right
    primary_block = fuel
    paired_block = coolant
    new_boundary = interface
  []
[]

[Variables]
  [phi]
    block = fuel
  []

  [T]
    block = 'fuel coolant'
  []
[]

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

[Functions]
  [phi_left_func]
    type = ParsedFunction
    expression = '(1 - exp(-5*t))*(1 + 0.2*sin(pi*y)*sin(pi*y))'
  []
[]

[Kernels]
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

  [T_time_fuel]
    type = CoefTimeDerivative
    variable = T
    block = fuel
    Coefficient = ${rho_s_cp_s}
  []

  [T_diff_fuel]
    type = MatDiffusion
    variable = T
    block = fuel
    diffusivity = k_th
  []

  [T_source_from_phi]
    type = CoupledForce
    variable = T
    block = fuel
    v = phi
    coef = ${gamma}
  []

  [T_time_coolant]
    type = CoefTimeDerivative
    variable = T
    block = coolant
    Coefficient = ${rho_f_cp_f}
  []

  [T_diff_coolant]
    type = MatDiffusion
    variable = T
    block = coolant
    diffusivity = k_th
  []

  [T_advection_coolant]
    type = ConservativeAdvection
    variable = T
    block = coolant
    velocity = '0 ${vy} 0'
    upwinding_type = full
  []
[]

[BCs]
  [phi_left]
    type = FunctionDirichletBC
    variable = phi
    boundary = fuel_left
    function = phi_left_func
  []

  [phi_zero_flux]
    type = NeumannBC
    variable = phi
    boundary = 'fuel_top fuel_bottom interface'
    value = 0.0
  []

  [T_fuel_outer_insulated]
    type = NeumannBC
    variable = T
    boundary = 'fuel_left fuel_top fuel_bottom'
    value = 0.0
  []

  [T_coolant_bottom_inlet]
    type = DirichletBC
    variable = T
    boundary = coolant_bottom
    value = 0.0
  []

  [T_coolant_top_zero_flux]
    type = NeumannBC
    variable = T
    boundary = coolant_top
    value = 0.0
  []

  [T_coolant_right_insulated]
    type = NeumannBC
    variable = T
    boundary = coolant_right
    value = 0.0
  []
[]

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

[Outputs]
  [exo]
    type = Exodus
    file_base = coupled_single_T_adv_80x64
    execute_on = 'initial timestep_end'
  []

  csv = true
[]