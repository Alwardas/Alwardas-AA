const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT DISTINCT subject_id FROM lesson_plan_items WHERE subject_id ILIKE 'CM-303%'");
        console.log("Distinct subject_id like CM-303:", res.rows);
        
        const res2 = await client.query("SELECT * FROM lesson_plan_items WHERE subject_id = 'CM-303' LIMIT 5");
        console.log("Samples for CM-303:", res2.rows);
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
