phi_in = './phi.txt'
v = 2.416

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0
    xmax = 0.019
    ymin = 0
    ymax = 0.75
    nx = 20
    ny = 64
  []

  [fuel_block]
    type = SubdomainBoundingBoxGenerator
    input = gen
    block_id = 1
    block_name = fuel
    bottom_left = '0 0 0'
    top_right = '0.0076 0.75 0'
  []

  [fluid_block]
    type = SubdomainBoundingBoxGenerator
    input = fuel_block
    block_id = 2
    block_name = fluid
    bottom_left = '0.0076 0 0'
    top_right = '0.019 0.75 0'
  []
[]

[Variables]
  [u]
  []
[]

[AuxVariables]
  [T]
  []
  [aux_sigma_af]
  []
  [flux]
    order = CONSTANT
    family = MONOMIAL
    block = fuel
  []
[]

[Kernels]
  [td]
    type = CoefTimeDerivative
    variable = u
    Coefficient = '${fparse 1 / v}'
  []
  [diff_fuel]
    type = MatDiffusion
    variable = u
    diffusivity = D_fuel
    block = 'fuel'
  []
  [diff_fluid]
    type = MatDiffusion
    variable = u
    diffusivity = D_fluid
    block = 'fluid'
  []
  [reaction_fuel]
    type = MatReaction
    variable = u
    reaction_rate = sigma_af_fuel
    block = 'fuel'
  []
  [reaction_fluid]
    type = MatReaction
    variable = u
    reaction_rate = sigma_af_fluid
    block = 'fluid'
  []
[]

[AuxKernels]
  [compute_aux_sigma_af_fuel]
    type = ParsedAux
    variable = aux_sigma_af
    coupled_variables = T
    expression = '2.416 * 583.5 * 1.305 * 1.602 * 0.1 - (13.47 * (T- 560) / (900 - 560) + 7.53) * 2.1479 * 1.602 + 0.185 * 6.6072 * 0.1 - 680.9 * 1.305 * 1.602 * 0.1'
    block = fuel
  []
  [compute_aux_sigma_af_fluid]
    type = ParsedAux
    variable = aux_sigma_af
    coupled_variables = T
    expression = '-(20 + 20 * (T - 560) / (800 - 560))'
    block = fluid
  []
[]

[Materials]
  [compute_Dfluid]
    type = GenericConstantMaterial
    prop_names = 'D_fluid'
    prop_values = 0.01
    block = 'fluid'
  []
  [compute_Dfuel]
    type = GenericConstantMaterial
    prop_names = 'D_fuel'
    prop_values = 0.008249
    block = 'fuel'
  []
  [compute_sigma_af_fuel]
    type = ParsedMaterial
    property_name = sigma_af_fuel
    coupled_variables = T
    expression = '2.416 * 583.5 * 1.305 * 1.602 * 0.1 - (13.47 * (T - 560) / (900 - 560) + 7.53) * 2.1479 * 1.602 + 0.185 * 6.6072 * 0.1 - 680.9 * 1.305 * 1.602 * 0.1'
    block = 'fuel'
  []
  [compute_sigma_af_fluid]
    type = ParsedMaterial
    property_name = sigma_af_fluid
    coupled_variables = T
    expression = '-(20 + 20 * (T - 560) / (800 - 560))'
    block = 'fluid'
  []
[]

[Functions]
  [U_IC]
    type = ParsedFunction
    expression = '2*cos(3.14*(y-0.375)/0.75)'
  []
  [phi_BC]
    type = PiecewiseMultilinear
    data_file = ${phi_in}
  []
[]

[BCs]
  [left]
    type = FunctionDirichletBC
    variable = u
    boundary = 'left'
    function = phi_BC
  []

  [right]
    type = DirichletBC
    variable = u
    boundary = 'right'
    value = 0.0
  []

  [top]
    type = DirichletBC
    variable = u
    value = 0.5
    boundary = top
  []

  [bottom]
    type = DirichletBC
    variable = u
    value = 0.5
    boundary = bottom
  []
[]

[ICs]
  [u_ic]
    type = FunctionIC
    variable = 'u'
    function = U_IC
  []
[]

[MultiApps]
  [sub_app]
    type = TransientMultiApp
    positions = '0.0076 0 0'
    input_files = 'fluid.i'
    sub_cycling = true
  []
[]

[Transfers]
  [push_flux]
    type = MultiAppGeneralFieldNearestLocationTransfer
    to_multi_app = sub_app
    source_variable = flux
    variable = flux
    error_on_miss = true
  []

  [pull_temp]
    type = MultiAppGeneralFieldNearestLocationTransfer
    from_multi_app = sub_app
    source_variable = T_fluid
    variable = T
    error_on_miss = true
    to_blocks = fluid
  []
[]

[Executioner]
  type = Transient
  start_time = 0
  end_time = 5
[]

[Outputs]
  [exodus]
    type = Exodus
    sync_only = true
    sync_times = '0. 0.3125 0.625 0.9375 1.25 1.5625 1.875 2.1875 2.5 2.8125 3.125 3.4375 3.75 4.0625 4.375 4.6875 5.'
  []
[]