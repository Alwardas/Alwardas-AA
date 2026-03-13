const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT subject_id, COUNT(*) FROM lesson_plan_items GROUP BY subject_id");
        console.log(JSON.stringify(res.rows, null, 2));
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
