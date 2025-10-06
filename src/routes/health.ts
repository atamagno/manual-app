import { FastifyInstance } from "fastify";
import { getHealth } from "../controllers/healthController";

async function healthRoutes(fastify: FastifyInstance) {
  fastify.get("/", getHealth);
}

export default healthRoutes;
