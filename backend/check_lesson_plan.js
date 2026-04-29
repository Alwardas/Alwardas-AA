const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT subject_id, topic FROM lesson_plan_items LIMIT 5");
        console.log(JSON.stringify(res.rows, null, 2));
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
