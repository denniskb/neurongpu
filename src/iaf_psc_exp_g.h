/*
Copyright (C) 2020 Bruno Golosio
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// adapted from:
// https://github.com/nest/nest-simulator/blob/master/models/iaf_psc_exp.h


#ifndef IAFPSCEXPGH
#define IAFPSCEXPGH

#include <iostream>
#include <string>
#include "cuda_error.h"
#include "node_group.h"
#include "base_neuron.h"
#include "neuron_models.h"


namespace iaf_psc_exp_g_ns
{
enum ScalVarIndexes {
  i_I_syn_ex = 0,        // postsynaptic current for exc. inputs
  i_I_syn_in,            // postsynaptic current for inh. inputs
  i_V_m_rel,                 // membrane potential
  i_refractory_step,     // refractory step counter
  i_G_ex,
  i_G_in,
  N_SCAL_VAR
};

enum ScalParamIndexes {
  i_tau_m = 0,       // Membrane time constant in ms
  i_C_m,             // Membrane capacitance in pF
  i_E_L,             // Resting potential in mV
  i_I_e,             // External current in pA
  i_Theta_rel,       // Threshold, RELATIVE TO RESTING POTENTAIL(!)
                     // i.e. the real threshold is (E_L_+Theta_rel_)
  i_V_reset_rel,     // relative reset value of the membrane potential
  i_tau_ex,          // Time constant of excitatory synaptic current in ms
  i_tau_in,          // Time constant of inhibitory synaptic current in ms
  // i_rho,          // Stochastic firing intensity at threshold in 1/s
  // i_delta,        // Width of threshold region in mV
  i_t_ref,           // Refractory period in ms
  i_den_delay, // dendritic backpropagation delay
  // time evolution operator
  i_P20,
  i_P11ex,
  i_P11in,
  i_P21ex,
  i_P21in,
  i_P22,
  N_SCAL_PARAM
};

 
const std::string iaf_psc_exp_g_scal_var_name[N_SCAL_VAR] = {
  "I_syn_ex",
  "I_syn_in",
  "V_m_rel",
  "refractory_step",
  "G_ex",
  "G_in"
};


const std::string iaf_psc_exp_g_scal_param_name[N_SCAL_PARAM] = {
  "tau_m",
  "C_m",
  "E_L",
  "I_e",
  "Theta_rel",
  "V_reset_rel",
  "tau_ex",
  "tau_in",
  // "rho",
  //"delta",
  "t_ref",
  "den_delay",
  "P20",
  "P11ex",
  "P11in",
  "P21ex",
  "P21in",
  "P22"
};

} // namespace
 
class iaf_psc_exp_g : public BaseNeuron
{
 public:
  ~iaf_psc_exp_g();
  
  int Init(int i_node_0, int n_neuron, int n_port, int i_group,
	   unsigned long long *seed);

  int Calibrate(float, float time_resolution);
		
  int Update(int it, float t1);

  int Free();

};


#endif
