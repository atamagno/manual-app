import request from "supertest";
import express from "express";
import healthRoutes from "../routes/health";
import { describe, it, expect } from "@jest/globals";

const app = express();
app.use("/api/health", healthRoutes);

describe("Health endpoint", () => {
  it("should return OK", async () => {
    const res = await request(app).get("/api/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("OK");
  });
});
