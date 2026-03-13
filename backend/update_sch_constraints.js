const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        await client.query("ALTER TABLE lesson_schedule DROP CONSTRAINT IF EXISTS lesson_schedule_subject_id_topic_id_key");
        await client.query("ALTER TABLE lesson_schedule ADD CONSTRAINT lesson_schedule_subject_topic_section_branch_key UNIQUE (subject_id, topic_id, section, branch)");
        console.log("Updated lesson_schedule constraints to support per-section schedules");
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
