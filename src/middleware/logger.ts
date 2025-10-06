import { FastifyInstance, FastifyRequest } from "fastify";
import fp from "fastify-plugin";

async function logger(fastify: FastifyInstance) {
  fastify.addHook("onRequest", async (request: FastifyRequest) => {
    console.log(`${request.method} ${request.url}`);
  });
}

export { logger };
export default fp(logger);
