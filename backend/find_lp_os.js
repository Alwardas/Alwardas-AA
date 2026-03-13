const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT DISTINCT subject_id FROM lesson_plan_items WHERE topic ILIKE '%Operating System%' OR topic ILIKE '%OS%' LIMIT 10");
        console.log("LP Subject IDs for OS:", res.rows.map(r => r.subject_id));
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
