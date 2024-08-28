FROM jupyterhub/k8s-hub:3.3.8

ADD ./authenticator/ ./authenticator

USER root
RUN chmod -R u+w ./authenticator

RUN pip3 install notebook
RUN pip3 install ./authenticator

USER jovyan
