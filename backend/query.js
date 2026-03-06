const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: { rejectUnauthorized: false }
});

client.connect()
    .then(() => {
        return client.query("SELECT * FROM users WHERE login_id = '24634-CM-026'");
    })
    .then(res => {
        console.log("Data for 24634-CM-026:", res.rows[0]);
        client.end();
    })
    .catch(err => {
        console.error(err);
        client.end();
    });
