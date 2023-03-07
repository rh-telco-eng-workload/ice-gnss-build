ARG IMAGE
ARG BUILD_IMAGE

FROM ${BUILD_IMAGE} AS builder
WORKDIR /build/

ARG GNSS_KERNEL_TAG
ARG KERNEL_VERSION
RUN git clone --depth 1 --branch ${GNSS_KERNEL_TAG} https://github.com/torvalds/linux
RUN cp /build/linux/include/linux/gnss.h /usr/src/kernels/${KERNEL_VERSION}/include/linux/gnss.h

WORKDIR /build/linux/drivers/gnss
RUN sed -i 's/stream_open/nonseekable_open/' *
RUN CONFIG_GNSS=m GNSS_SERIAL=m make -C /usr/src/kernels/${KERNEL_VERSION}/ M=$PWD

WORKDIR /build/
ARG DRIVER_VER

RUN curl https://netix.dl.sourceforge.net/project/e1000/ice%20stable/${DRIVER_VER}/ice-${DRIVER_VER}.tar.gz -o ice-${DRIVER_VER}.tar.gz
RUN tar xvfz ice-${DRIVER_VER}.tar.gz
RUN curl -o ice-gnss.patch https://raw.githubusercontent.com/javierpena/ice-gnss-build/main/patches/ice-force-gnss-${DRIVER_VER}.patch

WORKDIR /build/ice-${DRIVER_VER}/
RUN patch -p0 < /build/ice-gnss.patch

WORKDIR /build/ice-${DRIVER_VER}/src
ARG KERNEL_VERSION
RUN CONFIG_GNSS=m BUILD_KERNEL=${KERNEL_VERSION} KSRC=/usr/src/kernels/${KERNEL_VERSION} make CFLAGS_EXTRA="-DGNSS_SUPPORT"

FROM ${IMAGE}

ARG DRIVER_VER
ARG KERNEL_VERSION

RUN microdnf install -y kmod; microdnf clean all

COPY --from=builder /build/ice-$DRIVER_VER/src/ice.ko /opt/lib/modules/${KERNEL_VERSION}/
COPY --from=builder /build/ice-$DRIVER_VER/ddp/ /ddp/
COPY --from=builder /build/linux/drivers/gnss/gnss.ko /opt/lib/modules/${KERNEL_VERSION}/
COPY scripts/load.sh scripts/unload.sh /usr/local/bin

RUN chmod +x /usr/local/bin/load.sh && chmod +x /usr/local/bin/unload.sh
RUN depmod -b /opt ${KERNEL_VERSION}
