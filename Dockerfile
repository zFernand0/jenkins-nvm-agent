# This docker file will build on the jenkins-agent to provide access to npm utilities
FROM zfernand0/jenkins-agent

USER root

# Install minimum required software
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN apt-get update

RUN apt-get -y install git
RUN apt-get -y install curl

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Install curl, maven,
RUN apt-get update && apt-get install -y \
curl \
git \
openjdk-8-jdk \
sshpass \
&& rm -rf /var/lib/apt/lists/*

# Add node version 10 which should bring in npm, add maven and build essentials and required ssl certificates to contact maven central
# expect is also installed so that you can use that to login to your npm registry if you need to
# Note: we'll install Node.js globally and include the build tools for pyhton - but nvm will override when the container starts
RUN curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
RUN apt-get install -y nodejs expect build-essential maven ca-certificates-java && update-ca-certificates -f
ENV NODE_JS_NVM_VERSION 10.22.1

# Install nvm to enable multiple versions of node runtime and define environment
# variable for setting the desired node js version (defaulted to "current" for Node.js)
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash

# dd the jenkins users
RUN groupadd npmusers \
  && usermod -aG npmusers jenkins

# Also install nvm for user jenkins
USER jenkins
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
USER root

ARG tempDir=/tmp/jenkins-npm-agent
ARG sshEnv=/etc/profile.d/npm_setup.sh
ARG bashEnv=/etc/bash.bashrc

# First move the template file over
RUN mkdir ${tempDir}
COPY env.bashrc ${tempDir}/env.bashrc

# Create a shell file that applies the configuration for sessions. (anything not bash really)
RUN touch ${sshEnv} \
    && echo '#!bin/sh'>>${sshEnv} \
    && cat ${tempDir}/env.bashrc>>${sshEnv}

# Create a properties file that is used for all bash sessions on the machine
# Add the environment setup before the exit line in the global bashrc file
RUN sed -i -e "/# If not running interactively, don't do anything/r ${tempDir}/env.bashrc" -e //N ${bashEnv}

# Cleanup after ourselves
RUN rm -rdf ${tempDir}

# Copy the setup script and node/nvm scripts for execution (allow anyone to run them)
ARG scriptsDir=/usr/local/bin/
COPY docker-entrypoint.sh ${scriptsDir}
COPY install_node.sh ${scriptsDir}

# Execute the setup script when the image is run. Setup will install the desired version via
# nvm for both the root user and jenkins - then start the ssh service
ENTRYPOINT ["docker-entrypoint.sh"]

# Install minimum required software
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN apt-get update

RUN apt-get -y install git
RUN apt-get -y install curl

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Install curl, maven,
RUN apt-get update && apt-get install -y \
curl \
git \
openjdk-8-jdk \
sshpass \
&& rm -rf /var/lib/apt/lists/*

# Add node version 8 which should bring in npm, add maven and build essentials and required ssl certificates to contact maven central
# expect is also installed so that you can use that to login to your npm registry if you need to
RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
RUN apt-get install -y nodejs expect build-essential maven ca-certificates-java && update-ca-certificates -f

# Make the global npm install directory and update the environmental variables
RUN mkdir /.npm-global
ENV NPM_CONFIG_PREFIX=/.npm-global
ENV PATH=/.npm-global/bin:$PATH

# Grab the latest version of npm and put it in the new space
RUN npm install npm --global

# Adjust permissions so that the jenkins user can execute global npm commands
RUN chown root:npmusers /.npm-global -R \
  && chmod g+rwx /.npm-global -R

ARG tempDir=/tmp/jenkins-npm-agent
ARG sshEnv=/etc/profile.d/npm_setup.sh
ARG bashEnv=/etc/bash.bashrc

# Set the npm configuration so that users can install and run
# global modules when permissions are set properly

# Set the config globally (this should be extracted out of environment so that we can easily use concatenation)
RUN rm /etc/environment && touch /etc/environment
RUN echo PATH="\"/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games\"">>/etc/environment
RUN echo NPM_CONFIG_PREFIX="\"/.npm-global\"">>/etc/environment
# End figure out how to do this better

# First move the template file over
RUN mkdir ${tempDir}
COPY env.bashrc ${tempDir}/env.bashrc

# Create a shell file that applies the configuration for sessions. (anything not bash really)
RUN touch ${sshEnv} \
    && echo '#!bin/sh'>>${sshEnv} \
    && cat ${tempDir}/env.bashrc>>${sshEnv}

# Create a properties file that is used for all bash sessions on the machine
# Add the environment setup before the exit line in the global bashrc file
RUN sed -i -e "/# If not running interactively, don't do anything/r ${tempDir}/env.bashrc" -e //N ${bashEnv}

# Cleanup after ourselves
RUN rm -rdf ${tempDir}

# Default to exec ssh
CMD ["/usr/sbin/sshd", "-D"]

