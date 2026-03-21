const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const tables = ['faculty_subjects', 'lesson_plan_items', 'lesson_plan_progress', 'lesson_schedule'];
        for (const table of tables) {
            const res = await client.query(`SELECT column_name FROM information_schema.columns WHERE table_name = '${table}'`);
            console.log(`${table} Columns:`, res.rows.map(r => r.column_name));
        }
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
