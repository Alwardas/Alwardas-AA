const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        await client.query("ALTER TABLE lesson_schedule ADD COLUMN IF NOT EXISTS section TEXT");
        console.log("Added section column to lesson_schedule");
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
