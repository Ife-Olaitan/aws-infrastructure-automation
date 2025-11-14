const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'database',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'appdb',
    user: process.env.DB_USER || 'dbadmin',
    password: process.env.DB_PASSWORD || 'changeme',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint - IMPORTANT for ALB!
app.get('/health', async (req, res) => {
    try {
        // Check database connection
        await pool.query('SELECT 1');
        res.status(200).json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            database: 'connected'
        });
    } catch (error) {
        console.error('Health check failed:', error);
        res.status(503).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            database: 'disconnected',
            error: error.message
        });
    }
});

// Health check endpoint - Same as /health but under /api for frontend
app.get('/api/health', async (req, res) => {
    try {
        // Check database connection
        await pool.query('SELECT 1');
        res.status(200).json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            database: 'connected'
        });
    } catch (error) {
        console.error('Health check failed:', error);
        res.status(503).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            database: 'disconnected',
            error: error.message
        });
    }
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'AWS Infrastructure Automation - Backend API',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            users: '/api/users',
            info: '/api/info'
        }
    });
});

// Get users from database
app.get('/api/users', async (req, res) => {
    try {
        const result = await pool.query('SELECT id, username, email, created_at FROM users ORDER BY id');
        res.json({
            success: true,
            count: result.rows.length,
            users: result.rows
        });
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({
            success: false,
            error: 'Database error',
            message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
        });
    }
});

// System info endpoint
app.get('/api/info', (req, res) => {
    res.json({
        success: true,
        info: {
            environment: process.env.NODE_ENV || 'production',
            hostname: require('os').hostname(),
            platform: process.platform,
            uptime: process.uptime(),
            memory: process.memoryUsage()
        }
    });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        error: 'Something went wrong!',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Backend server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'production'}`);
    console.log(`Database: ${process.env.DB_HOST || 'database'}:${process.env.DB_PORT || 5432}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    pool.end(() => {
        console.log('Database pool closed');
        process.exit(0);
    });
});