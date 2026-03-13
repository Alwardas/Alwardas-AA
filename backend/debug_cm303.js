const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = 'CM-303'");
        console.log("Count for CM-303:", res.rows[0].count);
        
        const res2 = await client.query("SELECT DISTINCT subject_id FROM lesson_plan_items WHERE subject_id LIKE 'CM-30%'");
        console.log("Subject IDs starting with CM-30 in LP items:", res2.rows.map(r => r.subject_id));
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
