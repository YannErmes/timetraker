variables:
  # Name the image is tagged with locally. `make docker-build` reads this.
  IMAGE_NAME: 4cus-web
  IMAGE_TAG: latest
  # Host port the app is published on. 8080 rather than 80 so it does not need
  # elevation to run.
  HOST_PORT: 8080

# `make docker-help` lists everything.

.PHONY: help docker-build docker-run docker-stop docker-logs docker-shell docker-clean docker-rebuild

help: ## Show this help
	@echo "4cus web - docker targets"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Then open http://localhost:$(HOST_PORT)"

docker-build: ## Build the web image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: ## Run the image in the background on $(HOST_PORT)
	docker run -d --name $(IMAGE_NAME) -p $(HOST_PORT):80 $(IMAGE_NAME):$(IMAGE_TAG)

docker-stop: ## Stop and remove the running container
	-docker stop $(IMAGE_NAME)
	-docker rm $(IMAGE_NAME)

docker-logs: ## Follow the container logs
	docker logs -f $(IMAGE_NAME)

docker-shell: ## Open a shell inside the running container
	docker exec -it $(IMAGE_NAME) sh

docker-rebuild: docker-stop ## Rebuild and restart
	docker-build
	docker-run

docker-clean: docker-stop ## Remove the image as well
	-docker rmi $(IMAGE_NAME):$(IMAGE_TAG)
