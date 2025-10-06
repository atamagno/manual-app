import Fastify from "fastify";
import dotenv from "dotenv";
import healthRoutes from "./routes/health";
import { logger } from "./middleware/logger";

dotenv.config();

const port = parseInt(process.env.PORT || "3000");
const logLevel = process.env.LOG_LEVEL || "info";

const fastify = Fastify({
  logger: { level: logLevel },
});

// Start the server
const start = async () => {
  try {
    // Register middleware
    await fastify.register(logger);

    // Register routes
    await fastify.register(healthRoutes, { prefix: "/api/health" });

    await fastify.listen({ port, host: "0.0.0.0" });
    console.log(`Server running at http://localhost:${port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
