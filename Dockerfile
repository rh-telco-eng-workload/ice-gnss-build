ARG IMAGE
ARG BUILD_IMAGE

FROM ${BUILD_IMAGE} AS builder

WORKDIR /build/
ARG DRIVER_VER

RUN curl https://netix.dl.sourceforge.net/project/e1000/unsupported/ice%20unsupported/${DRIVER_VER}/ice-${DRIVER_VER}.tar.gz -o ice-${DRIVER_VER}.tar.gz
RUN tar xvfz ice-${DRIVER_VER}.tar.gz

WORKDIR /build/ice-${DRIVER_VER}/src
ARG KERNEL_VERSION
RUN BUILD_KERNEL=${KERNEL_VERSION} KSRC=/usr/src/kernels/${KERNEL_VERSION} make CFLAGS_EXTRA="-DGNSS_SUPPORT"

FROM ${IMAGE}

ARG DRIVER_VER
ARG KERNEL_VERSION

RUN microdnf install -y kmod; microdnf clean all

COPY --from=builder /build/ice-$DRIVER_VER/src/*.ko /opt/lib/modules/${KERNEL_VERSION}/
COPY --from=builder /build/ice-$DRIVER_VER/ddp/ /ddp/
COPY scripts/load.sh scripts/unload.sh /usr/local/bin

RUN chmod +x /usr/local/bin/load.sh && chmod +x /usr/local/bin/unload.sh
RUN depmod -b /opt ${KERNEL_VERSION}
