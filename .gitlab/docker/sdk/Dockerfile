ARG DESIGNATED_BRANCH=prplos-next
FROM registry.gitlab.com/prpl-foundation/prplos/prplos/$DESIGNATED_BRANCH/builder:latest

COPY --chown=builder:builder . /home/builder/

WORKDIR /home/builder
RUN mkdir .ssh && ssh-keyscan gitlab.com > .ssh/known_hosts
RUN sed -i 's;\(http[s]\?\)://\(.*@\);\1://;g' feeds.conf.default
RUN sed -i 's/prplos.git/prplos.git;prplos-next/' feeds.conf.default
