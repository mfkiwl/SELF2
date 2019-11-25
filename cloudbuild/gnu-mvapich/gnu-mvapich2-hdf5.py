"""
HPC Base image

Contents:
  CUDA version 10.0
  HDF5 version 1.10.5
  GNU compilers version 8.3
  MVAPICH2 version 2.3.1
  Python 2 and 3 (upstream)
"""
# pylint: disable=invalid-name, undefined-variable, used-before-assignment

devel_image = 'nvidia/cuda:10.1-devel-centos7'
runtime_image = 'nvidia/cuda:10.1-runtime-centos7'

######
# Devel stage
######

Stage0 += comment(__doc__, reformat=False)

Stage0 += baseimage(image=devel_image, _as='devel')

# Python
Stage0 += python()

# GNU compilers
compiler = gnu(version='8')
Stage0 += compiler

# Mellanox OFED
Stage0 += mlnx_ofed(version='4.6-1.0.1.1')

# MVAPICH2
Stage0 += mvapich2(version='2.3.1', cuda=True, toolchain=compiler.toolchain)

# HDF5
Stage0 += hdf5(version='1.10.5', mpi=True, toolchain=compiler.toolchain)

# Metis
Stage0 += shell(commands=['yum install -y cmake'])
Stage0 += shell(commands=['mkdir -p /var/tmp',
                          'wget -q -nc --no-check-certificate -P /var/tmp http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/metis-5.1.0.tar.gz',
                          'tar -xzf /var/tmp/metis-5.1.0.tar.gz -C /var/tmp',
                          'cd /var/tmp/metis-5.1.0',
                          'make config prefix=/usr/local/metis',
                          'make install'])
Stage0 += environment(variables={'LIB_METIS':'/usr/local/metis/libmetis.a'})

######
# Runtime image
######

Stage1 += baseimage(image=runtime_image)

Stage1 += Stage0.runtime(_from='devel')
