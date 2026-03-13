const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT id, subject_name FROM course_subjects WHERE subject_code IS NULL OR subject_code = ''");
        console.log("Course subjects with mission codes:", res.rows);
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
