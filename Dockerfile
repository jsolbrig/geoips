# EXT_REGISTRY allows specifying a different registry that is acting as a pull-through cache for Docker Hub.
# To provide EXT_REGISTRY at build time, supply it as a build argument 
#     `docker build . --build-arg EXT_REGISTRY=https://myregistry.com/`
# Note that the value MUST contain a trailing slash
# If not provided, images will be pulled from Docker Hub
ARG EXT_REGISTRY=""
ARG IMAGE_TAG="11.4"
ARG PROJ_VERSION='9.0.1'
ARG USER=geoips_user
ARG UID=25000
ARG GID=25000
ARG GEOIPS_BASEDIR=/app
ARG GEOIPS_REPO_URL=git@github.com/jsolbrig/geoips.git
ARG GEOIPS_OUTDIRS=/output
ARG GEOIPS_PACKAGES_DIR=/app/geoips_packages
ARG GEOIPS_DEPENDENCIES_DIR=/data
ARG GEOIPS_TESTDATA_DIR=/data


FROM ${EXT_REGISTRY}docker.io/library/debian:${IMAGE_TAG} as proj
# Renew build args for the stage
ARG EXT_REGISTRY IMAGE_TAG PROJ_VERSION USER UID GID \
    GEOIPS_BASEDIR GEOIPS_REPO_URL GEOIPS_OUTDIRS GEOIPS_PACKAGES_DIR GEOIPS_DEPENDENCIES_DIR GEOIPS_TESTDATA_DIR

WORKDIR /build

RUN apt-get update \
    && apt-get install -y python3 python3-pip \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# When we update this to use debian:bookworm we should begin installing proj via `apt-get install proj-bin`
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing --no-install-recommends \
        software-properties-common build-essential ca-certificates cmake wget unzip \
        zlib1g-dev libsqlite3-dev sqlite3 libcurl4-gnutls-dev libtiff5-dev
RUN mkdir -p /build/usr/local \
    && wget https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz \
    && tar -xzvf ./proj-${PROJ_VERSION}.tar.gz \
    && cd proj-${PROJ_VERSION} \
    && cmake . -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    && DESTDIR=/build cmake --build build --target install

FROM ${EXT_REGISTRY}docker.io/library/debian:${IMAGE_TAG} as rclone
ARG EXT_REGISTRY IMAGE_TAG PROJ_VERSION USER UID GID \
    GEOIPS_BASEDIR GEOIPS_REPO_URL GEOIPS_OUTDIRS GEOIPS_PACKAGES_DIR GEOIPS_DEPENDENCIES_DIR GEOIPS_TESTDATA_DIR

RUN apt-get update \
    && apt-get install -y unzip wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# I don't like this because it doesn't grab a specific rclone version but I don't know where to
# get a specific version right now and am hurrying
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip rclone*.zip \
    && cp rclone-*-linux-amd64/rclone /usr/bin/rclone \
    && chown root:root /usr/bin/rclone \
    && chmod 755 /usr/bin/rclone \
    && rm -rf rclone-*-linux-amd64

FROM ${EXT_REGISTRY}docker.io/library/debian:${IMAGE_TAG} as geoips
ARG EXT_REGISTRY IMAGE_TAG PROJ_VERSION USER UID GID \
    GEOIPS_BASEDIR GEOIPS_REPO_URL GEOIPS_OUTDIRS GEOIPS_PACKAGES_DIR GEOIPS_DEPENDENCIES_DIR GEOIPS_TESTDATA_DIR

ENV PATH=${PATH}:/home/${USER}/.local/bin:${GEOIPS_DEPENDENCIES_DIR}/bin

ENV GEOIPS_BASEDIR=${GEOIPS_BASEDIR}
ENV GEOIPS_REPO_URL=${GEOIPS_REPO_URL}
ENV GEOIPS_OUTDIRS=${GEOIPS_OUTDIRS}
ENV GEOIPS_PACKAGES_DIR=${GEOIPS_PACKAGES_DIR}
ENV GEOIPS_DEPENDENCIES_DIR=${GEOIPS_DEPENDENCIES_DIR}
ENV GEOIPS_TESTDATA_DIR=${GEOIPS_TESTDATA_DIR}

WORKDIR $GEOIPS_BASEDIR

# RUN apt-get update \
#     && DEBIAN_FRONTEND=noninteractive apt-get install -y \
#         build-essential imagemagick wget libsqlite3-0 libtiff5 libcurl4 libcurl3-gnutls ca-certificates \
#         libgeos-dev python3 python3-pip unzip \
#     && ln -s /usr/bin/python3 /usr/bin/python \
#     && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential imagemagick wget libsqlite3-0 libtiff5 libcurl4 libcurl3-gnutls ca-certificates libgeos-dev \
        python3 python3-pip \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# # Not sure if this is needed or not. Leaving them commented here for now.
# # These files add 600MB to the image size.
# # They appear to contain a bunch of GeoTIFFs that proj uses in some way.
# # RUN mkdir -p /usr/share/proj; \
# #     wget --no-verbose --mirror https://cdn.proj.org/; \
# #     rm -f cdn.proj.org/*.js; \
# #     rm -f cdn.proj.org/*.css; \
# #     mv cdn.proj.org/* /usr/share/proj/; \
# #     rmdir cdn.proj.org

RUN groupadd --gid ${GID} ${USER} \
    && useradd --gid ${GID} --uid ${UID} -m ${USER}

COPY --from=proj /build/usr/share/proj/ /usr/share/proj/
COPY --from=proj /build/usr/include/ /usr/include/
COPY --from=proj /build/usr/bin/ /usr/bin/
COPY --from=proj /build/usr/lib/ /usr/lib/
COPY --from=rclone /usr/bin/rclone /usr/bin/rclone
COPY --chown=${USER} . ${GEOIPS_PACKAGES_DIR}/geoips
COPY --chown=${USER} ./setup/rclone_setup/rclone.conf /home/${USER}/.config/rclone/rclone.conf

USER ${USER}

# RUN cd ${GEOIPS_PACKAGES_DIR}/geoips \
#     pip install --no-cache ".[efficiency_improvements, test_outputs, config_based, hdf5_readers, hdf4_readers, syntax_checking, documentation, debug, overpass_predictor, geostationary_readers]"