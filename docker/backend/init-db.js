const { Pool } = require('pg');

// Database connection with SSL
const pool = new Pool({
    host: process.env.DB_HOST || 'database',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'appdb',
    user: process.env.DB_USER || 'dbadmin',
    password: process.env.DB_PASSWORD || 'changeme',
    ssl: {
        rejectUnauthorized: false
    }
});

async function initializeDatabase() {
    try {
        console.log('🔄 Initializing database schema...');

        // Create users table
        await pool.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        console.log('✅ Users table created/verified');

        // Create index on email for faster lookups
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
        `);

        console.log('✅ Email index created/verified');

        // Create function to update the updated_at timestamp
        await pool.query(`
            CREATE OR REPLACE FUNCTION update_updated_at_column()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ language 'plpgsql';
        `);

        // Create trigger to automatically update updated_at
        await pool.query(`
            DROP TRIGGER IF EXISTS update_users_updated_at ON users;
            CREATE TRIGGER update_users_updated_at
                BEFORE UPDATE ON users
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
        `);

        console.log('✅ Triggers created/verified');

        // Insert sample data
        await pool.query(`
            INSERT INTO users (username, email) VALUES
                ('john_doe', 'john@example.com'),
                ('jane_smith', 'jane@example.com'),
                ('bob_jones', 'bob@example.com'),
                ('alice_williams', 'alice@example.com'),
                ('charlie_brown', 'charlie@example.com')
            ON CONFLICT (username) DO NOTHING;
        `);

        console.log('✅ Sample data inserted');
        console.log('✅ Database initialization complete');

    } catch (error) {
        console.error('❌ Database initialization failed:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

// Run if executed directly
if (require.main === module) {
    initializeDatabase()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
}

module.exports = initializeDatabase;
