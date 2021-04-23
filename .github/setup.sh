#!/bin/sh


# Setup Swift on Linux
echo "Downloading Swift 4.2..."
wget https://swift.org/builds/swift-4.2-release/ubuntu1804/swift-4.2-RELEASE/swift-4.2-RELEASE-ubuntu18.04.tar.gz
echo "Extracting Swift 4.2 package..."
tar xzf swift-4.2-RELEASE-ubuntu18.04.tar.gz
echo "Adding Swift to PATH"
export PATH="${PWD}/swift-4.2-RELEASE-ubuntu18.04/usr/bin:$PATH"
  
  
