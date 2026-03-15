const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:Alwardas-Polytechnic%402025@db.eyvpvrfadrgnewxslxzo.supabase.co:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});

client.connect()
    .then(() => {
        console.log("Direct connection successful!");
        return client.query("SELECT id FROM users LIMIT 1");
    })
    .then(res => {
        console.log("User ID:", res.rows[0].id);
        client.end();
    })
    .catch(err => {
        console.error("Direct connection failed:", err.message);
        client.end();
    });
