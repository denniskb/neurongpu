import sys

sys.path.append('../../pythonlib')

import ctypes
import neurongpu as ngpu
from random import randrange

if len(sys.argv) != 2:
    print ("Usage: python %s n_neurons" % sys.argv[0])
    quit()
    
order = int(sys.argv[1])//5

ngpu.SetRandomSeed(1234) # seed for GPU random numbers

n_receptors = 2

NE = 4 * order       # number of excitatory neurons
NI = 1 * order       # number of inhibitory neurons
n_neurons = NE + NI  # number of neurons in total

CE = 800   # number of excitatory synapses per neuron
CI = CE//4  # number of inhibitory synapses per neuron

Wex = 0.05
Win = 0.35

# poisson generator parameters
poiss_rate = 20000.0 # poisson signal rate in Hz
poiss_weight = 0.37
poiss_delay = 0.2 # poisson signal delay in ms

# create poisson generator
pg = ngpu.Create("poisson_generator")
ngpu.SetStatus(pg, "rate", poiss_rate)

# Create n_neurons neurons with n_receptor receptor ports
neuron = ngpu.Create("aeif_cond_beta", n_neurons, n_receptors)
exc_neuron = neuron[0:NE]      # excitatory neurons
inh_neuron = neuron[NE:n_neurons]   # inhibitory neurons
  
# receptor parameters
E_rev = [0.0, -85.0]
tau_decay = [1.0, 1.0]
tau_rise = [1.0, 1.0]

ngpu.SetStatus(neuron, {"E_rev":E_rev, "tau_decay":tau_decay,
                        "tau_rise":tau_rise})
mean_delay = 0.5
std_delay = 0.25
min_delay = 0.1
# Excitatory connections
# connect excitatory neurons to port 0 of all neurons
# normally distributed delays, weight Wex and CE connections per neuron
exc_delays = ngpu.RandomNormalClipped(CE*n_neurons, mean_delay,
  			              std_delay, min_delay,
  			              mean_delay+3*std_delay)

exc_conn_dict={"rule": "fixed_indegree", "indegree": CE}
exc_syn_dict={"weight": Wex, "delay": {"array":exc_delays}, "receptor":0}
ngpu.Connect(exc_neuron, neuron, exc_conn_dict, exc_syn_dict)


# Inhibitory connections
# connect inhibitory neurons to port 1 of all neurons
# normally distributed delays, weight Win and CI connections per neuron
inh_delays = ngpu.RandomNormalClipped(CI*n_neurons, mean_delay,
  					    std_delay, min_delay,
  					    mean_delay+3*std_delay)

inh_conn_dict={"rule": "fixed_indegree", "indegree": CI}
inh_syn_dict={"weight": Win, "delay":{"array": inh_delays},
              "receptor":1}
ngpu.Connect(inh_neuron, neuron, inh_conn_dict, inh_syn_dict)


#connect poisson generator to port 0 of all neurons
pg_conn_dict={"rule": "all_to_all"}
pg_syn_dict={"weight": poiss_weight, "delay": poiss_delay,
              "receptor":0}

ngpu.Connect(pg, neuron, pg_conn_dict, pg_syn_dict)

ngpu.Simulate()