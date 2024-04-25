ARG DESIGNATED_BRANCH_SLUG=prpl-nightly
FROM registry.gitlab.com/prpl-foundation/prplos/prplos/$DESIGNATED_BRANCH_SLUG/builder:latest

COPY --chown=builder:builder . /home/builder/

WORKDIR /home/builder
RUN mkdir .ssh && ssh-keyscan gitlab.com > .ssh/known_hosts
RUN sed -i 's;\(http[s]\?\)://\(.*@\);\1://;g' feeds.conf.default
