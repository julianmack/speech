#!/bin/bash
cd speech && \
			mkdir ~/Data && \
      python3 examples/librispeech/download.py ~/Data && \
      python3 examples/librispeech/preprocess.py ~/Data; \
      python3 train.py ~/speech/configs/strawperson.json;
