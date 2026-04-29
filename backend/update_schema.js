const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        await client.query(`
            ALTER TABLE course_subjects ADD COLUMN IF NOT EXISTS subject_code VARCHAR(100);
        `);
        console.log("Column subject_code added to course_subjects.");
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
