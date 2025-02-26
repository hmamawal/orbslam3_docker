#!/bin/bash

# Check for Jetson-specific GPU tools
if ! command -v tegrastats &>/dev/null; then
  echo "******************************"
  echo "tegrastats not found! Ensure NVIDIA Jetson drivers are installed."
  echo "******************************"
  exit 1
fi

# Check if NVIDIA Container Runtime is installed
if ! dpkg -l | grep -q nvidia-container-runtime; then
  echo "******************************"
  echo "NVIDIA Container Runtime is not installed! Install it first."
  echo "******************************"
  exit 1
fi

# UI permissions
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

xhost +local:docker

# Ensure DISPLAY is set correctly
if [ -z "$DISPLAY" ]; then
  export DISPLAY=:0
  echo "DISPLAY was not set. Defaulting to :0"
fi

docker pull jahaniam/orbslam3:jetson

# Remove existing container
docker rm -f orbslam3 &>/dev/null
[ -d "ORB_SLAM3" ] && sudo rm -rf ORB_SLAM3 && mkdir ORB_SLAM3

# Create a new container
docker run -td --runtime nvidia --privileged --net=host --ipc=host \
    --name="orbslam3" \
    --gpus all \
    -e "DISPLAY=$DISPLAY" \
    -e "QT_X11_NO_MITSHM=1" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    -e "XAUTHORITY=$XAUTH" \
    -e ROS_IP=127.0.0.1 \
    --cap-add=SYS_PTRACE \
    -v `pwd`/Datasets:/Datasets \
    -v /etc/group:/etc/group:ro \
    -v `pwd`/ORB_SLAM3:/ORB_SLAM3 \
    jahaniam/orbslam3:jetson bash

# Git pull orbslam and compile
docker exec -it orbslam3 bash -i -c "git clone -b add_euroc_example.sh https://github.com/jahaniam/ORB_SLAM3.git /ORB_SLAM3 && cd /ORB_SLAM3 && chmod +x build.sh && ./build.sh "
# Compile ORBSLAM3-ROS
docker exec -it orbslam3 bash -i -c "echo 'ROS_PACKAGE_PATH=/opt/ros/noetic/share:/ORB_SLAM3/Examples/ROS'>>~/.bashrc && source ~/.bashrc && cd /ORB_SLAM3 && chmod +x build_ros.sh && ./build_ros.sh"
