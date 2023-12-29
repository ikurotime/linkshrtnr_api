CREATE TABLE "User" (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE "Links" (
  id SERIAL PRIMARY KEY,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  original_url VARCHAR(255),
  short_url VARCHAR(255),
  userId INTEGER REFERENCES "User"(id) ON DELETE SET NULL
);
CREATE TABLE "QRCodes" (
  id SERIAL PRIMARY KEY,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  qr_code TEXT,
  userId INTEGER REFERENCES "User"(id) ON DELETE SET NULL
);
