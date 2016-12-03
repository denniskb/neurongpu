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

#include <stdio.h>
#include <stdlib.h>

#include "cuda_error.h"
#include "spike_buffer.h"
#include "spike_mpi.h"
#include "connect_mpi.h"

using namespace std;

__device__ int NExternalTargetHost;
__device__ int MaxSpikePerHost;

int *d_ExternalSpikeNum;
__device__ int *ExternalSpikeNum;

int *d_ExternalSpikeSourceNeuron; // [MaxSpikeNum];
__device__ int *ExternalSpikeSourceNeuron;

float *d_ExternalSpikeHeight; // [MaxSpikeNum];
__device__ float *ExternalSpikeHeight;

int *d_ExternalTargetSpikeNum;
__device__ int *ExternalTargetSpikeNum;

int *d_ExternalTargetSpikeNeuronId;
__device__ int *ExternalTargetSpikeNeuronId;

float *d_ExternalTargetSpikeHeight;
__device__ float *ExternalTargetSpikeHeight;

int *d_NExternalNeuronTargetHost;
__device__ int *NExternalNeuronTargetHost;

int **d_ExternalNeuronTargetHostId;
__device__ int **ExternalNeuronTargetHostId;

int **d_ExternalNeuronId;
__device__ int **ExternalNeuronId;

//int *d_ExternalSourceSpikeNum;
//__device__ int *ExternalSourceSpikeNum;

int *d_ExternalSourceSpikeNeuronId;
__device__ int *ExternalSourceSpikeNeuronId;

float *d_ExternalSourceSpikeHeight;
__device__ float *ExternalSourceSpikeHeight;

int *h_ExternalSpikeNeuronId;

float *h_ExternalSpikeHeight;

__device__ void PushExternalSpike(int i_source, float height)
{
  int pos = atomicAdd(ExternalSpikeNum, 1);
  ExternalSpikeSourceNeuron[pos] = i_source;
  ExternalSpikeHeight[pos] = height;
}

__global__ void SendExternalSpike()
{
  int i_spike = threadIdx.x + blockIdx.x * blockDim.x;
  if (i_spike < *ExternalSpikeNum) {
    int i_source = ExternalSpikeSourceNeuron[i_spike];
    float height = ExternalSpikeHeight[i_spike];
    int Nth = NExternalNeuronTargetHost[i_source];
      
    for (int ith=0; ith<Nth; ith++) {
      int target_host_id = ExternalNeuronTargetHostId[i_source][ith];
      int remote_neuron_id = ExternalNeuronId[i_source][ith];
      int pos = atomicAdd(&ExternalTargetSpikeNum[target_host_id], 1);
      ExternalTargetSpikeNeuronId[target_host_id*MaxSpikePerHost + pos]
	= remote_neuron_id;
      ExternalTargetSpikeHeight[target_host_id*MaxSpikePerHost + pos]
	= height;
    }
  }
}

__global__ void ExternalSpikeReset()
{
  *ExternalSpikeNum = 0;
  for (int ith=0; ith<NExternalTargetHost; ith++) {
    ExternalTargetSpikeNum[ith] = 0;
  }
}

int ConnectMpi::ExternalSpikeInit(int n_neurons, int max_spike_num, int n_hosts,
				  int max_spike_per_host)
{
  int *h_NExternalNeuronTargetHost = new int[n_neurons];
  int **h_ExternalNeuronTargetHostId = new int*[n_neurons];
  int **h_ExternalNeuronId = new int*[n_neurons];
  
  h_ExternalSpikeNeuronId = new int[max_spike_num];

  h_ExternalSpikeHeight = new float[max_spike_num];
  
  gpuErrchk(cudaMalloc(&d_ExternalSpikeNum, sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalSpikeSourceNeuron,
		       max_spike_num*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalSpikeHeight, max_spike_num*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalTargetSpikeNum, n_hosts*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalTargetSpikeNeuronId,
		       n_hosts*max_spike_per_host*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalTargetSpikeHeight,
		       n_hosts*max_spike_per_host*sizeof(float)));
  //gpuErrchk(cudaMalloc(&d_ExternalSourceSpikeNum, n_hosts*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalSourceSpikeNeuronId, //n_hosts*
		       max_spike_per_host*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalSourceSpikeHeight, //n_hosts*
		       max_spike_per_host*sizeof(float)));
	    
  gpuErrchk(cudaMalloc(&d_NExternalNeuronTargetHost, n_neurons*sizeof(int)));
  gpuErrchk(cudaMalloc(&d_ExternalNeuronTargetHostId, n_neurons*sizeof(int*)));
  gpuErrchk(cudaMalloc(&d_ExternalNeuronId, n_neurons*sizeof(int*)));
 
  for (int i_source=0; i_source<n_neurons; i_source++) {
    vector< ExternalConnectionNode > *conn = &extern_connection_[i_source];
    int Nth = conn->size();
    h_NExternalNeuronTargetHost[i_source] = Nth;
    if (Nth>0) {
       gpuErrchk(cudaMalloc(&h_ExternalNeuronTargetHostId[i_source],
   			 Nth*sizeof(int)));
       gpuErrchk(cudaMalloc(&h_ExternalNeuronId[i_source], Nth*sizeof(int)));
       int *target_host_arr = new int[Nth];
       int *neuron_id_arr = new int[Nth];
       for (int ith=0; ith<Nth; ith++) {
         target_host_arr[ith] = conn->at(ith).target_host_id;
         neuron_id_arr[ith] = conn->at(ith).remote_neuron_id;
       }
       cudaMemcpy(h_ExternalNeuronTargetHostId[i_source], target_host_arr,
   	       Nth*sizeof(int), cudaMemcpyHostToDevice);
       cudaMemcpy(h_ExternalNeuronId[i_source], neuron_id_arr,
   	       Nth*sizeof(int), cudaMemcpyHostToDevice);
       delete[] target_host_arr;
       delete[] neuron_id_arr;
     }
  }
  cudaMemcpy(d_NExternalNeuronTargetHost, h_NExternalNeuronTargetHost,
	     n_neurons*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_ExternalNeuronTargetHostId, h_ExternalNeuronTargetHostId,
	     n_neurons*sizeof(int*), cudaMemcpyHostToDevice);
  cudaMemcpy(d_ExternalNeuronId, h_ExternalNeuronId,
	     n_neurons*sizeof(int*), cudaMemcpyHostToDevice);

  DeviceExternalSpikeInit<<<1,1>>>(n_hosts, max_spike_per_host,
				   d_ExternalSpikeNum,
				   d_ExternalSpikeSourceNeuron,
				   d_ExternalSpikeHeight,
				   d_ExternalTargetSpikeNum,
				   d_ExternalTargetSpikeNeuronId,
				   d_ExternalTargetSpikeHeight,
				   d_NExternalNeuronTargetHost,
				   d_ExternalNeuronTargetHostId,
				   d_ExternalNeuronId
				   );
  delete[] h_NExternalNeuronTargetHost;
  delete[] h_ExternalNeuronTargetHostId;
  delete[] h_ExternalNeuronId;

  return 0;
}

__global__ void DeviceExternalSpikeInit(int n_hosts,
					int max_spike_per_host,
					int *ext_spike_num,
					int *ext_spike_source_neuron,
					float *ext_spike_height,
					int *ext_target_spike_num,
					int *ext_target_spike_neuron_id,
					float *ext_target_spike_height,
					int *n_ext_neuron_target_host,
					int **ext_neuron_target_host_id,
					int **ext_neuron_id
					)
  
{
  NExternalTargetHost = n_hosts;
  MaxSpikePerHost =  max_spike_per_host;
  ExternalSpikeNum = ext_spike_num;
  ExternalSpikeSourceNeuron = ext_spike_source_neuron;
  ExternalSpikeHeight = ext_spike_height;
  ExternalTargetSpikeNum = ext_target_spike_num;
  ExternalTargetSpikeNeuronId = ext_target_spike_neuron_id;
  ExternalTargetSpikeHeight = ext_target_spike_height;
  NExternalNeuronTargetHost = n_ext_neuron_target_host;
  ExternalNeuronTargetHostId = ext_neuron_target_host_id;
  ExternalNeuronId = ext_neuron_id;
  *ExternalSpikeNum = 0;
  for (int ith=0; ith<NExternalTargetHost; ith++) {
    ExternalTargetSpikeNum[ith] = 0;
  }  
}

int ConnectMpi::SendSpikeToRemote(int n_hosts, int max_spike_per_host)
{
  int mpi_id, tag = 1;  // id is already in the class, remove
  MPI_Comm_rank(MPI_COMM_WORLD, &mpi_id);

  int *h_ExternalTargetSpikeNum = new int[n_hosts];
  gpuErrchk(cudaMemcpy(h_ExternalTargetSpikeNum, d_ExternalTargetSpikeNum,
                       n_hosts*sizeof(int), cudaMemcpyDeviceToHost));
  for (int ih=0; ih<n_hosts; ih++) {
    if (ih == mpi_id) continue;
    int n_spike = h_ExternalTargetSpikeNum[ih];
    MPI_Send(&n_spike, 1, MPI_INT, ih, tag, MPI_COMM_WORLD);
    if (n_spike>0) {
      //cout << "nspike send: " << n_spike << endl;
#ifdef GPUDIRECT
      MPI_Send(&d_ExternalTargetSpikeNeuronId[ih*max_spike_per_host],
	       n_spike, MPI_INT, ih, tag, MPI_COMM_WORLD);
      MPI_Send(&d_ExternalTargetSpikeHeight[ih*max_spike_per_host],
	       n_spike, MPI_FLOAT, ih, tag, MPI_COMM_WORLD);
#else
      gpuErrchk(cudaMemcpy(h_ExternalSpikeNeuronId,
			  &d_ExternalTargetSpikeNeuronId[ih*max_spike_per_host],
			   n_spike*sizeof(int), cudaMemcpyDeviceToHost));
      MPI_Send(h_ExternalSpikeNeuronId,
               n_spike, MPI_INT, ih, tag, MPI_COMM_WORLD);
      gpuErrchk(cudaMemcpy(h_ExternalSpikeHeight,
			  &d_ExternalTargetSpikeHeight[ih*max_spike_per_host],
			   n_spike*sizeof(float), cudaMemcpyDeviceToHost));
      MPI_Send(h_ExternalSpikeHeight,
               n_spike, MPI_FLOAT, ih, tag, MPI_COMM_WORLD);
#endif      
    }
  }

  delete[] h_ExternalTargetSpikeNum;
  return 0;
}

int ConnectMpi::RecvSpikeFromRemote(int i_host, int max_spike_per_host)
{
  MPI_Status Stat;
  int mpi_id, tag = 1; // id is already in the class, remove
  MPI_Comm_rank(MPI_COMM_WORLD, &mpi_id);

  int n_spike;
  MPI_Recv(&n_spike, 1, MPI_INT, i_host, tag, MPI_COMM_WORLD, &Stat);
  //h_ExternalSourceSpikeNum[ih] = n_spike;
  if (n_spike>0) {
    //cout << "nspike recv: " << n_spike << endl;
#ifdef GPUDIRECT
    MPI_Recv(d_ExternalSourceSpikeNeuronId, // [ih*max_spike_per_host],
	     n_spike, MPI_INT, i_host, tag, MPI_COMM_WORLD, &Stat);
    MPI_Recv(d_ExternalSourceSpikeHeight, // [ih*max_spike_per_host],
	     n_spike, MPI_FLOAT, i_host, tag, MPI_COMM_WORLD, &Stat);
#else
    MPI_Recv(h_ExternalSpikeNeuronId,
	     n_spike, MPI_INT, i_host, tag, MPI_COMM_WORLD, &Stat);
    cudaMemcpy(d_ExternalSourceSpikeNeuronId, h_ExternalSpikeNeuronId,
	       n_spike*sizeof(int), cudaMemcpyHostToDevice);
    MPI_Recv(h_ExternalSpikeHeight,
	     n_spike, MPI_FLOAT, i_host, tag, MPI_COMM_WORLD, &Stat);
    cudaMemcpy(d_ExternalSourceSpikeHeight, h_ExternalSpikeHeight,
	       n_spike*sizeof(float), cudaMemcpyHostToDevice);
#endif
    PushSpikeFromRemote<<<(n_spike+1023)/1024, 1024>>>
      (n_spike, d_ExternalSourceSpikeNeuronId,
      d_ExternalSourceSpikeHeight); //[ih*max_spike_per_host])
    gpuErrchk( cudaPeekAtLastError() );
    cudaDeviceSynchronize();
    
  }

  //delete[] h_ExternalSourceSpikeNum;
  return 0;
}

__global__ void PushSpikeFromRemote(int n_spikes, int *spike_buffer_id,
           float *spike_height)
{
  int i_spike = threadIdx.x + blockIdx.x * blockDim.x;
  if (i_spike<n_spikes) {
    int isb = spike_buffer_id[i_spike];
    float height = spike_height[i_spike];
    PushSpike(isb, height);
  }
}
