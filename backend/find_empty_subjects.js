const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query(`
            SELECT s.branch, s.semester, s.id, s.name, (SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = s.id) as lp_count
            FROM subjects s
            WHERE (SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = s.id) = 0
            LIMIT 50
        `);
        console.log("Subjects with NO lesson plans:", res.rows);
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
