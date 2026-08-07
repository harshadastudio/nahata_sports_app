require('dotenv').config();

/**
 * Connection pool tuning.
 *
 * The database is remote (DB_HOST is a network host, not localhost), so a cold
 * TCP+Postgres handshake costs ~280ms while a warm query is ~15ms. With the
 * Sequelize defaults (min: 0), idle connections close after 10s, so intermittent
 * traffic pays the handshake penalty on almost every request — and every page
 * runs several sequential queries (auth middleware + controller lookups), so the
 * cost stacks up and the UI feels sluggish.
 *
 * Keeping a couple of warm connections alive (min: 2) and enabling TCP keepAlive
 * removes that recurring penalty. A larger max + shorter acquire timeout avoids
 * the 60s "stuck loading" stall when the pool is briefly contended.
 */
const pool = {
  max: Number(process.env.DB_POOL_MAX) || 15,
  min: Number(process.env.DB_POOL_MIN) || 2,
  acquire: Number(process.env.DB_POOL_ACQUIRE) || 15000,
  idle: Number(process.env.DB_POOL_IDLE) || 30000,
  evict: 10000,
};

const baseConfig = {
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  dialect: "postgres",
  // Sequelize logs every SQL statement to console by default. That's a
  // synchronous stdout write on every query — set DB_LOGGING=true only when
  // actively debugging.
  logging: process.env.DB_LOGGING === 'true' ? console.log : false,
  pool,
  dialectOptions: {
    // Keep the TCP socket alive so warm connections aren't dropped by the
    // network/NAT between requests (which would force a fresh ~280ms handshake).
    keepAlive: true,
    ssl: process.env.DB_SSL === 'true' ? {
      require: true,
      rejectUnauthorized: false
    } : false
  }
};

const neonConfig = { ...baseConfig };

module.exports = {
  development: { ...baseConfig },
  staging: neonConfig,
  production: neonConfig,
};