FROM ghcr.io/cozy/meet-backend:0.0.1

USER root

RUN pip install --no-cache-dir \
    django-extensions \
    drf-spectacular \
    drf-spectacular-sidecar \
    django-filter \
    django-cors-headers

USER 1000
