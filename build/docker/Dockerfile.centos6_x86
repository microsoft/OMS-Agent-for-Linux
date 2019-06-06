FROM i386/centos:6
MAINTAINER Abderrahmane Benbachir abderb@microsoft.com

# Important for unittests
RUN adduser omsagent && groupadd omiusers

RUN mkdir -p /home/scratch
WORKDIR /home/scratch

# Edit the repos files to use vault.centos.org instead
RUN sed -i 's/^mirrorlist/#mirrorlist/' /etc/yum.repos.d/*.repo && \
    sed -i 's/^#baseurl=/baseurl=/' /etc/yum.repos.d/*.repo && \
    sed -i 's/\$basearch/i386/g' /etc/yum.repos.d/*.repo

RUN yum install -y yum-utils epel-release centos-release-scl && yum-config-manager --enable rhel-server-rhscl-7-rpms

# Edit the repos files to use for epel
RUN sed -i 's/^mirrorlist/#mirrorlist/' /etc/yum.repos.d/*.repo && \
    sed -i 's/^#baseurl=/baseurl=/' /etc/yum.repos.d/*.repo && \
    sed -i 's/\$basearch/i386/g' /etc/yum.repos.d/*.repo

# Extra repos & dependencies
RUN yum update -y

RUN yum install -y which wget sudo make tree vim cmake zip git \
    openssh-clients bind-utils bison gcc-c++ rpm-devel \
    pam-devel openssl-devel rpm-build mysql-devel curl-devel selinux-policy-devel \
    audit-libs-devel lsof net-tools patch curl tar bzip2 unzip boost148-devel.i686 redhat-lsb.i686 \
    && yum clean all

# Devtoolset-2 (gcc 4.8)
RUN wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
RUN sed -i 's/\$basearch/i386/g' /etc/yum.repos.d/devtools-2.repo    
RUN yum update -y && yum install -y devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
ENV PATH /opt/rh/devtoolset-2/root/usr/bin:$PATH

# git
ADD https://github.com/git/git/archive/v2.17.1.tar.gz /home/scratch/v2.17.1.tar.gz
RUN tar -xzf v2.17.1.tar.gz
RUN cd git-2.17.1/ && make configure && ./configure --prefix=/usr && make all && make install

# Autoconf >= 2.67 required by ruby
ADD http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz /home/scratch/autoconf-2.69.tar.gz
RUN cd /home/scratch && tar -vzxf autoconf-2.69.tar.gz
RUN cd /home/scratch/autoconf-2.69 && ./configure && make && make install

# Ruby 2.4
ADD https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz /home/scratch/ruby-2.4.4.tar.gz
RUN cd /home/scratch && tar -zxf ruby-2.4.4.tar.gz
RUN cd /home/scratch/ruby-2.4.4 && ./configure && make CC="gcc -m32" && make install

# OpenSSL
RUN mkdir -p /home/scratch/ostc-openssl
RUN mkdir -p ~/.ssh/ && ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN git clone --branch OpenSSL_1_0_0  https://github.com/openssl/openssl.git /home/scratch/ostc-openssl/openssl-1.0.0
RUN git clone --branch OpenSSL_1_0_1  https://github.com/openssl/openssl.git /home/scratch/ostc-openssl/openssl-1.0.1
RUN git clone --branch OpenSSL_1_0_1  https://github.com/openssl/openssl.git /home/scratch/ostc-openssl/openssl-1.0.1
# Build OpenSSL
RUN cd /home/scratch/ostc-openssl/openssl-1.0.0 && ./Configure linux-generic32 --prefix=/usr/local_ssl_1.0.0 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh && make CC="gcc -m32" depend && make CC="gcc -m32" && make install_sw
RUN cd /home/scratch/ostc-openssl/openssl-1.0.1 && ./Configure linux-generic32 --prefix=/usr/local_ssl_1.0.1 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh && make CC="gcc -m32" depend && make CC="gcc -m32" && make install_sw
RUN cd /home/scratch/ostc-openssl/openssl-1.0.1 && ./Configure linux-generic32 --prefix=/usr/local_ssl_1.0.1 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh && make CC="gcc -m32" depend && make CC="gcc -m32" && make install_sw

