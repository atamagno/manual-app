import Fastify from "fastify";
import healthRoutes from "../routes/health";
import { describe, it, expect } from "@jest/globals";

describe("Health endpoint", () => {
  it("should return OK", async () => {
    const fastify = Fastify();

    await fastify.register(healthRoutes, { prefix: "/api/health" });

    const response = await fastify.inject({
      method: "GET",
      url: "/api/health",
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.status).toBe("OK");

    await fastify.close();
  });
});
