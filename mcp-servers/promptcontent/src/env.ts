import dotenv from "dotenv"
import path from "path"

// Load environment variables from the project-local .env file.
dotenv.config({ path: path.resolve(__dirname, "..", ".env") })
