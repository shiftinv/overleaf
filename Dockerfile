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
      aspell aspell-* \
    \
# install Node.JS 12
 && curl -sSL https://deb.nodesource.com/setup_12.x | bash - \
 && apt-get install -y nodejs \
    \
 && rm -rf \
      /etc/nginx/nginx.conf \
      /etc/nginx/sites-enabled/default \
 && find /var/lib/apt/lists/ /tmp/ /var/tmp/ -mindepth 1 -maxdepth 1 -exec rm -rf "{}" +

# Add envsubst
# ------------
ADD ./vendor/envsubst /usr/bin/envsubst
RUN chmod +x /usr/bin/envsubst

# Install Grunt
# ------------
RUN npm install -g grunt-cli \
 && find /root/.npm /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf "{}" +


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
 && find /root/.cache /root/.npm /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf "{}" + \
# Stores the version installed for each service
# ---------------------------------------------
 && cd /var/www \
 && ./git-revision.sh > revisions.txt \
# Store web service version separately (for displaying in browser) in $SHARELATEX_WEB_VERSION
# -------------------------------------------------------------------------------------------
 && git --git-dir="sharelatex/web/.git" rev-parse --short HEAD \
      > /etc/container_environment/SHARELATEX_WEB_VERSION \
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
 && find /root/.cache /root/.npm /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf "{}" +

# Compile CoffeeScript
# --------------------
RUN cd /var/www/sharelatex \
 && bash ./bin/compile-services \
 && find /root/.cache /root/.npm /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf "{}" +


# Copy runit service startup scripts to its location
# --------------------------------------------------
ADD ${baseDir}/runit /etc/service


# Configure nginx
# ---------------
ADD ${baseDir}/nginx/nginx.conf.template /etc/nginx/templates/nginx.conf.template
ADD ${baseDir}/nginx/sharelatex.conf /etc/nginx/sites-enabled/sharelatex.conf


# Configure log rotation
# ----------------------
ADD ${baseDir}/logrotate/sharelatex /etc/logrotate.d/sharelatex
RUN chmod 644 /etc/logrotate.d/sharelatex


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

ENV SHARELATEX_APP_VERSION "2.4.1"

ENV OPTIMISE_PDF "true"


EXPOSE 80

WORKDIR /

ENTRYPOINT ["/sbin/my_init"]

