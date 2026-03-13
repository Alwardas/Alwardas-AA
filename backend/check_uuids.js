const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT id, name FROM subjects WHERE id ~ '^[0-9a-f]{8}-[0-9a-f]{4}' LIMIT 5");
        console.log("Subjects with UUID-like IDs:", res.rows);
        
        const res2 = await client.query("SELECT DISTINCT subject_id FROM lesson_plan_items WHERE subject_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}' LIMIT 5");
        console.log("LP items with UUID-like subject_ids:", res2.rows);
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
