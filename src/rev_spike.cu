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

#include <stdio.h>
				    //#include "neuralgpu.h"
#include "spike_buffer.h"
#include "cuda_error.h"


#define SPIKE_TIME_DIFF_GUARD 15000 // must be less than 16384
#define SPIKE_TIME_DIFF_THR 10000 // must be less than GUARD

extern __constant__ int NeuralGPUTimeIdx;

unsigned int *d_RevSpikeNum;
unsigned int *d_RevSpikeTarget;
int *d_RevSpikeNConn;

__device__ unsigned int *RevSpikeNum;
__device__ unsigned int *RevSpikeTarget;
__device__ int *RevSpikeNConn;


//////////////////////////////////////////////////////////////////////
// This is the function called by the nested loop
// that makes use of positive post-pre spike time difference
__device__ void NestedLoopFunction1(int i_spike, int i_target_rev_conn)
{
  unsigned int target = RevSpikeTarget[i_spike];
  unsigned int i_conn = TargetRevConnection[target][i_target_rev_conn];
  unsigned char syn_group = ConnectionSynGroup[i_conn];
  printf("i_spike %d i_target_rev_conn %d target %d i_conn %d syn_group %d\n",
	 i_spike, i_target_rev_conn, target, i_conn, syn_group);
  if (syn_group==1) { // TEMPORARY, TO BE IMPROVED
    float *weight = &ConnectionWeight[i_conn];
    int spike_time_idx = ConnectionSpikeTime[i_conn];
    int Dt = ((int)NeuralGPUTimeIdx - spike_time_idx)&0xffff;
    printf("weight %f spike_time_idx %d Dt %d NGPUtime %d spike_time_idx %d\n",
	   weight, spike_time_idx, Dt, NeuralGPUTimeIdx, spike_time_idx);
    if (Dt<0) { // there was no spike from this connection
      return;
    }
    // The following lines are for solving the problem of limited size of
    // connection spike time
    //if (Dt>SPIKE_TIME_DIFF_THR) { // there was no spike from this connection
    //  return;
    //}
    //if (Dt==SPIKE_TIME_DIFF_THR) { // there was no spike from this connection
      // but due to the increase of time idx the difference
      // reached the threshold, so let's put it well above threshold
    //  ConnectionSpikeTime[i_conn]
    //	= (unsigned short)((NeuralGPUTimeIdx + SPIKE_TIME_DIFF_GUARD)&0xffff);
    //  return;
    //}
    // STDP(Dt, &weight);
    // TEST temporary:
    if (Dt<100) {
      *weight = *weight + Dt;
    }
  }
}
	    

__global__ void RevSpikeBufferUpdate(unsigned int n_node)
{
  unsigned int i_node = threadIdx.x + blockIdx.x * blockDim.x;
  if (i_node >= n_node) {
    return;
  }
  int target_spike_time_idx = LastSpikeTimeIdx[i_node];
  // Check if neuron is spiking now
  if (target_spike_time_idx!=NeuralGPUTimeIdx) {
    return;
  }
  printf("neuron %d is spiking\n", i_node);
  int n_conn = TargetRevConnectionSize[i_node];
  printf("n_conn %d\n", n_conn);
  printf("RevSpikeNum %d\n", *RevSpikeNum);
  if (n_conn>0) {
    unsigned int pos = atomicAdd(RevSpikeNum, 1);
    RevSpikeTarget[pos] = i_node;
    RevSpikeNConn[pos] = n_conn;
  }
}

__global__ void SetConnectionSpikeTime(unsigned int n_conn,
				       unsigned short time_idx)
{
  unsigned int i_conn = threadIdx.x + blockIdx.x * blockDim.x;
  if (i_conn>=n_conn) {
    return;
  }
  ConnectionSpikeTime[i_conn] = time_idx;
}

__global__ void DeviceRevSpikeInit(unsigned int *rev_spike_num,
				   unsigned int *rev_spike_target,
				   int *rev_spike_n_conn)
{
  RevSpikeNum = rev_spike_num;
  RevSpikeTarget = rev_spike_target;
  RevSpikeNConn = rev_spike_n_conn;
  *RevSpikeNum = 0;
}

__global__ void RevSpikeReset()
{
  *RevSpikeNum = 0;
}
  

int RevSpikeInit(NetConnection *net_connection, int time_min_idx)
{
  int n_spike_buffers = net_connection->connection_.size();
  
  SetConnectionSpikeTime
    <<<(net_connection->StoredNConnections()+1023)/1024, 1024>>>
    (net_connection->StoredNConnections(),
     time_min_idx + SPIKE_TIME_DIFF_GUARD);
  gpuErrchk( cudaPeekAtLastError() );
  gpuErrchk( cudaDeviceSynchronize() );

  gpuErrchk(cudaMalloc(&d_RevSpikeNum, sizeof(unsigned int)));
  
  gpuErrchk(cudaMalloc(&d_RevSpikeTarget,
		       n_spike_buffers*sizeof(unsigned int)));
  gpuErrchk(cudaMalloc(&d_RevSpikeNConn,
		       n_spike_buffers*sizeof(int)));

  DeviceRevSpikeInit<<<1,1>>>(d_RevSpikeNum, d_RevSpikeTarget,
			      d_RevSpikeNConn);
  gpuErrchk( cudaPeekAtLastError() );
  gpuErrchk( cudaDeviceSynchronize() );

  return 0;
}


int RevSpikeFree()
{
  gpuErrchk(cudaFree(&d_RevSpikeNum));
  gpuErrchk(cudaFree(&d_RevSpikeTarget));
  gpuErrchk(cudaFree(&d_RevSpikeNConn));

  return 0;
}