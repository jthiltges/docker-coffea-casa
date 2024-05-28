FROM almalinux/8-minimal

# Install required packages (not available in conda)
RUN microdnf install -y \
      findutils \
      less \
      shadow-utils \
      strace \
      which \
 && microdnf clean all \
 && rm -rf /var/cache/yum

# Add jovyan user, following conventions from jupyterhub/singleuser
# https://github.com/jupyterhub/zero-to-jupyterhub-k8s/blob/main/images/singleuser-sample/Dockerfile
ENV NB_USER=jovyan \
    NB_UID=1000 \
    HOME=/home/jovyan
RUN adduser \
      --uid ${NB_UID} \
      ${NB_USER}

# Set conda install path and change ownership to user
ENV CONDA_PATH=/usr/local
# Allow jovyan user to write to conda install path
# Make passwd writable so we can modify the jovyan username at runtime
RUN chown -R ${NB_USER}:${NB_USER} \
      ${CONDA_PATH} \
      /etc/passwd

# Add symlinks in /etc for grid-security, vomses, xrootd (plugins), etc.
RUN ln -s ${CONDA_PATH}/etc/grid-security /etc/grid-security \
 && ln -s ${CONDA_PATH}/etc/vomses /etc \
 && ln -s ${CONDA_PATH}/etc/xrootd /etc

# Switch to user
USER ${NB_USER}:${NB_USER}

# Install mamba
RUN cd /tmp \
 && curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
 && bash Miniforge3-$(uname)-$(uname -m).sh -bfp ${CONDA_PATH} \
 && rm Miniforge3-$(uname)-$(uname -m).sh

##############################################################################
# docker-coffea-base/base-almalinux8 #########################################
ENV PYTHON_VERSION=3.10
COPY --chown=${NB_USER} environment.yaml /tmp
RUN mamba install --yes \
      python=${PYTHON_VERSION} \
 && mamba env update --file /tmp/environment.yaml \
 && mamba clean --all --yes \
 && rm -rf $HOME/.cache

# Add VOMS config
RUN curl -L https://github.com/opensciencegrid/osg-vo-config/archive/refs/heads/master.tar.gz | \
    tar -xz --strip-components=1 --directory=${CONDA_PATH}/etc/grid-security --wildcards "*/vomses" "*/vomsdir" \
 && mv ${CONDA_PATH}/etc/grid-security/vomses ${CONDA_PATH}/etc

# Build and install xcache plugin
RUN cd /tmp \
 && git clone -b xcache https://github.com/jthiltges/xrdcl-authz-plugin.git \
 && cd xrdcl-authz-plugin \
 && mkdir build \
 && cd build \
 && cmake .. -DCMAKE_INSTALL_PREFIX=${CONDA_PATH} \
 && make \
 && make install \
 && rm -rf /tmp/xrdcl-authz-plugin

# Copy coffea utilities to libexec/coffea
COPY --chown=${NB_USER} --chmod=755 libexec/ ${CONDA_PATH}/libexec/coffea/

# Configure supervisord ######################################################
# Load runtime config from supervisord/conf.d and ${SUPERVISORD_PROFILE}.d
# Use singleuser as the default profile
ENV SUPERVISORD_PROFILE="singleuser"
COPY --chown=${NB_USER} supervisord.conf ${CONDA_PATH}/etc
COPY --chown=${NB_USER} supervisord/     ${CONDA_PATH}/etc/supervisord/

# Allow custom conda environments
# https://z2jh.jupyter.org/en/stable/jupyterhub/customizing/user-environment.html#allow-users-to-create-their-own-conda-environments-for-notebooks
RUN conda config --system --append envs_dirs "~/conda-envs"
