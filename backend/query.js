const { Client } = require('pg');
const connectionString = 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require';

const client = new Client({
    connectionString: connectionString,
    ssl: { rejectUnauthorized: false }
});

async function main() {
    await client.connect();
    const res = await client.query("SELECT id, login_id, full_name, email, phone_number, dob FROM users WHERE role = 'Student' LIMIT 5");
    console.log(res.rows);
    const user = await client.query("SELECT * FROM users WHERE login_id = 'A25P001' OR login_id = 'A26P001' LIMIT 1");
    console.log("Specific User:", user.rows);
    await client.end();
}
main().catch(console.error);
