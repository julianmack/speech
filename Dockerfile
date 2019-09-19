FROM nvidia/cuda:9.1-cudnn7-devel-ubuntu16.04

LABEL maintainer="julian@myrtle.ai"


ENV PATH /opt/conda/bin:$PATH

#- Upgrade system and install dependencies -------------------------------------
RUN apt-get update --fix-missing && \
    apt-get install -y software-properties-common && \
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
                    sudo \
                    vim && \
    apt-get remove -y python3.5 && \
    apt-get autoremove -y && \
		apt-get update && \
		apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists
#- Enable passwordless sudo for users under the "sudo" group -------------------
RUN sed -i.bkp -e \
      's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' \
      /etc/sudoers

RUN apt-get update && \
    apt-get install -y wget && \
		apt-get update


#- Create data group for NFS mount --------------------------------------------
RUN groupadd --system data --gid 5555

#- Create and switch to a non-root user ----------------------------------------
RUN groupadd -r ubuntu && \
    useradd --no-log-init \
            --create-home \
            --gid ubuntu \
            ubuntu && \
    usermod -aG sudo ubuntu

ENV SHELL /bin/bash

#Install conda -------------------------------------------
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda2-4.5.11-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc


# update conda --------------------------------
RUN conda update conda
RUN conda install conda-build

RUN conda install python=3.6.8 && \
		conda create --name awni python=3.6.8 && \
		echo "source activate awni" > ~/.bashrc
ENV PATH /opt/conda/envs/env/bin:$PATH

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


# Install transduce and warp ctc--------------------------------------
RUN git clone https://github.com/awni/transducer.git libs/transducer && \
      cd libs/transducer; python3 build.py
RUN git clone https://github.com/awni/warp-ctc.git libs/warp-ctc && \
      cd libs/warp-ctc; mkdir build; cd build; cmake ../ && make; \
      cd ../pytorch_binding; python3 build.py

#- Install speech package --------------------------------------------------
COPY --chown=ubuntu:ubuntu . speech
RUN cd speech && pip3 install --user .


#set env variables for speech repo ---------------------------------------------
RUN echo "source speech/setup.sh" > .bashrc

#install ffmpeg for preprocessing -----------------------------------------
RUN sudo apt-get update --fix-missing && \
    sudo apt-get install -y ffmpeg && \
		sudo apt-get update --fix-missing

#- Setup Jupyter ---------------------------------------------------------------
EXPOSE 9999

CMD ["jupyter", "lab", \
     "--ip=0.0.0.0",   \
     "--port=9999"]
