const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        // Backfill subject_code from subjects table where it matches subject_name and branch
        const res = await client.query(`
            UPDATE course_subjects cs
            SET subject_code = s.id::text
            FROM subjects s
            WHERE cs.subject_name = s.name 
            AND (cs.branch = s.branch OR s.branch IS NULL OR cs.branch LIKE '%' || s.branch || '%')
            AND cs.subject_code IS NULL;
        `);
        console.log(`Backfilled ${res.rowCount} records.`);
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
