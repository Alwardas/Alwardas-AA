const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        // Sample some subjects from the HOD's branch
        const res = await client.query("SELECT id, name FROM subjects WHERE branch = 'Computer Engineering' LIMIT 10");
        for (let s of res.rows) {
            const res2 = await client.query("SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = $1", [s.id]);
            console.log(`Subject: ${s.id} (${s.name}), Topic Count: ${res2.rows[0].count}`);
        }
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
