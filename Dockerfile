FROM nvidia/cuda:9.1-cudnn7-devel-ubuntu16.04

LABEL maintainer="julian@myrtle.ai"



#- Upgrade system and install dependencies -------------------------------------
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
                    build-essential \
                    cmake \
                    curl \
                    git \
                    libboost-program-options-dev \
                    libboost-system-dev \
                    libboost-test-dev \
                    libboost-thread-dev \
                    libbz2-dev \
                    libeigen3-dev \
                    liblzma-dev \
                    libsndfile1 \
                    python3.6 \
                    python3.6-dev \
                    sudo \
                    vim && \
    apt-get remove -y python3.5 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists

#- Enable passwordless sudo for users under the "sudo" group -------------------
RUN sed -i.bkp -e \
      's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' \
      /etc/sudoers

#- Create data group for NFS mount --------------------------------------------
RUN groupadd --system data --gid 5555

#- Create and switch to a non-root user ----------------------------------------
RUN groupadd -r ubuntu && \
    useradd --no-log-init \
            --create-home \
            --gid ubuntu \
            ubuntu && \
    usermod -aG sudo ubuntu
USER ubuntu
WORKDIR /home/ubuntu



#- Install Python packages -----------------------------------------------------
ARG WHEELDIR=/home/ubuntu/.cache/pip/wheels
#COPY --chown=ubuntu:ubuntu libs libs
COPY --chown=ubuntu:ubuntu requirements.txt requirements.txt
ENV PATH "/home/ubuntu/.local/bin:${PATH}"
RUN sudo ln -s /usr/bin/python3.6 /usr/local/bin/python3 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py --user && \
    rm get-pip.py
#RUN pip3 wheel -w ${WHEELDIR} libs/myrtledata
RUN pip3 install --user \
                 --find-links ${WHEELDIR} \
                 -r requirements.txt && \
    rm requirements.txt && \
    rm -r ${WHEELDIR} && \
    rm -r /home/ubuntu/.cache/pip && \
		pip3 install jupyter jupyterlab --user

#- Install speech package --------------------------------------------------
COPY --chown=ubuntu:ubuntu . speech
RUN cd speech && pip3 install --user .
#ENTRYPOINT ["/bin/bash", "-c", "cd", "speech", "&&", "ls", "&&", "source", "setup.sh"]




#- Setup Jupyter ---------------------------------------------------------------
EXPOSE 9999
ENV SHELL /bin/bash


#set env variables for speech repo ---------------------------------------------
ENV PYTHONPATH /home/ubuntu/:/home/ubuntu/libs/warp-ctc/pytorch_binding:/home/ubuntu/libs:${PYTHONPATH}

ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/home/ubuntu/libs/warp-ctc/build

#ENV PYTHONPATH=`pwd`:`pwd`/libs/warp-ctc/pytorch_binding:`pwd`/libs:$PYTHONPATH
#ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`/libs/warp-ctc/build

RUN ls && ls && ls && echo $PYTHONPATH
RUN cd speech/tests && pytest

CMD ["jupyter", "lab", \
     "--ip=0.0.0.0",   \
     "--port=9999"]
