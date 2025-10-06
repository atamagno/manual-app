import { FastifyRequest, FastifyReply } from "fastify";

export const getHealth = async (
  request: FastifyRequest,
  reply: FastifyReply
) => {
  return reply.send({ status: "OK", uptime: process.uptime() });
};
