const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        try {
            await client.query("ALTER TABLE subjects ADD COLUMN IF NOT EXISTS course_id TEXT");
            await client.query("UPDATE subjects SET course_id = 'C-23' WHERE course_id IS NULL");
            console.log("Subjects table updated with course_id 'C-23'");
        } catch (e) {
            console.error("Error updating subjects:", e);
        }
        
        try {
            await client.query("ALTER TABLE course_subjects ADD COLUMN IF NOT EXISTS course_id TEXT");
            await client.query("UPDATE course_subjects SET course_id = 'C-23' WHERE course_id IS NULL");
            console.log("Course Subjects table updated with course_id 'C-23'");
        } catch (e) {
            console.error("Error updating course_subjects:", e);
        }

        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
