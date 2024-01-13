#!/bin/bash
# Update system
yum update -y

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker

# Login to GitHub Container Registry
echo "${docker_token}" | docker login ghcr.io -u "${docker_username}" --password-stdin

# Pull your SvelteKit app image from GHCR
docker pull ${docker_image_url}

# Run your SvelteKit app
docker run -d -p 80:3000 --restart unless-stopped --name my_app ${docker_image_url}
