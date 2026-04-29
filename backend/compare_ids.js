const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT id FROM subjects WHERE name ILIKE '%Mathematics%' LIMIT 10");
        console.log("Subject IDs:", res.rows.map(r => r.id));
        
        const res2 = await client.query("SELECT DISTINCT subject_id FROM lesson_plan_items WHERE topic ILIKE '%Mathematics%' OR topic ILIKE '%Algebra%' LIMIT 10");
        console.log("LP Subject IDs:", res2.rows.map(r => r.subject_id));
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
