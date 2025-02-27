#!/bin/bash
set -e

# 1. Build the Docker image for Jetson (using updated Dockerfile)
IMAGE_NAME="orbslam3:jetson"
docker build -t $IMAGE_NAME -f Dockerfile_jetson.cuda .

# 2. Remove old ORB_SLAM3 output on host and create volume directory
[ -d "ORB_SLAM3" ] && sudo rm -rf ORB_SLAM3
mkdir ORB_SLAM3

# 3. Run a container with NVIDIA runtime, mounting X11 and the ORB_SLAM3 folder
docker run -d --name orbslam3_container --runtime=nvidia \
    -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v `pwd`/ORB_SLAM3:/ORB_SLAM3 \
    -w /ORB_SLAM3 --net=host $IMAGE_NAME bash

# Allow container X access (assumes xhost installed on host)
xhost +local:root

# 4. Inside the container: clone ORB_SLAM3 and build it
docker exec orbslam3_container bash -c "\
    git clone --recursive https://github.com/UZ-SLAMLab/ORB_SLAM3.git /ORB_SLAM3 && \
    cd /ORB_SLAM3 && chmod +x build.sh && ./build.sh"

# 5. Build the ROS node (if needed)
docker exec orbslam3_container bash -c "\
    source /opt/ros/noetic/setup.bash && \
    echo 'export ROS_PACKAGE_PATH=\$ROS_PACKAGE_PATH:/ORB_SLAM3/Examples/ROS' >> ~/.bashrc && \
    cd /ORB_SLAM3 && chmod +x build_ros.sh && ./build_ros.sh"

echo "ORB-SLAM3 has been built inside the container. You can now enter the container with:"
echo "    docker exec -it orbslam3_container bash"
