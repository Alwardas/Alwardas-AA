const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});

client.connect()
    .then(() => {
        return client.query("SELECT id FROM users LIMIT 1");
    })
    .then(res => {
        console.log("Valid user ID:", res.rows[0].id);
        client.end();
    })
    .catch(err => {
        console.error(err);
        client.end();
    });
