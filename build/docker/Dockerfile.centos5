FROM centos:5
MAINTAINER Abderrahmane Benbachir abderb@microsoft.com

# Important for unittests
RUN adduser omsagent && groupadd omiusers

RUN mkdir -p /home/scratch
WORKDIR /home/scratch

# Edit the repos files to use vault.centos.org instead
RUN sed -i 's/^mirrorlist/#mirrorlist/' /etc/yum.repos.d/*.repo && \
    sed -i 's/^#baseurl=http:\/\/mirror\.centos\.org\/centos\//baseurl=http:\/\/vault\.centos\.org\//' /etc/yum.repos.d/*.repo && \
    sed -i 's/\$releasever/5.11/g' /etc/yum.repos.d/*.repo

# Extra repos & dependencies
RUN yum update -y && yum clean all && yum install -y wget epel-release

# because Centos5 was deprecated
RUN wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
RUN yum update -y && yum install -y devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils && scl enable devtoolset-2 bash && source /opt/rh/devtoolset-2/enable
# ENV PATH /opt/rh/devtoolset-2/root/usr/bin:$PATH

RUN yum install -y which sudo make tree vim cmake zip git redhat-lsb openssh-clients bind-utils bison gcc-c++ libcxx \
    rpm-devel pam-devel openssl-devel rpm-build mysql-devel curl-devel selinux-policy-devel audit-libs-devel boost148-devel

# Autoconf >= 2.67 required by ruby to generate ./configure
ADD http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz /home/scratch/autoconf-2.69.tar.gz
RUN cd /home/scratch && tar -vzxf autoconf-2.69.tar.gz
RUN cd /home/scratch/autoconf-2.69 && ./configure && make && make install

# Ruby
ADD https://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.6.tar.gz /home/scratch/ruby-2.2.6.tar.gz
RUN cd /home/scratch && tar -zxf ruby-2.2.6.tar.gz
RUN cd /home/scratch/ruby-2.2.6 && ./configure && make && make install

# Perl >= 5.10 required by openssl-1.1.0, which not installed in centos5
ADD https://github.com/Perl/perl5/archive/v5.24.1.tar.gz /home/scratch/perl.tar.gz
RUN cd /home/scratch && tar -zxvf perl.tar.gz
RUN cd /home/scratch/perl5-5.24.1 && ./Configure -des -Dprefix=/usr/local_perl_5_24_1 && make install
ENV PATH /usr/local_perl_5_24_1/bin:$PATH

# OpenSSL
RUN mkdir -p /home/scratch/ostc-openssl
RUN mkdir -p ~/.ssh/ && ssh-keyscan github.com >> ~/.ssh/known_hosts
ADD https://github.com/msgpack/msgpack-c/archive/cpp-2.0.0.zip /home/scratch/msgpack-c-cpp-2.0.0.zip
ADD https://github.com/miloyip/rapidjson/archive/v1.0.2.tar.gz /home/scratch/rapidjson-1.0.2.tar.gz
ADD https://github.com/openssl/openssl/archive/OpenSSL_1_0_0.tar.gz /home/scratch
ADD https://github.com/openssl/openssl/archive/OpenSSL_1_1_0.tar.gz /home/scratch
RUN cd /home/scratch && tar -zxf OpenSSL_1_0_0.tar.gz && tar -zxf OpenSSL_1_1_0.tar.gz
RUN cd /home/scratch && mv openssl-OpenSSL_1_0_0 /home/scratch/ostc-openssl/openssl-1.0.0 && mv openssl-OpenSSL_1_1_0 /home/scratch/ostc-openssl/openssl-1.1.0

# Build OpenSSL
RUN cd /home/scratch/ostc-openssl/openssl-1.0.0 && ./config --prefix=/usr/local_ssl_1.0.0 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh && make depend && make && make install_sw
RUN cd /home/scratch/ostc-openssl/openssl-1.1.0 && ./config --prefix=/usr/local_ssl_1.1.0 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh && make depend && make && make install_sw


