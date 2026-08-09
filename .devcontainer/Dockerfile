FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG FLUTTER_VERSION=3.44.8
ARG JAVA_VERSION=21

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter

ENV PATH=${FLUTTER_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/build-tools/36.0.0:${PATH}

RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ca-certificates \
    openjdk-21-jdk \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Flutter
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git ${FLUTTER_HOME}

RUN flutter precache

# Android SDK command line tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && cd /tmp \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip \
    && unzip -q commandlinetools-linux-13114758_latest.zip \
    && mv cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm commandlinetools-linux-13114758_latest.zip

# Android SDK
RUN yes | sdkmanager --licenses >/dev/null || true

RUN sdkmanager \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" \
    "build-tools;28.0.3" \
    "ndk;28.2.13676358" \
    "cmake;3.22.1"

RUN flutter config --no-analytics \
    && flutter config --enable-android \
    && flutter config --enable-web \
    && flutter config --enable-linux-desktop

WORKDIR /workspaces/Bivium

CMD ["/bin/bash"]
