import express from "express";
import dotenv from "dotenv";
import healthRoutes from "./routes/health";
import { logger } from "./middleware/logger";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(logger);

// Routes
app.use("/api/health", healthRoutes);

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
