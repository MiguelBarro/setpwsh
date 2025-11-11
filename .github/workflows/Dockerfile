ARG base_image=alpine:latest

FROM ${base_image}

# trusted pub key
ARG pubkey=sshkey.pub

# ssh port
ARG sshport=22

# Create the new user
RUN adduser -D -h /home/sshuser -s /bin/sh sshuser && passwd -u sshuser

# Install the server
RUN apk update && apk add openssh && ssh-keygen -A 

# Modify the config file to allow empty passwords
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config && \
    sed -i "s/#Port 22/Port ${sshport}/" /etc/ssh/sshd_config

# Copy key to the docker an populate the authorization file
COPY ${pubkey} /home/sshuser/.ssh/authorized_keys

# make sure is running
CMD ["/usr/sbin/sshd", "-D"]
