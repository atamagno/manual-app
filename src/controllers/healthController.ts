import { Request, Response } from "express";

export const getHealth = (req: Request, res: Response) => {
  res.json({ status: "OK", uptime: process.uptime() });
};
