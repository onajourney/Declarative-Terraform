#!/bin/bash
# Login to GitHub Container Registry using provided credentials
echo "${docker_token}" | docker login ghcr.io -u "${docker_username}" --password-stdin

# Pull the SvelteKit app image from GHCR using the provided image path
docker pull ${docker_image_url}

# Run your SvelteKit app 
docker run -d -p 80:3000 --restart unless-stopped --name my_app ${docker_image_url}
