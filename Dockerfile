# --------------------------------------------------
# Overleaf Base Image
# --------------------------------------------------

FROM phusion/baseimage:0.11

ENV baseDir .


# Install dependencies
# --------------------
RUN apt-get update \
 && apt-get install -y \
      build-essential wget net-tools unzip time imagemagick optipng strace nginx git python zlib1g-dev libpcre3-dev \
      qpdf \
      aspell aspell-* \
    \
# install Node.JS 10
 && curl -sSL https://deb.nodesource.com/setup_10.x | bash - \
 && apt-get install -y nodejs \
    \
 && rm -rf \
      /etc/nginx/nginx.conf \
      /etc/nginx/sites-enabled/default \
 && find /var/lib/apt/lists/ /tmp/ /var/tmp/ -mindepth 1 -maxdepth 1 -exec rm -rf "{}" +

# Install Grunt
# ------------
RUN npm install -g grunt-cli \
 && rm -rf /root/.npm

# Install TexLive
# ---------------
# CTAN mirrors occasionally fail, in that case install TexLive against an
# specific server, for example http://ctan.crest.fr
#
# # docker build \
#     --build-arg TEXLIVE_MIRROR=http://ctan.crest.fr/tex-archive/systems/texlive/tlnet \
#     -f Dockerfile -t shiftinv/overleaf .
ARG TEXLIVE_MIRROR=http://mirror.ctan.org/systems/texlive/tlnet

ENV PATH "${PATH}:/usr/local/texlive/2020/bin/x86_64-linux"

RUN mkdir /install-tl-unx \
 && curl -sSL \
      ${TEXLIVE_MIRROR}/install-tl-unx.tar.gz \
    | tar -xzC /install-tl-unx --strip-components=1 \
    \
 && echo "tlpdbopt_autobackup 0" >> /install-tl-unx/texlive.profile \
 && echo "tlpdbopt_install_docfiles 0" >> /install-tl-unx/texlive.profile \
 && echo "tlpdbopt_install_srcfiles 0" >> /install-tl-unx/texlive.profile \
 && echo "selected_scheme scheme-basic" >> /install-tl-unx/texlive.profile \
    \
 && /install-tl-unx/install-tl \
      -profile /install-tl-unx/texlive.profile \
      -repository ${TEXLIVE_MIRROR} \
    \
 && tlmgr install --repository ${TEXLIVE_MIRROR} \
      latexmk \
      texcount \
    \
 && rm -rf /install-tl-unx


# Set up sharelatex user and home directory
# -----------------------------------------
RUN adduser --system --group --home /var/www/sharelatex --no-create-home sharelatex \
 && mkdir -p /var/lib/sharelatex \
 && chown www-data:www-data /var/lib/sharelatex \
 && mkdir -p /var/log/sharelatex \
 && chown www-data:www-data /var/log/sharelatex \
 && mkdir -p /var/lib/sharelatex/data/template_files \
 && chown www-data:www-data /var/lib/sharelatex/data/template_files






# ---------------------------------------------
# Overleaf Community Edition
# ---------------------------------------------

ENV SHARELATEX_CONFIG /etc/sharelatex/settings.coffee


# Add required source files
# -------------------------
ADD ${baseDir}/bin /var/www/sharelatex/bin
ADD ${baseDir}/doc /var/www/sharelatex/doc
ADD ${baseDir}/migrations /var/www/sharelatex/migrations
ADD ${baseDir}/tasks /var/www/sharelatex/tasks
ADD ${baseDir}/Gruntfile.coffee /var/www/sharelatex/Gruntfile.coffee
ADD ${baseDir}/package.json /var/www/sharelatex/package.json
ADD ${baseDir}/npm-shrinkwrap.json /var/www/sharelatex/npm-shrinkwrap.json
ADD ${baseDir}/services.js /var/www/sharelatex/config/services.js


# Copy build dependencies
# -----------------------
ADD ${baseDir}/git-revision.sh /var/www/git-revision.sh
ADD ${baseDir}/services.js /var/www/sharelatex/config/services.js


# Checkout services
# -----------------
RUN cd /var/www/sharelatex \
 && npm install \
 && grunt install \
  \
# Cleanup not needed artifacts
# ----------------------------
 && rm -rf /root/.cache /root/.npm $(find /tmp/ -mindepth 1 -maxdepth 1) \
# Stores the version installed for each service
# ---------------------------------------------
 && cd /var/www \
 && ./git-revision.sh > revisions.txt \
  \
# Cleanup the git history
# -------------------
 && rm -rf $(find /var/www/sharelatex -name .git)

# Install npm dependencies
# ------------------------
RUN cd /var/www/sharelatex \
 && bash ./bin/install-services \
  \
# Cleanup not needed artifacts
# ----------------------------
 && rm -rf /root/.cache /root/.npm $(find /tmp/ -mindepth 1 -maxdepth 1)

# Compile CoffeeScript
# --------------------
RUN cd /var/www/sharelatex \
 && bash ./bin/compile-services

# Links CLSI sycntex to its default location
# ------------------------------------------
RUN ln -s /var/www/sharelatex/clsi/bin/synctex /opt/synctex


# Copy runit service startup scripts to its location
# --------------------------------------------------
ADD ${baseDir}/runit /etc/service


# Configure nginx
# ---------------
ADD ${baseDir}/nginx/nginx.conf /etc/nginx/nginx.conf
ADD ${baseDir}/nginx/sharelatex.conf /etc/nginx/sites-enabled/sharelatex.conf


# Configure log rotation
# ----------------------
ADD ${baseDir}/logrotate/sharelatex /etc/logrotate.d/sharelatex


# Copy Phusion Image startup scripts to its location
# --------------------------------------------------
COPY ${baseDir}/init_scripts/ /etc/my_init.d/

# Copy app settings files
# -----------------------
COPY ${baseDir}/settings.coffee /etc/sharelatex/settings.coffee

# Set Environment Variables
# --------------------------------
ENV WEB_API_USER "sharelatex"

ENV SHARELATEX_APP_NAME "Overleaf Community Edition"

ENV OPTIMISE_PDF "true"


EXPOSE 80

WORKDIR /

ENTRYPOINT ["/sbin/my_init"]

