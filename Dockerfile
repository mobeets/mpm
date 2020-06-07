FROM registry.mathworks.com/matlab:R2018a

USER root

RUN apt-get update && \
    apt-get install -y unzip vim git

USER matlab

WORKDIR /matlab
