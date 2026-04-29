const { Client } = require('pg');
const connectionString = 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';
const client = new Client({
    connectionString: connectionString,
    ssl: { rejectUnauthorized: false }
});

async function main() {
    await client.connect();
    
    // Check if Parent exists in users table with P- prefix
    const count = await client.query("SELECT * FROM users LIMIT 3");
    console.log('Limit 3 in users table:', count.rows);

    await client.end();
}
main().catch(console.error);
