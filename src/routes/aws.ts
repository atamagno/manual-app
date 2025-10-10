import { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";

// ECS Task Metadata interfaces
interface ECSTaskMetadata {
  Family: string;
  Revision: string;
  TaskARN: string;
  Cluster: string;
  AvailabilityZone: string;
  DesiredStatus: string;
  KnownStatus: string;
  PullStartedAt?: string;
  PullStoppedAt?: string;
  CreatedAt: string;
  StartedAt?: string;
}

interface ECSContainerMetadata {
  DockerId: string;
  Name: string;
  DockerName: string;
  Image: string;
  ImageID: string;
  CreatedAt: string;
  StartedAt?: string;
  Type: string;
  Networks?: Record<string, unknown>;
  Health?: Record<string, unknown>;
}

interface ECSTaskStatsMetadata {
  cpu?: Record<string, unknown>;
  memory?: Record<string, unknown>;
  read?: string;
}

// AWS ECS Task metadata endpoint routes
export default async function awsRoutes(fastify: FastifyInstance) {
  // Get current availability zone from ECS task metadata
  fastify.get(
    "/aws/availability-zone",
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        // ECS Task Metadata Endpoint V4 - get task metadata
        const metadataUriV4 = process.env.ECS_CONTAINER_METADATA_URI_V4;

        if (!metadataUriV4) {
          throw new Error("ECS_CONTAINER_METADATA_URI_V4 not available");
        }

        // Get task metadata
        const taskResponse = await fetch(`${metadataUriV4}/task`);

        if (!taskResponse.ok) {
          throw new Error("Failed to fetch ECS task metadata");
        }

        const taskData = (await taskResponse.json()) as ECSTaskMetadata;
        const availabilityZone = taskData.AvailabilityZone;

        return {
          status: "success",
          availabilityZone,
          timestamp: new Date().toISOString(),
          message: `Running in availability zone: ${availabilityZone}`,
          source: "ECS Task Metadata",
        };
      } catch (error) {
        fastify.log.error(
          { error },
          "Error fetching availability zone from ECS"
        );

        // Fallback: try to get from container metadata
        try {
          const metadataUriV4 = process.env.ECS_CONTAINER_METADATA_URI_V4;
          if (metadataUriV4) {
            const containerResponse = await fetch(metadataUriV4);
            if (containerResponse.ok) {
              const containerData =
                (await containerResponse.json()) as ECSContainerMetadata;
              // Container metadata doesn't have AZ, but we can indicate ECS
              return {
                status: "partial",
                availabilityZone: "unknown",
                timestamp: new Date().toISOString(),
                message:
                  "Running on ECS but availability zone not available from container metadata",
                source: "ECS Container Metadata",
                containerName: containerData.Name || "unknown",
              };
            }
          }
        } catch (fallbackError) {
          fastify.log.error(
            { error: fallbackError },
            "Fallback ECS metadata also failed"
          );
        }

        // Return error response when not running on ECS or when metadata is unavailable
        return reply.status(503).send({
          status: "error",
          availabilityZone: "unknown",
          timestamp: new Date().toISOString(),
          message:
            "Unable to determine availability zone - not running on ECS or metadata service unavailable",
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }
  );

  // Get comprehensive ECS task and container metadata
  fastify.get(
    "/aws/metadata",
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const metadataUriV4 = process.env.ECS_CONTAINER_METADATA_URI_V4;

        if (!metadataUriV4) {
          throw new Error("ECS_CONTAINER_METADATA_URI_V4 not available");
        }

        // Get both task and container metadata
        const [taskResponse, containerResponse] = await Promise.all([
          fetch(`${metadataUriV4}/task`),
          fetch(metadataUriV4),
        ]);

        const metadata: Record<string, any> = {};

        // Process task metadata
        if (taskResponse.ok) {
          const taskData = (await taskResponse.json()) as ECSTaskMetadata;
          metadata.task = {
            family: taskData.Family,
            revision: taskData.Revision,
            taskArn: taskData.TaskARN,
            clusterName: taskData.Cluster,
            availabilityZone: taskData.AvailabilityZone,
            desiredStatus: taskData.DesiredStatus,
            knownStatus: taskData.KnownStatus,
            pullStartedAt: taskData.PullStartedAt,
            pullStoppedAt: taskData.PullStoppedAt,
            createdAt: taskData.CreatedAt,
            startedAt: taskData.StartedAt,
          };
        }

        // Process container metadata
        if (containerResponse.ok) {
          const containerData =
            (await containerResponse.json()) as ECSContainerMetadata;
          metadata.container = {
            dockerID: containerData.DockerId,
            name: containerData.Name,
            dockerName: containerData.DockerName,
            image: containerData.Image,
            imageID: containerData.ImageID,
            createdAt: containerData.CreatedAt,
            startedAt: containerData.StartedAt,
            type: containerData.Type,
            networks: containerData.Networks,
            health: containerData.Health,
          };
        }

        // Get task stats if available
        try {
          const statsResponse = await fetch(`${metadataUriV4}/task/stats`);
          if (statsResponse.ok) {
            const statsData =
              (await statsResponse.json()) as ECSTaskStatsMetadata;
            metadata.stats = {
              cpu: statsData.cpu,
              memory: statsData.memory,
              timestamp: statsData.read,
            };
          }
        } catch (statsError) {
          fastify.log.warn({ error: statsError }, "Could not fetch task stats");
        }

        return {
          status: "success",
          metadata,
          timestamp: new Date().toISOString(),
          message: "ECS task and container metadata retrieved successfully",
          source: "ECS Task Metadata Endpoint V4",
        };
      } catch (error) {
        fastify.log.error({ error }, "Error fetching ECS metadata");

        return reply.status(503).send({
          status: "error",
          metadata: {},
          timestamp: new Date().toISOString(),
          message:
            "Unable to retrieve ECS metadata - not running on ECS or metadata service unavailable",
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }
  );

  // Get ECS task statistics
  fastify.get(
    "/aws/stats",
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const metadataUriV4 = process.env.ECS_CONTAINER_METADATA_URI_V4;

        if (!metadataUriV4) {
          throw new Error("ECS_CONTAINER_METADATA_URI_V4 not available");
        }

        const statsResponse = await fetch(`${metadataUriV4}/task/stats`);

        if (!statsResponse.ok) {
          throw new Error("Failed to fetch ECS task stats");
        }

        const statsData = await statsResponse.json();

        return {
          status: "success",
          stats: statsData,
          timestamp: new Date().toISOString(),
          message: "ECS task statistics retrieved successfully",
        };
      } catch (error) {
        fastify.log.error({ error }, "Error fetching ECS stats");

        return reply.status(503).send({
          status: "error",
          stats: {},
          timestamp: new Date().toISOString(),
          message:
            "Unable to retrieve ECS stats - not running on ECS or stats unavailable",
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }
  );
}
