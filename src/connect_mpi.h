/*
Copyright (C) 2016 Bruno Golosio
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

#ifndef CONNECT_MPI_H
#define CONNECT_MPI_H
#include <vector>
#include <mpi.h>
#include "connect.h"

enum MPI_Commands {
  LOCAL_CONNECT,
  SOURCE_CONNECT,
  TARGET_CONNECT,
  PRINT,
  QUIT
};

struct ExternalConnectionNode
{
  int target_host_id;
  int remote_neuron_id;
};

class ConnectMpi
{
 public:
  NetConnection *net_connection_;
  int mpi_id_;
  int mpi_np_;
  int mpi_master_;
    
  std::vector<std::vector<ExternalConnectionNode > > extern_connection_;

  int MPI_Recv_int(int *int_val, int n, int sender_id);
  
  int MPI_Recv_float(float *float_val, int n, int sender_id);

  int MPI_Recv_uchar(unsigned char *uchar_val, int n, int sender_id);
  
  int MPI_Send_int(int *int_val, int n, int target_id);
  
  int MPI_Send_float(float *float_val, int n, int target_id);

  int MPI_Send_uchar(unsigned char *uchar_val, int n, int target_id);

  int SourceConnect(int source_neuron_id, int target_host_id,
		    int target_neuron_id, unsigned char port_id, float weight,
		    float delay);
  
  int TargetConnect(int source_host_id, int source_neuron_id,
		    int target_neuron_id, unsigned char port_id, float weight,
		    float delay);
  
  int RemoteConnect(int source_host_id, int source_neuron_id,
		    int target_host_id, int target_neuron_id,
		    unsigned char port_id, float weight, float delay);
  
  int RemoteConnectionPrint(int target_host_id);
  
  int MpiInit(int argc, char *argv[]);
  
  bool ProcMaster();
  
  int Quit();
  
  int ReceiveCommands();

  int ExternalSpikeInit(int n_neurons, int max_spike_num, int n_hosts,
			int max_spike_per_host);

  int SendSpikeToRemote(int n_hosts, int max_spike_per_host);

  int RecvSpikeFromRemote(int i_host, int max_spike_per_host);


};

#endif