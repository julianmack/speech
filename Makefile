IMAGE_NAME=awni-speech
IMAGE_TAG=first


all: warp transduce


warp:
	git clone https://github.com/awni/warp-ctc.git libs/warp-ctc
	cd libs/warp-ctc; mkdir build; cd build; cmake ../ && make; \
		cd ../pytorch_binding; python3 build.py

transduce:
	git clone https://github.com/awni/transducer.git libs/transducer
	cd libs/transducer; python3 build.py

gcp:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) gcr.io/myrtle-deepspeech/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push gcr.io/myrtle-deepspeech/$(IMAGE_NAME):$(IMAGE_TAG)


build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

build/push: build gcp	


libs/apex:
		git clone git@github.com:NVIDIA/apex.git libs/apex


clean: cleansmall
		rm -rf libs
		find . -type d -name "__pycache*" -exec rm -r {} +


cleansmall:
		find . -type d -name "__pycache*" -exec rm -r {} +
		sudo docker images -q $(IMAGE_NAME):$(IMAGE_TAG) | \
				xargs --no-run-if-empty sudo docker rmi
		sudo docker images -q $(IMAGE_REPOSITORY):$(IMAGE_TAG) | \
				xargs --no-run-if-empty sudo docker rmi

.PHONY: build clean gcp
